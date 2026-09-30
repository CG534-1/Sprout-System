import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/app.dart';
import 'package:sprout/data/app_services.dart';
import 'package:sprout/features/shell/care_nav.dart';
import 'package:sprout/features/splash/splash_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('onboarding and sign in open today', (tester) async {
    final services = AppServices.mock(delay: Duration.zero);
    await tester.pumpWidget(SproutApp(services: services));

    expect(find.text('Start Sprout'), findsNothing);

    await tester.pump();
    await tester.pump();
    await tester.pump(SplashPage.hold);
    await tester.pump(SplashPage.reveal);
    await tester.pump();
    await tester.pump();

    expect(find.text('Start Sprout'), findsWidgets);
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Sign in'), findsWidgets);
    expect(
      tester.getTopLeft(find.text('EMAIL')).dy,
      lessThan(tester.getTopLeft(find.text('PASSWORD')).dy),
    );
    await services.auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    await tester.pump();
    await tester.pump();

    expect(find.text("Today's care"), findsOneWidget);
    expect(find.text('Alex.'), findsOneWidget);
  });

  testWidgets('avatar picker opens a sheet of a few memojis', (tester) async {
    final services = AppServices.mock(delay: Duration.zero);
    services.auth.markSplashSeen();
    services.auth.completeOnboarding();
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Select Your Avatar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('select-avatar')));
    await tester.pumpAndSettle();

    expect(find.text('You can always change this later.'), findsOneWidget);
    expect(find.text('Upload image'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);
    expect(find.text('SKIP, DO THIS LATER'), findsNothing);

    await tester.tap(
      find.image(const AssetImage('assets/images/memoji_hijab.png')).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('You can always change this later.'), findsNothing);
    expect(find.text('Upload image'), findsNothing);
    expect(
      find.image(const AssetImage('assets/images/memoji_hijab.png')),
      findsOneWidget,
    );
  });

  testWidgets('completed tasks and the calendar sheet', (tester) async {
    final services = AppServices.mock(delay: Duration.zero);
    services.auth.markSplashSeen();
    services.auth.completeOnboarding();
    await services.auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('3 care tasks today'), findsOneWidget);
    expect(find.text('0/3 complete'), findsOneWidget);

    for (final id in [
      'task-water-monstera',
      'task-feed-milo',
      'task-walk-milo',
    ]) {
      await tester.tap(find.byKey(Key('complete-$id')));
      await tester.pumpAndSettle();
    }

    expect(find.text('All caught up! 🌿'), findsOneWidget);
    expect(find.text('3/3 complete'), findsOneWidget);
    expect(find.text('All caught up for today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-task-water-monstera')));
    await tester.pumpAndSettle();
    expect(find.text('2/3 complete'), findsOneWidget);
    expect(find.text('All caught up! 🌿'), findsNothing);

    await tester.tap(find.byKey(const Key('complete-task-water-monstera')));
    await tester.pumpAndSettle();
    expect(find.text('3/3 complete'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('view-calendar')),
      200,
    );
    await tester.tap(find.byKey(const Key('view-calendar')));
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Water Monstera'), findsWidgets);
    expect(find.text('Feed Milo'), findsWidgets);
  });

  testWidgets('appearance keeps the page, sheet, and nav in sync', (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final services = AppServices.mock(delay: Duration.zero);
    services.auth.markSplashSeen();
    services.auth.completeOnboarding();
    await services.auth.signIn(email: 'ama@sprout.app', password: 'secret1');
    await tester.pumpWidget(SproutApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Appearance'), 200);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, const Color(0xFF102017));
    expect(_navColor(tester), const Color(0xEB102017));
    expect(_textColor(tester, 'Alex Morgan'), const Color(0xFFF4FBF6));
    expect(
      _textColor(tester, 'Choose how Sprout looks on your device.'),
      const Color(0xFF9BB8A6),
    );

    await tester.tap(find.text('Light'));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, const Color(0xFFF8FEF9));
    expect(_navColor(tester), const Color(0xEBFFFFFF));
    expect(_textColor(tester, 'Alex Morgan'), const Color(0xFF0B1F13));
    expect(
      _textColor(tester, 'Choose how Sprout looks on your device.'),
      const Color(0xFF4C7259),
    );
  });
}

Color? _navColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(CareNav), matching: find.byType(Container)).first,
  );
  return (container.decoration! as BoxDecoration).color;
}

Color? _textColor(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style?.color;
}
