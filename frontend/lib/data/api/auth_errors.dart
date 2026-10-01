import 'package:supabase_flutter/supabase_flutter.dart';

/// What the person was trying to do, so one Supabase error can be worded for
/// the screen they are on. "Invalid" means a wrong password on sign in and a
/// wrong code on the code page, and those need different sentences.
enum AuthOp { signIn, code, password, send, general }

const takenEmailMessage = 'That email already has an account. Sign in instead.';

String authErrorMessage(AuthException error, AuthOp op) {
  final code = error.code ?? '';
  final text = error.message.toLowerCase();

  if (text.contains('failed host lookup') ||
      text.contains('clientexception') ||
      text.contains('socketexception') ||
      text.contains('connection') ||
      text.contains('timed out')) {
    return 'No connection. Check your internet and try again.';
  }
  if (code == 'over_email_send_rate_limit' ||
      code == 'over_request_rate_limit' ||
      code == 'over_sms_send_rate_limit' ||
      text.contains('rate limit') ||
      text.contains('security purposes')) {
    return 'Too many tries. Wait a minute, then try again.';
  }
  if (op == AuthOp.code &&
      (code == 'otp_expired' ||
          text.contains('expired') ||
          text.contains('token') ||
          text.contains('otp') ||
          text.contains('invalid'))) {
    return 'That code is wrong or has expired. '
        'Check the digits, or send a new code.';
  }
  if (code == 'invalid_credentials' ||
      text.contains('invalid login credentials')) {
    return 'Those details do not match an account. '
        'Check your email and password.';
  }
  if (code == 'user_not_found' ||
      text.contains('user not found') ||
      text.contains('no user found')) {
    return 'We could not find a Sprout account with that email.';
  }
  if (code == 'email_not_confirmed' || text.contains('not confirmed')) {
    return 'Confirm your email first. We sent a 6-digit code to your inbox.';
  }
  if (code == 'email_exists' ||
      code == 'user_already_exists' ||
      text.contains('already registered') ||
      text.contains('already been registered')) {
    return takenEmailMessage;
  }
  if (code == 'same_password' ||
      text.contains('different from the old password')) {
    return 'That is already your password. Choose a different one.';
  }
  if (code == 'weak_password' || text.contains('password should be')) {
    return 'Use 8+ characters with a number, a capital letter, and a symbol.';
  }
  if (code == 'otp_expired' || text.contains('expired')) {
    return 'That link or code has expired. Start again to get a new one.';
  }
  if (code == 'validation_failed' || text.contains('invalid')) {
    return switch (op) {
      AuthOp.signIn =>
        'Those details do not match an account. Check your email and password.',
      AuthOp.send => 'That email does not look right. Check it and try again.',
      AuthOp.password =>
        'Use 8+ characters with a number, a capital letter, and a symbol.',
      _ => 'Something in that form was not right. Check it and try again.',
    };
  }
  if (code == 'signup_disabled' || code == 'email_provider_disabled') {
    return 'New accounts are paused right now. Try again later.';
  }
  return error.message;
}
