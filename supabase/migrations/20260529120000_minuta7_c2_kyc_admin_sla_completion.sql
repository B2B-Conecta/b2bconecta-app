-- Minuta #7 C2 (cierre): RPCs KYC aliado/importador, notificación admin, deep link SLA.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public._notify_admins_kyc_review (
  p_profile_id uuid,
  p_business_name text,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, title, body, type, related_id)
  select
    adm.id,
    'KYC · documentación pendiente',
    format(
      '%s (%s) envió documentación a revisión MotoLink.',
      coalesce(nullif(trim(p_business_name), ''), 'Sin nombre'),
      coalesce(nullif(trim(p_role), ''), 'B2B')
    ),
    'kyc',
    p_profile_id::text
  from public.profiles adm
  where adm.role = 'administrador'::text;
end;
$$;

-- ---------------------------------------------------------------------------
-- Usuario B2B: enviar expediente a revisión (aliado o importador)
-- ---------------------------------------------------------------------------
create or replace function public.profile_submit_kyc_for_review ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_name text;
  v_pce int;
  c_entregas_req constant int := 3;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role, nullif(trim(p.business_name), ''), coalesce(p.primeros_pedidos_contado_entregados, 0)
    into v_role, v_name, v_pce
  from public.profiles p
  where p.id = v_uid;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;

  if v_role not in ('aliado'::text, 'importador'::text) then
    raise exception 'Solo aliados e importadores pueden enviar documentación KYC.';
  end if;

  if v_role = 'aliado' and v_pce < c_entregas_req then
    raise exception
      'Complete la fase inicial de pedidos en contado antes de enviar la documentación a revisión.';
  end if;

  if not exists (
    select 1
    from public.profile_documents pd
    where pd.profile_id = v_uid
      and pd.is_current = true
  ) then
    raise exception 'Suba al menos un documento antes de enviar a revisión.';
  end if;

  update public.profiles
  set kyc_status = 'en_revision'::text
  where id = v_uid;

  update public.profile_documents
  set
    review_status = 'en_revision'::text,
    review_note = null,
    reviewed_at = null,
    reviewed_by = null
  where profile_id = v_uid
    and is_current = true
    and coalesce(review_status, 'pendiente') in ('pendiente'::text, 'rechazado'::text);

  perform public._notify_admins_kyc_review (v_uid, v_name, v_role);
end;
$$;

grant execute on function public.profile_submit_kyc_for_review () to authenticated;

create or replace function public.aliado_submit_kyc_for_review ()
returns void
language sql
security definer
set search_path = public
as $$
  select public.profile_submit_kyc_for_review ();
$$;

grant execute on function public.aliado_submit_kyc_for_review () to authenticated;

-- ---------------------------------------------------------------------------
-- Admin: estado KYC global del perfil
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_profile_kyc_status (
  p_profile_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_st text;
begin
  perform public._assert_administrador ();

  v_st := lower(trim(p_status));
  if v_st is null or v_st = '' then
    raise exception 'Estado KYC requerido';
  end if;

  if v_st not in ('pendiente', 'en_revision', 'aprobado', 'rechazado') then
    raise exception 'Estado KYC no válido';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = p_profile_id;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;

  if v_role not in ('aliado'::text, 'importador'::text) then
    raise exception 'Solo aplica a perfiles aliado o importador';
  end if;

  update public.profiles
  set kyc_status = v_st
  where id = p_profile_id;
end;
$$;

grant execute on function public.admin_set_profile_kyc_status (uuid, text) to authenticated;

create or replace function public.admin_set_aliado_kyc_status (
  p_aliado_id uuid,
  p_status text
)
returns void
language sql
security definer
set search_path = public
as $$
  select public.admin_set_profile_kyc_status (p_aliado_id, p_status);
$$;

grant execute on function public.admin_set_aliado_kyc_status (uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin: revisión por documento
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_profile_document_review_status (
  p_profile_id uuid,
  p_doc_type text,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_st text;
  v_doc_id uuid;
begin
  perform public._assert_administrador ();

  v_st := lower(trim(p_status));
  if v_st not in ('pendiente', 'en_revision', 'aprobado', 'rechazado') then
    raise exception 'Estado de revisión no válido';
  end if;

  if v_st = 'rechazado' and (p_note is null or length(trim(p_note)) < 3) then
    raise exception 'Indique el motivo del rechazo (mínimo 3 caracteres).';
  end if;

  select pd.id
    into v_doc_id
  from public.profile_documents pd
  where pd.profile_id = p_profile_id
    and pd.doc_type = trim(p_doc_type)
    and pd.is_current = true
  order by pd.created_at desc
  limit 1;

  if v_doc_id is null then
    raise exception 'No hay documento vigente de ese tipo para este perfil.';
  end if;

  update public.profile_documents
  set
    review_status = v_st,
    review_note = case when v_st = 'rechazado' then trim(p_note) else null end,
    reviewed_at = now(),
    reviewed_by = auth.uid ()
  where id = v_doc_id;
end;
$$;

grant execute on function public.admin_set_profile_document_review_status (uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- SLA 12 h: related_id = id de pedido ancla (deep link en app)
-- ---------------------------------------------------------------------------
create or replace function public.run_importer_sla_admin_alerts ()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  v_count int := 0;
  v_imp_name text;
  v_anchor_tr uuid;
begin
  perform set_config ('row_security', 'off', true);

  for rec in
    select
      tr.checkout_group_id,
      tr.importador_id,
      min(tr.created_at) as first_pending_at
    from public.transaction_requests tr
    where tr.status = 'pendiente'::text
      and tr.checkout_group_id is not null
    group by tr.checkout_group_id, tr.importador_id
    having min(tr.created_at) + interval '12 hours' < now ()
  loop
    if exists (
      select 1
      from public.sla_importer_pending_alert_sent s
      where s.checkout_group_id = rec.checkout_group_id
        and s.importador_id = rec.importador_id
    ) then
      continue;
    end if;

    insert into public.sla_importer_pending_alert_sent (
      checkout_group_id,
      importador_id
    )
    values (rec.checkout_group_id, rec.importador_id);

    select tr.id
      into v_anchor_tr
    from public.transaction_requests tr
    where tr.checkout_group_id = rec.checkout_group_id
      and tr.importador_id = rec.importador_id
      and tr.status = 'pendiente'::text
    order by tr.created_at, tr.id
    limit 1;

    select nullif(trim(p.business_name), '')
    into v_imp_name
    from public.profiles p
    where p.id = rec.importador_id;

    insert into public.notifications (
      user_id, title, body, type, related_id
    )
    select
      adm.id,
      'Supervisión · SLA proveedor (12 h)',
      format(
        'El importador %s no confirmó el carrito en más de 12 h (ref. %s).',
        coalesce(v_imp_name, 'sin nombre'),
        substring(rec.checkout_group_id::text, 1, 8) || '…'
      ),
      'supervision',
      coalesce(v_anchor_tr::text, rec.checkout_group_id::text)
    from public.profiles adm
    where adm.role = 'administrador'::text;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.run_importer_sla_admin_alerts () to service_role;
