-- Demo: desglose dimensional en perfiles importador1/2 (sin order_ratings).
-- Idempotente; no altera rating_avg_received.

update public.profiles
set rating_dimensions_received_rolling100 = '{
  "product_quality": {"avg": 4.75, "count": 18},
  "dispatch_time": {"avg": 4.55, "count": 18},
  "packaging_condition": {"avg": 4.50, "count": 18},
  "communication": {"avg": 4.65, "count": 18},
  "supplier_b2b_experience": {"avg": 4.70, "count": 18}
}'::jsonb
where id = 'c1000001-0000-4000-8000-000000000001'::uuid;

update public.profiles
set rating_dimensions_received_rolling100 = '{
  "product_quality": {"avg": 4.45, "count": 12},
  "dispatch_time": {"avg": 4.35, "count": 12},
  "packaging_condition": {"avg": 4.40, "count": 12},
  "communication": {"avg": 4.50, "count": 12},
  "supplier_b2b_experience": {"avg": 4.30, "count": 12}
}'::jsonb
where id = 'c1000002-0000-4000-8000-000000000001'::uuid;
