-- Recepción exclusiva de stock Profit. Tablas vacías, instalaciones deshabilitadas
-- por defecto. No cambia precios, políticas de compra ni datos de otro mayorista.
-- Versión 20261129120000: 20261126120000 ya es la moneda del carrito.
do $$
begin
  if to_regclass('public.order_postventa_casos') is null or
     to_regclass('public.replacement_orders') is null or
     not exists(select 1 from information_schema.columns where table_schema='public'
       and table_name='products' and column_name='stock_reserved' and data_type='integer') then
    raise exception 'SYNC_SCHEMA_UNSUPPORTED';
  end if;
end;
$$;
create table public.profit_sync_installations (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id) on delete restrict,
  token_sha256 text not null check (token_sha256 ~ '^[0-9a-f]{64}$'),
  database_name text not null default 'MOTO' check (database_name = 'MOTO'),
  warehouse text not null default 'GM' check (warehouse = 'GM'),
  enabled boolean not null default false,
  last_sequence bigint not null default 0 check (last_sequence >= 0),
  last_observed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.profit_sync_product_mappings (
  installation_id uuid not null references public.profit_sync_installations(id) on delete cascade,
  co_art text collate "C" not null check (length(co_art) between 1 and 128),
  product_id uuid not null unique references public.products(id) on delete restrict,
  unit text not null default 'UNI' check (unit = 'UNI'),
  last_published_stock integer check (last_published_stock >= 0),
  primary key (installation_id, co_art)
);

create table public.profit_sync_batches (
  installation_id uuid not null references public.profit_sync_installations(id) on delete restrict,
  batch_id uuid not null,
  source_sequence bigint not null,
  payload_sha256 text not null,
  observed_at timestamptz not null,
  applied_at timestamptz not null default now(),
  result jsonb not null,
  primary key (installation_id, batch_id),
  unique (installation_id, source_sequence)
);

-- Barrera conservadora hasta implementar acuse/conciliación de pedidos en ERP.
-- No se borra al eliminar un pedido: borrar historia no acredita reflejo en ERP.
create table public.profit_sync_order_events (
  id bigint generated always as identity primary key,
  installation_id uuid not null references public.profit_sync_installations(id) on delete restrict,
  product_id uuid not null,
  request_id uuid not null,
  operation text not null,
  observed_at timestamptz not null default now(),
  reconciled_at timestamptz
);
create index profit_sync_order_events_pending
  on public.profit_sync_order_events(installation_id) where reconciled_at is null;

-- Eventos independientes del pedido original; una reserva puede cambiar sin
-- tocar product_id/cantidad/status en transaction_requests. No purgar historia.
create table public.profit_sync_inventory_events (
  id bigint generated always as identity primary key,
  installation_id uuid not null references public.profit_sync_installations(id) on delete restrict,
  product_id uuid not null,
  source_table text not null check(source_table in ('products','order_postventa_casos','replacement_orders')),
  source_id uuid not null,
  operation text not null,
  observed_at timestamptz not null default now(),
  reconciled_at timestamptz
);
create index profit_sync_inventory_events_pending
  on public.profit_sync_inventory_events(installation_id) where reconciled_at is null;

alter table public.profit_sync_installations enable row level security;
alter table public.profit_sync_product_mappings enable row level security;
alter table public.profit_sync_batches enable row level security;
alter table public.profit_sync_order_events enable row level security;
alter table public.profit_sync_inventory_events enable row level security;
revoke all on public.profit_sync_installations, public.profit_sync_product_mappings,
  public.profit_sync_batches, public.profit_sync_order_events, public.profit_sync_inventory_events
  from public, anon, authenticated, service_role;
grant select, insert, update, delete on public.profit_sync_installations, public.profit_sync_product_mappings,
  public.profit_sync_batches, public.profit_sync_order_events, public.profit_sync_inventory_events to service_role;
grant usage, select on sequence public.profit_sync_order_events_id_seq to service_role;
grant usage, select on sequence public.profit_sync_inventory_events_id_seq to service_role;

create function public.profit_sync_capture_reserved_event()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, extensions
as $$
begin
  if new.stock_reserved is not distinct from old.stock_reserved then return null; end if;
  -- La actualización ya mantiene el bloqueo del producto. El lote toma el mismo
  -- bloqueo antes de consultar esta barrera en una sentencia nueva.
  insert into public.profit_sync_inventory_events
    (installation_id,product_id,source_table,source_id,operation)
  select m.installation_id,new.id,'products',new.id,'UPDATE_RESERVED'
  from public.profit_sync_product_mappings m where m.product_id=new.id;
  return null;
end;
$$;
revoke all on function public.profit_sync_capture_reserved_event() from public, anon, authenticated;
create trigger profit_sync_reserved_event
after update of stock_reserved on public.products
for each row execute function public.profit_sync_capture_reserved_event();

create function public.profit_sync_capture_postventa_event()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, extensions
as $$
declare v_old jsonb; v_new jsonb; v_ids uuid[]; v_source_id uuid;
begin
  if tg_op <> 'INSERT' then v_old := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then v_new := to_jsonb(new); end if;
  if tg_op='UPDATE' and (v_new-'updated_at') is not distinct from (v_old-'updated_at') then
    return null;
  end if;
  v_ids := array[(v_old->>'product_id')::uuid,(v_new->>'product_id')::uuid];
  v_source_id := coalesce((v_new->>'id')::uuid,(v_old->>'id')::uuid);
  perform p.id from public.products p
    join public.profit_sync_product_mappings m on m.product_id=p.id
    where p.id=any(v_ids) order by p.id for no key update of p;
  insert into public.profit_sync_inventory_events
    (installation_id,product_id,source_table,source_id,operation)
  select m.installation_id,m.product_id,tg_table_name,v_source_id,tg_op
  from public.profit_sync_product_mappings m where m.product_id=any(v_ids);
  return null;
end;
$$;
revoke all on function public.profit_sync_capture_postventa_event() from public, anon, authenticated;
create trigger profit_sync_postventa_event
after insert or update or delete on public.order_postventa_casos
for each row execute function public.profit_sync_capture_postventa_event();
create trigger profit_sync_replacement_event
after insert or update or delete on public.replacement_orders
for each row execute function public.profit_sync_capture_postventa_event();

create function public.profit_sync_capture_order_event()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, extensions
as $$
declare v_ids uuid[]; v_request uuid;
begin
  if tg_op = 'UPDATE' and (new.product_id, new.cantidad, new.status)
      is not distinct from (old.product_id, old.cantidad, old.status) then
    return null;
  end if;
  if tg_op = 'INSERT' then v_ids := array[new.product_id]; v_request := new.id;
  elsif tg_op = 'DELETE' then v_ids := array[old.product_id]; v_request := old.id;
  else v_ids := array[old.product_id, new.product_id]; v_request := new.id;
  end if;
  -- También serializa modificaciones/eliminaciones que no pasaron por checkout.
  -- La RPC bloquea estos mismos productos antes de revisar la barrera de pedidos.
  perform p.id from public.products p
    join public.profit_sync_product_mappings m on m.product_id=p.id
    where p.id=any(v_ids) order by p.id for no key update of p;
  insert into public.profit_sync_order_events(installation_id, product_id, request_id, operation)
  select m.installation_id, m.product_id, v_request, tg_op
  from public.profit_sync_product_mappings m where m.product_id = any(v_ids);
  return null;
end;
$$;
revoke all on function public.profit_sync_capture_order_event() from public, anon, authenticated;
create trigger profit_sync_order_event
after insert or update or delete on public.transaction_requests
for each row execute function public.profit_sync_capture_order_event();

create function public.profit_sync_apply_stock(p_token_hash text, p_batch jsonb)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_install public.profit_sync_installations%rowtype;
  v_previous public.profit_sync_batches%rowtype;
  v_install_id uuid; v_batch_id uuid; v_seq bigint; v_observed timestamptz;
  v_hash text; v_row jsonb; v_map record; v_rows jsonb;
  v_actual integer; v_committed integer; v_stock integer; v_result jsonb;
  v_changed integer := 0;
  v_updates jsonb := '[]'::jsonb;
begin
  -- Se repite validación crítica aquí; el rol de cliente no puede invocar esta RPC.
  if jsonb_typeof(p_batch) is distinct from 'object' then
    raise exception 'SYNC_INVALID_BATCH';
  end if;
  if (select count(*) from jsonb_object_keys(p_batch)) <> 8 or
     not (p_batch ?& array['schema_version','installation_id','batch_id','source_sequence','observed_at','source','rows','mode']) or
     p_batch->>'mode' is distinct from 'stock_only' or
     p_batch->>'schema_version' is distinct from '2' or
     jsonb_typeof(p_batch->'schema_version') is distinct from 'number' or
     jsonb_typeof(p_batch->'installation_id') is distinct from 'string' or
     jsonb_typeof(p_batch->'batch_id') is distinct from 'string' or
     jsonb_typeof(p_batch->'observed_at') is distinct from 'string' or
     coalesce(p_batch->>'observed_at','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,7})?(Z|[+-][0-9]{2}:[0-9]{2})$' or
     jsonb_typeof(p_batch->'source_sequence') is distinct from 'number' or
     coalesce(p_batch->>'source_sequence','') !~ '^[1-9][0-9]{0,15}$' then
    raise exception 'SYNC_INVALID_BATCH';
  end if;
  begin
    v_install_id := (p_batch->>'installation_id')::uuid;
    v_batch_id := (p_batch->>'batch_id')::uuid;
    v_seq := (p_batch->>'source_sequence')::bigint;
    v_observed := (p_batch->>'observed_at')::timestamptz;
  exception when others then raise exception 'SYNC_INVALID_BATCH'; end;
  if v_install_id is null or v_batch_id is null or v_observed is null or
     v_seq > 9007199254740991 then raise exception 'SYNC_INVALID_BATCH'; end if;

  select * into v_install from public.profit_sync_installations
  -- NO KEY UPDATE serializa lotes, permite KEY SHARE de las FK de eventos/pedidos.
  -- FOR UPDATE aquí crearía ciclo instalación→producto→FK de instalación.
  where id = v_install_id for no key update;
  if not found or p_token_hash is null or
     v_install.token_sha256 is distinct from p_token_hash or not v_install.enabled then
    raise exception 'SYNC_UNAUTHORIZED';
  end if;
  if not exists(select 1 from public.profiles where id = v_install.owner_id
      and role = 'importador' and account_access_status = 'active' and deactivated_at is null) then
    raise exception 'SYNC_OWNER_INVALID';
  end if;
  if p_batch->'source' is distinct from jsonb_build_object(
       'erp','Profit','database',v_install.database_name,'warehouse',v_install.warehouse) then
    raise exception 'SYNC_SOURCE_MISMATCH';
  end if;

  v_hash := encode(digest(convert_to(p_batch::text,'UTF8'),'sha256'),'hex');
  select * into v_previous from public.profit_sync_batches
    where installation_id = v_install_id and batch_id = v_batch_id;
  if found then
    if v_previous.payload_sha256 <> v_hash then raise exception 'SYNC_BATCH_CONFLICT'; end if;
    return v_previous.result || jsonb_build_object('status','duplicate');
  end if;
  if v_seq <= v_install.last_sequence then raise exception 'SYNC_STALE_SEQUENCE'; end if;
  if v_observed > clock_timestamp() + interval '2 minutes' or
     v_observed < clock_timestamp() - interval '10 minutes' or
     (v_install.last_observed_at is not null and v_observed < v_install.last_observed_at) then
    raise exception 'SYNC_STALE_OBSERVATION';
  end if;
  v_rows := p_batch->'rows';
  if jsonb_typeof(v_rows) is distinct from 'array' then
    raise exception 'SYNC_INVALID_ROWS';
  end if;
  if jsonb_array_length(v_rows) not between 1 and 20 then
    raise exception 'SYNC_INVALID_ROWS';
  end if;
  if jsonb_array_length(v_rows) <> (select count(*) from public.profit_sync_product_mappings where installation_id = v_install_id) then
    raise exception 'SYNC_INCOMPLETE_SNAPSHOT';
  end if;
  for v_row in select value from jsonb_array_elements(v_rows) loop
    if jsonb_typeof(v_row) is distinct from 'object' then
      raise exception 'SYNC_INVALID_ROWS';
    end if;
    if (select count(*) from jsonb_object_keys(v_row)) <> 4 or
       not (v_row ?& array['co_art','unidad','stock_actual','stock_comprometido']) or
       jsonb_typeof(v_row->'co_art') is distinct from 'string' or
       length(v_row->>'co_art') not between 1 and 128 or
       v_row->>'unidad' is distinct from 'UNI' or
       jsonb_typeof(v_row->'stock_actual') is distinct from 'number' or
       jsonb_typeof(v_row->'stock_comprometido') is distinct from 'number' or
       coalesce(v_row->>'stock_actual','') !~ '^(0|[1-9][0-9]{0,9})$' or
       coalesce(v_row->>'stock_comprometido','') !~ '^(0|[1-9][0-9]{0,9})$' then
      raise exception 'SYNC_INVALID_ROWS';
    end if;
    if (v_row->>'stock_actual')::numeric > 2147483647 or
       (v_row->>'stock_comprometido')::numeric > 2147483647 then raise exception 'SYNC_INVALID_ROWS'; end if;
    if not exists(select 1 from public.profit_sync_product_mappings
      where installation_id = v_install_id and co_art = v_row->>'co_art') then
      raise exception 'SYNC_UNKNOWN_CODE';
    end if;
  end loop;
  if (select count(distinct (value->>'co_art') collate "C") from jsonb_array_elements(v_rows)) <> jsonb_array_length(v_rows) then
    raise exception 'SYNC_DUPLICATE_CODE';
  end if;

  -- Mismo bloqueo de producto que checkout; consulta posterior ve pedidos confirmados
  -- mientras se esperaba ese bloqueo. Todo el lote confirma o revierte junto.
  perform p.id from public.products p join public.profit_sync_product_mappings m on m.product_id=p.id
    where m.installation_id=v_install_id order by p.id for no key update of p;
  if exists(select 1 from public.profit_sync_product_mappings m join public.products p on p.id=m.product_id
    where m.installation_id=v_install_id and p.owner_id is distinct from v_install.owner_id) then
    raise exception 'SYNC_PRODUCT_OWNER_MISMATCH';
  end if;
  if exists(select 1 from public.profit_sync_product_mappings m join public.products p on p.id=m.product_id
       where m.installation_id=v_install_id and p.stock_reserved<>0) or
     exists(select 1 from public.profit_sync_inventory_events where installation_id=v_install_id and reconciled_at is null) or
     exists(select 1 from public.profit_sync_order_events where installation_id=v_install_id and reconciled_at is null) or
     exists(select 1 from public.profit_sync_product_mappings m join public.transaction_requests tr on tr.product_id=m.product_id
       where m.installation_id=v_install_id and m.last_published_stock is null and tr.status <> 'rechazado') or
     exists(select 1 from public.profit_sync_product_mappings m join public.order_postventa_casos c on c.product_id=m.product_id
       where m.installation_id=v_install_id and m.last_published_stock is null) or
     exists(select 1 from public.profit_sync_product_mappings m join public.replacement_orders r on r.product_id=m.product_id
       where m.installation_id=v_install_id and m.last_published_stock is null) then
    raise exception 'SYNC_RESERVATION_REQUIRES_RECONCILIATION';
  end if;
  if exists(select 1 from public.profit_sync_product_mappings m join public.products p on p.id=m.product_id
    where m.installation_id=v_install_id and m.last_published_stock is not null and m.last_published_stock <> p.stock) then
    raise exception 'SYNC_LOCAL_STOCK_CHANGED';
  end if;

  for v_row in select value from jsonb_array_elements(v_rows) loop
    select m.product_id, p.stock into v_map from public.profit_sync_product_mappings m
      join public.products p on p.id=m.product_id
      where m.installation_id=v_install_id and m.co_art=v_row->>'co_art';
    v_actual := (v_row->>'stock_actual')::integer;
    v_committed := (v_row->>'stock_comprometido')::integer;
    v_stock := greatest(v_actual-v_committed,0);
    -- Lista de asignación intencionalmente exclusiva: no importador masivo/UPSERT.
    -- Evitar escrituras/triggers innecesarios cuando la existencia no cambió.
    if v_map.stock is distinct from v_stock then
      update public.products set stock=v_stock where id=v_map.product_id;
      v_changed := v_changed + 1;
    end if;
    update public.profit_sync_product_mappings set last_published_stock=v_stock
      where installation_id=v_install_id and co_art=v_row->>'co_art'
        and last_published_stock is distinct from v_stock;
    v_updates := v_updates || jsonb_build_array(jsonb_build_object(
      'product_id',v_map.product_id,'stock_before',v_map.stock,'stock_after',v_stock));
  end loop;
  v_result := jsonb_build_object('status','applied','installation_id',v_install_id,
    'batch_id',v_batch_id,'source_sequence',v_seq,'processed',jsonb_array_length(v_rows),'updated',v_changed,'rows',v_updates);
  insert into public.profit_sync_batches(installation_id,batch_id,source_sequence,payload_sha256,observed_at,result)
    values(v_install_id,v_batch_id,v_seq,v_hash,v_observed,v_result);
  update public.profit_sync_installations set last_sequence=v_seq,last_observed_at=v_observed where id=v_install_id;
  return v_result;
end;
$$;
revoke all on function public.profit_sync_apply_stock(text,jsonb) from public, anon, authenticated;
grant execute on function public.profit_sync_apply_stock(text,jsonb) to service_role;
comment on function public.profit_sync_apply_stock(text,jsonb) is
  'Lotes stock_only autenticados por instalación: atómicos/idempotentes; pausa ante reservas o cambios locales sin conciliar. No registra pedidos en ERP.';
