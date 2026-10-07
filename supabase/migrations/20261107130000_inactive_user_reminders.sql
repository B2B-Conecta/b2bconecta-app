-- Recordatorio para quien ya aceptó avisos y lleva días sin volver a la app.
-- Un aviso a las 24 h y otro a las 72 h. Al entrar, touch_my_last_active reinicia el conteo.

alter table public.profiles
  add column if not exists last_active_at timestamptz;

comment on column public.profiles.last_active_at is
  'Última vez que la sesión volvió a primer plano. Lo actualiza touch_my_last_active, como máximo cada hora.';

-- Quien ya tiene canal de aviso empieza el reloj ahora, no en el pasado.
update public.profiles p
set last_active_at = now()
where p.last_active_at is null
  and (
    exists (
      select 1
      from public.device_push_tokens t
      where t.user_id = p.id
    )
    or exists (
      select 1
      from public.web_push_subscriptions w
      where w.user_id = p.id
        and w.is_active
    )
  );

create table if not exists public.user_inactivity_reminders (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  reminder_count integer not null default 0 check (reminder_count >= 0),
  last_sent_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.user_inactivity_reminders enable row level security;

revoke all on table public.user_inactivity_reminders from anon, authenticated;

create or replace function public.touch_my_last_active ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_prev timestamptz;
begin
  if v_uid is null then
    return;
  end if;

  select p.last_active_at
    into v_prev
  from public.profiles p
  where p.id = v_uid
  for update;

  if not found then
    return;
  end if;

  if v_prev is not null and v_prev > now() - interval '1 hour' then
    return;
  end if;

  update public.profiles
  set last_active_at = now()
  where id = v_uid;

  delete from public.user_inactivity_reminders
  where user_id = v_uid;
end;
$$;

revoke all on function public.touch_my_last_active () from public, anon;
grant execute on function public.touch_my_last_active () to authenticated;

create or replace function public.run_inactive_user_reminders ()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  v_count integer := 0;
  v_updated integer := 0;
  v_active timestamptz;
  v_access text;
  v_terms timestamptz;
  v_incomplete boolean;
  v_title text;
  v_body text;
  v_related text;
begin
  if not pg_try_advisory_xact_lock(hashtext('run_inactive_user_reminders')::bigint) then
    return 0;
  end if;

  perform set_config('row_security', 'off', true);

  for rec in
    select
      p.id,
      coalesce(r.reminder_count, 0) as reminder_count
    from public.profiles p
    left join public.user_inactivity_reminders r
      on r.user_id = p.id
    where p.role in ('aliado'::text, 'importador'::text)
      and p.deactivated_at is null
      and coalesce(p.account_access_status, 'active') <> 'rejected'::text
      and p.last_active_at is not null
      and coalesce(r.reminder_count, 0) < 2
      and (
        (
          coalesce(r.reminder_count, 0) = 0
          and p.last_active_at <= now() - interval '24 hours'
        )
        or (
          coalesce(r.reminder_count, 0) = 1
          and p.last_active_at <= now() - interval '72 hours'
        )
      )
      and (
        exists (
          select 1
          from public.device_push_tokens t
          where t.user_id = p.id
        )
        or exists (
          select 1
          from public.web_push_subscriptions w
          where w.user_id = p.id
            and w.is_active
        )
      )
      and not exists (
        select 1
        from public.transaction_requests tr
        where (tr.aliado_id = p.id or tr.importador_id = p.id)
          and tr.status not in ('entregado'::text, 'rechazado'::text)
      )
      and not exists (
        select 1
        from public.notifications n
        where n.user_id = p.id
          and n.is_read = false
          and n.type = 'mensaje'::text
      )
      and not exists (
        select 1
        from public.transaction_requests tr
        where tr.aliado_id = p.id
          and public.tr_is_moroso_pago_pendiente (tr)
      )
  loop
    select p.last_active_at, p.account_access_status, p.terms_accepted_at
      into v_active, v_access, v_terms
    from public.profiles p
    where p.id = rec.id
    for update;

    if v_active is null then
      continue;
    end if;
    if rec.reminder_count = 0 and v_active > now() - interval '24 hours' then
      continue;
    end if;
    if rec.reminder_count = 1 and v_active > now() - interval '72 hours' then
      continue;
    end if;

    insert into public.user_inactivity_reminders (user_id, reminder_count, last_sent_at)
    values (rec.id, 0, null)
    on conflict (user_id) do nothing;

    update public.user_inactivity_reminders r
    set
      reminder_count = r.reminder_count + 1,
      last_sent_at = now()
    where r.user_id = rec.id
      and r.reminder_count = rec.reminder_count
      and r.reminder_count < 2;

    get diagnostics v_updated = row_count;
    if v_updated = 0 then
      continue;
    end if;

    v_incomplete := coalesce(v_access, 'active') in ('draft'::text, 'pending_review'::text)
      or v_terms is null;
    if v_incomplete then
      v_title := 'Termina tu registro';
      v_body := 'Termina tu registro para comprar o vender en B2B Conecta.';
      v_related := 'registro';
    else
      v_title := 'Tu cuenta está lista';
      v_body := 'Tu cuenta está lista. Revisa el catálogo cuando quieras.';
      v_related := 'catalogo';
    end if;

    perform public.mc_insert_notification (
      rec.id,
      v_title,
      v_body,
      'actividad',
      v_related
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.run_inactive_user_reminders () from public, anon, authenticated;
grant execute on function public.run_inactive_user_reminders () to service_role;

do $cron$
begin
  create extension if not exists pg_cron with schema extensions;
exception
  when insufficient_privilege then
    raise notice 'pg_cron: sin privilegio para crear extensión (omitir en local).';
  when others then
    raise notice 'pg_cron: %', sqlerrm;
end;
$cron$;

do $schedule$
declare
  v_job_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'pg_cron no instalado; programe run_inactive_user_reminders manualmente.';
    return;
  end if;

  select jobid
  into v_job_id
  from cron.job
  where jobname = 'b2b_inactive_user_reminders'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'b2b_inactive_user_reminders',
    '0 10 * * *',
    $cmd$select public.run_inactive_user_reminders();$cmd$
  );
exception
  when undefined_table then
    raise notice 'cron.job no disponible; omitiendo schedule de inactividad.';
  when others then
    raise notice 'pg_cron inactividad: %', sqlerrm;
end;
$schedule$;
