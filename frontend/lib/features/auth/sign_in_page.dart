import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/auth/auth_validators.dart';
import 'package:sprout/features/auth/auth_widgets.dart';
import 'package:sprout/features/splash/splash_cup.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _submitting = false;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _email.addListener(_refresh);
    _password.addListener(_refresh);
    _leaveFieldsAlone();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tellIfTimedOut());
  }

  void _tellIfTimedOut() {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    if (!auth.sessionExpired) return;
    auth.clearSessionExpired();
    showSproutToast(
      context,
      'You were away a while, so we signed you out. Sign in to pick up again.',
    );
  }

  void _leaveFieldsAlone() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void _refresh() {
    if (_emailError != null && _email.text.trim().isNotEmpty) {
      _emailError = null;
    }
    if (_passwordError != null && _password.text.isNotEmpty) {
      _passwordError = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _email.removeListener(_refresh);
    _password.removeListener(_refresh);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailError = validateEmail(_email.text);
    final passwordError = validatePassword(_password.text);
    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _emailError = null;
      _passwordError = null;
    });
    final toast = sproutToaster(context);
    final router = GoRouter.of(context);
    try {
      await context.read<AuthService>().signIn(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      router.go(AppRoutes.today);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _passwordError = error.message;
        _submitting = false;
      });
      toast.show(error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        controller: _email,
                        hint: 'you@example.com',
                        error: _emailError,
                        fieldKey: const Key('sign-in-email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      AuthField(
                        label: 'PASSWORD',
                        controller: _password,
                        hint: 'Your password',
                        error: _passwordError,
                        fieldKey: const Key('sign-in-password'),
                        obscure: _obscure,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
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
                  label: _submitting ? 'Signing in' : 'Sign in',
                  onPressed: _submitting ? null : _submit,
                  busy: _submitting,
                  enabled:
                      _email.text.trim().isNotEmpty &&
                      _password.text.isNotEmpty &&
                      !_submitting,
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
