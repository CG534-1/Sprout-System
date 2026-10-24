import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/app.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/app_services.dart';
import 'package:sprout/data/mock/mock_auth_service.dart';
import 'package:sprout/data/mock/mock_care_service.dart';
import 'package:sprout/data/mock/mock_pet_service.dart';
import 'package:sprout/data/mock/mock_plant_service.dart';
import 'package:sprout/data/mock/mock_profile_service.dart';
import 'package:sprout/data/mock/mock_store.dart';
import 'package:sprout/data/models/care_history_entry.dart';

/// History fails until the connection comes back.
class _FlakyCare extends MockCareService {
  _FlakyCare(super.store);

  var online = false;

  @override
  Future<List<CareHistoryEntry>> history() async {
    if (!online) throw const AppException('No connection.');
    return super.history();
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('history that fails to load offers a retry that recovers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MockStore.seeded(delay: Duration.zero);
    final auth = MockAuthService(store);
    auth.markSplashSeen();
    auth.completeOnboarding();
    await auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    final care = _FlakyCare(store);
    final services = AppServices(
      auth: auth,
      plants: MockPlantService(store),
      pets: MockPetService(store),
      care: care,
      profile: MockProfileService(store, auth),
    );
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Your history could not load'), findsOneWidget);
    expect(find.text('History starts later'), findsNothing);

    care.online = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Your history could not load'), findsNothing);
    expect(find.textContaining('Monstera'), findsWidgets);
  });
}
