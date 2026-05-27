-- =============================================================================
-- QA: limpiar valoraciones demo para probar cuestionario bucket_v2 (sliders)
-- =============================================================================
-- No borra usuarios ni catálogo. Permite volver a valorar pedidos entregados del seed.
--
-- Requisitos: migración 20260701120000_rating_questionnaire_bucket_v2.sql aplicada.
--
-- Uso:
--   supabase db query --linked -f supabase/scripts/reset_demo_order_ratings_for_v2.sql
--
-- Luego en la app (aliado1): Pedidos entregados → enviar valoración con sliders v2.
-- =============================================================================

begin;

delete from public.order_ratings
where importador_id::text like 'c100000%'
   or aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid;

update public.transaction_requests tr
set
  aliado_experience_stars = null,
  aliado_experience_comment = null,
  aliado_experience_submitted_at = null,
  updated_at = now()
where tr.aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid
  and tr.status = 'entregado';

do $$
declare
  v_id uuid;
begin
  for v_id in
    select p.id
    from public.profiles p
    where p.id::text like 'c100000%'
       or p.id = 'c2000001-0000-4000-8000-000000000001'::uuid
  loop
    perform public.refresh_profile_rating_aggregates(v_id);
  end loop;
end;
$$;

commit;
