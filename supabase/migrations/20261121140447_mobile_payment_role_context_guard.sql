-- Existing order triggers can SET LOCAL row_security. Isolate their settings
-- inside the payment RPC so the calling API transaction retains its context.
alter function public.aliado_submit_supplier_payment_v1(uuid[],text,jsonb,text,text) set row_security=on;
