import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/api/auth_errors.dart';
import 'package:sprout/data/mock/mock_auth_service.dart';
import 'package:sprout/data/mock/mock_store.dart';

void main() {
  test('a finished email is refused before a code is sent', () async {
    final auth = MockAuthService(MockStore(delay: Duration.zero));
    await auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    await auth.signOut();

    expect(
      () => auth.requestEmailConfirmation(
        firstName: 'Ama',
        lastName: 'Mensah',
        email: 'ama@sprout.app',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          takenEmailMessage,
        ),
      ),
    );
  });

  test('a new email can still request a code', () async {
    final auth = MockAuthService(MockStore(delay: Duration.zero));
    await auth.requestEmailConfirmation(
      firstName: 'Ama',
      lastName: 'Mensah',
      email: 'new@sprout.app',
    );
    expect(auth.codeSentAt, isNotNull);
  });
}
