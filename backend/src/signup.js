export function signupEmailTaken(user, profile) {
  if (profile) return true;
  if (!user) return false;
  const meta = user.user_metadata ?? {};
  const flag = (value) => value === true || value === 'true';
  if (flag(meta.password_set)) return true;
  if (flag(meta.signup_pending)) return false;
  return true;
}

export async function lookupSignupEmail(admin, email) {
  const normalised = String(email ?? '').trim().toLowerCase();
  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('id')
    .ilike('email', normalised)
    .maybeSingle();
  if (profileError) throw profileError;
  if (profile) return true;

  const user = await authUserByEmail(normalised);
  return signupEmailTaken(user, null);
}

/// GoTrue has no getUserByEmail helper. The admin list accepts a filter
/// substring, then we keep only an exact email match.
export async function authUserByEmail(email, options = {}) {
  const base = options.url ?? process.env.SUPABASE_URL;
  const key = options.key ?? process.env.SUPABASE_SERVICE_ROLE_KEY;
  const fetchImpl = options.fetchImpl ?? fetch;
  if (!base || !key) {
    throw new Error('API is not configured.');
  }
  const response = await fetchImpl(
    `${base.replace(/\/$/, '')}/auth/v1/admin/users?page=1&per_page=50&filter=${encodeURIComponent(email)}`,
    {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
      },
    },
  );
  if (!response.ok) {
    throw new Error('Could not look up that email.');
  }
  const body = await response.json();
  const users = Array.isArray(body.users) ? body.users : [];
  return users.find((item) => (item.email ?? '').toLowerCase() === email) ?? null;
}
