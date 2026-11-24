-- These RPCs call aliado_checkout_proveedores_v1 at runtime; install the complete
-- migration chain (including 20261210120000) before enabling mobile checkout v2.
create schema if not exists b2b_private;
revoke all on schema b2b_private from public, anon, authenticated;
create table b2b_private.checkout_attempts (
  aliado_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid not null,
  payload_hash text,
  state text not null check (state in ('pending','completed','cancelled')),
  checkout_group_id uuid,
  created_at timestamptz not null default now(),
  primary key (aliado_id, request_id),
  check ((state = 'completed') = (checkout_group_id is not null))
);
alter table b2b_private.checkout_attempts enable row level security;

create table public.retailer_delivery_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null check (length(trim(label)) between 1 and 80),
  estado text not null check (length(trim(estado)) between 1 and 100),
  ciudad text not null check (length(trim(ciudad)) between 1 and 100),
  direccion text not null check (length(trim(direccion)) between 1 and 1000),
  maps_url text not null check (maps_url ~* '^https?://[^/[:space:]]+'),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index retailer_addresses_owner on public.retailer_delivery_addresses(user_id);
create unique index retailer_addresses_default on public.retailer_delivery_addresses(user_id) where is_default;
alter table public.retailer_delivery_addresses enable row level security;
revoke all on public.retailer_delivery_addresses from public, anon, authenticated;
grant select, delete on public.retailer_delivery_addresses to authenticated;
create policy retailer_addresses_read on public.retailer_delivery_addresses for select to authenticated
  using (user_id = (select auth.uid()));
create policy retailer_addresses_delete on public.retailer_delivery_addresses for delete to authenticated
  using (user_id = (select auth.uid()));

create function public.save_retailer_delivery_address(p_label text, p_estado text, p_ciudad text,
  p_direccion text, p_maps_url text, p_id uuid default null, p_is_default boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
  if not exists(select 1 from public.profiles where id=v_uid and role='aliado'
    and account_access_status='active' and deactivated_at is null) then
    raise exception 'Acceso reservado a tiendas habilitadas.' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':delivery_addresses',0));
  if p_id is not null and not exists(select 1 from public.retailer_delivery_addresses where id=p_id and user_id=v_uid) then
    raise exception 'Dirección no disponible.' using errcode='42501';
  end if;
  if p_is_default then update public.retailer_delivery_addresses set is_default=false where user_id=v_uid and is_default; end if;
  insert into public.retailer_delivery_addresses(id,user_id,label,estado,ciudad,direccion,maps_url,is_default)
    values(coalesce(p_id,gen_random_uuid()),v_uid,trim(p_label),trim(p_estado),trim(p_ciudad),trim(p_direccion),trim(p_maps_url),p_is_default)
  on conflict(id) do update set label=excluded.label, estado=excluded.estado, ciudad=excluded.ciudad,
    direccion=excluded.direccion,maps_url=excluded.maps_url,is_default=excluded.is_default,updated_at=now()
    where public.retailer_delivery_addresses.user_id=v_uid
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.save_retailer_delivery_address(text,text,text,text,text,uuid,boolean) from public,anon;
grant execute on function public.save_retailer_delivery_address(text,text,text,text,text,uuid,boolean) to authenticated;

alter table public.importer_pickup_locations
  add column customer_pickup_enabled boolean not null default false,
  add column customer_pickup_instructions text not null default '' check (length(customer_pickup_instructions)<=1000);
create function public.set_customer_pickup_offer(p_location_id uuid,p_enabled boolean,p_instructions text default '')
returns void language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and role='importador'
    and account_access_status='active' and deactivated_at is null) then
    raise exception 'Acceso reservado al proveedor.' using errcode='42501'; end if;
  update public.importer_pickup_locations set customer_pickup_enabled=p_enabled,
    customer_pickup_instructions=trim(coalesce(p_instructions,'')), updated_at=now()
    where id=p_location_id and importador_id=auth.uid()
      and (not p_enabled or (is_active and nullif(trim(estado),'') is not null
        and nullif(trim(ciudad),'') is not null and nullif(trim(direccion),'') is not null
        and maps_url ~* '^https?://[^/[:space:]]+'));
  if not found then raise exception 'Completa la ubicación y el enlace de mapas antes de ofrecer el retiro.'; end if;
end $$;
revoke all on function public.set_customer_pickup_offer(uuid,boolean,text) from public,anon;
grant execute on function public.set_customer_pickup_offer(uuid,boolean,text) to authenticated;

create function public.list_customer_pickup_for_checkout(p_importador_id uuid)
returns table(id uuid,importador_id uuid,label text,estado text,ciudad text,direccion text,maps_url text,instructions text)
language sql stable security definer set search_path='' as $$
  select l.id,l.importador_id,l.label,l.estado,l.ciudad,l.direccion,l.maps_url,l.customer_pickup_instructions
  from public.importer_pickup_locations l
  where l.importador_id=p_importador_id and l.customer_pickup_enabled and l.is_active
    and public._importer_store_is_public(l.importador_id)
    and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='aliado'
      and p.account_access_status='active' and p.deactivated_at is null)
  order by l.is_default desc,l.sort_order,l.label,l.id;
$$;
revoke all on function public.list_customer_pickup_for_checkout(uuid) from public,anon;
grant execute on function public.list_customer_pickup_for_checkout(uuid) to authenticated;

alter table public.transaction_requests
  add column customer_delivery_mode text not null default 'DELIVERY' check (customer_delivery_mode in ('DELIVERY','PICKUP')),
  add column customer_pickup_location_id uuid references public.importer_pickup_locations(id),
  add column customer_delivery_snapshot jsonb not null default '{}'::jsonb;
create index tr_customer_pickup_location on public.transaction_requests(customer_pickup_location_id) where customer_pickup_location_id is not null;

create function b2b_private.checkout_delivery_snapshot() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_context jsonb; v_choice jsonb;
begin
  if tg_op='UPDATE' then
    if (new.customer_delivery_mode,new.customer_pickup_location_id,new.customer_delivery_snapshot)
       is distinct from (old.customer_delivery_mode,old.customer_pickup_location_id,old.customer_delivery_snapshot) then
      raise exception 'La modalidad y dirección elegidas forman parte del pedido confirmado.' using errcode='23514';
    end if;
    return new;
  end if;
  v_context := nullif(current_setting('b2b.checkout_delivery_v2',true),'')::jsonb;
  new.customer_delivery_mode := 'DELIVERY';
  new.customer_pickup_location_id := null;
  new.customer_delivery_snapshot := '{}'::jsonb;
  if v_context->>'user_id'=new.aliado_id::text then
    v_choice := v_context->'suppliers'->new.importador_id::text;
    new.customer_delivery_mode := coalesce(v_choice->>'mode','DELIVERY');
    new.customer_delivery_snapshot := coalesce(v_choice->'snapshot','{}'::jsonb);
    if new.customer_delivery_mode='PICKUP' then
      new.customer_pickup_location_id := (v_choice->>'location_id')::uuid;
      new.importer_carrier_id:=null; new.importer_carrier_driver_id:=null;
      new.carrier_fee_usd_snapshot:=0; new.carrier_eta_hours_snapshot:=null;
      new.carrier_distance_km_snapshot:=null; new.carrier_decision:='skipped';
      new.shipping_included:=true; new.shipping_cost_usd:=0;
    end if;
  end if;
  return new;
end $$;
create trigger tr_customer_delivery_snapshot before insert or update of customer_delivery_mode,customer_pickup_location_id,customer_delivery_snapshot
  on public.transaction_requests for each row execute function b2b_private.checkout_delivery_snapshot();
revoke all on function b2b_private.checkout_delivery_snapshot() from public,anon,authenticated;

create function public.resolve_checkout_attempt(p_request_id uuid) returns text
language plpgsql security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_row b2b_private.checkout_attempts%rowtype;
begin
  if v_uid is null then raise exception 'No autenticado' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':' || p_request_id::text,0));
  insert into b2b_private.checkout_attempts(aliado_id,request_id,state) values(v_uid,p_request_id,'cancelled')
    on conflict(aliado_id,request_id) do nothing;
  select * into v_row from b2b_private.checkout_attempts where aliado_id=v_uid and request_id=p_request_id for update;
  if v_row.state='completed' then return v_row.checkout_group_id::text; end if;
  update b2b_private.checkout_attempts set state='cancelled' where aliado_id=v_uid and request_id=p_request_id;
  return null;
end $$;
revoke all on function public.resolve_checkout_attempt(uuid) from public,anon;
grant execute on function public.resolve_checkout_attempt(uuid) to authenticated;

create function public.aliado_checkout_confirmar_v2(p_request_id uuid,p_lines jsonb,
  p_destino_entrega_usa_perfil boolean,p_destino_entrega_texto text default null,p_destino_entrega_maps_url text default null,
  p_promo_by_importador jsonb default '{}',p_carriers_by_importador jsonb default '{}',
  p_apply_credit_by_importador jsonb default '{}',p_moneda_by_importador jsonb default '{}',
  p_delivery_by_importador jsonb default '{}',p_saved_address_id uuid default null)
returns text language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_hash text; v_attempt b2b_private.checkout_attempts%rowtype; v_group text;
  v_owner uuid; v_choice jsonb; v_location public.importer_pickup_locations%rowtype;
  v_saved public.retailer_delivery_addresses%rowtype; v_snapshot jsonb; v_choices jsonb:='{}';
  v_use_profile boolean:=p_destino_entrega_usa_perfil; v_text text:=p_destino_entrega_texto;
  v_maps text:=p_destino_entrega_maps_url; v_carriers jsonb:=p_carriers_by_importador;
  v_previous_context text:=current_setting('b2b.checkout_delivery_v2',true);
begin
  if v_uid is null then raise exception 'No autenticado' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'Falta la referencia de confirmación.' using errcode='22023'; end if;
  v_hash:=md5(jsonb_build_object('lines',p_lines,'profile',p_destino_entrega_usa_perfil,'text',p_destino_entrega_texto,
    'maps',p_destino_entrega_maps_url,'promos',p_promo_by_importador,'carriers',p_carriers_by_importador,
    'credit',p_apply_credit_by_importador,'currency',p_moneda_by_importador,'delivery',p_delivery_by_importador,
    'address',p_saved_address_id)::text);
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':' || p_request_id::text,0));
  insert into b2b_private.checkout_attempts(aliado_id,request_id,payload_hash,state) values(v_uid,p_request_id,v_hash,'pending')
    on conflict(aliado_id,request_id) do nothing;
  select * into v_attempt from b2b_private.checkout_attempts where aliado_id=v_uid and request_id=p_request_id for update;
  if v_attempt.state='cancelled' then raise exception 'Esta confirmación fue cancelada. Revisa el pedido antes de enviarlo nuevamente.' using errcode='22023'; end if;
  if v_attempt.payload_hash<>v_hash then raise exception 'La confirmación anterior tiene otros datos.' using errcode='22023'; end if;
  if v_attempt.state='completed' then return v_attempt.checkout_group_id::text; end if;
  if p_lines is null or jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines)=0
    or jsonb_typeof(p_delivery_by_importador)<>'object' then
    raise exception 'Revisa los productos y la modalidad de entrega.' using errcode='22023'; end if;
  if p_saved_address_id is not null then
    select * into v_saved from public.retailer_delivery_addresses where id=p_saved_address_id and user_id=v_uid for share;
    if not found then raise exception 'La dirección guardada ya no está disponible.' using errcode='22023'; end if;
    v_use_profile:=false; v_text:='Estado: '||v_saved.estado||E'\nCiudad: '||v_saved.ciudad||E'\nDomicilio: '||v_saved.direccion;
    v_maps:=v_saved.maps_url;
    v_snapshot:=jsonb_build_object('label',v_saved.label,'estado',v_saved.estado,'ciudad',v_saved.ciudad,'direccion',v_saved.direccion,'maps_url',v_maps);
  elsif v_use_profile then
    select jsonb_build_object('label','Mi tienda','estado',p.estado,'ciudad',p.ciudad,'direccion',p.direccion,'maps_url',p.fiscal_maps_url)
      into v_snapshot from public.profiles p where p.id=v_uid;
  else
    v_snapshot:=jsonb_build_object('label','Otra dirección','direccion',v_text,'maps_url',v_maps);
  end if;
  if exists(select 1 from jsonb_object_keys(p_delivery_by_importador) k where not exists(
    select 1 from jsonb_array_elements(p_lines) x join public.products pr on pr.id=(x->>'product_id')::uuid where pr.owner_id::text=k)) then
    raise exception 'La modalidad contiene un proveedor ajeno al pedido.' using errcode='22023'; end if;
  for v_owner in select distinct pr.owner_id from jsonb_array_elements(p_lines) x
    join public.products pr on pr.id=(x->>'product_id')::uuid order by pr.owner_id
  loop
    v_choice:=coalesce(p_delivery_by_importador->v_owner::text,'{"mode":"DELIVERY"}'::jsonb);
    if v_choice->>'mode'='PICKUP' then
      select * into v_location from public.importer_pickup_locations where id=(v_choice->>'location_id')::uuid
        and importador_id=v_owner and is_active and customer_pickup_enabled for share;
      if not found then raise exception 'El punto de retiro ya no está disponible. Revisa la entrega.' using errcode='22023'; end if;
      v_choices:=v_choices||jsonb_build_object(v_owner::text,jsonb_build_object('mode','PICKUP','location_id',v_location.id,
        'snapshot',jsonb_build_object('label',v_location.label,'estado',v_location.estado,'ciudad',v_location.ciudad,
          'direccion',v_location.direccion,'maps_url',v_location.maps_url,'instructions',v_location.customer_pickup_instructions)));
      v_carriers:=v_carriers-v_owner::text;
    elsif v_choice->>'mode'='DELIVERY' then
      v_choices:=v_choices||jsonb_build_object(v_owner::text,jsonb_build_object('mode','DELIVERY','snapshot',v_snapshot));
    else raise exception 'Modalidad de entrega inválida.' using errcode='22023'; end if;
  end loop;
  perform set_config('b2b.checkout_delivery_v2',jsonb_build_object('user_id',v_uid,'suppliers',v_choices)::text,true);
  v_group:=public.aliado_checkout_proveedores_v1(p_lines,v_use_profile,v_text,v_maps,p_promo_by_importador,v_carriers,
    p_apply_credit_by_importador,'BOLIVARES',p_moneda_by_importador);
  perform set_config('b2b.checkout_delivery_v2',coalesce(v_previous_context,''),true);
  update b2b_private.checkout_attempts set state='completed',checkout_group_id=v_group::uuid where aliado_id=v_uid and request_id=p_request_id;
  return v_group;
end $$;
revoke all on function public.aliado_checkout_confirmar_v2(uuid,jsonb,boolean,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,uuid) from public,anon;
grant execute on function public.aliado_checkout_confirmar_v2(uuid,jsonb,boolean,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,uuid) to authenticated;
