# MotoConecta — esquema y seed (greenfield)

Marketplace B2B simplificado: solo roles **aliado**, **importador** y **administrador** (supervisor). Sin transportista ni logística en app.

## Cuándo usar esto

- **Proyecto Supabase nuevo** (p. ej. el entorno MotoConecta enlazado desde Flutter con `.env`).
- No ejecutes `schema.sql` sobre la base **MotoLink** legacy: chocaría con tablas y migraciones antiguas.

## Orden recomendado (SQL Editor o `psql`)

1. `schema.sql` — crea tablas, índices, comisión generada al 5 % y políticas RLS básicas.
2. Desde la raíz del repo, `supabase/seed.sql` — usuarios de prueba, perfiles, catálogo y un pedido `pendiente` (valida `comision_motoconecta`).

Contraseña de todos los usuarios seed: **`SeedPass123!`**

| Rol | Email |
|-----|--------|
| Admin | `admin@motoconecta.seed` |
| Importador 1 | `importador1@motoconecta.seed` |
| Importador 2 | `importador2@motoconecta.seed` |
| Aliado 1 | `aliado1@motoconecta.seed` |
| Aliado 2 | `aliado2@motoconecta.seed` |

## Credenciales de API

No las guardes en el repositorio. Copia `.env.example` → `.env` y pega **Project URL** y **anon / publishable key** desde Supabase Dashboard → Project Settings → API.

## Realtime (chat)

Tras crear `messages`, en el Dashboard puedes añadir la tabla a **Database → Replication** para `supabase_realtime` si la publicación no la incluye ya por defecto en tu proyecto.

## Próximos pasos (Flutter, rama `version/MotoConecta`)

1. Enlazar `.env` al proyecto Supabase MotoConecta (URL + clave publicable); no commitear secretos.
2. Retirar rol **transportista**: `AppHomeRole`, `main_shell`, paneles y servicios de envío/maps/ruta.
3. **Chat:** suscripción Realtime a `messages` filtrada por `transaction_id`; pantalla de hilo por pedido.
4. **Factura:** el importador sube archivo a Storage y actualiza `transaction_requests.factura_url`; el aliado ve y confirma pago (flujo UI + políticas RLS si añades bucket).
5. **Admin:** solo lectura agregada / reportes sobre `transaction_requests` y `comision_motoconecta` (sin aprobación previa de pedidos).
