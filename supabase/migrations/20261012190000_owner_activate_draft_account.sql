-- Activar un borrador: habilita acceso con el expediente ya cargado
-- (términos + KYC aliado), sin volver al registro inicial.

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
  v_prev text;
  v_role text;
begin
  perform public._owner_guard_target (p_profile_id);

  v_status := lower(trim(p_status));
  if v_status is null or v_status not in ('active', 'rejected') then
    raise exception 'Estado de acceso no valido';
  end if;

  if v_status = 'rejected' and v_note is null then
    raise exception 'Indique el motivo del bloqueo';
  end if;

  select p.account_access_status, p.role
    into v_prev, v_role
  from public.profiles p
  where p.id = p_profile_id;

  perform public._allow_profile_privilege ();

  if v_status = 'active' then
    update public.profiles
    set
      account_access_status = 'active',
      account_review_note = null,
      deactivated_at = null,
      deactivated_by = null,
      terms_accepted_at = coalesce(terms_accepted_at, now()),
      terms_version = coalesce(nullif(trim(terms_version), ''), '2026-06-13'),
      kyc_status = case
        when role = 'aliado' then 'aprobado'
        else kyc_status
      end
    where id = p_profile_id;

    if v_prev in ('draft', 'pending_review') then
      perform public.mc_insert_notification (
        p_profile_id,
        'Cuenta activada',
        'B2B Conecta habilitó su cuenta con el expediente cargado. Ya puede entrar.',
        'kyc',
        p_profile_id::text
      );
    else
      perform public.mc_insert_notification (
        p_profile_id,
        'Cuenta reactivada',
        'B2B Conecta restauró el acceso a su cuenta.',
        'kyc',
        p_profile_id::text
      );
    end if;
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
