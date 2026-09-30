import { existsSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { createApp } from './http.js';

const envPath = join(dirname(fileURLToPath(import.meta.url)), '../.env');
if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const index = trimmed.indexOf('=');
    if (index === -1) continue;
    const key = trimmed.slice(0, index);
    if (process.env[key]) continue;
    process.env[key] = trimmed.slice(index + 1);
  }
}

const port = Number(process.env.PORT || 3000);
createApp().listen(port, () => {
  console.log(`Sprout API listening on ${port}`);
});
