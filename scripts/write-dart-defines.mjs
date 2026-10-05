import { existsSync, readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const envPath = join(root, 'backend', '.env');
const env = {};
if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const index = trimmed.indexOf('=');
    if (index === -1) continue;
    env[trimmed.slice(0, index)] = trimmed.slice(index + 1);
  }
}

const ready = Boolean(env.SUPABASE_URL && env.SUPABASE_ANON_KEY);
if (!ready) {
  console.log('defines-missing');
  process.exit(1);
}

writeFileSync(
  join(root, 'frontend', 'dart-defines.local.json'),
  `${JSON.stringify({
    SUPABASE_URL: env.SUPABASE_URL ?? '',
    SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY ?? '',
    API_BASE_URL: process.argv[2] || 'https://sprout-api-a0tw.onrender.com',
    FIREBASE_API_KEY: env.FIREBASE_API_KEY ?? '',
    FIREBASE_APP_ID: env.FIREBASE_APP_ID ?? '',
    FIREBASE_MESSAGING_SENDER_ID: env.FIREBASE_MESSAGING_SENDER_ID ?? '',
    FIREBASE_PROJECT_ID: env.FIREBASE_PROJECT_ID ?? '',
    FIREBASE_VAPID_KEY: env.FIREBASE_VAPID_KEY ?? '',
  })}\n`,
);
console.log('defines-ok');
