-- Trazabilidad fina: estados post-aprobación (importador) y entrega (bump credit_score).

-- Migrar estado legacy
update public.transaction_requests
set status = 'entregado'
where status = 'completado';

alter table public.transaction_requests
  drop constraint if exists transaction_requests_status_check;

alter table public.transaction_requests
  add constraint transaction_requests_status_check
  check (
    status in (
      'pendiente',
      'aprobado_admin',
      'rechazado',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
  );

-- Importador ve todo el ciclo tras validación MotoLink (no pendientes ni rechazos ajenos).
drop policy if exists "tr_select_importer_approved" on public.transaction_requests;
create policy "tr_select_importer_fulfillment"
on public.transaction_requests
for select
to authenticated
using (
  owner_id = auth.uid()
  and status in (
    'aprobado_admin',
    'en_preparacion',
    'en_transito',
    'entregado'
  )
);

-- Importador actualiza solo sus filas (transiciones validadas por trigger).
drop policy if exists "tr_update_importer_fulfillment" on public.transaction_requests;
create policy "tr_update_importer_fulfillment"
on public.transaction_requests
for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- Transiciones permitidas: admin (pendiente→…); importador (cadena de fulfillment).
create or replace function public.transaction_requests_enforce_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
  is_importer_owner boolean;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) into is_admin;

  select
    new.owner_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'importador'
    )
  into is_importer_owner;

  if is_admin then
    if old.status = 'pendiente' and new.status in ('aprobado_admin', 'rechazado') then
      return new;
    end if;
    raise exception 'Transición de estado no permitida para administrador';
  end if;

  if is_importer_owner then
    if old.status = 'aprobado_admin' and new.status = 'en_preparacion' then
      return new;
    end if;
    if old.status = 'en_preparacion' and new.status = 'en_transito' then
      return new;
    end if;
    if old.status = 'en_transito' and new.status = 'entregado' then
      return new;
    end if;
    raise exception 'Transición de estado no permitida para importador';
  end if;

  raise exception 'No autorizado a cambiar el estado del pedido';
end;
$$;

drop trigger if exists tr_transaction_requests_status on public.transaction_requests;
create trigger tr_transaction_requests_status
  before update on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_enforce_status_transition();

-- Al marcar entregado: refuerzo positivo al credit_score del aliado (máx. 100).
create or replace function public.transaction_requests_bump_credit_on_delivery()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'entregado' and old.status is distinct from 'entregado' then
    update public.profiles
    set credit_score = least(coalesce(credit_score, 100) + 2, 100)
    where id = new.aliado_id
      and role = 'aliado';
  end if;
  return new;
end;
$$;

drop trigger if exists tr_transaction_requests_delivery_credit on public.transaction_requests;
create trigger tr_transaction_requests_delivery_credit
  after update on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_bump_credit_on_delivery();
