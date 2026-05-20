-- Minuta #7 — Bloque C4: valoraciones estructuradas, mutuas y reputación en catálogo.

-- ---------------------------------------------------------------------------
-- 1) Tabla de valoraciones (fuente de verdad)
-- ---------------------------------------------------------------------------
create table if not exists public.order_ratings (
  id uuid not null default gen_random_uuid () primary key,
  checkout_group_id uuid,
  transaction_request_id uuid references public.transaction_requests (id) on delete set null,
  importador_id uuid not null references public.profiles (id) on delete restrict,
  aliado_id uuid not null references public.profiles (id) on delete restrict,
  rater_role text not null
    check (rater_role = any (array['aliado'::text, 'importador'::text])),
  ratee_role text not null
    check (ratee_role = any (array['importador'::text, 'aliado'::text])),
  overall_stars integer not null
    check (overall_stars >= 1 and overall_stars <= 5),
  comment text not null,
  questionnaire_version text not null default 'bucket_v1',
  answers jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now (),
  constraint order_ratings_role_pair_chk check (
    (
      rater_role = 'aliado'
      and ratee_role = 'importador'
    )
    or (
      rater_role = 'importador'
      and ratee_role = 'aliado'
    )
  ),
  constraint order_ratings_comment_nonempty_chk check (length(trim(comment)) > 0)
);

create index if not exists order_ratings_importador_idx
  on public.order_ratings (importador_id, submitted_at desc);

create index if not exists order_ratings_aliado_idx
  on public.order_ratings (aliado_id, submitted_at desc);

create unique index if not exists order_ratings_unique_carrito
  on public.order_ratings (checkout_group_id, importador_id, aliado_id, rater_role)
  where checkout_group_id is not null;

create unique index if not exists order_ratings_unique_linea
  on public.order_ratings (transaction_request_id, rater_role)
  where checkout_group_id is null
    and transaction_request_id is not null;

alter table public.order_ratings enable row level security;

-- Aliado ve sus propias valoraciones enviadas; importador ve recibidas (sin identidad del aliado en SELECT directo — usar RPC).
create policy order_ratings_select_own_rater on public.order_ratings
  for select
  to authenticated
  using (rater_role = 'aliado' and aliado_id = auth.uid ());

create policy order_ratings_select_own_rater_imp on public.order_ratings
  for select
  to authenticated
  using (rater_role = 'importador' and importador_id = auth.uid ());

create policy order_ratings_select_admin on public.order_ratings
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'
    )
  );

-- Inserts solo vía RPC security definer.

-- ---------------------------------------------------------------------------
-- 2) Agregados de reputación en perfiles
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists rating_avg_received numeric(4, 2),
  add column if not exists rating_count_received integer not null default 0,
  add column if not exists rating_as_payer_avg numeric(4, 2),
  add column if not exists rating_as_payer_count integer not null default 0;

comment on column public.profiles.rating_avg_received is
  'Promedio 1–5 como proveedor (valoraciones de aliados).';

comment on column public.profiles.rating_as_payer_avg is
  'Promedio 1–5 como pagador/cliente (valoraciones de importadores).';

-- ---------------------------------------------------------------------------
-- 3) Cuestionario Bucket List (configurable)
-- ---------------------------------------------------------------------------
insert into public.platform_settings (key, value)
values (
  'rating_questionnaire_bucket_v1',
  '{
    "version": "bucket_v1",
    "scale": { "min": 1, "max": 5 },
    "questions": [
      {
        "id": "product_quality",
        "text_es": "Calidad del producto: ¿La mercancía coincide con catálogo y etiquetas?",
        "applies_to": ["aliado_rates_importer"]
      },
      {
        "id": "dispatch_time",
        "text_es": "Tiempo de despacho: ¿Cumplió tiempos de preparación y entrega?",
        "applies_to": ["aliado_rates_importer"]
      },
      {
        "id": "packaging_condition",
        "text_es": "Estado del empaque: ¿Piezas sin daños y bien embaladas?",
        "applies_to": ["aliado_rates_importer"]
      },
      {
        "id": "communication",
        "text_es": "Atención y comunicación: ¿Respuestas satisfactorias en el chat?",
        "applies_to": ["aliado_rates_importer", "importer_rates_aliado"]
      },
      {
        "id": "payment_punctuality_transparency",
        "text_es": "Puntualidad y transparencia de pago: ¿El aliado cumplió plazos y fue claro al declarar método y comprobante de pago?",
        "applies_to": ["importer_rates_aliado"]
      },
      {
        "id": "supplier_b2b_experience",
        "text_es": "Proveedor B2B: ¿Cómo valora el desempeño del importador como socio (claridad comercial, cumplimiento y trato profesional)?",
        "applies_to": ["aliado_rates_importer"]
      }
    ]
  }'::jsonb
)
on conflict (key) do update
set
  value = excluded.value,
  updated_at = now ();

-- ---------------------------------------------------------------------------
-- 4) Recalcular agregados de reputación
-- ---------------------------------------------------------------------------
create or replace function public.refresh_profile_rating_aggregates (p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_as_supplier_avg numeric;
  v_as_supplier_cnt int;
  v_as_payer_avg numeric;
  v_as_payer_cnt int;
begin
  select
    round(avg(overall_stars)::numeric, 2),
    count(*)::int
    into v_as_supplier_avg, v_as_supplier_cnt
  from public.order_ratings r
  where r.ratee_role = 'importador'
    and r.importador_id = p_profile_id;

  select
    round(avg(overall_stars)::numeric, 2),
    count(*)::int
    into v_as_payer_avg, v_as_payer_cnt
  from public.order_ratings r
  where r.ratee_role = 'aliado'
    and r.aliado_id = p_profile_id;

  update public.profiles p
  set
    rating_avg_received = v_as_supplier_avg,
    rating_count_received = coalesce(v_as_supplier_cnt, 0),
    rating_as_payer_avg = v_as_payer_avg,
    rating_as_payer_count = coalesce(v_as_payer_cnt, 0)
  where p.id = p_profile_id;
end;
$$;

create or replace function public.trg_order_ratings_refresh_profiles ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.refresh_profile_rating_aggregates (new.importador_id);
  perform public.refresh_profile_rating_aggregates (new.aliado_id);
  return new;
end;
$$;

drop trigger if exists order_ratings_refresh_profiles on public.order_ratings;

create trigger order_ratings_refresh_profiles
after insert on public.order_ratings
for each row
execute function public.trg_order_ratings_refresh_profiles ();

-- ---------------------------------------------------------------------------
-- 5) RPC: cuestionario
-- ---------------------------------------------------------------------------
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
  v_out jsonb := '[]'::jsonb;
  v_q jsonb;
begin
  select ps.value
    into v_cfg
  from public.platform_settings ps
  where ps.key = 'rating_questionnaire_bucket_v1';

  if v_cfg is null then
    return jsonb_build_object('version', 'bucket_v1', 'questions', '[]'::jsonb);
  end if;

  for v_q in
    select elem
    from jsonb_array_elements(coalesce(v_cfg -> 'questions', '[]'::jsonb)) elem
  where elem -> 'applies_to' ? p_audience
  loop
    v_out := v_out || jsonb_build_array(v_q);
  end loop;

  return jsonb_build_object(
    'version', coalesce(v_cfg ->> 'version', 'bucket_v1'),
    'scale', coalesce(v_cfg -> 'scale', '{"min":1,"max":5}'::jsonb),
    'questions', v_out
  );
end;
$$;

grant execute on function public.get_rating_questionnaire (text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) RPC: aliado valora importador (reemplaza lógica extendida de experience)
-- ---------------------------------------------------------------------------
drop function if exists public.aliado_submit_order_experience (uuid, integer, text);

drop function if exists public.aliado_submit_order_experience_importador_grupo (
  uuid,
  uuid,
  integer,
  text
);

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
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Calificación inválida' using errcode = 'P0001';
  end if;
  if length(v_comment) < 1 then
    raise exception 'El comentario es obligatorio' using errcode = 'P0001';
  end if;

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
    p_stars,
    v_comment,
    'bucket_v1',
    coalesce(p_answers, '{}'::jsonb)
  );

  update public.transaction_requests tr
  set
    aliado_experience_stars = p_stars,
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
begin
  if v_aliado is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Calificación inválida' using errcode = 'P0001';
  end if;
  if length(v_comment) < 1 then
    raise exception 'El comentario es obligatorio' using errcode = 'P0001';
  end if;

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
    raise exception
      'No se puede registrar la valoración (pedidos no entregados o ya valorados).'
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
    p_stars,
    v_comment,
    'bucket_v1',
    coalesce(p_answers, '{}'::jsonb)
  );

  update public.transaction_requests tr
  set
    aliado_experience_stars = p_stars,
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

grant execute on function public.aliado_submit_order_experience (uuid, integer, text, jsonb)
  to authenticated;

grant execute on function public.aliado_submit_order_experience_importador_grupo (
  uuid,
  uuid,
  integer,
  text,
  jsonb
) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) RPC: importador valora aliado (mutua)
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
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Calificación inválida' using errcode = 'P0001';
  end if;
  if length(v_comment) < 1 then
    raise exception 'El comentario es obligatorio' using errcode = 'P0001';
  end if;

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
    p_stars,
    v_comment,
    'bucket_v1',
    coalesce(p_answers, '{}'::jsonb)
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
begin
  if v_imp is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Calificación inválida' using errcode = 'P0001';
  end if;
  if length(v_comment) < 1 then
    raise exception 'El comentario es obligatorio' using errcode = 'P0001';
  end if;

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
    p_stars,
    v_comment,
    'bucket_v1',
    coalesce(p_answers, '{}'::jsonb)
  );

  return 1;
end;
$$;

grant execute on function public.importer_submit_order_rating (uuid, integer, text, jsonb)
  to authenticated;

grant execute on function public.importer_submit_order_rating_importador_grupo (
  uuid,
  uuid,
  integer,
  text,
  jsonb
) to authenticated;

-- ---------------------------------------------------------------------------
-- 8) RPC: comentarios para importador (anónimos) y admin (identificados)
-- ---------------------------------------------------------------------------
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
    r.comment,
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

-- ---------------------------------------------------------------------------
-- 9) Backfill desde columnas legacy
-- ---------------------------------------------------------------------------
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
  answers,
  submitted_at
)
select
  tr.checkout_group_id,
  tr.id,
  tr.importador_id,
  tr.aliado_id,
  'aliado',
  'importador',
  tr.aliado_experience_stars,
  trim(tr.aliado_experience_comment),
  'bucket_v1',
  '{}'::jsonb,
  tr.aliado_experience_submitted_at
from public.transaction_requests tr
where tr.aliado_experience_submitted_at is not null
  and tr.aliado_experience_stars between 1 and 5
  and length(trim(coalesce(tr.aliado_experience_comment, ''))) > 0
  and not exists (
    select 1
    from public.order_ratings r
    where r.rater_role = 'aliado'
      and r.importador_id = tr.importador_id
      and r.aliado_id = tr.aliado_id
      and (
        (
          tr.checkout_group_id is not null
          and r.checkout_group_id = tr.checkout_group_id
        )
        or (
          tr.checkout_group_id is null
          and r.transaction_request_id = tr.id
        )
      )
  );

-- Recalcular agregados para perfiles con valoraciones
do $$
declare
  v_pid uuid;
begin
  for v_pid in
    select distinct importador_id
    from public.order_ratings
    where ratee_role = 'importador'
    union
    select distinct aliado_id
    from public.order_ratings
    where ratee_role = 'aliado'
  loop
    perform public.refresh_profile_rating_aggregates (v_pid);
  end loop;
end;
$$;
