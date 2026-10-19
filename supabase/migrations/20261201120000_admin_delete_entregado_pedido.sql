-- Un pedido entregado se puede borrar si el administrador deja un motivo.
-- El motivo queda en el registro de limpieza. Las valoraciones de esas líneas
-- se quitan y se recalcula la reputación, para que no sigan en los reportes.

create table if not exists public.admin_pedido_delete_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null,
  motivo text not null,
  request_ids uuid[] not null,
  checkout_group_id uuid,
  statuses text[] not null,
  created_at timestamptz not null default now()
);

comment on table public.admin_pedido_delete_log is
  'Motivo con el que un administrador eliminó pedidos, incluidos los entregados de prueba.';

alter table public.admin_pedido_delete_log enable row level security;

drop policy if exists admin_pedido_delete_log_select on public.admin_pedido_delete_log;
create policy admin_pedido_delete_log_select
  on public.admin_pedido_delete_log
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'administrador'
        and p.deactivated_at is null
    )
  );

drop function if exists public.admin_delete_pedido (uuid, boolean);

create or replace function public.admin_delete_pedido (
  p_request_id uuid,
  p_delete_checkout_group boolean default false,
  p_motivo text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
  v_ids uuid[];
  v_statuses text[];
  v_profiles uuid[];
  v_profile uuid;
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_count integer;
  v_has_entregado boolean;
begin
  perform public._assert_administrador ();

  if p_request_id is null then
    raise exception 'Pedido inválido';
  end if;

  select tr.checkout_group_id
    into v_group
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if coalesce(p_delete_checkout_group, false) and v_group is not null then
    select array_agg(tr.id)
      into v_ids
    from public.transaction_requests tr
    where tr.checkout_group_id = v_group;
  else
    v_ids := array[p_request_id];
  end if;

  perform 1
  from public.transaction_requests tr
  where tr.id = any (v_ids)
  for update;

  select coalesce(bool_or(tr.status = 'entregado'), false),
         array_agg(tr.status)
    into v_has_entregado, v_statuses
  from public.transaction_requests tr
  where tr.id = any (v_ids);

  if v_has_entregado and length(v_motivo) < 3 then
    raise exception 'Indique el motivo de la eliminación (mínimo 3 caracteres)';
  end if;

  if v_has_entregado then
    insert into public.admin_pedido_delete_log (
      admin_id,
      motivo,
      request_ids,
      checkout_group_id,
      statuses
    )
    values (
      auth.uid(),
      v_motivo,
      v_ids,
      v_group,
      v_statuses
    );
  end if;

  select array_agg(distinct pid)
    into v_profiles
  from (
    select r.importador_id as pid
    from public.order_ratings r
    where r.transaction_request_id = any (v_ids)
    union
    select r.aliado_id
    from public.order_ratings r
    where r.transaction_request_id = any (v_ids)
  ) rated
  where pid is not null;

  delete from public.order_ratings r
  where r.transaction_request_id = any (v_ids);

  if v_profiles is not null then
    foreach v_profile in array v_profiles loop
      perform public.refresh_profile_rating_aggregates(v_profile);
    end loop;
  end if;

  delete from public.replacement_orders ro
  where ro.source_transaction_request_id = any (v_ids)
     or ro.caso_id in (
       select c.id
       from public.order_postventa_casos c
       where c.transaction_request_id = any (v_ids)
     );

  delete from public.aliado_importer_credit_notes n
  where n.caso_id in (
    select c.id
    from public.order_postventa_casos c
    where c.transaction_request_id = any (v_ids)
  );

  delete from public.notifications n
  where n.related_id in (
    select t.id::text
    from unnest(v_ids) as t(id)
  );

  delete from public.transaction_requests tr
  where tr.id = any (v_ids);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.admin_delete_pedido (uuid, boolean, text) from public;
grant execute on function public.admin_delete_pedido (uuid, boolean, text) to authenticated;

comment on function public.admin_delete_pedido (uuid, boolean, text) is
  'Administrador: borra una línea de pedido. Un pedido entregado exige p_motivo. Con p_delete_checkout_group borra el carrito completo.';
