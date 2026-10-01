import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/data/api/auth_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a wrong email or password never mentions a code', () {
    const error = AuthException(
      'Invalid login credentials',
      code: 'invalid_credentials',
      statusCode: '400',
    );
    expect(
      authErrorMessage(error, AuthOp.signIn),
      'Those details do not match an account. '
      'Check your email and password.',
    );
  });

  test('a wrong or stale code says so on the code page', () {
    const error = AuthException(
      'Token has expired or is invalid',
      code: 'otp_expired',
      statusCode: '403',
    );
    expect(
      authErrorMessage(error, AuthOp.code),
      'That code is wrong or has expired. '
      'Check the digits, or send a new code.',
    );
  });

  test('an unconfirmed email points at the inbox', () {
    const error = AuthException(
      'Email not confirmed',
      code: 'email_not_confirmed',
      statusCode: '400',
    );
    expect(
      authErrorMessage(error, AuthOp.signIn),
      'Confirm your email first. We sent a 6-digit code to your inbox.',
    );
  });

  test('a missing account is named as missing', () {
    const error = AuthException('User not found', code: 'user_not_found');
    expect(
      authErrorMessage(error, AuthOp.send),
      'We could not find a Sprout account with that email.',
    );
  });

  test('a taken email sends you to sign in', () {
    const error = AuthException(
      'User already registered',
      code: 'user_already_exists',
    );
    expect(
      authErrorMessage(error, AuthOp.send),
      takenEmailMessage,
    );
  });

  test('a throttled resend asks for a pause', () {
    const error = AuthException(
      'For security purposes, you can only request this after 46 seconds.',
      code: 'over_email_send_rate_limit',
    );
    expect(
      authErrorMessage(error, AuthOp.send),
      'Too many tries. Wait a minute, then try again.',
    );
  });

  test('a reused password is named', () {
    const error = AuthException(
      'New password should be different from the old password.',
      code: 'same_password',
    );
    expect(
      authErrorMessage(error, AuthOp.password),
      'That is already your password. Choose a different one.',
    );
  });

  test('a dropped connection is not blamed on the person', () {
    const error = AuthException(
      'ClientException with SocketException: Failed host lookup',
    );
    expect(
      authErrorMessage(error, AuthOp.signIn),
      'No connection. Check your internet and try again.',
    );
  });

  test('an unmapped message is passed through rather than guessed at', () {
    const error = AuthException('Database error saving new user');
    expect(
      authErrorMessage(error, AuthOp.general),
      'Database error saving new user',
    );
  });
}
