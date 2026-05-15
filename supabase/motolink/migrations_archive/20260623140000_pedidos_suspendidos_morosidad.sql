-- Suspensión de nuevos pedidos por morosidad (admin): solo con pedidos entregados sin pago aprobado.

alter table public.profiles
  add column if not exists pedidos_suspendidos_morosidad boolean not null default false;

comment on column public.profiles.pedidos_suspendidos_morosidad is
  'Si es true, el aliado no puede crear nuevas solicitudes de pedido hasta que MotoLink reactive la cuenta (sin morosidad pendiente).';

-- Pedido moroso: entregado, con factura MotoLink al aliado, pago aún no aprobado.
create or replace function public.aliado_tiene_pedidos_morosos(p_aliado_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.transaction_requests tr
    where tr.aliado_id = p_aliado_id
      and tr.status = 'entregado'
      and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
      and coalesce(nullif(trim(tr.pago_estado_revision), ''), 'pendiente')
        is distinct from 'aprobado'
  );
$$;

create or replace function public.admin_aliados_pedidos_morosos_flags()
returns table (aliado_id uuid, tiene_morosos boolean)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid()
      and pr.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden consultar morosidad de aliados.';
  end if;

  return query
  select
    p.id,
    public.aliado_tiene_pedidos_morosos(p.id)
  from public.profiles p
  where p.role = 'aliado';
end;
$$;

grant execute on function public.admin_aliados_pedidos_morosos_flags() to authenticated;

create or replace function public.admin_set_aliado_pedidos_suspendidos_morosidad(
  p_aliado_id uuid,
  p_suspend boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  mor boolean;
  role text;
begin
  if not exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid()
      and pr.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden suspender o reactivar pedidos por morosidad.';
  end if;

  select p.role into role
  from public.profiles p
  where p.id = p_aliado_id;

  if role is null then
    raise exception 'Perfil no encontrado.';
  end if;

  if role is distinct from 'aliado' then
    raise exception 'Solo aplica a cuentas aliado.';
  end if;

  mor := public.aliado_tiene_pedidos_morosos(p_aliado_id);

  if p_suspend then
    if not mor then
      raise exception
        'No puede suspender pedidos: este aliado no tiene pedidos morosos (entregados con pago sin aprobar).';
    end if;
    update public.profiles
    set pedidos_suspendidos_morosidad = true
    where id = p_aliado_id;
  else
    if mor then
      raise exception
        'No puede reactivar pedidos mientras el aliado siga con pedidos morosos. Apruebe los pagos pendientes primero.';
    end if;
    update public.profiles
    set pedidos_suspendidos_morosidad = false
    where id = p_aliado_id;
  end if;
end;
$$;

grant execute on function public.admin_set_aliado_pedidos_suspendidos_morosidad(uuid, boolean)
  to authenticated;

-- Mensaje claro si intentan insertar con la cuenta suspendida.
create or replace function public.transaction_requests_reject_if_pedidos_suspendidos()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  sus boolean;
begin
  select coalesce(p.pedidos_suspendidos_morosidad, false)
  into sus
  from public.profiles p
  where p.id = new.aliado_id;

  if sus then
    raise exception
      'Sus nuevos pedidos están suspendidos por morosidad. Regularice los pagos pendientes con MotoLink.';
  end if;

  return new;
end;
$$;

drop trigger if exists tr_transaction_requests_005_reject_pedidos_suspendidos
  on public.transaction_requests;

create trigger tr_transaction_requests_005_reject_pedidos_suspendidos
  before insert on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_reject_if_pedidos_suspendidos();

drop policy if exists "tr_insert_aliado" on public.transaction_requests;

create policy "tr_insert_aliado"
on public.transaction_requests
for insert
to authenticated
with check (
  aliado_id = auth.uid()
  and exists (
    select 1
    from public.products p
    where p.id = transaction_requests.product_id
      and p.owner_id = transaction_requests.owner_id
  )
  and not coalesce(
    (
      select pr.pedidos_suspendidos_morosidad
      from public.profiles pr
      where pr.id = transaction_requests.aliado_id
    ),
    false
  )
);
