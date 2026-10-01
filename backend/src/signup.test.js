import assert from 'node:assert/strict';
import test from 'node:test';
import { signupEmailTaken } from './signup.js';

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
