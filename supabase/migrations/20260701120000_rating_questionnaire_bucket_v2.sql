-- C4 v2: cuestionario dimensional obligatorio, overall = promedio simple, sliders en app.

insert into public.platform_settings (key, value)
values (
  'rating_questionnaire_bucket_v1',
  '{
    "version": "bucket_v2",
    "scale": { "min": 1, "max": 5 },
    "label_scale": [
      { "value": 1, "label_es": "Muy mal" },
      { "value": 2, "label_es": "Mal" },
      { "value": 3, "label_es": "Regular" },
      { "value": 4, "label_es": "Bien" },
      { "value": 5, "label_es": "Excelente" }
    ],
    "questions": [
      {
        "id": "product_quality",
        "title_es": "Calidad",
        "subtitle_es": "El producto coincide con el catálogo y etiquetas",
        "applies_to": ["aliado_rates_importer"],
        "required": true
      },
      {
        "id": "dispatch_time",
        "title_es": "Despacho",
        "subtitle_es": "Cumplió con los tiempos de envío",
        "applies_to": ["aliado_rates_importer"],
        "required": true
      },
      {
        "id": "packaging_condition",
        "title_es": "Empaque",
        "subtitle_es": "La mercancía llegó protegida y en buen estado",
        "applies_to": ["aliado_rates_importer"],
        "required": true
      },
      {
        "id": "communication",
        "title_es": "Comunicación",
        "subtitle_es": "La atención por chat fue rápida y útil",
        "applies_to": ["aliado_rates_importer", "importer_rates_aliado"],
        "required": true
      },
      {
        "id": "supplier_b2b_experience",
        "title_es": "Socio B2B",
        "subtitle_es": "Calificación de su profesionalismo y trato comercial",
        "applies_to": ["aliado_rates_importer"],
        "required": true
      },
      {
        "id": "payment_punctuality_transparency",
        "title_es": "Pagos",
        "subtitle_es": "Cumplió con los plazos y reportó su pago claramente",
        "applies_to": ["importer_rates_aliado"],
        "required": true
      }
    ]
  }'::jsonb
)
on conflict (key) do update
set
  value = excluded.value,
  updated_at = now ();

-- ---------------------------------------------------------------------------
-- Helpers: validar respuestas y calcular overall (promedio simple redondeado).
-- ---------------------------------------------------------------------------
create or replace function public.rating_questionnaire_config ()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select ps.value
      from public.platform_settings ps
      where ps.key = 'rating_questionnaire_bucket_v1'
    ),
    '{"version":"bucket_v1","scale":{"min":1,"max":5},"questions":[]}'::jsonb
  );
$$;

create or replace function public.rating_questions_for_audience (p_audience text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_cfg jsonb;
  v_out jsonb := '[]'::jsonb;
  v_q jsonb;
begin
  v_cfg := public.rating_questionnaire_config ();
  for v_q in
    select elem
    from jsonb_array_elements(coalesce(v_cfg -> 'questions', '[]'::jsonb)) elem
    where elem -> 'applies_to' ? p_audience
  loop
    v_out := v_out || jsonb_build_array(v_q);
  end loop;
  return v_out;
end;
$$;

create or replace function public.resolve_rating_submission (
  p_audience text,
  p_stars integer,
  p_answers jsonb
)
returns table (
  overall_stars integer,
  questionnaire_version text,
  normalized_answers jsonb
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_cfg jsonb;
  v_version text;
  v_questions jsonb;
  v_q jsonb;
  v_id text;
  v_val int;
  v_sum numeric := 0;
  v_cnt int := 0;
  v_norm jsonb := '{}'::jsonb;
  v_scale_min int := 1;
  v_scale_max int := 5;
  v_use_v2 boolean;
begin
  v_cfg := public.rating_questionnaire_config ();
  v_version := coalesce(v_cfg ->> 'version', 'bucket_v1');
  v_questions := public.rating_questions_for_audience (p_audience);

  if (v_cfg -> 'scale' ->> 'min') is not null then
    v_scale_min := (v_cfg -> 'scale' ->> 'min')::int;
  end if;
  if (v_cfg -> 'scale' ->> 'max') is not null then
    v_scale_max := (v_cfg -> 'scale' ->> 'max')::int;
  end if;

  v_use_v2 := v_version = 'bucket_v2';

  if v_use_v2 then
    if v_questions is null or jsonb_array_length(v_questions) = 0 then
      raise exception 'Cuestionario no configurado para esta audiencia.'
        using errcode = 'P0001';
    end if;

    for v_q in select elem from jsonb_array_elements(v_questions) elem
    loop
      v_id := v_q ->> 'id';
      if v_id is null or length(trim(v_id)) = 0 then
        continue;
      end if;

      begin
        v_val := (p_answers ->> v_id)::int;
      exception
        when others then
          v_val := null;
      end;

      if v_val is null
        or v_val < v_scale_min
        or v_val > v_scale_max then
        raise exception 'Complete todas las categorías de la valoración (%).', v_id
          using errcode = 'P0001';
      end if;

      v_norm := v_norm || jsonb_build_object(v_id, v_val);
      v_sum := v_sum + v_val;
      v_cnt := v_cnt + 1;
    end loop;

    if v_cnt = 0 then
      raise exception 'Debe responder el cuestionario de valoración.'
        using errcode = 'P0001';
    end if;

    overall_stars := greatest(
      v_scale_min,
      least(v_scale_max, round(v_sum / v_cnt)::int)
    );
    questionnaire_version := 'bucket_v2';
    normalized_answers := v_norm;
    return next;
    return;
  end if;

  -- Legacy bucket_v1: estrellas enviadas por el cliente; respuestas opcionales.
  if p_stars is null or p_stars < v_scale_min or p_stars > v_scale_max then
    raise exception 'Calificación inválida' using errcode = 'P0001';
  end if;

  overall_stars := p_stars;
  questionnaire_version := 'bucket_v1';
  normalized_answers := coalesce(p_answers, '{}'::jsonb);
  return next;
end;
$$;

create or replace function public.get_rating_questionnaire (
  p_audience text default 'aliado_rates_importer'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_cfg jsonb;
begin
  v_cfg := public.rating_questionnaire_config ();
  return jsonb_build_object(
    'version', coalesce(v_cfg ->> 'version', 'bucket_v1'),
    'scale', coalesce(v_cfg -> 'scale', '{"min":1,"max":5}'::jsonb),
    'label_scale', coalesce(v_cfg -> 'label_scale', '[]'::jsonb),
    'questions', public.rating_questions_for_audience (p_audience)
  );
end;
$$;

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
  if length(v_comment) < 1 then
    raise exception 'El comentario es obligatorio' using errcode = 'P0001';
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
    aliado_experience_comment = v_comment,
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
  if length(v_comment) < 1 then
    raise exception 'El comentario es obligatorio' using errcode = 'P0001';
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
    aliado_experience_comment = v_comment,
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
  if length(v_comment) < 1 then
    raise exception 'El comentario es obligatorio' using errcode = 'P0001';
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
  if length(v_comment) < 1 then
    raise exception 'El comentario es obligatorio' using errcode = 'P0001';
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
