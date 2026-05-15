# Archivo MotoLink (referencia en rama MotoConecta)

## `migrations_archive/`

Copia de las **109 migraciones SQL** del producto broker MotoLink que vivían en `supabase/migrations/`. Se retiraron de esa carpeta para que `supabase db reset` / `db push` no creen tablas legacy (`sub_orders`, `payment_schedule`, transportista, RPCs, etc.) en el proyecto MotoConecta.

No ejecutes estos archivos sobre la base MotoConecta salvo que estés portando funcionalidad a propósito.

## `policies_archive/`

Políticas RLS sueltas que acompañaban documentación MotoLink; el esquema MotoConecta define RLS dentro de `motoconecta/schema.sql`.
