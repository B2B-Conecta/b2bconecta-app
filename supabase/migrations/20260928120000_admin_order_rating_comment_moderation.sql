-- Moderación admin v1: ocultar/restaurar comentario de valoración (estrellas intactas).

alter table public.order_ratings
  add column if not exists comment_hidden_at timestamptz,
  add column if not exists comment_hidden_by uuid references public.profiles (id),
  add column if not exists comment_hidden_reason text;

comment on column public.order_ratings.comment_hidden_at is
  'Si no es null, el comentario de texto está oculto en vistas públicas.';
comment on column public.order_ratings.comment_hidden_by is
  'Admin que ocultó el comentario.';
comment on column public.order_ratings.comment_hidden_reason is
  'Motivo opcional de moderación.';

create or replace function public.admin_set_order_rating_comment_hidden (
  p_rating_id uuid,
  p_hidden boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_rater text;
  v_tr uuid;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_uid
      and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden moderar valoraciones';
  end if;

  if p_rating_id is null then
    raise exception 'Valoración requerida';
  end if;

  select r.rater_role, r.transaction_request_id
    into v_rater, v_tr
  from public.order_ratings r
  where r.id = p_rating_id;

  if not found then
    raise exception 'Valoración no encontrada';
  end if;

  if p_hidden then
    update public.order_ratings
    set
      comment_hidden_at = now(),
      comment_hidden_by = v_uid,
      comment_hidden_reason = v_reason
    where id = p_rating_id;

    -- Campo legado espejo en el pedido (comentario aliado → importador).
    if v_rater = 'aliado' and v_tr is not null then
      update public.transaction_requests
      set aliado_experience_comment = null
      where id = v_tr;
    end if;
  else
    update public.order_ratings
    set
      comment_hidden_at = null,
      comment_hidden_by = null,
      comment_hidden_reason = null
    where id = p_rating_id;
  end if;
end;
$$;

grant execute on function public.admin_set_order_rating_comment_hidden (uuid, boolean, text)
  to authenticated;

-- Admin list: incluir flags de moderación + filtro opcional.
drop function if exists public.list_admin_order_ratings (uuid, uuid, integer, integer);

create or replace function public.list_admin_order_ratings (
  p_importador_id uuid default null,
  p_aliado_id uuid default null,
  p_limit integer default 50,
  p_offset integer default 0,
  p_comment_hidden boolean default null
)
returns table (
  id uuid,
  overall_stars integer,
  comment text,
  answers jsonb,
  questionnaire_version text,
  submitted_at timestamptz,
  rater_role text,
  ratee_role text,
  importador_id uuid,
  importador_name text,
  aliado_id uuid,
  aliado_name text,
  checkout_group_id uuid,
  comment_hidden boolean,
  comment_hidden_at timestamptz,
  comment_hidden_reason text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.overall_stars,
    r.comment,
    r.answers,
    r.questionnaire_version,
    r.submitted_at,
    r.rater_role,
    r.ratee_role,
    r.importador_id,
    pi.business_name as importador_name,
    r.aliado_id,
    pa.business_name as aliado_name,
    r.checkout_group_id,
    (r.comment_hidden_at is not null) as comment_hidden,
    r.comment_hidden_at,
    r.comment_hidden_reason
  from public.order_ratings r
  join public.profiles pi on pi.id = r.importador_id
  join public.profiles pa on pa.id = r.aliado_id
  where exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
  )
    and (p_importador_id is null or r.importador_id = p_importador_id)
    and (p_aliado_id is null or r.aliado_id = p_aliado_id)
    and (
      p_comment_hidden is null
      or (p_comment_hidden = true and r.comment_hidden_at is not null)
      or (p_comment_hidden = false and r.comment_hidden_at is null)
    )
  order by r.submitted_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.list_admin_order_ratings (
  uuid, uuid, integer, integer, boolean
) to authenticated;

-- Vistas públicas: no devolver texto si está oculto (estrellas sí).
create or replace function public.list_importador_received_ratings (
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (
  id uuid,
  overall_stars integer,
  comment text,
  answers jsonb,
  submitted_at timestamptz,
  aliado_label text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.overall_stars,
    case
      when r.comment_hidden_at is not null then ''::text
      else coalesce(r.comment, '')
    end as comment,
    r.answers,
    r.submitted_at,
    (
      'Aliado de '
      || coalesce(nullif(trim(pa.ciudad), ''), nullif(trim(pa.estado), ''), 'Venezuela')
    ) as aliado_label
  from public.order_ratings r
  join public.profiles pa on pa.id = r.aliado_id
  where r.ratee_role = 'importador'
    and r.rater_role = 'aliado'
    and r.importador_id = auth.uid ()
  order by r.submitted_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.list_importador_received_ratings (integer, integer)
  to authenticated;

create or replace function public.list_aliado_received_ratings (
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (
  id uuid,
  overall_stars integer,
  comment text,
  answers jsonb,
  submitted_at timestamptz,
  importer_label text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.overall_stars,
    case
      when r.comment_hidden_at is not null then ''::text
      else coalesce(r.comment, '')
    end as comment,
    r.answers,
    r.submitted_at,
    (
      'Importador de '
      || coalesce(nullif(trim(pi.ciudad), ''), nullif(trim(pi.estado), ''), 'Venezuela')
    ) as importer_label
  from public.order_ratings r
  join public.profiles pi on pi.id = r.importador_id
  where r.ratee_role = 'aliado'
    and r.rater_role = 'importador'
    and r.aliado_id = auth.uid ()
  order by r.submitted_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.list_aliado_received_ratings (integer, integer)
  to authenticated;
