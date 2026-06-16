# MotoLink Pro App

Flutter B2B marketplace (aliados, importadores, administrador). Backend: Supabase.

## Environments

| Target | Template | Use case |
|--------|----------|----------|
| `local` | `config/env/local.env` | Docker Supabase (`supabase start`) |
| `staging` | `config/env/staging.env` | Web dev against staging API |
| `mobile-staging` | `config/env/mobile-staging.env` | APK/iOS QA (default release builds) |
| `production` | `config/env/production.env` | Web production |
| `mobile-production` | `config/env/mobile-production.env` | Store release builds |

```bash
bash scripts/use_env.sh local          # or staging | mobile-staging | production
```

Real API keys go in **gitignored** `config/env/<env>.env.local` (see `staging.env.local.example`).  
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

## Project refs

- Staging: `lwrqjpqyitnveizshawc`
- Production: `ufrphhiynowsychgxvkn`
