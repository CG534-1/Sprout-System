import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/core/layout/mobile_frame.dart';
import 'package:sprout/core/notifications/push_service.dart';
import 'package:sprout/core/router/app_router.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/theme/app_theme.dart';
import 'package:sprout/core/theme/theme_controller.dart';
import 'package:sprout/data/app_services.dart';
import 'package:sprout/data/providers.dart';
import 'package:sprout/data/services/auth_service.dart';

class SproutApp extends StatefulWidget {
  const SproutApp({
    super.key,
    required this.services,
    this.appearance = SproutAppearance.light,
  });

  final AppServices services;
  final SproutAppearance appearance;

  @override
  State<SproutApp> createState() => _SproutAppState();
}

class _SproutAppState extends State<SproutApp> {
  @override
  void dispose() {
    // The scope below unmounts first, so providers have let go of the
    // services by the time they are disposed here.
    widget.services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(widget.services),
        themeControllerProvider.overrideWith(
          () => ThemeController(widget.appearance),
        ),
      ],
      // A failed load shows its error and waits for the person to retry,
      // as it did before Riverpod, instead of retrying on its own.
      retry: (retryCount, error) => null,
      child: const _SproutMaterialApp(),
    );
  }
}

class _SproutMaterialApp extends ConsumerStatefulWidget {
  const _SproutMaterialApp();

  @override
  ConsumerState<_SproutMaterialApp> createState() => _SproutMaterialAppState();
}

class _SproutMaterialAppState extends ConsumerState<_SproutMaterialApp>
    with WidgetsBindingObserver {
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = ref.read(authServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_syncPush);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPush());
  }

  void _syncPush() {
    if (!_auth.isSignedIn) {
      ref.read(pushServiceProvider).reset();
      return;
    }
    ref.read(pushServiceProvider).start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stamps the idle clock when the app is backgrounded or brought back.
    _auth.keepAlive();
  }

  @override
  void dispose() {
    _auth.removeListener(_syncPush);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'Sprout',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: appearance.themeMode,
      themeAnimationDuration: Duration.zero,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _PhoneScrollBehavior(),
      builder: (context, child) {
        final platform = MediaQuery.platformBrightnessOf(context);
        final brightness = switch (appearance) {
          SproutAppearance.dark => Brightness.dark,
          SproutAppearance.light => Brightness.light,
          SproutAppearance.system => platform,
        };
        AppColors.sync(brightness);
        return _ThemeSync(
          brightness: brightness,
          child: MobileFrame(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Rebuilds the current page, bottom nav, and any open sheet together.
///
/// Colors are read from a static palette, and several of those widgets are
/// const, so a theme change would otherwise repaint only the widgets that
/// happen to rebuild.
class _ThemeSync extends StatefulWidget {
  const _ThemeSync({required this.brightness, required this.child});

  final Brightness brightness;
  final Widget child;

  @override
  State<_ThemeSync> createState() => _ThemeSyncState();
}

class _ThemeSyncState extends State<_ThemeSync> {
  @override
  void didUpdateWidget(_ThemeSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness == widget.brightness) return;
    _mark((context as Element));
  }

  void _mark(Element element) {
    element.visitChildren((child) {
      child.markNeedsBuild();
      _mark(child);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PhoneScrollBehavior extends MaterialScrollBehavior {
  const _PhoneScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
