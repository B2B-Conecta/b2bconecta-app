-- Fase 2: Minorista-Emprendedor
-- Badge condicional en pedidos, transiciones de etapa, alertas y docs diferidos.

-- ---------------------------------------------------------------------------
-- 1) Badge denormalizado en pedidos (solo visible vía RLS del TR)
-- ---------------------------------------------------------------------------
alter table public.transaction_requests
  add column if not exists aliado_entrepreneur_badge boolean not null default false;

comment on column public.transaction_requests.aliado_entrepreneur_badge is
  'True si el comprador es entrepreneur con sello. Solo visible a quien pueda leer el TR '
  '(importador vinculado / admin). No se expone en perfiles públicos.';

create or replace function public._tr_set_aliado_entrepreneur_badge ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select coalesce(p.retailer_tier, 'standard') = 'entrepreneur'
     and coalesce(p.is_entrepreneur_badge, false)
    into new.aliado_entrepreneur_badge
  from public.profiles p
  where p.id = new.aliado_id;

  new.aliado_entrepreneur_badge := coalesce(new.aliado_entrepreneur_badge, false);
  return new;
end;
$$;

drop trigger if exists tr_set_aliado_entrepreneur_badge on public.transaction_requests;
create trigger tr_set_aliado_entrepreneur_badge
before insert or update of aliado_id
on public.transaction_requests
for each row
execute function public._tr_set_aliado_entrepreneur_badge ();

update public.transaction_requests tr
set aliado_entrepreneur_badge = true
from public.profiles p
where p.id = tr.aliado_id
  and p.retailer_tier = 'entrepreneur'
  and p.is_entrepreneur_badge = true
  and tr.aliado_entrepreneur_badge is distinct from true;

-- ---------------------------------------------------------------------------
-- 2) Helpers
-- ---------------------------------------------------------------------------
create or replace function public.entrepreneur_deferred_docs_complete (
  p_aliado_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select (
    select count(distinct d.doc_type)
    from public.profile_documents d
    where d.profile_id = p_aliado_id
      and d.is_current = true
      and d.review_status = 'aprobado'
      and d.doc_type = any (
        array[
          'registro_mercantil',
          'referencia_bancaria_1',
          'referencia_bancaria_2',
          'referencia_comercial'
        ]
      )
  ) >= 4;
$$;

create or replace function public._notify_admins_entrepreneur (
  p_title text,
  p_body text,
  p_related_id text,
  p_type text default 'entrepreneur'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
begin
  for v_admin in
    select id from public.profiles
    where lower(trim(coalesce(role, ''))) = 'administrador'
      and deactivated_at is null
  loop
    perform public.mc_insert_notification(
      v_admin.id,
      p_title,
      p_body,
      p_type,
      p_related_id
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Etapa A: deadline sin primera compra → pending_first_purchase_alert
-- ---------------------------------------------------------------------------
create or replace function public.entrepreneur_mark_first_purchase_alerts ()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_count integer := 0;
begin
  perform set_config('b2b.profile_privilege_ok', '1', true);

  for v_row in
    select p.id, p.business_name, p.first_purchase_deadline
    from public.profiles p
    where p.retailer_tier = 'entrepreneur'
      and p.entrepreneur_status = 'active_trial'
      and p.first_purchase_deadline is not null
      and p.first_purchase_deadline < now()
      and not exists (
        select 1
        from public.transaction_requests tr
        where tr.aliado_id = p.id
          and coalesce(tr.pago_estado_revision, '') = 'aprobado'
      )
  loop
    update public.profiles
    set entrepreneur_status = 'pending_first_purchase_alert'
    where id = v_row.id;

    perform public.mc_insert_notification(
      v_row.id,
      'Te acompañamos en tu primera compra',
      'Un asesor comercial se comunicará contigo pronto para apoyarte en tu primera compra.',
      'entrepreneur',
      v_row.id::text
    );

    perform public._notify_admins_entrepreneur(
      'Emprendedor sin primera compra',
      coalesce(nullif(btrim(v_row.business_name), ''), 'Minorista')
        || ' agotó el plazo de 5 días hábiles sin compra confirmada.',
      v_row.id::text
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.entrepreneur_mark_first_purchase_alerts () from public;
grant execute on function public.entrepreneur_mark_first_purchase_alerts () to service_role;

-- ---------------------------------------------------------------------------
-- 4) Etapa B: primer pago aprobado → kyc_in_progress
-- ---------------------------------------------------------------------------
create or replace function public._entrepreneur_on_first_paid_order ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prof public.profiles%rowtype;
  v_had_paid boolean;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;
  if coalesce(old.pago_estado_revision, '') = 'aprobado' then
    return new;
  end if;
  if coalesce(new.pago_estado_revision, '') <> 'aprobado' then
    return new;
  end if;

  select * into v_prof from public.profiles where id = new.aliado_id;
  if not found then
    return new;
  end if;
  if coalesce(v_prof.retailer_tier, '') <> 'entrepreneur' then
    return new;
  end if;
  if coalesce(v_prof.entrepreneur_status, '') not in (
    'active_trial',
    'pending_first_purchase_alert'
  ) then
    return new;
  end if;

  select exists (
    select 1
    from public.transaction_requests tr
    where tr.aliado_id = new.aliado_id
      and tr.id is distinct from new.id
      and coalesce(tr.pago_estado_revision, '') = 'aprobado'
  ) into v_had_paid;

  if v_had_paid then
    return new;
  end if;

  perform set_config('b2b.profile_privilege_ok', '1', true);

  update public.profiles
  set
    entrepreneur_status = 'kyc_in_progress',
    kyc_completion_deadline = coalesce(
      kyc_completion_deadline,
      now() + interval '56 days'
    )
  where id = new.aliado_id;

  perform public.mc_insert_notification(
    new.aliado_id,
    '¡Primera compra confirmada!',
    'Tienes 8 semanas para completar tu expediente comercial '
      || '(Registro Mercantil, 2 referencias bancarias y Registro Comercial / Carta de Crédito).',
    'entrepreneur',
    new.aliado_id::text
  );

  perform public._notify_admins_entrepreneur(
    'Emprendedor: primera compra',
    coalesce(nullif(btrim(v_prof.business_name), ''), 'Minorista')
      || ' confirmó su primera compra. Inicia plazo KYC de 8 semanas.',
    new.aliado_id::text
  );

  return new;
end;
$$;

drop trigger if exists tr_entrepreneur_on_first_paid_order on public.transaction_requests;
create trigger tr_entrepreneur_on_first_paid_order
after update of pago_estado_revision
on public.transaction_requests
for each row
execute function public._entrepreneur_on_first_paid_order ();

-- ---------------------------------------------------------------------------
-- 5) Docs diferidos: notificar aliado + verified_standard / expired_locked
-- ---------------------------------------------------------------------------
create or replace function public._entrepreneur_on_deferred_doc_review ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prof public.profiles%rowtype;
  v_label text;
  v_types text[] := array[
    'registro_mercantil',
    'referencia_bancaria_1',
    'referencia_bancaria_2',
    'referencia_comercial'
  ];
begin
  if new.doc_type is null or not (new.doc_type = any (v_types)) then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and coalesce(old.review_status, '') = coalesce(new.review_status, '') then
    return new;
  end if;
  if coalesce(new.review_status, '') not in ('aprobado', 'rechazado', 'en_revision') then
    return new;
  end if;

  select * into v_prof from public.profiles where id = new.profile_id;
  if not found or coalesce(v_prof.retailer_tier, '') <> 'entrepreneur' then
    return new;
  end if;

  v_label := case new.doc_type
    when 'registro_mercantil' then 'Registro Mercantil'
    when 'referencia_bancaria_1' then 'Referencia Bancaria 1'
    when 'referencia_bancaria_2' then 'Referencia Bancaria 2'
    when 'referencia_comercial' then 'Registro Comercial / Carta de Crédito'
    else new.doc_type
  end;

  if new.review_status = 'aprobado' then
    perform public.mc_insert_notification(
      new.profile_id,
      'Documento aprobado',
      v_label || ' fue aprobado por Administración.',
      'kyc',
      new.profile_id::text
    );
  elsif new.review_status = 'rechazado' then
    perform public.mc_insert_notification(
      new.profile_id,
      'Documento rechazado',
      v_label || ' fue rechazado'
        || case
             when nullif(btrim(coalesce(new.review_note, '')), '') is not null
             then ': ' || btrim(new.review_note)
             else '. Corrígelo y vuelve a subirlo.'
           end,
      'kyc',
      new.profile_id::text
    );
  elsif new.review_status = 'en_revision' then
    perform public.mc_insert_notification(
      new.profile_id,
      'Documento en revisión',
      v_label || ' está en revisión por B2B Conecta.',
      'kyc',
      new.profile_id::text
    );
  end if;

  if new.review_status = 'aprobado'
     and public.entrepreneur_deferred_docs_complete(new.profile_id)
     and coalesce(v_prof.entrepreneur_status, '') in (
       'kyc_in_progress',
       'active_trial',
       'pending_first_purchase_alert',
       'reactivation_requested'
     ) then
    perform set_config('b2b.profile_privilege_ok', '1', true);
    update public.profiles
    set
      entrepreneur_status = 'verified_standard',
      retailer_tier = 'standard',
      kyc_status = 'aprobado'
    where id = new.profile_id;

    perform public.mc_insert_notification(
      new.profile_id,
      'Expediente completo',
      'Completaste tu documentación emprendedor. Tu cuenta pasa a minorista estándar.',
      'entrepreneur',
      new.profile_id::text
    );
  end if;

  return new;
end;
$$;

drop trigger if exists tr_entrepreneur_on_deferred_doc_review on public.profile_documents;
create trigger tr_entrepreneur_on_deferred_doc_review
after insert or update of review_status, review_note, is_current
on public.profile_documents
for each row
execute function public._entrepreneur_on_deferred_doc_review ();

create or replace function public.entrepreneur_mark_kyc_expired ()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_count integer := 0;
begin
  perform set_config('b2b.profile_privilege_ok', '1', true);

  for v_row in
    select p.id, p.business_name
    from public.profiles p
    where p.retailer_tier = 'entrepreneur'
      and p.entrepreneur_status = 'kyc_in_progress'
      and p.kyc_completion_deadline is not null
      and p.kyc_completion_deadline < now()
      and not public.entrepreneur_deferred_docs_complete(p.id)
  loop
    update public.profiles
    set entrepreneur_status = 'expired_locked'
    where id = v_row.id;

    perform public.mc_insert_notification(
      v_row.id,
      'Plazo de documentación vencido',
      'Tu expediente de 8 semanas venció. Puedes seguir subiendo documentos '
        || 'y solicitar reactivación con un asesor.',
      'entrepreneur',
      v_row.id::text
    );

    perform public._notify_admins_entrepreneur(
      'Emprendedor: KYC vencido',
      coalesce(nullif(btrim(v_row.business_name), ''), 'Minorista')
        || ' no completó el expediente en 8 semanas.',
      v_row.id::text
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.entrepreneur_mark_kyc_expired () from public;
grant execute on function public.entrepreneur_mark_kyc_expired () to service_role;

-- ---------------------------------------------------------------------------
-- 6) Job diario (si pg_cron está disponible)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('entrepreneur_phase2_daily');
    exception
      when others then null;
    end;
    perform cron.schedule(
      'entrepreneur_phase2_daily',
      '15 8 * * *',
      $cron$
        select public.entrepreneur_mark_first_purchase_alerts();
        select public.entrepreneur_mark_kyc_expired();
      $cron$
    );
  end if;
exception
  when others then
    raise notice 'pg_cron no disponible; ejecutar jobs Fase 2 vía service_role.';
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) RPC opcional: recordatorio docs pendientes (invocable desde app/admin)
-- ---------------------------------------------------------------------------
create or replace function public.entrepreneur_notify_pending_docs (
  p_aliado_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row record;
  v_count integer := 0;
  v_missing integer;
  v_is_admin boolean := false;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select lower(trim(coalesce(role, ''))) = 'administrador'
    into v_is_admin
  from public.profiles where id = v_uid;

  for v_row in
    select p.id
    from public.profiles p
    where p.retailer_tier = 'entrepreneur'
      and p.entrepreneur_status in (
        'kyc_in_progress',
        'expired_locked',
        'reactivation_requested'
      )
      and (p_aliado_id is null or p.id = p_aliado_id)
      and (
        v_is_admin
        or p.id = v_uid
      )
  loop
    select 4 - (
      select count(distinct d.doc_type)
      from public.profile_documents d
      where d.profile_id = v_row.id
        and d.is_current = true
        and d.review_status in ('aprobado', 'en_revision', 'pendiente')
        and d.doc_type = any (
          array[
            'registro_mercantil',
            'referencia_bancaria_1',
            'referencia_bancaria_2',
            'referencia_comercial'
          ]
        )
    ) into v_missing;

    if coalesce(v_missing, 0) > 0 then
      perform public.mc_insert_notification(
        v_row.id,
        'Documentos comerciales pendientes',
        'Te faltan ' || v_missing::text
          || ' documento(s) del expediente emprendedor. Ábrelos en Perfil → Verificación KYC.',
        'entrepreneur',
        v_row.id::text
      );
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.entrepreneur_notify_pending_docs (uuid) from public;
grant execute on function public.entrepreneur_notify_pending_docs (uuid) to authenticated;
