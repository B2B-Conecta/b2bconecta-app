-- Catálogo aliado: precio = lista/oferta del importador (sin +10% markup MotoLink).
-- Comisión de plataforma sigue en liquidación semanal (E3), no en precio visible.

create or replace function public.motoconecta_aliado_unit_price_usd (
  p_price_usd numeric,
  p_sale_price_usd numeric,
  p_discount_rules jsonb,
  p_cantidad integer,
  p_fase_contado boolean
)
returns numeric
language sql
stable
as $$
  select round(
    (
      coalesce(nullif(p_sale_price_usd, 0::numeric), p_price_usd)
      * (1 - public.motoconecta_product_volume_discount_pct (p_discount_rules, p_cantidad) / 100.0)
    )::numeric,
    4
  );
$$;

comment on function public.motoconecta_aliado_unit_price_usd (numeric, numeric, jsonb, integer, boolean) is
  'E4: precio unitario aliado = mayorista (oferta o lista) menos % volumen; sin markup broker.';
