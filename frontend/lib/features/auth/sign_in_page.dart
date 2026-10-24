import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/data/providers.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/features/auth/auth_validators.dart';
import 'package:sprout/features/auth/auth_widgets.dart';
import 'package:sprout/features/splash/splash_cup.dart';

class SignInPage extends HookConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = useTextEditingController();
    final password = useTextEditingController();
    useListenable(Listenable.merge([email, password]));
    final obscure = useState(true);
    final submitting = useState(false);
    final emailError = useState<String?>(null);
    final passwordError = useState<String?>(null);

    useEffect(() {
      void clearFixedErrors() {
        if (emailError.value != null && email.text.trim().isNotEmpty) {
          emailError.value = null;
        }
        if (passwordError.value != null && password.text.isNotEmpty) {
          passwordError.value = null;
        }
      }

      email.addListener(clearFixedErrors);
      password.addListener(clearFixedErrors);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusManager.instance.primaryFocus?.unfocus();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final auth = ref.read(authServiceProvider);
        if (!auth.sessionExpired) return;
        auth.clearSessionExpired();
        showSproutToast(
          context,
          'You were away a while, so we signed you out. Sign in to pick up again.',
        );
      });
      return () {
        email.removeListener(clearFixedErrors);
        password.removeListener(clearFixedErrors);
      };
    }, const []);

    Future<void> submit() async {
      final emailFailure = validateEmail(email.text);
      final passwordFailure = validatePassword(password.text);
      if (emailFailure != null || passwordFailure != null) {
        emailError.value = emailFailure;
        passwordError.value = passwordFailure;
        return;
      }
      submitting.value = true;
      emailError.value = null;
      passwordError.value = null;
      final toast = sproutToaster(context);
      final router = GoRouter.of(context);
      try {
        await ref.read(authServiceProvider).signIn(
          email: email.text,
          password: password.text,
        );
        if (!context.mounted) return;
        router.go(AppRoutes.today);
      } on AppException catch (failure) {
        if (!context.mounted) return;
        passwordError.value = failure.message;
        submitting.value = false;
        toast.show(failure.message, error: true);
      }
    }

    return Focus(
      autofocus: true,
      child: Scaffold(
        backgroundColor: AppColors.onboardingPaper,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 16),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    children: [
                      const SizedBox(height: 36),
                      const Center(
                        child: SplashCup(filled: true, diameter: 72),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 34.5 / 24,
                          color: authInk,
                        ),
                      ),
                      Text(
                        'Sign in to see what needs your care today.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          height: 22 / 15,
                          color: AppColors.onboardingBody,
                        ),
                      ),
                      const SizedBox(height: 36),
                      AuthField(
                        label: 'EMAIL',
                        controller: email,
                        hint: 'you@example.com',
                        error: emailError.value,
                        fieldKey: const Key('sign-in-email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      AuthField(
                        label: 'PASSWORD',
                        controller: password,
                        hint: 'Your password',
                        error: passwordError.value,
                        fieldKey: const Key('sign-in-password'),
                        obscure: obscure.value,
                        suffix: IconButton(
                          onPressed: () => obscure.value = !obscure.value,
                          icon: Icon(
                            obscure.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.sproutGreen,
                            size: 20,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.forgotPassword),
                          child: Text(
                            'Forgot password?',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sproutGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SlabButton(
                  key: const Key('sign-in-submit'),
                  label: submitting.value ? 'Signing in' : 'Sign in',
                  onPressed: submitting.value ? null : submit,
                  busy: submitting.value,
                  enabled:
                      email.text.trim().isNotEmpty &&
                      password.text.isNotEmpty &&
                      !submitting.value,
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.onboardingBody,
                    ),
                    children: [
                      const TextSpan(text: 'New to Sprout? '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => context.push(AppRoutes.signUp),
                          child: Text(
                            'Create an account',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.sproutGreen,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.sproutGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
