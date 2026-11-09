# Seed product images

Fotos de catálogo para el seed de desarrollo (no producción).

- **15 SKU de `importador1`**: imagen propia generada a partir del nombre del ítem.
- **`CAT-*.jpg`**: placeholders por categoría (Frenos / Motor / Transmisión) para el resto del catálogo seed.

## Publicar en DEV

```bash
# Sube a Storage product-images/seed/ del proyecto staging
bash scripts/upload_seed_product_images.sh staging

# Aplica campos completos + variantes + URLs de imagen
supabase link --project-ref kdrccmqcrruixuworlmz
supabase db query --linked -f supabase/scripts/seed_enrich_catalog.sql
```

URL pública base:

`https://kdrccmqcrruixuworlmz.supabase.co/storage/v1/object/public/product-images/seed/`
