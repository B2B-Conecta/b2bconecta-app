-- Polish: expediente admin incluye questionnaire_version por fila.

drop function if exists public.list_admin_order_ratings (uuid, uuid, integer, integer);

create or replace function public.list_admin_order_ratings (
  p_importador_id uuid default null,
  p_aliado_id uuid default null,
  p_limit integer default 50,
  p_offset integer default 0
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
  checkout_group_id uuid
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
    r.checkout_group_id
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
  order by r.submitted_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.list_admin_order_ratings (uuid, uuid, integer, integer)
  to authenticated;
