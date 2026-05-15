-- MotoLink puede asignar cupo y habilitar uso de línea de crédito antes de completar la fase contado (confianza).

alter table public.profiles
  add column if not exists credito_preactivado_por_admin boolean not null default false;

comment on column public.profiles.credito_preactivado_por_admin is
  'Si es true, el aliado puede usar crédito MotoLink (pago y cupo) aunque primeros_pedidos_contado_entregados < 3. Solo lo define el admin al asignar cupo.';

-- Sustituye firma (uuid, numeric) por una con tercer parámetro opcional.
drop function if exists public.admin_set_aliado_credit_limit(uuid, numeric);

create or replace function public.admin_set_aliado_credit_limit(
  p_aliado_id uuid,
  p_credit_limit numeric,
  p_credito_preactivado boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  prev_preact boolean;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden actualizar el límite de crédito';
  end if;
  if not exists (
    select 1 from public.profiles where id = p_aliado_id and role = 'aliado'
  ) then
    raise exception 'El perfil indicado no es un aliado';
  end if;

  select coalesce(credito_preactivado_por_admin, false)
  into prev_preact
  from public.profiles
  where id = p_aliado_id;

  update public.profiles
  set
    credit_limit = p_credit_limit,
    credito_preactivado_por_admin = p_credito_preactivado
  where id = p_aliado_id;

  if p_credit_limit > 0
     and p_credito_preactivado
     and not coalesce(prev_preact, false) then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      p_aliado_id,
      'Línea de crédito MotoLink habilitada',
      'MotoLink le asignó un cupo de USD '
        || trim(to_char(p_credit_limit, 'FM999999990.00'))
        || ' y autorizó el uso de la línea de crédito en la plataforma desde ahora, '
        || 'incluso durante sus primeros pedidos. Revise su perfil y los métodos de pago al confirmar pedidos.',
      'kyc',
      p_aliado_id::text
    );
  end if;
end;
$$;

grant execute on function public.admin_set_aliado_credit_limit(uuid, numeric, boolean) to authenticated;

-- Pago con crédito del sistema permitido si admin preactivó, aunque pc < 3.
create or replace function public.aliado_declara_pago_credito_sistema(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  pc int;
  lim numeric;
  preact boolean;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede solicitar pago con crédito del sistema.';
  end if;

  select
    coalesce(primeros_pedidos_contado_entregados, 0),
    credit_limit,
    coalesce(credito_preactivado_por_admin, false)
  into pc, lim, preact
  from public.profiles
  where id = auth.uid();

  if pc < 3 and not preact then
    raise exception 'El pago con crédito del sistema solo aplica tras completar la fase de contado.';
  end if;
  if lim is null or lim <= 0 then
    raise exception 'Debe tener un límite de crédito asignado por MotoLink para usar esta modalidad.';
  end if;

  update public.transaction_requests tr
  set
    pago_metodo = 'credito_sistema',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status = 'en_preparacion'
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la solicitud. Verifique factura MotoLink, pedido en preparación '
      'y que pueda reintentar si el pago fue rechazado.';
  end if;
end;
$$;
