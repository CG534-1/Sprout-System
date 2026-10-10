# Sprout

Flutter client (`frontend`) and Node API (`backend`) for plant/pet care schedules, with Supabase auth/data and optional FCM push.

Live API: `https://sprout-api-a0tw.onrender.com`

Requires Node 22 and Flutter (Dart ^3.13).

## Supabase

Schema: `backend/supabase/schema.sql` (also under `supabase/migrations/`).  
Storage: private bucket `care-media`.

Put project URL, anon key, and service role in `backend/.env` (see `.env.example`). The Flutter client and API must use the same Supabase project. Env files and `dart-defines.local.json` are gitignored.

## Backend

```bash
cd backend
cp .env.example .env   # fill Supabase; optional Firebase + CRON_SECRET + CLIENT_ORIGIN
npm install
npm start              # http://127.0.0.1:3000
```

## Frontend

```bash
# repo root — builds frontend/dart-defines.local.json from backend/.env
node scripts/write-dart-defines.mjs                         # API → live Render
node scripts/write-dart-defines.mjs http://127.0.0.1:3000   # API → local

cd frontend
flutter pub get
flutter run -d chrome --dart-define-from-file=dart-defines.local.json
flutter build apk --release --dart-define-from-file=dart-defines.local.json
```

Android FCM needs `frontend/android/app/google-services.json` (package `com.sprout.care.sprout`).

## Render

`render.yaml`: `sprout-api`, static `sprout-web`, cron `sprout-reminders` (`* * * * *` → `/api/internal/dispatch-reminders`). Wire env in the dashboard; web `API_BASE_URL` should match the API service.
