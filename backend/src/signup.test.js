import assert from 'node:assert/strict';
import test from 'node:test';
import { authUserByEmail, lookupSignupEmail, signupEmailTaken } from './signup.js';

test('a missing auth user is free to sign up', () => {
  assert.equal(signupEmailTaken(null, null), false);
});

test('an unfinished signup can request another code', () => {
  assert.equal(
    signupEmailTaken({ user_metadata: { signup_pending: true } }, null),
    false,
  );
});

test('a finished password blocks a second account', () => {
  assert.equal(
    signupEmailTaken({ user_metadata: { password_set: true } }, null),
    true,
  );
});

test('a profile row means the email is already in use', () => {
  assert.equal(
    signupEmailTaken({ user_metadata: { signup_pending: true } }, { id: '1' }),
    true,
  );
});

test('an older account without signup flags is still taken', () => {
  assert.equal(signupEmailTaken({ user_metadata: {} }, null), true);
});

test('a profile email is taken before any code is sent', async () => {
  const admin = {
    from() {
      return {
        select() {
          return this;
        },
        ilike() {
          return this;
        },
        maybeSingle: async () => ({ data: { id: '1' }, error: null }),
      };
    },
  };
  assert.equal(await lookupSignupEmail(admin, 'ama@sprout.app'), true);
});

test('a profile lookup error is not treated as a free email', async () => {
  const admin = {
    from() {
      return {
        select() {
          return this;
        },
        ilike() {
          return this;
        },
        maybeSingle: async () => ({ data: null, error: new Error('profiles down') }),
      };
    },
  };
  await assert.rejects(() => lookupSignupEmail(admin, 'ama@sprout.app'));
});

test('auth looks up the exact email through the admin users filter', async () => {
  const user = await authUserByEmail('ama@sprout.app', {
    url: 'https://example.supabase.co',
    key: 'service-role',
    fetchImpl: async (url) => {
      assert.match(url, /filter=ama%40sprout\.app/);
      return {
        ok: true,
        json: async () => ({
          users: [
            { email: 'ama@sprout.app', user_metadata: { password_set: true } },
            { email: 'ama@sprout.app.example', user_metadata: {} },
          ],
        }),
      };
    },
  });
  assert.equal(user.email, 'ama@sprout.app');
});

test('a failed auth lookup is not treated as a free email', async () => {
  await assert.rejects(() =>
    authUserByEmail('ama@sprout.app', {
      url: 'https://example.supabase.co',
      key: 'service-role',
      fetchImpl: async () => ({ ok: false, json: async () => ({}) }),
    }),
  );
});
