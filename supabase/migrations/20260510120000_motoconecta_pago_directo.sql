-- MotoConecta: pago directo aliado ↔ importador (comprobante + verificación por importador).
-- Añade columnas, RPC de registro (aliado) y verificación (importador), y bucket Storage.

alter table public.transaction_requests
  add column if not exists pago_metodo text,
  add column if not exists comprobante_pago_storage_path text,
  add column if not exists comprobante_pago_file_name text,
  add column if not exists comprobante_pago_submitted_at timestamptz,
  add column if not exists pago_estado_revision text,
  add column if not exists pago_comprobante_rechazo_nota text,
  add column if not exists pago_aprobado_at timestamptz;

create or replace function public.aliado_registra_comprobante_pago (
  p_request_id uuid,
  p_metodo text,
  p_storage_path text,
  p_file_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_status text;
  v_pe text;
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;

  select tr.aliado_id, tr.status, tr.pago_estado_revision
    into v_aliado, v_status, v_pe
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_aliado is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_aliado is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;
  if v_status = 'rechazado' then
    raise exception 'El pedido está rechazado';
  end if;
  if trim(p_metodo) not in (
    'zelle_divisas',
    'pago_movil',
    'binance',
    'transferencia'
  ) then
    raise exception 'Método de pago no permitido';
  end if;
  if v_pe is not null and trim(v_pe) = 'aprobado' then
    raise exception 'El pago ya fue confirmado; no puede modificar el comprobante';
  end if;

  update public.transaction_requests
  set
    pago_metodo = trim(p_metodo),
    comprobante_pago_storage_path = p_storage_path,
    comprobante_pago_file_name = nullif(trim(p_file_name), ''),
    comprobante_pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.aliado_registra_comprobante_pago (uuid, text, text, text) to authenticated;

create or replace function public.importador_set_pago_revision_estado (
  p_request_id uuid,
  p_nuevo_estado text,
  p_rechazo_nota text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp uuid;
  v_path text;
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;
  if trim(p_nuevo_estado) not in ('aprobado', 'rechazado') then
    raise exception 'Estado no válido';
  end if;

  select tr.importador_id, tr.comprobante_pago_storage_path
    into v_imp, v_path
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_imp is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_imp is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;
  if trim(p_nuevo_estado) = 'aprobado' then
    if v_path is null or length(trim(v_path)) = 0 then
      raise exception 'No hay comprobante para aprobar';
    end if;
    update public.transaction_requests
    set
      pago_estado_revision = 'aprobado',
      pago_comprobante_rechazo_nota = null,
      pago_aprobado_at = now (),
      updated_at = now ()
    where id = p_request_id;
  else
    update public.transaction_requests
    set
      pago_estado_revision = 'rechazado',
      pago_comprobante_rechazo_nota = nullif(trim(p_rechazo_nota), ''),
      pago_aprobado_at = null,
      updated_at = now ()
    where id = p_request_id;
  end if;
end;
$$;

grant execute on function public.importador_set_pago_revision_estado (uuid, text, text) to authenticated;

-- Storage: comprobantes de pago (bucket + RLS alineada a pedido por carpeta = UUID)
insert into storage.buckets (id, name, public)
values ('order-payment-proofs', 'order-payment-proofs', false)
on conflict (id) do nothing;

drop policy if exists "order_payproof_select_participants" on storage.objects;
create policy "order_payproof_select_participants"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-payment-proofs'
  and (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and (tr.aliado_id = auth.uid () or tr.importador_id = auth.uid ())
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid () and p.role = 'administrador'
    )
  )
);

drop policy if exists "order_payproof_insert_aliado" on storage.objects;
create policy "order_payproof_insert_aliado"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-payment-proofs'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.aliado_id = auth.uid ()
  )
);

drop policy if exists "order_payproof_update_aliado" on storage.objects;
create policy "order_payproof_update_aliado"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'order-payment-proofs'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.aliado_id = auth.uid ()
  )
)
with check (
  bucket_id = 'order-payment-proofs'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.aliado_id = auth.uid ()
  )
);

drop policy if exists "order_payproof_delete_aliado" on storage.objects;
create policy "order_payproof_delete_aliado"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-payment-proofs'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.aliado_id = auth.uid ()
  )
);
