-- Fase 3: bloqueo expired_locked, solicitud de reactivación (ticket + admin), sync al login.

-- ---------------------------------------------------------------------------
-- 1) Categoría de soporte: reactivación emprendedor
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.support_tickets'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%category%'
  loop
    execute format(
      'alter table public.support_tickets drop constraint %I',
      r.conname
    );
  end loop;
end $$;

alter table public.support_tickets
  add constraint support_tickets_category_check
  check (
    category = any (
      array[
        'cuenta'::text,
        'pedido'::text,
        'pago'::text,
        'kyc'::text,
        'plataforma'::text,
        'otro'::text,
        'reactivacion_emprendedor'::text
      ]
    )
  );

create or replace function public.create_support_ticket (
  p_subject text,
  p_category text,
  p_body text,
  p_related_transaction_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_open_count integer;
  v_ticket_id uuid;
  v_subject text := trim(p_subject);
  v_body text := trim(p_body);
  v_category text := trim(coalesce(p_category, 'otro'));
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role not in ('aliado', 'importador') then
    raise exception 'Solo aliados e importadores pueden abrir reclamos.';
  end if;

  if char_length(v_subject) < 3 then
    raise exception 'El asunto debe tener al menos 3 caracteres.';
  end if;

  if char_length(v_body) < 3 then
    raise exception 'El mensaje debe tener al menos 3 caracteres.';
  end if;

  if v_category not in (
    'cuenta',
    'pedido',
    'pago',
    'kyc',
    'plataforma',
    'otro',
    'reactivacion_emprendedor'
  ) then
    raise exception 'Categoría no válida.';
  end if;

  select count(*)::integer
    into v_open_count
  from public.support_tickets st
  where st.created_by = v_uid
    and st.status <> 'cerrado';

  -- Reactivación emprendedor no cuenta contra el tope de 3 (flujo operativo).
  if v_category <> 'reactivacion_emprendedor' and v_open_count >= 3 then
    raise exception
      'Ya tiene 3 reclamos abiertos. Cierre uno antes de abrir otro.';
  end if;

  if p_related_transaction_request_id is not null then
    if not exists (
      select 1
      from public.transaction_requests tr
      where tr.id = p_related_transaction_request_id
        and (
          tr.aliado_id = v_uid
          or tr.importador_id = v_uid
        )
    ) then
      raise exception 'El pedido vinculado no pertenece a su cuenta.';
    end if;
  end if;

  insert into public.support_tickets (
    created_by,
    author_role,
    subject,
    category,
    status,
    related_transaction_request_id
  )
  values (
    v_uid,
    v_role,
    v_subject,
    v_category,
    'abierto',
    p_related_transaction_request_id
  )
  returning id into v_ticket_id;

  insert into public.support_ticket_messages (
    ticket_id,
    author_id,
    author_role,
    body
  )
  values (
    v_ticket_id,
    v_uid,
    v_role,
    v_body
  );

  return v_ticket_id;
end;
$$;

revoke all on function public.create_support_ticket (text, text, text, uuid) from public;
grant execute on function public.create_support_ticket (text, text, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Sync de expiración al iniciar sesión (idempotente para el usuario actual)
-- ---------------------------------------------------------------------------
create or replace function public.sync_my_entrepreneur_expiry ()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_prof public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  select * into v_prof from public.profiles where id = v_uid;
  if not found then
    return null;
  end if;

  if coalesce(v_prof.retailer_tier, '') <> 'entrepreneur' then
    return v_prof.entrepreneur_status;
  end if;

  if coalesce(v_prof.entrepreneur_status, '') = 'kyc_in_progress'
     and v_prof.kyc_completion_deadline is not null
     and v_prof.kyc_completion_deadline < now()
     and not public.entrepreneur_deferred_docs_complete(v_uid)
  then
    perform set_config('b2b.profile_privilege_ok', '1', true);

    update public.profiles
    set entrepreneur_status = 'expired_locked'
    where id = v_uid
      and entrepreneur_status = 'kyc_in_progress';

    perform public.mc_insert_notification(
      v_uid,
      'Plazo de documentación vencido',
      'Tu expediente de 8 semanas venció. Puedes seguir subiendo documentos '
        || 'y solicitar reactivación con un asesor.',
      'entrepreneur',
      v_uid::text
    );

    perform public._notify_admins_entrepreneur(
      'Emprendedor: KYC vencido',
      coalesce(nullif(btrim(v_prof.business_name), ''), 'Minorista')
        || ' no completó el expediente en 8 semanas.',
      v_uid::text
    );

    return 'expired_locked';
  end if;

  return v_prof.entrepreneur_status;
end;
$$;

revoke all on function public.sync_my_entrepreneur_expiry () from public;
grant execute on function public.sync_my_entrepreneur_expiry () to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Solicitud de reactivación → ticket + estado + notificación admin
-- ---------------------------------------------------------------------------
create or replace function public.request_entrepreneur_reactivation ()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_prof public.profiles%rowtype;
  v_ticket_id uuid;
  v_existing uuid;
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  select * into v_prof from public.profiles where id = v_uid;
  if not found then
    raise exception 'Perfil no encontrado.';
  end if;

  if coalesce(v_prof.retailer_tier, '') <> 'entrepreneur' then
    raise exception 'Solo aplica a Minorista-Emprendedor.';
  end if;

  if coalesce(v_prof.entrepreneur_status, '') not in (
    'expired_locked',
    'reactivation_requested'
  ) then
    raise exception 'Tu cuenta no está en estado de reactivación.';
  end if;

  -- Reutilizar ticket abierto de reactivación si ya existe.
  select st.id
    into v_existing
  from public.support_tickets st
  where st.created_by = v_uid
    and st.category = 'reactivacion_emprendedor'
    and st.status <> 'cerrado'
  order by st.created_at desc
  limit 1;

  if v_existing is not null then
    perform set_config('b2b.profile_privilege_ok', '1', true);
    update public.profiles
    set entrepreneur_status = 'reactivation_requested'
    where id = v_uid
      and entrepreneur_status is distinct from 'reactivation_requested';
    return v_existing;
  end if;

  v_ticket_id := public.create_support_ticket(
    'Reactivación de Cuenta Emprendedor',
    'reactivacion_emprendedor',
    'Solicito reactivación de mi cuenta Minorista-Emprendedor tras el vencimiento '
      || 'del plazo de 8 semanas de documentación comercial. '
      || 'Negocio: '
      || coalesce(nullif(btrim(v_prof.business_name), ''), '—')
      || '. Quedo atento a verificación, prórroga o habilitación.',
    null
  );

  perform set_config('b2b.profile_privilege_ok', '1', true);

  update public.profiles
  set entrepreneur_status = 'reactivation_requested'
  where id = v_uid;

  perform public._notify_admins_entrepreneur(
    'Solicitud de reactivación emprendedor',
    coalesce(nullif(btrim(v_prof.business_name), ''), 'Minorista')
      || ' solicitó reactivar su cuenta. Revisar ticket de soporte.',
    v_ticket_id::text,
    'soporte'
  );

  return v_ticket_id;
end;
$$;

revoke all on function public.request_entrepreneur_reactivation () from public;
grant execute on function public.request_entrepreneur_reactivation () to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Admin: prórroga KYC emprendedor (vuelve a kyc_in_progress)
-- ---------------------------------------------------------------------------
create or replace function public.admin_extend_entrepreneur_kyc (
  p_aliado_id uuid,
  p_extra_days integer default 14
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_days integer := greatest(1, least(coalesce(p_extra_days, 14), 56));
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if coalesce(v_role, '') <> 'administrador' then
    raise exception 'Solo administradores.';
  end if;

  perform set_config('b2b.profile_privilege_ok', '1', true);

  update public.profiles
  set
    entrepreneur_status = 'kyc_in_progress',
    kyc_completion_deadline = now() + make_interval(days => v_days)
  where id = p_aliado_id
    and retailer_tier = 'entrepreneur'
    and entrepreneur_status in ('expired_locked', 'reactivation_requested');

  if not found then
    raise exception 'No hay cuenta emprendedora bloqueada para prorrogar.';
  end if;

  perform public.mc_insert_notification(
    p_aliado_id,
    'Prórroga de documentación concedida',
    'Un asesor habilitó una prórroga de '
      || v_days::text
      || ' días para completar tu expediente comercial.',
    'entrepreneur',
    p_aliado_id::text
  );
end;
$$;

revoke all on function public.admin_extend_entrepreneur_kyc (uuid, integer) from public;
grant execute on function public.admin_extend_entrepreneur_kyc (uuid, integer) to authenticated;

comment on function public.request_entrepreneur_reactivation () is
  'Fase 3: ticket de reactivación + estado reactivation_requested + aviso admin.';
comment on function public.sync_my_entrepreneur_expiry () is
  'Fase 3: al entrar, marca expired_locked si venció el plazo KYC de 8 semanas.';
