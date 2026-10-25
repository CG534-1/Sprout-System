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

## API contracts (Protobuf + Connect)

Contracts live in `proto/` (`buf.yaml` and `buf.gen.yaml` at the repo root) and are published to [`buf.build/sprout-care/sprout`](https://buf.build/sprout-care/sprout). Connect serves them from the same Express app as REST, at `POST /<package>.<Service>/<Method>`.

On Connect so far: `sprout.v1.NotificationService/ListNotifications` (the bell). Everything else is REST. `GET /api/me/notifications` stays for app builds already installed.

Needs the Buf CLI (`npm i -g @bufbuild/buf`). Plugins run remotely and are pinned in `buf.gen.yaml`; `protocolbuffers/dart` must match `protobuf` in `frontend/pubspec.yaml`.

```bash
# repo root, after editing a .proto
buf lint
buf breaking --against buf.build/sprout-care/sprout   # blocks renumbered or removed fields
buf generate                                          # rewrites backend/src/gen and frontend/lib/gen
```

Then implement the method in `backend/src/connect.js` (call the same function the REST route uses), call it from the Flutter service through the client in `frontend/lib/gen`, and commit the `.proto` with the generated code. After merging, `buf registry login` once, then `buf push --git-metadata`.

- Never hand-edit `gen/` folders; `clean: true` wipes them on every `buf generate`.
- Never reuse or renumber a field; add new numbers and keep old ones.
- Protobuf JSON leaves out default values (`false`, `0`, `""`, empty lists); the generated classes fill them back in.
- Deploy the API before shipping an app build that calls a new method.
- Local Android testing: `adb reverse tcp:3100 tcp:3100`, `API_BASE_URL=http://127.0.0.1:3100`; debug builds allow plain http.

## Render

`render.yaml`: `sprout-api`, static `sprout-web`, cron `sprout-reminders` (`* * * * *` → `/api/internal/dispatch-reminders`). Wire env in the dashboard; web `API_BASE_URL` should match the API service.
