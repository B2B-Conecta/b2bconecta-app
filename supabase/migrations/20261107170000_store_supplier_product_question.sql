-- Una pregunta de la tienda puede referirse a un producto publicado del proveedor.
-- El hilo general de la vitrina no cambia: product_id queda null.

alter table public.store_supplier_messages
  add column if not exists product_id uuid references public.products (id) on delete set null,
  add column if not exists product_name text,
  add column if not exists product_sku text;

comment on column public.store_supplier_messages.product_id is
  'Producto publicado del proveedor cuando la tienda pregunta por un artículo. Null en el mensaje general de la vitrina.';

create index if not exists store_supplier_messages_product_idx
  on public.store_supplier_messages (product_id)
  where product_id is not null;

create or replace function public.store_supplier_message_attach_product()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_name text;
  v_sku text;
  v_active boolean;
  v_imp uuid;
begin
  if new.product_id is null then
    new.product_name := null;
    new.product_sku := null;
    return new;
  end if;

  select t.importador_id
    into v_imp
  from public.store_supplier_threads t
  where t.id = new.thread_id;

  select p.owner_id, p.name, p.sku, p.is_active
    into v_owner, v_name, v_sku, v_active
  from public.products p
  where p.id = new.product_id;

  if v_owner is distinct from v_imp or v_active is not true then
    raise exception 'El producto no pertenece al catálogo publicado de ese proveedor'
      using errcode = '23514';
  end if;

  new.product_name := nullif(btrim(coalesce(v_name, '')), '');
  new.product_sku := nullif(btrim(coalesce(v_sku, '')), '');
  return new;
end;
$$;

drop trigger if exists trg_store_supplier_message_attach_product
  on public.store_supplier_messages;

create trigger trg_store_supplier_message_attach_product
  before insert on public.store_supplier_messages
  for each row
  execute function public.store_supplier_message_attach_product();

create or replace function public.mc_notify_store_supplier_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_imp uuid;
  v_product text;
begin
  select t.aliado_id, t.importador_id
    into v_aliado, v_imp
  from public.store_supplier_threads t
  where t.id = new.thread_id;

  v_product := nullif(btrim(coalesce(new.product_name, '')), '');

  if new.author_role = 'aliado' and v_imp is not null then
    perform public.mc_insert_notification(
      v_imp,
      'Nuevo mensaje',
      case
        when v_product is not null then 'Una tienda preguntó por ' || v_product || '.'
        else 'Una tienda te escribió sobre tu catálogo.'
      end,
      'mensaje_directo',
      new.thread_id::text
    );
  elsif new.author_role = 'importador' and v_aliado is not null then
    perform public.mc_insert_notification(
      v_aliado,
      'Nuevo mensaje del proveedor',
      'El proveedor respondió en la conversación de su catálogo.',
      'mensaje_directo',
      new.thread_id::text
    );
  end if;

  return new;
end;
$$;
