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
  → AuthGate          (sesión, deep links, recovery)
    → ProfileGate     (carga profiles)
      → ProfileSetupScreen / AliadoPendingReviewScreen
      → MainShell     (tabs por rol)
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

Estados y copy: `lib/models/transaction_request_status.dart` y `lib/utils/order_flow_copy/`.

Alrededor: factura, pago, flete/transportistas, chat, SLA 12 h, morosidad, valoraciones, comisión B2B Conecta.

## Dónde está cada cosa (layout actual)

`lib/` está organizado **por tipo de archivo**, no por feature. Los prefijos `admin_`, `aliado_`, `importer_` son el mapa dentro de `widgets/`.

| Si quieres tocar… | Empieza aquí |
|-------------------|--------------|
| Login, recovery, deep links | `lib/auth/` (`auth_gate.dart`) |
| Onboarding / KYC de acceso | `lib/auth/profile_gate.dart`, `lib/screens/profile_setup_screen.dart`, `lib/screens/aliado_pending_review_screen.dart` |
| Tabs y shells por rol | `lib/screens/main_shell.dart` |
| Catálogo aliado | `lib/screens/home_screen.dart`, `lib/screens/product_detail_screen.dart`, `lib/widgets/aliado_catalog_*` |
| Inventario importador | `lib/widgets/importer_inventory_dashboard.dart`, `lib/widgets/importer_flexible_import_screen.dart` |
| Carrito / checkout | `lib/screens/cart_screen.dart`, `lib/services/cart_service.dart` → RPC `aliado_checkout_multi_importador` |
| Pedidos aliado | `lib/widgets/aliado_pedidos_panel.dart` |
| Pedidos importador | `lib/widgets/importer_active_orders_panel.dart` |
| Pedidos admin | `lib/widgets/admin_orders_panel.dart` |
| Detalle de un pedido | `lib/screens/transaction_request_detail_screen.dart` |
| Transportistas / flete / pickup | `lib/screens/importer_carriers_screen.dart`, `lib/widgets/importer_pickup_*`, `lib/widgets/aliado_pedido_carrier_*` |
| Comisiones | `lib/widgets/admin_commission_settlements_panel.dart`, `lib/widgets/importer_commission_*`, `lib/services/motolink_commission_*` |
| Reputación / ratings | `lib/screens/reputation_tab.dart`, `lib/widgets/aliado_reputation_panel.dart`, `lib/widgets/importer_reputation_panel.dart` |
| KYC documentos | `lib/widgets/profile_kyc_*`, `lib/widgets/admin_kyc_review_panel.dart` |
| Soporte | `lib/screens/support_tickets_screen.dart`, `lib/widgets/admin_support_tickets_panel.dart` |
| Referidos | `lib/widgets/admin_referrals_panel.dart`, `lib/widgets/profile_referral_section.dart`, `lib/config/referral_invite_config.dart` |
| Tema / marca | `lib/theme/`, `lib/widgets/motolink_pro_logo.dart` |
| Términos / privacidad (web pública) | `lib/config/terms_config.dart`, `lib/screens/public_legal_document_screen.dart` |
| **Cualquier llamada a Supabase** | `lib/services/supabase_service.dart` (~5 400 líneas, ~100 métodos). Punto único hoy; no añadir features nuevas ahí si se puede extraer un servicio. |

Otras carpetas en `lib/`:

| Carpeta | Rol |
|---------|-----|
| `lib/models/` | DTOs alineados a Postgres |
| `lib/utils/` | Copy, pricing, filtros, layout |
| `lib/config/` | Constantes (legal, fiscal, redirects) |
| `lib/services/` | Cart, push, Excel, PDF, geolocalización, **supabase_service** |
| `lib/widgets/shell/` | Rail desktop compartido |
| `lib/gen/` | Logos embebidos (`python3 tool/embed_logo.py`) |

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
| `tool/` | `embed_logo.py`, `build_launcher_icon.py` (venv local `.venv-logo`, no se commitea) |
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

1. UI de un rol en un dominio → widget/screen con prefijo `aliado_` / `importer_` / `admin_` (hasta que `lib/` pase a carpetas por feature).
2. Regla de negocio / RPC → migración nueva + método en un servicio de dominio; evita inflar `supabase_service.dart`.
3. Compartido (tema, auth, shell) → `lib/auth/`, `lib/theme/`, `lib/widgets/shell/`.
4. Secretos → `config/env/*.env.local`, nunca `lib/` ni git.
5. Nombres `motolink_*` / `motoconecta_*` en código son legado; la marca en UI es B2B Conecta. No renombrar el package en el mismo PR que un feature.

## Siguiente paso de scaffolding

Este documento describe el layout **actual**. El siguiente PR (`feat/lib-feature-modules`) moverá `lib/` a `app/` + `core/` + `features/<dominio>/` sin cambiar lógica. Hasta entonces, usa la tabla “Dónde está cada cosa”.
