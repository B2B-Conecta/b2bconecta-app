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

**Staging URL:** `https://motolink-app.vercel.app` (Vercel project `motolink-app`).

Align before testing password recovery:

1. **Vercel** → Environment Variables → `SUPABASE_AUTH_REDIRECT_URL=https://motolink-app.vercel.app`
2. **Supabase staging** → Auth → Site URL = same; Redirect URLs include `https://motolink-app.vercel.app/**`
3. **Redeploy** Vercel after changing env vars (Flutter web bakes `.env` at build time)
4. **PKCE:** request reset and open the email link in the **same browser** on `motolink-app.vercel.app` (not incognito / not the phone mail app if you requested on desktop)

See `config/supabase-auth-redirects.example` for the full redirect list.

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
