import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/data/api/session_idle.dart';

void main() {
  final now = DateTime(2026, 10, 1, 12);
  int ago(Duration gap) => now.subtract(gap).millisecondsSinceEpoch;

  test('a first ever launch has nothing to expire', () {
    expect(
      idledOut(lastActive: null, signedIn: false, midSetup: false, now: now),
      isFalse,
    );
  });

  test('a signed out visitor is left alone', () {
    expect(
      idledOut(
        lastActive: ago(const Duration(days: 30)),
        signedIn: false,
        midSetup: false,
        now: now,
      ),
      isFalse,
    );
  });

  test('a setup left for hours starts over', () {
    expect(
      idledOut(
        lastActive: ago(const Duration(hours: 4)),
        signedIn: false,
        midSetup: true,
        now: now,
      ),
      isTrue,
    );
  });

  test('a short break during setup keeps the flow', () {
    expect(
      idledOut(
        lastActive: ago(const Duration(minutes: 20)),
        signedIn: false,
        midSetup: true,
        now: now,
      ),
      isFalse,
    );
  });

  test('an account stays signed in across a few days', () {
    expect(
      idledOut(
        lastActive: ago(const Duration(days: 3)),
        signedIn: true,
        midSetup: false,
        now: now,
      ),
      isFalse,
    );
  });

  test('an account left for over a week is signed out', () {
    expect(
      idledOut(
        lastActive: ago(const Duration(days: 8)),
        signedIn: true,
        midSetup: false,
        now: now,
      ),
      isTrue,
    );
  });

  test('setup beats the long limit even while signed in', () {
    expect(
      idledOut(
        lastActive: ago(const Duration(hours: 2)),
        signedIn: true,
        midSetup: true,
        now: now,
      ),
      isTrue,
    );
  });
}
