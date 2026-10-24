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

class ForgotPasswordPage extends HookConsumerWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = useTextEditingController();
    // Rebuilds on every keystroke so the button follows the field.
    useListenable(email);
    final submitting = useState(false);
    final error = useState<String?>(null);

    useEffect(() {
      void clearFixedError() {
        if (error.value != null && validateEmail(email.text) == null) {
          error.value = null;
        }
      }

      email.addListener(clearFixedError);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        FocusManager.instance.primaryFocus?.unfocus();
        final user = ref.read(authServiceProvider).currentUser;
        if (user != null && email.text.isEmpty) {
          email.text = user.email;
        }
      });
      return () => email.removeListener(clearFixedError);
    }, const []);

    Future<void> submit() async {
      final emailError = validateEmail(email.text);
      if (emailError != null) {
        error.value = emailError;
        return;
      }
      submitting.value = true;
      error.value = null;
      try {
        await ref.read(authServiceProvider).sendPasswordReset(email: email.text);
        if (!context.mounted) return;
        showSproutToast(context, 'Code sent to ${email.text.trim()}.');
        final address = Uri.encodeQueryComponent(email.text.trim());
        context.push('${AppRoutes.verifyEmail}?email=$address&purpose=recovery');
        submitting.value = false;
      } on AppException catch (failure) {
        if (!context.mounted) return;
        error.value = failure.message;
        submitting.value = false;
      }
    }

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
                      'Enter the email you use for Sprout. We will send a code.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        height: 20 / 14,
                        color: AppColors.onboardingBody,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AuthField(
                        label: 'EMAIL',
                        controller: email,
                        hint: 'you@example.com',
                        error: error.value,
                        keyboardType: TextInputType.emailAddress,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: SlabButton(
                  label: submitting.value ? 'Sending' : 'Send code',
                  enabled: email.text.trim().isNotEmpty && !submitting.value,
                  busy: submitting.value,
                  onPressed: submit,
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
