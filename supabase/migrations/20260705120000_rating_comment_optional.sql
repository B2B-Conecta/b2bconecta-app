-- Comentario opcional en valoraciones (UI + RPC).

alter table public.order_ratings
  drop constraint if exists order_ratings_comment_nonempty_chk;

-- ---------------------------------------------------------------------------
-- Aliado valora importador
-- ---------------------------------------------------------------------------
create or replace function public.aliado_submit_order_experience (
  p_request_id uuid,
  p_stars integer,
  p_comment text,
  p_answers jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tr record;
  v_comment text := trim(coalesce(p_comment, ''));
  v_res record;
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_res
  from public.resolve_rating_submission (
    'aliado_rates_importer',
    p_stars,
    coalesce(p_answers, '{}'::jsonb)
  );

  select tr.id, tr.checkout_group_id, tr.importador_id, tr.aliado_id
    into v_tr
  from public.transaction_requests tr
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid ()
    and tr.status = 'entregado'::text
    and tr.aliado_experience_submitted_at is null;

  if not found then
    raise exception 'No se puede registrar la valoración en este pedido.'
      using errcode = 'P0001';
  end if;

  insert into public.order_ratings (
    checkout_group_id,
    transaction_request_id,
    importador_id,
    aliado_id,
    rater_role,
    ratee_role,
    overall_stars,
    comment,
    questionnaire_version,
    answers
  )
  values (
    v_tr.checkout_group_id,
    v_tr.id,
    v_tr.importador_id,
    v_tr.aliado_id,
    'aliado',
    'importador',
    v_res.overall_stars,
    v_comment,
    v_res.questionnaire_version,
    v_res.normalized_answers
  );

  update public.transaction_requests tr
  set
    aliado_experience_stars = v_res.overall_stars,
    aliado_experience_comment = nullif(v_comment, ''),
    aliado_experience_submitted_at = now (),
    updated_at = now ()
  where tr.id = p_request_id;
end;
$$;

create or replace function public.aliado_submit_order_experience_importador_grupo (
  p_checkout_group_id uuid,
  p_importador_id uuid,
  p_stars integer,
  p_comment text,
  p_answers jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
  v_comment text := trim(coalesce(p_comment, ''));
  v_aliado uuid := auth.uid ();
  v_anchor uuid;
  v_res record;
begin
  if v_aliado is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_res
  from public.resolve_rating_submission (
    'aliado_rates_importer',
    p_stars,
    coalesce(p_answers, '{}'::jsonb)
  );

  select tr.id
    into v_anchor
  from public.transaction_requests tr
  where tr.checkout_group_id = p_checkout_group_id
    and tr.importador_id = p_importador_id
    and tr.aliado_id = v_aliado
    and tr.status = 'entregado'::text
    and tr.aliado_experience_submitted_at is null
  limit 1;

  if v_anchor is null then
    raise exception 'No se puede registrar la valoración en este pedido.'
      using errcode = 'P0001';
  end if;

  insert into public.order_ratings (
    checkout_group_id,
    transaction_request_id,
    importador_id,
    aliado_id,
    rater_role,
    ratee_role,
    overall_stars,
    comment,
    questionnaire_version,
    answers
  )
  values (
    p_checkout_group_id,
    v_anchor,
    p_importador_id,
    v_aliado,
    'aliado',
    'importador',
    v_res.overall_stars,
    v_comment,
    v_res.questionnaire_version,
    v_res.normalized_answers
  );

  update public.transaction_requests tr
  set
    aliado_experience_stars = v_res.overall_stars,
    aliado_experience_comment = nullif(v_comment, ''),
    aliado_experience_submitted_at = now (),
    updated_at = now ()
  where tr.checkout_group_id = p_checkout_group_id
    and tr.importador_id = p_importador_id
    and tr.aliado_id = v_aliado
    and tr.status = 'entregado'::text
    and tr.aliado_experience_submitted_at is null;

  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- Importador valora aliado
-- ---------------------------------------------------------------------------
create or replace function public.importer_submit_order_rating (
  p_request_id uuid,
  p_stars integer,
  p_comment text,
  p_answers jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tr record;
  v_comment text := trim(coalesce(p_comment, ''));
  v_res record;
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_res
  from public.resolve_rating_submission (
    'importer_rates_aliado',
    p_stars,
    coalesce(p_answers, '{}'::jsonb)
  );

  select tr.id, tr.checkout_group_id, tr.importador_id, tr.aliado_id
    into v_tr
  from public.transaction_requests tr
  where tr.id = p_request_id
    and tr.importador_id = auth.uid ()
    and tr.status = 'entregado'::text;

  if not found then
    raise exception 'No se puede registrar la valoración en este pedido.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.order_ratings r
    where r.rater_role = 'importador'
      and r.importador_id = v_tr.importador_id
      and r.aliado_id = v_tr.aliado_id
      and (
        (
          v_tr.checkout_group_id is not null
          and r.checkout_group_id = v_tr.checkout_group_id
        )
        or (
          v_tr.checkout_group_id is null
          and r.transaction_request_id = v_tr.id
        )
      )
  ) then
    raise exception 'La valoración de este aliado ya fue registrada.'
      using errcode = 'P0001';
  end if;

  insert into public.order_ratings (
    checkout_group_id,
    transaction_request_id,
    importador_id,
    aliado_id,
    rater_role,
    ratee_role,
    overall_stars,
    comment,
    questionnaire_version,
    answers
  )
  values (
    v_tr.checkout_group_id,
    v_tr.id,
    v_tr.importador_id,
    v_tr.aliado_id,
    'importador',
    'aliado',
    v_res.overall_stars,
    v_comment,
    v_res.questionnaire_version,
    v_res.normalized_answers
  );
end;
$$;

create or replace function public.importer_submit_order_rating_importador_grupo (
  p_checkout_group_id uuid,
  p_aliado_id uuid,
  p_stars integer,
  p_comment text,
  p_answers jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_comment text := trim(coalesce(p_comment, ''));
  v_imp uuid := auth.uid ();
  v_anchor uuid;
  v_res record;
begin
  if v_imp is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_res
  from public.resolve_rating_submission (
    'importer_rates_aliado',
    p_stars,
    coalesce(p_answers, '{}'::jsonb)
  );

  select tr.id
    into v_anchor
  from public.transaction_requests tr
  where tr.checkout_group_id = p_checkout_group_id
    and tr.importador_id = v_imp
    and tr.aliado_id = p_aliado_id
    and tr.status = 'entregado'::text
  limit 1;

  if v_anchor is null then
    raise exception 'No se puede registrar la valoración en este pedido.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.order_ratings r
    where r.checkout_group_id = p_checkout_group_id
      and r.importador_id = v_imp
      and r.aliado_id = p_aliado_id
      and r.rater_role = 'importador'
  ) then
    raise exception 'La valoración de este aliado ya fue registrada.'
      using errcode = 'P0001';
  end if;

  insert into public.order_ratings (
    checkout_group_id,
    transaction_request_id,
    importador_id,
    aliado_id,
    rater_role,
    ratee_role,
    overall_stars,
    comment,
    questionnaire_version,
    answers
  )
  values (
    p_checkout_group_id,
    v_anchor,
    v_imp,
    p_aliado_id,
    'importador',
    'aliado',
    v_res.overall_stars,
    v_comment,
    v_res.questionnaire_version,
    v_res.normalized_answers
  );

  return 1;
end;
$$;
