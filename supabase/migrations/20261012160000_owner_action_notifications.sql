-- Avisar en la campana al usuario afectado por acciones del owner.

create or replace function public.owner_set_profile_role (
  p_profile_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_label text;
begin
  perform public._owner_guard_target (p_profile_id);

  v_role := lower(trim(p_role));
  if v_role is null or v_role not in ('aliado', 'importador', 'administrador') then
    raise exception 'Rol no valido';
  end if;

  perform public._allow_profile_privilege ();

  update public.profiles
  set role = v_role
  where id = p_profile_id;

  v_label := case v_role
    when 'aliado' then 'tienda minorista'
    when 'importador' then 'importador'
    else 'administración'
  end;

  perform public.mc_insert_notification (
    p_profile_id,
    'Cambio de rol',
    format(
      'B2B Conecta asignó su cuenta como %s.',
      v_label
    ),
    'kyc',
    p_profile_id::text
  );
end;
$$;

create or replace function public.owner_set_account_access (
  p_profile_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_note text := nullif(trim(p_note), '');
begin
  perform public._owner_guard_target (p_profile_id);

  v_status := lower(trim(p_status));
  if v_status is null or v_status not in ('active', 'rejected') then
    raise exception 'Estado de acceso no valido';
  end if;

  if v_status = 'rejected' and v_note is null then
    raise exception 'Indique el motivo del bloqueo';
  end if;

  perform public._allow_profile_privilege ();

  if v_status = 'active' then
    update public.profiles
    set
      account_access_status = 'active',
      account_review_note = null,
      deactivated_at = null,
      deactivated_by = null
    where id = p_profile_id;

    perform public.mc_insert_notification (
      p_profile_id,
      'Cuenta reactivada',
      'B2B Conecta restauró el acceso a su cuenta.',
      'kyc',
      p_profile_id::text
    );
  else
    update public.profiles
    set
      account_access_status = 'rejected',
      account_review_note = v_note,
      deactivated_at = null,
      deactivated_by = null
    where id = p_profile_id;

    perform public.mc_insert_notification (
      p_profile_id,
      'Cuenta bloqueada',
      coalesce(v_note, 'B2B Conecta bloqueó el acceso a su cuenta.'),
      'kyc',
      p_profile_id::text
    );
  end if;
end;
$$;

create or replace function public.owner_deactivate_profile (
  p_profile_id uuid,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_note text := nullif(trim(p_note), '');
begin
  perform public._owner_guard_target (p_profile_id);

  if v_note is null then
    raise exception 'Indique el motivo de la baja';
  end if;

  perform public._allow_profile_privilege ();

  update public.profiles
  set
    account_access_status = 'rejected',
    account_review_note = v_note,
    deactivated_at = now(),
    deactivated_by = auth.uid ()
  where id = p_profile_id;

  perform public.mc_insert_notification (
    p_profile_id,
    'Cuenta deshabilitada',
    v_note,
    'kyc',
    p_profile_id::text
  );
end;
$$;

create or replace function public.owner_set_importer_products_active (
  p_product_ids uuid[],
  p_is_active boolean
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_rec record;
begin
  perform public._assert_owner ();

  if p_product_ids is null or cardinality(p_product_ids) = 0 then
    return 0;
  end if;

  update public.products p
  set is_active = p_is_active
  from public.profiles pr
  where p.id = any (p_product_ids)
    and p.owner_id = pr.id
    and pr.role = 'importador';

  get diagnostics v_count = row_count;

  if v_count > 0 then
    for v_rec in
      select
        p.owner_id,
        string_agg(p.name, ', ' order by p.name) as names,
        count(*)::integer as n
      from public.products p
      join public.profiles pr on pr.id = p.owner_id
      where p.id = any (p_product_ids)
        and pr.role = 'importador'
      group by p.owner_id
    loop
      if p_is_active then
        perform public.mc_insert_notification (
          v_rec.owner_id,
          'Producto publicado',
          case
            when v_rec.n = 1 then
              format(
                'B2B Conecta volvió a publicar «%s» en el catálogo.',
                v_rec.names
              )
            else
              format(
                'B2B Conecta volvió a publicar %s productos en el catálogo.',
                v_rec.n
              )
          end,
          'inventario',
          v_rec.owner_id::text
        );
      else
        perform public.mc_insert_notification (
          v_rec.owner_id,
          'Producto en pausa',
          case
            when v_rec.n = 1 then
              format(
                'B2B Conecta ocultó «%s» del catálogo. Las tiendas no lo verán.',
                v_rec.names
              )
            else
              format(
                'B2B Conecta pausó %s productos de su catálogo.',
                v_rec.n
              )
          end,
          'inventario',
          v_rec.owner_id::text
        );
      end if;
    end loop;
  end if;

  return v_count;
end;
$$;

create or replace function public.owner_delete_importer_products (p_product_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_payload jsonb := '[]'::jsonb;
  v_rec record;
begin
  perform public._assert_owner ();

  if p_product_ids is null or cardinality(p_product_ids) = 0 then
    return 0;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'owner_id', s.owner_id,
        'names', s.names,
        'n', s.n
      )
    ),
    '[]'::jsonb
  )
  into v_payload
  from (
    select
      p.owner_id,
      string_agg(p.name, ', ' order by p.name) as names,
      count(*)::integer as n
    from public.products p
    join public.profiles pr on pr.id = p.owner_id
    where p.id = any (p_product_ids)
      and pr.role = 'importador'
    group by p.owner_id
  ) s;

  delete from public.products p
  using public.profiles pr
  where p.id = any (p_product_ids)
    and p.owner_id = pr.id
    and pr.role = 'importador';

  get diagnostics v_count = row_count;

  if v_count > 0 then
    for v_rec in
      select *
      from jsonb_to_recordset(v_payload) as x(
        owner_id uuid,
        names text,
        n integer
      )
    loop
      perform public.mc_insert_notification (
        v_rec.owner_id,
        'Producto eliminado',
        case
          when v_rec.n = 1 then
            format(
              'B2B Conecta quitó «%s» de su inventario.',
              v_rec.names
            )
          else
            format(
              'B2B Conecta quitó %s productos de su inventario.',
              v_rec.n
            )
        end,
        'inventario',
        v_rec.owner_id::text
      );
    end loop;
  end if;

  return v_count;
end;
$$;
