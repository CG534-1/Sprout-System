import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/layout/mobile_frame.dart';
import 'package:sprout/core/router/app_router.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/theme/app_theme.dart';
import 'package:sprout/core/theme/theme_controller.dart';
import 'package:sprout/data/app_services.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/data/services/profile_service.dart';

class SproutApp extends StatefulWidget {
  const SproutApp({super.key, required this.services, this.theme});

  final AppServices services;
  final ThemeController? theme;

  @override
  State<SproutApp> createState() => _SproutAppState();
}

class _SproutAppState extends State<SproutApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final ThemeController _theme;
  late final bool _ownsTheme;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.services.auth);
    _ownsTheme = widget.theme == null;
    _theme = widget.theme ?? ThemeController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stamps the idle clock when the app is backgrounded or brought back.
    widget.services.auth.keepAlive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    widget.services.dispose();
    if (_ownsTheme) _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: _theme),
        ChangeNotifierProvider<AuthService>.value(value: widget.services.auth),
        ChangeNotifierProvider<PlantService>.value(
          value: widget.services.plants,
        ),
        ChangeNotifierProvider<PetService>.value(value: widget.services.pets),
        ChangeNotifierProvider<CareService>.value(value: widget.services.care),
        ChangeNotifierProvider<ProfileService>.value(
          value: widget.services.profile,
        ),
      ],
      child: _SproutMaterialApp(router: _router),
    );
  }
}

class _SproutMaterialApp extends StatelessWidget {
  const _SproutMaterialApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sprout',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.watch<ThemeController>().themeMode,
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _PhoneScrollBehavior(),
      builder: (context, child) {
        final appearance = context.watch<ThemeController>().appearance;
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
