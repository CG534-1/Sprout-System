import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/app.dart';
import 'package:sprout/data/app_services.dart';
import 'package:sprout/data/mock/mock_auth_service.dart';
import 'package:sprout/data/mock/mock_care_service.dart';
import 'package:sprout/data/mock/mock_pet_service.dart';
import 'package:sprout/data/mock/mock_plant_service.dart';
import 'package:sprout/data/mock/mock_profile_service.dart';
import 'package:sprout/data/mock/mock_store.dart';
import 'package:sprout/features/profile/update_details_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('saving details closes the page and shows the new name', (
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
    final services = AppServices(
      auth: auth,
      plants: MockPlantService(store),
      pets: MockPetService(store),
      care: MockCareService(store),
      profile: MockProfileService(store, auth),
    );
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account & security'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update details'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateDetailsPage), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Alex Rivera');
    await tester.tap(find.text('Save details'));
    await tester.pumpAndSettle();

    expect(find.byType(UpdateDetailsPage), findsNothing);
    expect(find.text('Alex Rivera'), findsOneWidget);
  });
}
