# MotoConecta — esquema y seed (greenfield)

Marketplace B2B simplificado: solo roles **aliado**, **importador** y **administrador** (supervisor). Sin transportista ni logística en app.

## Cuándo usar esto

- **Proyecto Supabase nuevo** (p. ej. el entorno MotoConecta enlazado desde Flutter con `.env`).
- No ejecutes `schema.sql` sobre la base **MotoLink** legacy: chocaría con tablas antiguas.

## Local (Supabase CLI + Docker)

1. **`supabase start`** — levanta Postgres y servicios; hace falta **antes** de cualquier `db reset` / `db push` local.
2. **`supabase db reset --yes`** — reaplica migraciones + `seed.sql` sobre esa instancia.

Si ves `supabase start is not running`, ejecuta primero el paso 1.

## Migraciones en esta rama

Las migraciones históricas MotoLink **no** están en `supabase/migrations/`. Solo existe la baseline **`supabase/migrations/20260106000000_motoconecta_baseline.sql`**, que debe coincidir con este `schema.sql`.

## Orden recomendado (SQL Editor o `psql`)

1. `schema.sql` — crea tablas, índices, comisión generada al 5 %, `notifications`, `transaction_request_messages`, triggers mínimos y RLS.
2. Si la base ya existía con un esquema anterior MotoConecta: ejecuta **`upgrade_lat_lng_sku.sql`** (y revisa columnas nuevas manualmente si hace falta).
3. Si la app falla con **`proveedor_factura_storage_path` does not exist**: ejecuta en SQL Editor **`upgrade_proveedor_factura.sql`** (solo añade las columnas de adjunto).
4. Desde la raíz del repo, `supabase/seed.sql` — un importador, un aliado, un admin; perfiles con dirección fiscal de referencia; **15 productos** del importador; un pedido `pendiente` (valida `comision_motoconecta`).

Contraseña de todos los usuarios seed: **`SeedPass123!`**

| Rol | Email |
|-----|--------|
| Importador | `importador1@motoconecta.seed` |
| Aliado | `aliado1@motoconecta.seed` |
| Admin | `admin@motoconecta.seed` |

## Credenciales de API

No las guardes en el repositorio. Copia `.env.example` → `.env` y pega **Project URL** y **anon / publishable key** desde Supabase Dashboard → Project Settings → API.

## Realtime (chat)

En el Dashboard puedes añadir **`transaction_request_messages`** (y `notifications`) a **Database → Replication** si hace falta para `supabase_realtime`.

## Storage (factura del proveedor)

La app sube al bucket **`order-invoices`** (rutas `{transaction_request_id}/archivo`). Sin el bucket aparece **Bucket not found** (404).

- **Proyecto ya creado en la nube:** ejecuta en SQL Editor **`storage_order_invoices.sql`** (inserta el bucket y las políticas RLS en `storage.objects`). Es idempotente (`on conflict do nothing` + `drop policy if exists`).
- **Instalación nueva con `schema.sql` o `db reset`:** el mismo bloque va al final de `schema.sql` y en la migración baseline `20260106000000_motoconecta_baseline.sql`.

Si tu base es **MotoLink legacy** con `transaction_requests.owner_id`, revisa el comentario al inicio de `storage_order_invoices.sql` para extender las políticas.

## Próximos pasos (Flutter, rama `version/MotoConecta`)

1. Enlazar `.env` al proyecto Supabase MotoConecta (URL + clave publicable); no commitear secretos.
2. Retirar rol **transportista**: `AppHomeRole`, `main_shell`, paneles y servicios de envío/maps/ruta.
3. **Chat:** suscripción Realtime a `transaction_request_messages`; pantalla de hilo por pedido.
4. **Factura importador:** archivo en `order-invoices` + columnas `proveedor_factura_*` en `transaction_requests` (la app las actualiza vía Flutter).
5. **Admin:** solo lectura agregada / reportes sobre `transaction_requests` y `comision_motoconecta` (sin aprobación previa de pedidos).
