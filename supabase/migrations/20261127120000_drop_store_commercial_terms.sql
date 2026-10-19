-- Quita descuento por cantidad y descuento de pago en USD de los productos.
-- El precio de promoción sigue en sale_price_usd.

update public.products
set discount_rules = nullif(
  (
    coalesce(discount_rules, '{}'::jsonb)
    - 'volume_tiers'
    - 'usd_payment_discount_pct'
    - 'applied_usd_payment_discount_pct'
  ),
  '{}'::jsonb
)
where discount_rules is not null
  and (
    discount_rules ? 'volume_tiers'
    or discount_rules ? 'usd_payment_discount_pct'
    or discount_rules ? 'applied_usd_payment_discount_pct'
  );
