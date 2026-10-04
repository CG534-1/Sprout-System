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
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_task.dart';
import 'package:sprout/features/auth/auth_widgets.dart';
import 'package:sprout/features/auth/otp_page.dart';
import 'package:sprout/features/auth/sign_up_page.dart';
import 'package:sprout/features/care/care_sheet.dart';
import 'package:sprout/features/onboarding/onboarding_page.dart';
import 'package:sprout/features/splash/splash_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('a signed in launch goes from the splash straight home', (
    tester,
  ) async {
    final services = AppServices.mock(delay: Duration.zero);
    services.auth.completeOnboarding();
    await services.auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(SplashPage.hold);

    // The onboarding carousel must not flash for even one frame on the way
    // to a signed in home.
    for (var frame = 0; frame < 40; frame++) {
      expect(find.byType(OnboardingPage), findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.text("Today's care"), findsOneWidget);
  });

  testWidgets('a home with plants does not look empty when nothing is due today', (
    tester,
  ) async {
    final store = MockStore.seeded(delay: Duration.zero);
    store.tasks.clear();
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

    expect(find.text('Your home is empty'), findsNothing);
    expect(find.text('Nothing due today'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);
  });

  testWidgets('an empty home does not keep leftover today tasks', (tester) async {
    final store = MockStore.seeded(delay: Duration.zero);
    store.plants.clear();
    store.pets.clear();
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

    expect(find.text('Your home is empty'), findsOneWidget);
    expect(find.text('Water Monstera'), findsNothing);
    expect(find.text('Feed Milo'), findsNothing);
    expect(find.text('Coming up'), findsNothing);
  });

  testWidgets('coming up lists every event on the next day that has care', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MockStore.seeded(delay: Duration.zero);
    final now = DateTime.now();
    final later = DateTime(now.year, now.month, now.day + 2, 9);
    store.tasks.add(
      CareTask(
        id: 'task-groom-milo-tomorrow',
        scheduleId: 'schedule-walk-milo',
        subjectId: 'pet-milo',
        subjectType: CareSubjectType.pet,
        subjectName: 'Milo',
        action: CareAction.groom,
        dueAt: DateTime(now.year, now.month, now.day + 1, 19),
        status: TaskStatus.due,
      ),
    );
    store.tasks.add(
      CareTask(
        id: 'task-water-later',
        scheduleId: 'schedule-water-monstera',
        subjectId: 'plant-monstera',
        subjectType: CareSubjectType.plant,
        subjectName: 'Monstera',
        action: CareAction.water,
        dueAt: later,
        status: TaskStatus.due,
      ),
    );
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

    await tester.scrollUntilVisible(find.text('Water Aloe Vera'), 200);
    await tester.scrollUntilVisible(find.text('Groom Milo'), 200);
    expect(find.text('Water Aloe Vera'), findsOneWidget);
    expect(find.text('Groom Milo'), findsOneWidget);
    expect(find.text('In 2 days'), findsNothing);
  });

  testWidgets('an overdue task can be skipped', (tester) async {
    final store = MockStore.seeded(delay: Duration.zero);
    store.plants.clear();
    store.pets.removeWhere((pet) => pet.id != 'pet-milo');
    store.tasks
      ..clear()
      ..add(
        CareTask(
          id: 'task-walk-milo',
          scheduleId: 'schedule-walk-milo',
          subjectId: 'pet-milo',
          subjectType: CareSubjectType.pet,
          subjectName: 'Milo',
          action: CareAction.walk,
          dueAt: DateTime.now().subtract(const Duration(hours: 6)),
          status: TaskStatus.due,
        ),
      );
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

    expect(find.textContaining('Overdue'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(
      find.text('One is past its time. Mark it done, or skip it.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('skip-task-walk-milo')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Skipped'), findsOneWidget);
    expect(find.text('All caught up! 🌿'), findsOneWidget);
  });

  testWidgets('removing everyone shows the empty home without leftover care', (
    tester,
  ) async {
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

    expect(find.text('Feed Milo'), findsOneWidget);

    await services.plants.deletePlant('plant-monstera');
    await services.plants.deletePlant('plant-aloe');
    await services.pets.deletePet('pet-milo');
    await tester.pumpAndSettle();

    expect(find.text('Your home is empty'), findsOneWidget);
    expect(find.text('Feed Milo'), findsNothing);
    expect(find.text('Water Monstera'), findsNothing);
    expect(find.text('Coming up'), findsNothing);
  });

  testWidgets('a new password sends you back to sign in instead of home', (
    tester,
  ) async {
    final services = AppServices.mock(delay: Duration.zero);
    services.auth.markSplashSeen();
    services.auth.completeOnboarding();
    await services.auth.confirmRecoveryCode(
      email: 'ama@sprout.app',
      code: '123456',
    );
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    // The strength meter belongs here too, not only on sign up.
    expect(find.byType(PasswordRules), findsOneWidget);
    expect(find.text('Save password'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Sprout!2026');
    await tester.pump();
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(services.auth.isSignedIn, isFalse);
    expect(find.text('Welcome back'), findsOneWidget);

    await _letToastsGo(tester);
  });

  testWidgets('the care schedule opens as its own page and confirms the save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final services = AppServices.mock(delay: Duration.zero);
    services.auth.markSplashSeen();
    services.auth.completeOnboarding();
    await services.auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Care'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-care')));
    await tester.pumpAndSettle();

    // The sheet asks one question: plant or pet. No name fields.
    expect(find.text('Add to your care'), findsOneWidget);
    expect(find.text('PET NAME'), findsNothing);
    expect(find.text('PLANT NAME'), findsNothing);
    await tester.tap(find.widgetWithText(CareChoice, 'Pet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Next opens the details page, same as edit — not the plan.
    expect(find.text('Add to your care'), findsNothing);
    expect(find.text('Add a pet'), findsOneWidget);
    expect(find.text('PET NAME'), findsOneWidget);
    expect(find.text('Feeding'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Bean');
    await tester.pump();
    await tester.tap(find.text('Set up care schedule →'));
    await tester.pumpAndSettle();

    // Then the plan is its own page.
    expect(find.text('Add a pet'), findsNothing);
    expect(find.text('Care plan'), findsOneWidget);
    expect(find.text('Feeding'), findsOneWidget);
    expect(find.text('Walks'), findsOneWidget);

    await tester.tap(find.text('1x / day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Bean 🐾'));
    await tester.pumpAndSettle();

    expect(find.text('Bean is in your care now.'), findsOneWidget);
    expect(find.text('My care'), findsWidgets);

    await _letToastsGo(tester);
  });

  testWidgets('editing someone opens their details as a page', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final services = AppServices.mock(delay: Duration.zero);
    services.auth.markSplashSeen();
    services.auth.completeOnboarding();
    await services.auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Care'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // No sheet chrome: the form has the screen, with the name as the subtitle.
    expect(find.byType(CareSheetHandle), findsNothing);
    expect(find.text('Edit details'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CarePageHeader),
        matching: find.text('Milo'),
      ),
      findsOneWidget,
    );
    expect(find.text('Set up care schedule →'), findsOneWidget);

    await tester.tap(find.text('Set up care schedule →'));
    await tester.pumpAndSettle();

    expect(find.text('Edit details'), findsNothing);
    expect(find.text('Care plan'), findsOneWidget);
    expect(find.text('Save Milo 🐾'), findsOneWidget);

    // The details step is left behind, so back lands on My care.
    final context = tester.element(find.text('Care plan'));
    await Navigator.of(context).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('My care'), findsWidgets);
    expect(find.text('Edit details'), findsNothing);
  });

  testWidgets('the sign up stepper walks back one step at a time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final services = AppServices.mock(delay: Duration.zero);
    services.auth.markSplashSeen();
    services.auth.completeOnboarding();
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ama');
    await tester.enterText(fields.at(1), 'Mensah');
    await tester.enterText(fields.at(2), 'ama@sprout.app');
    await tester.pump();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // The sign up fields are still mounted under the pushed code page, so the
    // finder has to be scoped to it.
    await tester.enterText(
      find.descendant(
        of: find.byType(OtpPage),
        matching: find.byType(TextField),
      ),
      '123456',
    );
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.byType(OtpPage), findsNothing);
    expect(find.byType(SignupProgress), findsOneWidget);

    // A system or browser back has to land on step one, not leave the flow.
    final context = tester.element(find.byType(SignUpPage));
    await Navigator.of(context).maybePop();
    await tester.pumpAndSettle();

    expect(find.byType(SignUpPage), findsOneWidget);
    expect(find.text('Select Your Avatar'), findsOneWidget);

    await _letToastsGo(tester);
  });

  testWidgets('leaving the code page hands the setup button back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final services = AppServices.mock(delay: Duration.zero);
    services.auth.markSplashSeen();
    services.auth.completeOnboarding();
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ama');
    await tester.enterText(fields.at(1), 'Mensah');
    await tester.enterText(fields.at(2), 'ama@sprout.app');
    await tester.pump();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.byType(OtpPage), findsOneWidget);

    // A browser back closes the code page without completing the push, so
    // the button underneath must not be left spinning on 'Sending'.
    final context = tester.element(find.byType(OtpPage));
    await Navigator.of(context).maybePop();
    await tester.pumpAndSettle();

    expect(find.byType(OtpPage), findsNothing);
    expect(find.text('Sending'), findsNothing);
    expect(find.text('Get Started'), findsOneWidget);
    expect(tester.widget<SlabButton>(find.byType(SlabButton)).enabled, isTrue);

    await _letToastsGo(tester);
  });

  testWidgets('a finished email never reaches the code page', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final services = AppServices.mock(delay: Duration.zero);
    services.auth.completeOnboarding();
    await services.auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    await services.auth.signOut();
    services.auth.markSplashSeen();
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ama');
    await tester.enterText(fields.at(1), 'Mensah');
    await tester.enterText(fields.at(2), 'ama@sprout.app');
    await tester.pump();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.byType(OtpPage), findsNothing);
    expect(
      find.text('That email already has an account. Sign in instead.'),
      findsOneWidget,
    );
    expect(find.text('Get Started'), findsOneWidget);
  });
}

/// Lets any floating confirmation finish so no timer outlives the test.
Future<void> _letToastsGo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}
