# MotoConecta — esquema y seed (greenfield)

Marketplace B2B simplificado: solo roles **aliado**, **importador** y **administrador** (supervisor). Sin transportista ni logística en app.

## Cuándo usar esto

- **Proyecto Supabase** enlazado desde Flutter con `.env` (esta rama asume solo esquema MotoConecta).

## Local (Supabase CLI + Docker)

1. **`supabase start`** — levanta Postgres y servicios; hace falta **antes** de cualquier `db reset` / `db push` local.
2. **`supabase db reset --yes`** — reaplica migraciones + `seed.sql` sobre esa instancia.

Si ves `supabase start is not running`, ejecuta primero el paso 1.

## Migraciones

Solo la baseline **`supabase/migrations/20260106000000_motoconecta_baseline.sql`**, alineada con `schema.sql`.

## Orden recomendado (SQL Editor o `psql`)

1. `schema.sql` — crea tablas, índices, comisión generada al 5 %, `notifications`, `transaction_request_messages`, triggers mínimos y RLS.
2. Si la base ya existía con un esquema anterior MotoConecta: ejecuta **`upgrade_lat_lng_sku.sql`** (y revisa columnas nuevas manualmente si hace falta).
3. Si la app falla con **`proveedor_factura_storage_path` does not exist**: ejecuta en SQL Editor **`upgrade_proveedor_factura.sql`** (solo añade las columnas de adjunto).
4. Si el panel **Pedidos** del aliado muestra **PGRST202** / «`aliado_effective_open_exposure` not found»: ejecuta **`upgrade_aliado_effective_open_exposure.sql`** (RPC de suma de pedidos activos para el cupo en pantalla).
5. Desde la raíz del repo, `supabase/seed.sql` — dos importadores, un aliado, un admin; **15 productos por importador** (sin pedidos ni cortes). Para vaciar pedidos/facturas/cortes y restaurar stock: `supabase/scripts/reset_operational_data.sql`.

Contraseña de todos los usuarios seed: **`SeedPass123!`**

Si al ejecutar `seed.sql` aparece **`profiles_id_fkey`**: suele ser un email `@motoconecta.seed` que ya existía en `auth.users` con **otro** UUID (el seed inserta perfiles con IDs fijos). Vuelve a ejecutar el **mismo** `seed.sql` completo: el preámbulo borra esas filas por email antes de recrear. Si pegaste UUIDs a mano, revisa que importador2 sea **`c1000002-0000-4000-8000-000000000001`** (no `c1080802…`). **No hace falta** volver a ejecutar `schema.sql` salvo que hayas borrado tablas.

| Rol | Email |
|-----|--------|
| Importador (Delta) | `importador1@motoconecta.seed` |
| Importador (Omega) | `importador2@motoconecta.seed` |
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

## Operación B2B directa (C3)

- Pedidos por línea `transaction_requests` + `checkout_group_id` (sin `sub_orders` ni transportista).
- Ciclo importador: preparación → listo → tránsito → entregado; pago verificado por importador o MotoLink (admin).
- Migración `20260606120000_minuta7_c3_admin_pago_rpc.sql`: `admin_aprobar_pago_aliado`, `admin_rechazar_comprobante_pago` (auditoría `confirmado_por`).
- Morosidad, retiro de crédito/cuotas en plataforma: migraciones `20260601…`–`20260605…`.

## Próximos pasos (Flutter)

1. Enlazar `.env` al proyecto Supabase MotoConecta (URL + clave publicable); no commitear secretos.
2. Aplicar migraciones pendientes con `supabase db push` (incl. C3 admin pago y tasa BCV).

## Comisiones MotoLink (C1)

Migraciones en `supabase/migrations/` (prefijo `20260520…` / `20260526…`): devengo al Recibido, cortes, referencia automática, PDF, pago con comprobante, cron semanal (lunes 07:00 UTC).

- **Admin:** pestaña Comisiones — generar corte, emitir factura (genera PDF), confirmar pago.
- **Importador:** Perfil → Cortes de comisión — ver PDF, registrar comprobante.
- **Storage:** `commission-settlement-invoices` (PDF) y `order-payment-proofs/commission-settlements/` (comprobantes).

## Comunicación y KYC en pedido (C2)

Migraciones `20260527120000_minuta7_c2_chat_sla_kyc.sql` y `20260529120000_minuta7_c2_kyc_admin_sla_completion.sql`:

- **Chat del pedido:** aliado e importador en el mismo hilo; MotoLink (admin) lee y puede intervenir.
- **SLA 12 h:** `run_importer_sla_admin_alerts` cada 15 min (pg_cron); `related_id` = id de pedido ancla (deep link).
- **KYC aliado e importador:** subida en perfil; cola admin pestaña **KYC**; notificación `type=kyc` a administradores al enviar expediente.
- **Visibilidad KYC en pedido:** logo, fiscal, estado y documentos **aprobados** de la contraparte.
- **Storage:** bucket `profile-documents` con lectura de contraparte vía RLS.
