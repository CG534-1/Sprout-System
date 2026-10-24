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
import 'package:sprout/features/auth/auth_widgets.dart';

class ResetPasswordPage extends HookConsumerWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final password = useTextEditingController();
    useListenable(password);
    final error = useState<String?>(null);
    final saving = useState(false);
    final obscure = useState(true);
    final ready = PasswordRules.satisfied(password.text);

    useEffect(() {
      void clearError() => error.value = null;
      password.addListener(clearError);
      return () => password.removeListener(clearError);
    }, const []);

    Future<void> save() async {
      if (!ready || saving.value) return;
      saving.value = true;
      error.value = null;
      final toast = sproutToaster(context);
      try {
        await ref.read(authServiceProvider).setNewPassword(
          password: password.text,
        );
        if (!context.mounted) return;
        toast.show('Password updated. Sign in with your new password.');
        context.go(AppRoutes.signIn);
      } on AppException catch (failure) {
        if (!context.mounted) return;
        saving.value = false;
        error.value = failure.message;
      }
    }

    Future<void> cancel() async {
      if (saving.value) return;
      await ref.read(authServiceProvider).signOut();
      if (!context.mounted) return;
      context.go(AppRoutes.signIn);
    }

    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 26, 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AuthBackButton(onPressed: cancel),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    left: 6,
                    top: 12,
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  children: [
                    const AuthHeadline(
                      lead: 'Choose a new',
                      accent: 'password.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'At least 8 characters, with a number, a capital letter, and a symbol.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        height: 20 / 14,
                        color: AppColors.onboardingBody,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AuthField(
                      label: 'PASSWORD',
                      controller: password,
                      hint: 'New password',
                      error: error.value,
                      obscure: obscure.value,
                      suffix: IconButton(
                        onPressed: () => obscure.value = !obscure.value,
                        icon: Icon(
                          obscure.value
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    PasswordRules(value: password.text),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: SlabButton(
                  label: saving.value ? 'Saving' : 'Save password',
                  enabled: ready && !saving.value,
                  busy: saving.value,
                  onPressed: save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
