-- Importadores: consultar aliados con KYC aprobado y ver documentación para evaluar crédito B2B.

create or replace function public.list_kyc_approved_aliados_for_importador ()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  select p.role
    into v_role
  from public.profiles p
  where p.id = auth.uid ();

  if v_role is distinct from 'importador' then
    raise exception 'Solo importadores pueden consultar aliados verificados.';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'business_name', p.business_name,
          'rif', p.rif,
          'phone', p.phone,
          'estado', p.estado,
          'ciudad', p.ciudad,
          'direccion', p.direccion,
          'fiscal_maps_url', p.fiscal_maps_url,
          'logo_storage_path', p.logo_storage_path,
          'kyc_status', p.kyc_status,
          'rating_as_payer_avg_rolling100', p.rating_as_payer_avg_rolling100,
          'rating_as_payer_count_rolling100', p.rating_as_payer_count_rolling100,
          'approved_document_count', (
            select count(*)::int
            from public.profile_documents pd
            where pd.profile_id = p.id
              and pd.is_current = true
              and pd.review_status = 'aprobado'
          )
        )
        order by p.business_name nulls last, p.id
      )
      from public.profiles p
      where p.role = 'aliado'
        and p.kyc_status = 'aprobado'
    ),
    '[]'::jsonb
  );
end;
$$;

grant execute on function public.list_kyc_approved_aliados_for_importador () to authenticated;

-- Lectura de documentos aprobados: contraparte en pedido O aliado KYC aprobado (importador).
drop policy if exists profile_documents_select_counterparty on public.profile_documents;

create policy profile_documents_select_counterparty
on public.profile_documents
for select
to authenticated
using (
  is_current = true
  and review_status = 'aprobado'::text
  and (
    exists (
      select 1
      from public.transaction_requests tr
      where (
        tr.aliado_id = auth.uid ()
        and tr.importador_id = profile_documents.profile_id
      )
      or (
        tr.importador_id = auth.uid ()
        and tr.aliado_id = profile_documents.profile_id
      )
    )
    or exists (
      select 1
      from public.profiles p_ally
      inner join public.profiles p_imp on p_imp.id = auth.uid ()
      where p_ally.id = profile_documents.profile_id
        and p_ally.role = 'aliado'
        and p_ally.kyc_status = 'aprobado'
        and p_imp.role = 'importador'
    )
  )
);

drop policy if exists profile_documents_storage_select on storage.objects;

create policy profile_documents_storage_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-documents'
  and (
    (storage.foldername (name))[1] = auth.uid ()::text
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'::text
    )
    or exists (
      select 1
      from public.profile_documents pd
      where pd.storage_path = name
        and pd.is_current = true
        and pd.review_status = 'aprobado'::text
        and (
          exists (
            select 1
            from public.transaction_requests tr
            where (
              tr.aliado_id = auth.uid ()
              and tr.importador_id = pd.profile_id
            )
            or (
              tr.importador_id = auth.uid ()
              and tr.aliado_id = pd.profile_id
            )
          )
          or exists (
            select 1
            from public.profiles p_ally
            inner join public.profiles p_imp on p_imp.id = auth.uid ()
            where p_ally.id = pd.profile_id
              and p_ally.role = 'aliado'
              and p_ally.kyc_status = 'aprobado'
              and p_imp.role = 'importador'
          )
        )
    )
  )
);

comment on function public.list_kyc_approved_aliados_for_importador () is
  'Directorio de aliados con KYC aprobado visible para importadores (evaluación crédito B2B).';
