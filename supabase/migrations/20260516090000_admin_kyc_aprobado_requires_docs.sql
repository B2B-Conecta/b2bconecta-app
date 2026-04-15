-- Al marcar KYC global como aprobado vía admin, exigir los 6 documentos obligatorios
-- cargados y con revisión individual aprobada (coherente con la sincronización por documento).

create or replace function public.admin_set_aliado_kyc_status(
  p_aliado_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  required constant text[] := array[
    'acta_constitutiva',
    'registro_mercantil',
    'cedula_representante',
    'referencia_bancaria_1',
    'referencia_bancaria_2',
    'referencia_comercial'
  ];
  missing int;
  not_aprobado int;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden actualizar el estado KYC';
  end if;
  if not exists (
    select 1 from public.profiles where id = p_aliado_id and role = 'aliado'
  ) then
    raise exception 'El perfil indicado no es un aliado';
  end if;
  if p_status not in ('pendiente', 'en_revision', 'aprobado', 'rechazado') then
    raise exception 'Estado KYC no válido';
  end if;

  if p_status = 'aprobado' then
    select count(*)::int into missing
    from unnest(required) as exp(dt)
    where not exists (
      select 1 from public.profile_documents pd
      where pd.profile_id = p_aliado_id
        and pd.doc_type = exp.dt
        and pd.storage_path is not null
        and length(trim(pd.storage_path)) > 0
    );

    if missing > 0 then
      raise exception
        'No se puede marcar KYC como aprobado: deben estar registrados los 6 documentos obligatorios (archivo cargado por tipo).';
    end if;

    select count(*)::int into not_aprobado
    from public.profile_documents pd
    where pd.profile_id = p_aliado_id
      and pd.doc_type = any(required)
      and pd.review_status is distinct from 'aprobado';

    if not_aprobado > 0 then
      raise exception
        'No se puede marcar KYC como aprobado: cada documento obligatorio debe tener estado de revisión «aprobado».';
    end if;
  end if;

  update public.profiles
  set kyc_status = p_status
  where id = p_aliado_id and role = 'aliado';
end;
$$;
