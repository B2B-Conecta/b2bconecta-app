-- Hasta 3 imágenes por producto (`image_urls` jsonb). `image_url` = portada (slot 1).

alter table public.products
  add column if not exists image_urls jsonb not null default '[]'::jsonb;

comment on column public.products.image_urls is
  'URLs públicas de fotos del producto (máx. 3). image_url es la portada (índice 0).';

-- Migrar datos legacy.
update public.products
set image_urls = jsonb_build_array(image_url)
where image_url is not null
  and trim(image_url) <> ''
  and (image_urls is null or image_urls = '[]'::jsonb);

-- Sincronizar portada legacy.
create or replace function public.products_sync_image_url_from_urls ()
returns trigger
language plpgsql
as $$
declare
  v_first text;
  v_len integer;
begin
  if new.image_urls is null or jsonb_typeof(new.image_urls) <> 'array' then
    new.image_urls := '[]'::jsonb;
  end if;

  v_len := jsonb_array_length(new.image_urls);
  if v_len = 0 and new.image_url is not null and trim(new.image_url) <> '' then
    new.image_urls := jsonb_build_array(trim(new.image_url));
    v_len := 1;
  end if;

  if v_len > 3 then
    raise exception 'Un producto puede tener como máximo 3 imágenes';
  end if;

  v_first := nullif(trim(new.image_urls ->> 0), '');
  new.image_url := v_first;
  return new;
end;
$$;

drop trigger if exists products_sync_image_url_from_urls_trg on public.products;
create trigger products_sync_image_url_from_urls_trg
before insert or update of image_urls, image_url on public.products
for each row
execute function public.products_sync_image_url_from_urls ();

-- Actualiza image_urls en lote tras subida masiva desde la app.
create or replace function public.importador_bulk_set_product_images (
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_row jsonb;
  v_product_id uuid;
  v_urls jsonb;
  v_updated integer := 0;
  v_skipped integer := 0;
  v_errors jsonb := '[]'::jsonb;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden actualizar imágenes';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'p_rows debe ser un arreglo JSON';
  end if;

  for v_row in select * from jsonb_array_elements(p_rows)
  loop
    v_product_id := nullif(trim(v_row ->> 'product_id'), '')::uuid;
    v_urls := v_row -> 'image_urls';

    if v_product_id is null then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'code', 'MISSING_PRODUCT_ID',
        'message', 'product_id obligatorio'
      ));
      continue;
    end if;

    if v_urls is null or jsonb_typeof(v_urls) <> 'array' then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'product_id', v_product_id,
        'code', 'INVALID_URLS',
        'message', 'image_urls debe ser un arreglo'
      ));
      continue;
    end if;

    if jsonb_array_length(v_urls) > 3 then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'product_id', v_product_id,
        'code', 'TOO_MANY_IMAGES',
        'message', 'Máximo 3 imágenes por producto'
      ));
      continue;
    end if;

    update public.products pr
    set image_urls = v_urls
    where pr.id = v_product_id
      and pr.owner_id = v_uid;

    if found then
      v_updated := v_updated + 1;
    else
      v_skipped := v_skipped + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'updated', v_updated,
    'skipped', v_skipped,
    'errors', v_errors
  );
end;
$$;

grant execute on function public.importador_bulk_set_product_images (jsonb) to authenticated;
