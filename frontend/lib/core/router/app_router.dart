import 'package:go_router/go_router.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/auth/forgot_password_page.dart';
import 'package:sprout/features/auth/sign_in_page.dart';
import 'package:sprout/features/auth/sign_up_page.dart';
import 'package:sprout/features/care/my_care_page.dart';
import 'package:sprout/features/history/history_page.dart';
import 'package:sprout/features/onboarding/onboarding_page.dart';
import 'package:sprout/features/profile/profile_page.dart';
import 'package:sprout/features/profile/update_details_page.dart';
import 'package:sprout/features/splash/splash_page.dart';
import 'package:sprout/features/today/today_page.dart';

GoRouter createAppRouter(AuthService auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
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
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.today,
        builder: (context, state) => const TodayPage(),
      ),
      GoRoute(
        path: AppRoutes.myCare,
        builder: (context, state) => const MyCarePage(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.updateDetails,
        builder: (context, state) => const UpdateDetailsPage(),
      ),
    ],
  );
}

String? _redirect(AuthService auth, String location) {
  final onboarding = location == AppRoutes.onboarding;
  final authenticating =
      location == AppRoutes.signIn ||
      location == AppRoutes.signUp ||
      location == AppRoutes.forgotPassword;

  if (!auth.splashSeen) {
    if (location == AppRoutes.splash) return null;
    return AppRoutes.splash;
  }

  if (!auth.onboardingComplete) {
    if (onboarding) return null;
    return AppRoutes.onboarding;
  }

  if (auth.pendingSignup) {
    if (location == AppRoutes.signUp || location == AppRoutes.signIn) return null;
    return AppRoutes.signUp;
  }

  if (!auth.isSignedIn) {
    if (authenticating) return null;
    return AppRoutes.signIn;
  }

  if (location == AppRoutes.forgotPassword && auth.isSignedIn) return null;

  if (authenticating || location == AppRoutes.splash || onboarding) {
    return AppRoutes.today;
  }

  return null;
}
