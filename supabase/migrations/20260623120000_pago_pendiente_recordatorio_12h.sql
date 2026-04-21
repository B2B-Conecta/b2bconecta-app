-- Recordatorios cada 12 h (mientras entregado + factura MotoLink + pago no aprobado).
-- Requiere programar en el proyecto, por ejemplo con pg_cron (habilitar extensión en Supabase):
--   select cron.schedule(
--     'pago-pendiente-recordatorio-12h',
--     '15 * * * *',
--     $$select public.run_pago_pendiente_recordatorios_12h()$$
--   );

alter table public.transaction_requests
  add column if not exists pago_pendiente_ultimo_recordatorio_at timestamptz;

comment on column public.transaction_requests.pago_pendiente_ultimo_recordatorio_at is
  'Último aviso periódico (cada 12 h) por pago pendiente tras entrega; se limpia al aprobar pago.';

create or replace function public.run_pago_pendiente_recordatorios_12h()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  n int := 0;
  base_ts timestamptz;
begin
  for rec in
    select
      tr.id,
      tr.aliado_id,
      tr.at_entregado,
      tr.pago_pendiente_ultimo_recordatorio_at
    from public.transaction_requests tr
    where tr.status = 'entregado'
      and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
      and coalesce(nullif(trim(tr.pago_estado_revision), ''), 'pendiente')
        is distinct from 'aprobado'
      and tr.at_entregado is not null
  loop
    base_ts := coalesce(
      rec.pago_pendiente_ultimo_recordatorio_at,
      rec.at_entregado
    );
    if now() < base_ts + interval '12 hours' then
      continue;
    end if;

    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      rec.aliado_id,
      'Recordatorio: pago pendiente',
      'Su pedido está entregado y aún falta completar o aprobar el pago ante MotoLink. Revise la ficha del pedido.',
      'pago',
      rec.id::text
    );

    perform public.notify_to_all_admins(
      'Recordatorio: entrega con pago pendiente',
      format(
        'Pedido %s: siguen sin aprobar el pago del aliado ante MotoLink.',
        rec.id::text
      ),
      'pago',
      rec.id::text
    );

    update public.transaction_requests
    set
      pago_pendiente_ultimo_recordatorio_at = now(),
      updated_at = now()
    where id = rec.id;

    n := n + 1;
  end loop;

  return n;
end;
$$;

grant execute on function public.run_pago_pendiente_recordatorios_12h() to service_role;

grant execute on function public.admin_aprobar_pago_aliado(uuid) to authenticated;

-- Al aprobar pago, dejar de contar intervalos de recordatorio.
create or replace function public.admin_aprobar_pago_aliado(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden aprobar el pago';
  end if;

  update public.transaction_requests
  set
    pago_estado_revision = 'aprobado',
    pago_aprobado_at = now(),
    pago_pendiente_ultimo_recordatorio_at = null,
    updated_at = now()
  where id = p_request_id
    and status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and pago_estado_revision = 'en_revision';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'No hay comprobante en revisión para este pedido.';
  end if;
end;
$$;
