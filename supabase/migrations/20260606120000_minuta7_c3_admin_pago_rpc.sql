-- Minuta #7 — Bloque C3: RPC admin para aprobar/rechazar pago del aliado (auditoría confirmado_por).

create or replace function public.admin_aprobar_pago_aliado (p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_path text;
  v_pe text;
  v_metodo text;
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores' using errcode = '42501';
  end if;

  select
    tr.comprobante_pago_storage_path,
    tr.pago_estado_revision,
    tr.pago_metodo
    into v_path, v_pe, v_metodo
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_pe is null then
    raise exception 'Pedido no encontrado';
  end if;
  if coalesce(trim(v_pe), '') <> 'en_revision' then
    raise exception 'El pago no está en revisión';
  end if;
  if trim(coalesce(v_metodo, '')) = 'efectivo' then
  elsif v_path is null or length(trim(v_path)) = 0 then
    raise exception 'No hay comprobante para aprobar';
  end if;

  update public.transaction_requests
  set
    pago_estado_revision = 'aprobado',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = now (),
    confirmado_por = auth.uid (),
    updated_at = now ()
  where id = p_request_id;
end;
$$;

create or replace function public.admin_rechazar_comprobante_pago (
  p_request_id uuid,
  p_nota text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores' using errcode = '42501';
  end if;

  update public.transaction_requests
  set
    pago_estado_revision = 'rechazado',
    pago_comprobante_rechazo_nota = nullif(trim(p_nota), ''),
    pago_aprobado_at = null,
    confirmado_por = auth.uid (),
    updated_at = now ()
  where id = p_request_id
    and coalesce(trim(pago_estado_revision), '') = 'en_revision';

  if not found then
    raise exception 'El pago no está en revisión o el pedido no existe';
  end if;
end;
$$;

grant execute on function public.admin_aprobar_pago_aliado (uuid) to authenticated;
grant execute on function public.admin_rechazar_comprobante_pago (uuid, text) to authenticated;

comment on function public.admin_aprobar_pago_aliado (uuid) is
  'Admin: aprueba pago del aliado (comprobante o efectivo en revisión); registra confirmado_por.';

comment on function public.admin_rechazar_comprobante_pago (uuid, text) is
  'Admin: rechaza comprobante o solicitud de pago en revisión; registra confirmado_por.';
