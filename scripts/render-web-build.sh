#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$HOME/flutter/bin/flutter" ]; then
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  fi
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter config --no-analytics
flutter precache --web

python3 - <<'PY'
import json, os
config = {
    "apiKey": os.environ.get("FIREBASE_API_KEY", ""),
    "appId": os.environ.get("FIREBASE_APP_ID", ""),
    "messagingSenderId": os.environ.get("FIREBASE_MESSAGING_SENDER_ID", ""),
    "projectId": os.environ.get("FIREBASE_PROJECT_ID", ""),
}
path = "frontend/web/firebase-config.js"
if config["apiKey"] and config["projectId"]:
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("self.FIREBASE_CONFIG = " + json.dumps(config) + ";\n")
else:
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("self.FIREBASE_CONFIG = null;\n")
PY

cd frontend
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=API_BASE_URL="${API_BASE_URL:-}" \
  --dart-define=FIREBASE_API_KEY="${FIREBASE_API_KEY:-}" \
  --dart-define=FIREBASE_APP_ID="${FIREBASE_APP_ID:-}" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID:-}" \
  --dart-define=FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}" \
  --dart-define=FIREBASE_VAPID_KEY="${FIREBASE_VAPID_KEY:-}"
