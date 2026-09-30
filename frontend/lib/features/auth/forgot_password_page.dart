import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/auth/auth_validators.dart';
import 'package:sprout/features/auth/auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  var _submitting = false;
  var _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      final user = context.read<AuthService>().currentUser;
      if (user != null && _email.text.isEmpty) {
        _email.text = user.email;
      }
    });
  }

  void _refresh() {
    if (_error != null && validateEmail(_email.text) == null) _error = null;
    setState(() {});
  }

  @override
  void dispose() {
    _email.removeListener(_refresh);
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailError = validateEmail(_email.text);
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().sendPasswordReset(email: _email.text);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _submitting = false;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AuthService>().isSignedIn;
    return Focus(
      autofocus: true,
      child: Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 26, 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AuthBackButton(onPressed: () => context.pop()),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    left: 6,
                    top: 12,
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  children: [
                    const AuthHeadline(lead: 'Reset your', accent: 'password.'),
                    const SizedBox(height: 8),
                    Text(
                      _sent
                          ? 'Check your inbox for a reset link.'
                          : 'Enter the email you use for Sprout.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        height: 20 / 14,
                        color: AppColors.onboardingBody,
                      ),
                    ),
                    if (!_sent) ...[
                      const SizedBox(height: 22),
                      AuthField(
                        label: 'EMAIL',
                        controller: _email,
                        hint: 'you@example.com',
                        error: _error,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: SlabButton(
                  label: _sent
                      ? (signedIn ? 'Back to profile' : 'Back to sign in')
                      : (_submitting ? 'Sending' : 'Send reset link'),
                  enabled: _sent ||
                      (_email.text.trim().isNotEmpty && !_submitting),
                  onPressed: _sent ? () => context.pop() : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
