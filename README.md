# B2B Conecta App

Flutter B2B marketplace (aliados, importadores, administrador). Backend: Supabase.

| Documento | Contenido |
|-----------|-----------|
| [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md) | Clone, entornos, local, ramas |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Mapa del código, flujo de pedido, convenciones |
| [`config/ENVIRONMENTS.md`](config/ENVIRONMENTS.md) | Proyectos Supabase MAIN vs DEV |
| [`config/SECURITY.md`](config/SECURITY.md) | Qué puede ir en el cliente vs secretos |

## Dónde está cada cosa (resumen)

| Área | Path |
|------|------|
| App Flutter | `lib/` — `main.dart` → `core/auth` → `app/main_shell.dart` |
| Llamadas a Supabase | `lib/core/data/supabase_service.dart` |
| Schema vigente | `supabase/migrations/` (no `docs/archive/`) |
| Seed local | `supabase/seed.sql` |
| Env / keys | `bash scripts/use_env.sh local\|staging\|production` |
| Scripts de build | `scripts/build_*.sh`, `scripts/run_web_local.sh` |

Detalle por pantalla y rol: tabla **Dónde está cada cosa** en [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Environments

Detalle B2B Conecta (main limpio+seed vs dev con data): **`config/ENVIRONMENTS.md`**.

| Target | Template | Use case |
|--------|----------|----------|
| `local` | `config/env/local.env` | Docker Supabase (`supabase start`) |
| `staging` | `config/env/staging.env` | Web → proyecto **DEV** (2º Supabase; data de trabajo) |
| `mobile-staging` | `config/env/mobile-staging.env` | APK/iOS QA contra DEV |
| `production` | `config/env/production.env` | Web → **MAIN** (`fzugzjcwdzcwfxgviltw`, seed) |
| `mobile-production` | `config/env/mobile-production.env` | Store / release contra MAIN |

```bash
bash scripts/use_env.sh local          # or staging | mobile-staging | production
```

Real API keys go in **gitignored** `config/env/<env>.env.local` (see `config/env/staging.env.local.example`).  
Security notes: `config/SECURITY.md`.

### Local Supabase

```bash
supabase start
bash scripts/use_env.sh local
supabase db reset --yes
bash scripts/run_web_local.sh    # http://localhost:3000
```

### Staging web (Vercel)

Variables: `config/vercel-env.staging.example`  
Production web: `config/vercel-env.production.example`

**Dev / staging URL:** `https://b2bconecta-app-git-dev-b2bconecta.vercel.app` (Vercel project `b2bconecta-app`, branch `dev`).  
**Production:** `https://www.b2bconecta.com.ve`

Align before testing password recovery / email confirmation:

1. **SMTP** → `config/smtp.env` + `bash scripts/configure_supabase_smtp.sh staging|production` (sender `b2bconecta.ve@gmail.com`)
2. **Vercel** → Environment Variables → `SUPABASE_AUTH_REDIRECT_URL` = Site URL del entorno
3. **Supabase** → Auth → Site URL + Redirect URLs (ver `config/supabase-auth-redirects.example`)
4. **Redeploy** Vercel after changing env vars (Flutter web bakes `.env` at build time)
5. **PKCE:** request reset and open the email link in the **same browser** where you requested it

### Release mobile (staging QA)

```bash
bash scripts/build_apk_release.sh
bash scripts/build_ios_release.sh
# Production store: MOTOLINK_BUILD_ENV=mobile-production bash scripts/build_apk_release.sh
```

### Push notifications

```bash
cp config/push.env.example config/push.env   # fill secrets, do not commit
bash scripts/configure_supabase_push_secrets.sh staging
# bash scripts/configure_supabase_push_secrets.sh production
```

## Project refs (B2B Conecta)

- Main (plantilla + seed): `fzugzjcwdzcwfxgviltw` (`b2bconecta-db`)
- Dev (data de trabajo): `kdrccmqcrruixuworlmz` (`b2bconecta-db-dev`)
- Históricos MotoLink (referencia): staging `lwrqjpqyitnveizshawc`, prod `ufrphhiynowsychgxvkn`
