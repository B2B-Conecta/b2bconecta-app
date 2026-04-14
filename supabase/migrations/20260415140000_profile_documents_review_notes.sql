-- Notas de revisión por documento y trazabilidad del revisor (broker MotoLink).

alter table public.profile_documents
  add column if not exists review_note text,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles (id) on delete set null;

create index if not exists profile_documents_reviewed_by_idx
  on public.profile_documents (reviewed_by);

-- ---------------------------------------------------------------------------
-- RPC: reemplazar firma para incluir nota opcional / obligatoria en rechazo
-- ---------------------------------------------------------------------------

drop function if exists public.admin_set_profile_document_review_status(uuid, text, text);

create or replace function public.admin_set_profile_document_review_status(
  p_aliado_id uuid,
  p_doc_type text,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden actualizar el estado de documentos';
  end if;
  if not exists (
    select 1 from public.profiles where id = p_aliado_id and role = 'aliado'
  ) then
    raise exception 'El perfil indicado no es un aliado';
  end if;
  if p_status not in ('pendiente', 'en_revision', 'aprobado', 'rechazado') then
    raise exception 'Estado de revisión no válido';
  end if;

  if p_status = 'rechazado' then
    if p_note is null or length(trim(p_note)) < 3 then
      raise exception 'Indique el motivo del rechazo (nota para el aliado, mín. 3 caracteres).';
    end if;
  end if;

  update public.profile_documents
  set
    review_status = p_status,
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_note = case
      when p_status = 'aprobado' then null
      when p_status = 'rechazado' then trim(p_note)
      when p_note is not null then nullif(trim(p_note), '')
      else review_note
    end
  where profile_id = p_aliado_id and doc_type = p_doc_type;

  if not found then
    raise exception 'No hay archivo cargado para ese tipo de documento';
  end if;
end;
$$;

grant execute on function public.admin_set_profile_document_review_status(uuid, text, text, text) to authenticated;
