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

From `frontend`:

```
flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

The same defines are used for `flutter build apk`. Photos go to the private `care-media` bucket. Push notifications also need the Firebase defines, and they are not reliable in iPhone Safari.

Render uses `render.yaml`: the API is a web service, the Flutter web build is a static site, and reminders run on a cron job.
