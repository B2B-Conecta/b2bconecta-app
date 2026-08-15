# Getting started — B2B Conecta

Flutter + Supabase. Mapa del código: [`ARCHITECTURE.md`](ARCHITECTURE.md). Entornos: [`config/ENVIRONMENTS.md`](../config/ENVIRONMENTS.md).

## Requisitos

- Flutter SDK (Dart `>=3.5.0`)
- Supabase CLI
- Docker (solo para backend local)
- Copia de keys: Dashboard → Project Settings → API (URL + publishable/anon). **Nunca** service_role en el cliente.

## 1. Clonar y entorno

```bash
git checkout dev
cp .env.example .env
# Keys reales: copiar config/env/<env>.env.local.example → config/env/<env>.env.local
bash scripts/use_env.sh local          # o staging | mobile-staging | production
```

`use_env.sh` escribe `.env`. Flutter **embebe** ese archivo: tras cambiar de entorno, reinicia la app (hot reload no recarga `.env`).

| Target | Para qué |
|--------|----------|
| `local` | Docker en tu máquina |
| `staging` | Web contra Supabase DEV |
| `mobile-staging` | APK/iOS QA contra DEV |
| `production` / `mobile-production` | MAIN / store — no usar mientras desarrollas |

## 2. Backend local

```bash
supabase start
bash scripts/use_env.sh local
supabase db reset --yes                 # aplica las 114 migraciones + seed.sql
bash scripts/run_web_local.sh           # http://localhost:3000
```

Sin `supabase start`, `db reset` responde `supabase start is not running`.

Usuarios seed (solo local):

| Rol | Email | Contraseña |
|-----|--------|------------|
| Admin | `admin@motoconecta.seed` | `admin123` |
| Aliado | `aliado1@motoconecta.seed` | `aliado123` |
| Importador | `importador1@motoconecta.seed` | `importador123` |

## 3. Correr la app

```bash
flutter pub get
flutter run -d chrome                         # o un dispositivo
# web con el script del repo (puerto 3000, redirect de Auth):
bash scripts/run_web_local.sh
```

## 4. Rama de trabajo (no tocar `main`)

```bash
git checkout dev
git pull origin dev
git checkout -b feat/nombre-corto
```

- App: `local` o `staging`.
- SQL nuevo: archivo en `supabase/migrations/` con timestamp. Probar con `db reset` local.
- `supabase db push` **solo** al proyecto DEV (`kdrccmqcrruixuworlmz`) cuando el SQL esté estable.
- MAIN (`fzugzjcwdzcwfxgviltw`) solo vía merge `dev` → `main`.

## 5. QA web / móvil contra DEV

```bash
bash scripts/use_env.sh staging
bash scripts/run_web_local.sh

# APK QA:
bash scripts/use_env.sh mobile-staging
bash scripts/build_apk_release.sh
```

Preview Vercel de `dev`: `https://b2bconecta-app-git-dev-b2bconecta.vercel.app`.  
Producción: `https://www.b2bconecta.com.ve`.

Auth (recovery / confirmación): Site URL + Redirect URLs en **cada** Dashboard. Ver `config/supabase-auth-redirects.example`. SMTP: `config/smtp.env` + `bash scripts/configure_supabase_smtp.sh staging`.

## 6. Push (Android/iOS)

```bash
cp config/push.env.example config/push.env   # no commitear
bash scripts/configure_supabase_push_secrets.sh staging
```

La web no registra tokens FCM.

## Scripts útiles

| Script | Uso |
|--------|-----|
| `scripts/use_env.sh` | Cambia `.env` |
| `scripts/run_web_local.sh` | Flutter web :3000 |
| `scripts/build_apk_release.sh` | APK |
| `scripts/build_ios_release.sh` | iOS |
| `scripts/build_web_vercel.sh` | Usado por Vercel |
| `scripts/serve_functions_local.sh` | Edge Functions locales |
| `supabase/scripts/reset_operational_data.sql` | Vacía operación y deja seed de usuarios/catálogo |

## Dónde no buscar

- **Schema vigente:** `supabase/migrations/`, no `docs/archive/motoconecta/`.
- **Keys:** `config/env/*.env.local` y `.env` (gitignored), no el código Dart.
- **Lógica de negocio crítica:** RPCs SQL + RLS, no solo widgets.
- **Llamadas al backend desde Flutter:** servicio de dominio (`OrdersService`, `CatalogService`, …). `SupabaseService` sigue existiendo como fachada.
