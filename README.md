# Sprout

- `frontend` — Flutter app for Android and the web
- `backend` — Node API for Supabase

## API

From `backend`, copy `.env.example` to `.env` and fill in the Supabase URL, anon key, and service role key. Apply `backend/supabase/schema.sql` in the Supabase SQL editor.

```
npm install
npm start
```

## App

From the repo root, write local Flutter defines from `backend/.env` (the file is gitignored):

```
node scripts/write-dart-defines.mjs
```

That points the app at the live API by default. For a local API instead:

```
node scripts/write-dart-defines.mjs http://127.0.0.1:3010
```

Then from `frontend`:

```
flutter run -d chrome --dart-define-from-file=dart-defines.local.json
```

The same defines file is used for `flutter build apk`. Photos go to the private `care-media` bucket. Push notifications also need the Firebase keys in `.env`, and they are not reliable in iPhone Safari.

Render uses `render.yaml`: the API is a web service, the Flutter web build is a static site, and reminders run on a cron job.
