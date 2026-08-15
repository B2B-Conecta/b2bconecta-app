# Arquitectura — B2B Conecta

Mapa para quien entra al repo. El package Flutter se llama `motolink_pro_app` (v 1.3.0); la marca pública es **B2B Conecta**.

Arranque local: [`GETTING_STARTED.md`](GETTING_STARTED.md). Entornos Supabase: [`config/ENVIRONMENTS.md`](../config/ENVIRONMENTS.md). Secretos: [`config/SECURITY.md`](../config/SECURITY.md).

## Qué es

Marketplace B2B de repuestos. Tres roles en `profiles.role`:

| Rol | Quién | Superficie principal |
|-----|--------|----------------------|
| `aliado` | Taller / comprador | Catálogo, carrito, pedidos, reputación, perfil + KYC |
| `importador` | Mayorista | Inventario, pedidos, reputación, perfil, transportistas |
| `administrador` | Broker B2B Conecta | Pedidos, reportes, valoraciones, comisiones, KYC, soporte |

Backend: **solo Supabase** (Auth PKCE, Postgres + RLS + RPCs, Storage, Realtime, pg_cron, Edge Functions). No hay API propia.

## Arranque de la app

```
lib/main.dart
  → core/auth/AuthGate          (sesión, deep links, recovery)
    → features/onboarding/ProfileGate
      → ProfileSetupScreen / AliadoPendingReviewScreen
      → app/MainShell           (tabs por rol)
```

Nadie entra al dashboard sin rol válido, perfil completo, términos aceptados y `account_access` activo (aliado/importador pasan por revisión admin).

## Ciclo del pedido

```
Aliado: catálogo → carrito (multi-importador, en memoria)
      → RPC aliado_checkout_multi_importador
      → transaction_requests + checkout_group_id

pendiente → en_preparacion → pedido_listo → en_transito → entregado
            (avanza el importador)           (el aliado confirma recepción)
```

Estados y copy: `lib/features/orders/shared/transaction_request_status.dart` y `lib/features/orders/shared/order_flow_copy/`.

Alrededor: factura, pago, flete/transportistas, chat, SLA 12 h, morosidad, valoraciones, comisión B2B Conecta.

## Dónde está cada cosa

`lib/` está organizado **por dominio** (`app/`, `core/`, `features/<nombre>/`). Los nombres de archivo (`admin_*`, `aliado_*`, `importer_*`) se conservaron.

| Si quieres tocar… | Empieza aquí |
|-------------------|--------------|
| Login, recovery, deep links | `lib/core/auth/` |
| Onboarding / acceso | `lib/features/onboarding/` |
| Tabs y shells por rol | `lib/app/main_shell.dart`, `lib/core/layout/` |
| Catálogo aliado | `lib/features/catalog/` |
| Inventario importador | `lib/features/inventory/` |
| Carrito / checkout | `lib/features/cart/` → RPC `aliado_checkout_multi_importador` |
| Pedidos | `lib/features/orders/shared/`, `aliado/`, `importador/`, `admin/` |
| Transportistas / flete / pickup | `lib/features/logistics/` |
| Pagos y comprobantes | `lib/features/payments/` |
| Comisiones | `lib/features/commissions/` |
| Reputación / ratings | `lib/features/reputation/` |
| KYC documentos | `lib/features/kyc/` |
| Soporte | `lib/features/support/` |
| Referidos | `lib/features/referrals/` |
| Perfil / cuenta | `lib/features/profile/` |
| Reportes, promos, monitoreo admin | `lib/features/admin/` |
| Tema / marca | `lib/app/theme/`, `lib/core/widgets/` |
| Términos / privacidad | `lib/app/config/`, `lib/features/onboarding/public_legal_document_screen.dart` |
| **Cualquier llamada a Supabase** | Servicio de dominio (`OrdersService`, `CatalogService`, …). `SupabaseService` es solo fachada de compatibilidad. |

```
lib/
  main.dart
  app/                 # bootstrap, MainShell, tema, constantes
  core/
    auth/              # sesión, login, recovery
    data/              # supabase_access + fachada SupabaseService
    notifications/     # in-app + push + NotificationsService
    layout/            # rail desktop, breakpoints
    widgets/           # logo, app bar
    utils/             # fechas, geo, export Excel genérico
  features/
    onboarding/ catalog/ inventory/ cart/
    orders/{shared,aliado,importador,admin}/
    logistics/ payments/ reputation/ commissions/
    kyc/ support/ referrals/ profile/ admin/
```

Cliente y helpers compartidos: `lib/core/data/supabase_access.dart`. La fachada `SupabaseService` delega; el código nuevo debe llamar al servicio del dominio:

| Dominio | Servicio |
|---------|----------|
| Pedidos | `OrdersService` |
| Catálogo / promos | `CatalogService` |
| Inventario | `InventoryService` |
| Perfil | `ProfileService` |
| Pagos | `PaymentsService` |
| KYC | `KycService` |
| Comisiones | `CommissionsService` |
| Reputación | `ReputationService` |
| Admin (login / monitoreo) | `AdminService` |
| Referidos | `ReferralsService` |
| Soporte | `SupportService` |
| Flete / transportistas | `LogisticsService` |
| Notificaciones | `NotificationsService` |

## Backend (`supabase/`)

| Path | Qué es |
|------|--------|
| `migrations/` | **Fuente de verdad del schema.** 114 SQL: baseline + features. No editar migraciones ya aplicadas; añadir una nueva con timestamp. |
| `migrations/README.md` | Cómo aplicar local vs remoto |
| `seed.sql` | Demo local (`db reset`) |
| `scripts/` | Reset operativo, passwords seed, parches QA |
| `functions/send-push-notification/` | FCM al cambiar notificaciones |
| `functions/send-account-email/` | Correos de cuenta (logo + invocación desde SQL) |
| `config.toml` | Docker local (API 54321, seed habilitado) |
| `motoconecta/` | Puntero al archivo histórico |
| `docs/archive/motoconecta/` | Snapshot greenfield (no aplicar) |

Tablas núcleo (baseline): `profiles`, `products`, `transaction_requests`, `transaction_request_messages`, `notifications`, `commission_settlements`, `platform_settings`. El resto (ratings, KYC, carriers, tickets, referidos, promos…) llegó por migraciones posteriores.

## Repo alrededor de la app

| Path | Qué es |
|------|--------|
| `config/env/` | Templates por entorno. Keys reales en `*.env.local` (gitignored) |
| `scripts/use_env.sh` | Copia el env activo a `.env` (Flutter lo embebe; hay que **reiniciar**, no hot reload) |
| `scripts/run_web_local.sh` | Web en `http://localhost:3000` |
| `scripts/build_apk_release.sh` / `build_ios_release.sh` / `build_aab_release.sh` / `build_web_vercel.sh` | Releases |
| `scripts/configure_supabase_smtp.sh` | SMTP Gmail en el proyecto linkeado |
| `scripts/configure_supabase_push_secrets.sh` | Vault + deploy push |
| `tool/` | `embed_logo.py` escribe `lib/core/widgets/motolink_pro_logo_bytes.dart`; `build_launcher_icon.py` (venv local `.venv-logo`, no se commitea) |
| `test/` | Tests unitarios puntuales (no cubren el flujo completo) |
| `vercel.json` | Build Flutter web |

## Ramas y entornos (no mezclar)

| Git | Deploy web | Supabase |
|-----|------------|----------|
| `main` | `https://www.b2bconecta.com.ve` | `b2bconecta-db` (`fzugzjcwdzcwfxgviltw`) — plantilla + seed |
| `dev` | `https://b2bconecta-app-git-dev-b2bconecta.vercel.app` | `b2bconecta-db-dev` (`kdrccmqcrruixuworlmz`) — data de trabajo |
| feature (`feat/…`, `chore/…`) | Preview Vercel si está habilitado | **local Docker** primero; `db push` solo a DEV cuando el SQL esté estable |

Nunca `supabase db push` a MAIN desde una rama de trabajo. Nunca keys de la org histórica MotoLink en proyectos B2B Conecta.

## Convención al añadir código

1. UI de un dominio → `lib/features/<dominio>/` (pedidos: `orders/shared|aliado|importador|admin`).
2. Regla de negocio / RPC → migración nueva + método en el servicio de dominio (`lib/features/<dominio>/*_service.dart`). No añadas métodos nuevos a `SupabaseService`.
3. Compartido (tema, auth, shell, cliente Supabase) → `lib/app/`, `lib/core/` (`SupabaseAccess` para client/buckets/helpers).
4. Secretos → `config/env/*.env.local`, nunca `lib/` ni git.
5. Nombres `motolink_*` / `motoconecta_*` en código son legado; la marca en UI es B2B Conecta. No renombrar el package en el mismo PR que un feature.
