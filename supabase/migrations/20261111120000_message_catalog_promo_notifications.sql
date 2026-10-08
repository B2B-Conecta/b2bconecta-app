-- Avisos con emisor y contexto: mensaje, catálogo del proveedor y valla publicada.

create or replace function public.mc_profile_label (p_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(btrim(p.business_name), ''),
    'Un usuario'
  )
  from public.profiles p
  where p.id = p_id;
$$;

create or replace function public.mc_message_preview (
  p_body text,
  p_attachments jsonb default '[]'::jsonb
)
returns text
language plpgsql
immutable
as $$
declare
  v_text text := btrim(coalesce(p_body, ''));
  v_kind text;
begin
  if v_text = '' then
    v_kind := lower(coalesce(p_attachments->0->>'kind', ''));
    if v_kind = 'video' then
      return 'Te envió un video.';
    elsif v_kind in ('image', 'photo') then
      return 'Te envió una foto.';
    elsif jsonb_typeof(p_attachments) = 'array'
      and jsonb_array_length(p_attachments) > 0 then
      return 'Te envió un archivo.';
    end if;
    return 'Te escribió.';
  end if;
  if char_length(v_text) > 80 then
    return left(v_text, 77) || '…';
  end if;
  return v_text;
end;
$$;

create or replace function public.mc_notify_trm_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_imp uuid;
  v_product text;
  v_name text;
  v_preview text;
  v_body text;
begin
  perform set_config('row_security', 'off', true);

  select tr.aliado_id, tr.importador_id, nullif(btrim(pr.name), '')
    into v_aliado, v_imp, v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = new.transaction_request_id;

  if v_aliado is null then
    return new;
  end if;

  v_name := coalesce(public.mc_profile_label(new.author_id), 'Un usuario');
  v_preview := public.mc_message_preview(new.body, new.attachments);
  if v_product is not null then
    v_body := 'En el pedido de ' || v_product || ': ' || v_preview;
  else
    v_body := 'En tu pedido: ' || v_preview;
  end if;

  if new.author_role = 'aliado' and v_imp is not null then
    perform public.mc_insert_notification(
      v_imp,
      v_name,
      v_body,
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'importador' then
    perform public.mc_insert_notification(
      v_aliado,
      v_name,
      v_body,
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'administrador' then
    perform public.mc_insert_notification(
      v_aliado,
      'B2B Conecta',
      v_body,
      'mensaje',
      new.transaction_request_id::text
    );
    if v_imp is not null then
      perform public.mc_insert_notification(
        v_imp,
        'B2B Conecta',
        v_body,
        'mensaje',
        new.transaction_request_id::text
      );
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.mc_notify_store_supplier_message ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_imp uuid;
  v_product text;
  v_name text;
  v_preview text;
  v_body text;
begin
  perform set_config('row_security', 'off', true);

  select t.aliado_id, t.importador_id
    into v_aliado, v_imp
  from public.store_supplier_threads t
  where t.id = new.thread_id;

  v_product := nullif(btrim(coalesce(new.product_name, '')), '');
  v_name := coalesce(public.mc_profile_label(new.author_id), 'Un usuario');
  v_preview := public.mc_message_preview(new.body, '[]'::jsonb);

  if new.author_role = 'aliado' and v_imp is not null then
    v_body := case
      when v_product is not null then
        'Preguntó por ' || v_product || ': ' || v_preview
      else
        'Sobre tu catálogo: ' || v_preview
    end;
    perform public.mc_insert_notification(
      v_imp,
      v_name,
      v_body,
      'mensaje_directo',
      new.thread_id::text
    );
  elsif new.author_role = 'importador' and v_aliado is not null then
    v_body := case
      when v_product is not null then
        'Sobre ' || v_product || ': ' || v_preview
      else
        'Sobre su catálogo: ' || v_preview
    end;
    perform public.mc_insert_notification(
      v_aliado,
      v_name,
      v_body,
      'mensaje_directo',
      new.thread_id::text
    );
  end if;

  return new;
end;
$$;

alter table public.profiles
  add column if not exists catalog_announced_at timestamptz;

comment on column public.profiles.catalog_announced_at is
  'Momento en que se avisó a las tiendas que este proveedor publicó su catálogo inicial.';

update public.profiles p
set catalog_announced_at = coalesce(p.catalog_announced_at, now())
where p.role = 'importador'
  and p.catalog_announced_at is null
  and exists (
    select 1
    from public.products pr
    where pr.owner_id = p.id
      and pr.is_active
  );

create or replace function public.mc_notify_catalog_publication ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_name text;
  v_product text;
  v_is_importer boolean := false;
  v_first boolean := false;
  v_user uuid;
begin
  if new.is_active is distinct from true or new.owner_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.is_active is true then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select p.role = 'importador', public.mc_profile_label(p.id)
    into v_is_importer, v_name
  from public.profiles p
  where p.id = new.owner_id;

  if v_is_importer is distinct from true then
    return new;
  end if;

  v_owner := new.owner_id;
  v_product := coalesce(nullif(btrim(new.name), ''), 'un repuesto');

  update public.profiles
  set catalog_announced_at = now()
  where id = v_owner
    and catalog_announced_at is null;

  v_first := found;

  if v_first then
    for v_user in
      select p.id
      from public.profiles p
      where p.role = 'aliado'
        and p.deactivated_at is null
        and coalesce(p.account_access_status, 'active') = 'active'
        and p.id <> v_owner
    loop
      perform public.mc_insert_notification(
        v_user,
        v_name || ' publicó su catálogo',
        'Ya puedes ver sus repuestos en B2B Conecta.',
        'catalogo',
        v_owner::text
      );
    end loop;
    return new;
  end if;

  for v_user in
    select distinct audience.user_id
    from (
      select tr.aliado_id as user_id
      from public.transaction_requests tr
      where tr.importador_id = v_owner
      union
      select f.user_id
      from public.aliado_product_favorites f
      join public.products pr on pr.id = f.product_id
      where pr.owner_id = v_owner
    ) audience
    join public.profiles p on p.id = audience.user_id
    where p.role = 'aliado'
      and p.deactivated_at is null
      and coalesce(p.account_access_status, 'active') = 'active'
      and p.id <> v_owner
  loop
    perform public.mc_insert_notification(
      v_user,
      v_name,
      'Nuevo en su catálogo: ' || v_product || '.',
      'catalogo',
      new.id::text
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists products_notify_catalog_publication on public.products;

create trigger products_notify_catalog_publication
after insert or update of is_active on public.products
for each row
execute function public.mc_notify_catalog_publication ();

create or replace function public.mc_notify_promo_campaign_aliados ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_should boolean := false;
  v_name text;
  v_label text;
  v_offer text;
  v_title text;
  v_body text;
  v_user uuid;
begin
  if new.is_active is distinct from true then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_should := true;
  elsif tg_op = 'UPDATE' then
    v_should := old.is_active is distinct from true;
  end if;

  if not v_should then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  v_label := coalesce(
    nullif(btrim(new.display_title), ''),
    nullif(btrim(new.internal_title), ''),
    'una promoción'
  );

  if new.discount_percent is not null and new.discount_percent > 0 then
    v_offer := trim(to_char(new.discount_percent, 'FM999'))
      || '% en '
      || v_label;
  else
    v_offer := v_label;
  end if;

  if new.importador_id is not null then
    v_name := public.mc_profile_label(new.importador_id);
    v_title := 'Nueva promoción de ' || v_name;
  else
    v_title := 'Nueva promoción en el catálogo';
  end if;
  v_body := v_offer || '. Mírala en el catálogo.';

  for v_user in
    select p.id
    from public.profiles p
    where p.role = 'aliado'
      and p.deactivated_at is null
      and coalesce(p.account_access_status, 'active') = 'active'
  loop
    perform public.mc_insert_notification(
      v_user,
      v_title,
      v_body,
      'promocion',
      new.id::text
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists promo_campaigns_notify_aliados on public.promo_campaigns;

create trigger promo_campaigns_notify_aliados
after insert or update of is_active on public.promo_campaigns
for each row
execute function public.mc_notify_promo_campaign_aliados ();
