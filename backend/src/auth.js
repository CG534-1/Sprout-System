import { createClient } from '@supabase/supabase-js';
import { ensureSettings } from './settings.js';

export function service() {
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    throw httpError(503, 'API is not configured.');
  }
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

/**
 * Checks a Supabase access token and opens the two clients a request needs:
 * `admin` (service role) and `db` (the caller's own token, so RLS applies).
 * Used by the /api REST middleware and by Connect, so both sign in the
 * same way. Throws an `httpError` with the status the REST API returns.
 */
export async function authenticate({ authorization, offsetMinutes }) {
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_ANON_KEY) {
    throw httpError(503, 'API is not configured.');
  }
  const header = authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) throw httpError(401, 'Sign in to continue.');
  const admin = service();
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw httpError(401, 'Sign in to continue.');
  await ensureSettings(admin, data.user.id, offsetMinutes);
  const db = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    accessToken: async () => token,
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return { user: data.user, admin, db };
}
