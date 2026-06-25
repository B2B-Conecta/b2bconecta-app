-- Documentación: visibilidad aliado en custom_fields._aliado_visible_keys (jsonb array).
-- Sin columna nueva; los metadatos viven en el mismo jsonb.

comment on column public.products.custom_fields is
  'Campos ERP. Incluye _aliado_visible_keys: array de claves visibles para aliados; '
  'el resto es información interna del importador.';
