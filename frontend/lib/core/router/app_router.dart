import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/data/providers.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/auth/forgot_password_page.dart';
import 'package:sprout/features/auth/otp_page.dart';
import 'package:sprout/features/auth/reset_password_page.dart';
import 'package:sprout/features/auth/sign_in_page.dart';
import 'package:sprout/features/auth/sign_up_page.dart';
import 'package:sprout/features/care/add_care_sheet.dart';
import 'package:sprout/features/care/care_schedule_page.dart';
import 'package:sprout/features/care/my_care_page.dart';
import 'package:sprout/features/history/history_page.dart';
import 'package:sprout/features/onboarding/onboarding_page.dart';
import 'package:sprout/features/profile/profile_page.dart';
import 'package:sprout/features/profile/update_details_page.dart';
import 'package:sprout/features/splash/splash_page.dart';
import 'package:sprout/features/today/today_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final refresh = _RoutingRefresh(auth);
  final router = createAppRouter(auth, refresh);
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Passes on only the auth changes that [_redirect] reads.
///
/// Auth also notifies for a new name or avatar. Refreshing the router for
/// those re-reads the route stack, and when that lands just after a pop it
/// puts the closed page back.
class _RoutingRefresh extends ChangeNotifier {
  _RoutingRefresh(this._auth) : _last = _routing(_auth) {
    _auth.addListener(_changed);
  }

  final AuthService _auth;
  Object _last;

  static Object _routing(AuthService auth) => (
    auth.splashSeen,
    auth.pastOnboarding,
    auth.resettingPassword,
    auth.pendingSignup,
    auth.isSignedIn,
  );

  void _changed() {
    final next = _routing(_auth);
    if (next == _last) return;
    _last = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_changed);
    super.dispose();
  }
}

GoRouter createAppRouter(AuthService auth, Listenable refresh) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(auth, state.matchedLocation),
    routes: [
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.splash),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        // The step lives in the URL so browser back walks the stepper. A page
        // key that ignores the query keeps one route, and one set of
        // half-typed fields, across those steps.
        pageBuilder: (context, state) => MaterialPage(
          key: const ValueKey('sprout.sign-up'),
          child: SignUpPage(
            step: int.tryParse(state.uri.queryParameters['step'] ?? '') ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => OtpPage(
          email: state.uri.queryParameters['email'] ?? '',
          currentEmail: state.uri.queryParameters['current'] ?? '',
          purpose: state.uri.queryParameters['purpose'] ?? 'signup',
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.careDetails,
        builder: (context, state) {
          final args = state.extra;
          if (args is! CareDetailsArgs) return const _CareDraftGone();
          return CareDetailsPage(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.schedule,
        builder: (context, state) {
          final args = state.extra;
          if (args is! CareScheduleArgs) return const _CareDraftGone();
          return CareSchedulePage(args: args);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => navigationShell,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myCare,
                builder: (context, state) => const MyCarePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'details',
                    builder: (context, state) => const UpdateDetailsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// A care form only holds its draft in memory, so a reload or a browser back
/// onto one of those entries has nothing to show. This stands in for a frame
/// and hands straight back to My care rather than leaving a blank screen.
class _CareDraftGone extends StatefulWidget {
  const _CareDraftGone();

  @override
  State<_CareDraftGone> createState() => _CareDraftGoneState();
}

class _CareDraftGoneState extends State<_CareDraftGone> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(AppRoutes.myCare);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}

String? _redirect(AuthService auth, String location) {
  final onboarding = location == AppRoutes.onboarding;
  final authenticating =
      location == AppRoutes.signIn ||
      location == AppRoutes.signUp ||
      location == AppRoutes.forgotPassword ||
      location == AppRoutes.verifyEmail ||
      location == AppRoutes.resetPassword;

  if (!auth.splashSeen) {
    if (location == AppRoutes.splash) return null;
    return AppRoutes.splash;
  }

  if (!auth.pastOnboarding) {
    if (onboarding) return null;
    return AppRoutes.onboarding;
  }

  if (auth.resettingPassword) {
    if (location == AppRoutes.resetPassword) return null;
    return AppRoutes.resetPassword;
  }

  if (auth.pendingSignup) {
    if (location == AppRoutes.signUp ||
        location == AppRoutes.signIn ||
        location == AppRoutes.verifyEmail) {
      return null;
    }
    return AppRoutes.signUp;
  }

  if (!auth.isSignedIn) {
    if (authenticating) return null;
    return AppRoutes.signIn;
  }

  if (auth.isSignedIn &&
      (location == AppRoutes.forgotPassword || location == AppRoutes.verifyEmail)) {
    return null;
  }

  if (authenticating || location == AppRoutes.splash || onboarding) {
    return AppRoutes.today;
  }

  return null;
}
