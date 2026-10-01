import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/app.dart';
import 'package:sprout/data/app_services.dart';
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

    // Next opens the schedule page, with the name fields on it.
    expect(find.text('Add to your care'), findsNothing);
    expect(find.text('Add a pet'), findsOneWidget);
    expect(find.text('PET NAME'), findsOneWidget);
    expect(find.text('Feeding'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Bean');
    await tester.pump();

    await tester.ensureVisible(find.text('1x / day'));
    await tester.tap(find.text('1x / day'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Morning'));
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Bean 🐾'));
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
}

/// Lets any floating confirmation finish so no timer outlives the test.
Future<void> _letToastsGo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}
