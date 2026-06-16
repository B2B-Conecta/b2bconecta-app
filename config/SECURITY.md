# Security — MotoLink Pro App

## What belongs in the client app

| Variable | Safe in APK/web bundle? | Notes |
|----------|-------------------------|-------|
| `NEXT_PUBLIC_SUPABASE_URL` | Yes | Public API endpoint |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Yes | Anon/publishable key; RLS protects data |
| `SUPABASE_AUTH_REDIRECT_URL` | Yes | Redirect allow-list is enforced server-side |

Never embed **service_role**, **FCM server keys**, or **webhook secrets** in Flutter or commit them to git.

## Gitignored files (never commit)

- `.env` — active environment for local `flutter run` / builds
- `config/push.env` — FCM + Supabase service role for push setup scripts
- `config/env/*.env.local` — real publishable keys per environment

## Committed templates

Files under `config/env/*.env` and `config/*.example` use placeholders (`YOUR_*_PUBLISHABLE_KEY`).  
Copy `config/env/<env>.env.local.example` → `config/env/<env>.env.local` and fill keys from Supabase Dashboard.

## Supabase

- Row Level Security (RLS) is the real boundary; publishable key alone must not grant admin access.
- Rotate keys in Dashboard if a **service_role** or webhook secret was ever exposed.
- Register every auth redirect in **Authentication → URL Configuration** (staging + production).

## Firebase (FCM)

- `google-services.json` / `GoogleService-Info.plist` are client config; restrict API keys in Google Cloud Console by package/bundle ID.
- FCM credentials for Edge Functions live only in `config/push.env` and Supabase secrets.

## Builds

- Release APK/iOS default: `mobile-staging` (QA). Production store builds: `MOTOLINK_BUILD_ENV=mobile-production`.
- After `use_env.sh`, restart Flutter; hot reload does not reload `.env`.
