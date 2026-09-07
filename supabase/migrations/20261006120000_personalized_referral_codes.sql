-- Códigos de vendedor externo: NOMBRE.B2B (p. ej. PEDRO.B2B).
-- No regenera códigos ya emitidos.

create or replace function public.generate_personalized_referral_code (p_full_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_first text;
  v_stem text;
  v_code text;
  v_n int := 1;
begin
  v_first := split_part(btrim(coalesce(p_full_name, '')), ' ', 1);
  v_first := translate(
    upper(v_first),
    'ÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇÝ',
    'AAAAAAEEEEIIIIOOOOOUUUUNCY'
  );
  v_stem := regexp_replace(v_first, '[^A-Z0-9]', '', 'g');
  if length(v_stem) < 2 then
    v_stem := 'VENDEDOR';
  end if;
  if length(v_stem) > 16 then
    v_stem := left(v_stem, 16);
  end if;

  loop
    if v_n = 1 then
      v_code := v_stem || '.B2B';
    else
      v_code := v_stem || v_n::text || '.B2B';
    end if;

    exit when
      not exists (
        select 1
        from public.external_referrers e
        where upper(e.code) = upper(v_code)
      )
      and not exists (
        select 1
        from public.profiles p
        where upper(p.referral_code) = upper(v_code)
      );

    v_n := v_n + 1;
    if v_n > 99 then
      return public.generate_unique_referral_code ();
    end if;
  end loop;

  return v_code;
end;
$$;

create or replace function public.admin_create_external_referrer (
  p_full_name text,
  p_phone text,
  p_email text,
  p_notes text default null
)
returns public.external_referrers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_admin ();
  v_row public.external_referrers;
begin
  if btrim(coalesce(p_full_name, '')) = '' then
    raise exception 'Nombre requerido.';
  end if;
  if btrim(coalesce(p_phone, '')) = '' then
    raise exception 'Teléfono requerido.';
  end if;
  if btrim(coalesce(p_email, '')) = '' then
    raise exception 'Correo requerido.';
  end if;

  insert into public.external_referrers (
    full_name,
    phone,
    email,
    code,
    notes,
    created_by
  )
  values (
    btrim(p_full_name),
    btrim(p_phone),
    lower(btrim(p_email)),
    public.generate_personalized_referral_code (p_full_name),
    nullif(btrim(coalesce(p_notes, '')), ''),
    v_uid
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.admin_create_external_referrer (text, text, text, text)
  to authenticated;

create or replace function public.profile_apply_referral_code (p_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_ext record;
  v_me record;
  v_code_nodot text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  v_code := regexp_replace(v_code, '\s+', '', 'g');
  v_code_nodot := replace(v_code, '.', '');

  if v_code = '' or v_code_nodot = '' then
    raise exception 'Indique un código de referido.';
  end if;

  select
    p.id,
    p.referred_by_external_id,
    p.referred_by_profile_id,
    p.business_name
  into v_me
  from public.profiles p
  where p.id = v_uid
  for update;

  if not found then
    raise exception 'Complete su perfil antes de aplicar un código de referido.';
  end if;

  if v_me.referred_by_external_id is not null
     or v_me.referred_by_profile_id is not null then
    raise exception 'Ya tiene un referido registrado; no se puede cambiar.';
  end if;

  select e.id, e.full_name, e.code
  into v_ext
  from public.external_referrers e
  where e.active
    and (
      upper(e.code) = v_code
      or replace(upper(e.code), '.', '') = v_code_nodot
    )
  limit 1;

  if not found then
    raise exception 'Código de referido no válido.';
  end if;

  update public.profiles
  set
    referred_by_external_id = v_ext.id,
    referred_by_profile_id = null,
    referred_at = now()
  where id = v_uid;
end;
$$;

grant execute on function public.profile_apply_referral_code (text) to authenticated;
