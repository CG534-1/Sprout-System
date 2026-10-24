import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/data/providers.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/features/auth/auth_widgets.dart';

class OtpPage extends HookConsumerWidget {
  const OtpPage({
    super.key,
    required this.email,
    required this.purpose,
    this.currentEmail = '',
  });

  final String email;
  final String purpose;
  final String currentEmail;

  static const _resendWait = Duration(seconds: 60);

  bool get _recovery => purpose == 'recovery';
  bool get _emailChange => purpose == 'email_change';

  static int _remaining(DateTime sentAt) {
    final left = _resendWait - DateTime.now().difference(sentAt);
    return left.isNegative ? 0 : left.inSeconds;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = useTextEditingController();
    // The confirm button follows the code as it is typed.
    useListenable(code);
    final error = useState<String?>(null);
    final checking = useState(false);
    final resending = useState(false);
    // Anchored to when the code actually went out, so the countdown is right
    // when this page is reopened rather than starting over at a full minute.
    final sentAt = useState(
      useMemoized(
        () => ref.read(authServiceProvider).codeSentAt ?? DateTime.now(),
      ),
    );
    final secondsLeft = useState(useMemoized(() => _remaining(sentAt.value)));
    final target = useState(email);
    final askedCurrent = useState(false);

    // Ticks the resend countdown, and starts over whenever a new code goes out.
    useEffect(() {
      if (_remaining(sentAt.value) == 0) return null;
      final wait = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!context.mounted) {
          timer.cancel();
          return;
        }
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) return;
        final left = _remaining(sentAt.value);
        if (left == secondsLeft.value) return;
        secondsLeft.value = left;
        if (left == 0) timer.cancel();
      });
      return wait.cancel;
    }, [sentAt.value]);

    void leave() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(_recovery ? AppRoutes.signIn : AppRoutes.signUp);
    }

    Future<void> resend() async {
      if (secondsLeft.value > 0 || resending.value || checking.value) return;
      resending.value = true;
      error.value = null;
      final auth = ref.read(authServiceProvider);
      try {
        await auth.resendEmailCode(
          email: email,
          recovery: _recovery,
          emailChange: _emailChange,
        );
        if (!context.mounted) return;
        final sent = auth.codeSentAt ?? DateTime.now();
        secondsLeft.value = _remaining(sent);
        sentAt.value = sent;
        resending.value = false;
        showSproutToast(context, 'New code sent to $email.');
      } on AppException catch (failure) {
        if (!context.mounted) return;
        resending.value = false;
        error.value = failure.message;
      }
    }

    Future<void> confirm() async {
      if (checking.value) return;
      checking.value = true;
      error.value = null;
      final auth = ref.read(authServiceProvider);
      auth.holdRouting();
      try {
        if (_emailChange) {
          final confirmed = await auth.confirmEmailChange(
            email: target.value,
            code: code.text,
          );
          if (!context.mounted) return;
          final wanted = email.trim().toLowerCase();
          final now = confirmed?.trim().toLowerCase();
          if (now == wanted) {
            if (context.canPop()) {
              context.pop(true);
            } else {
              context.go(AppRoutes.updateDetails);
            }
            return;
          }
          if (!askedCurrent.value && currentEmail.isNotEmpty) {
            askedCurrent.value = true;
            target.value = currentEmail;
            code.clear();
            checking.value = false;
            return;
          }
          throw const AppException('That code did not finish the email change. Resend it and try again.');
        }
        if (_recovery) {
          await auth.confirmRecoveryCode(email: email, code: code.text);
          if (!context.mounted) return;
          context.go(AppRoutes.resetPassword);
          return;
        }
        await auth.confirmEmailCode(email: email, code: code.text);
        if (!context.mounted) return;
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go(AppRoutes.signUp);
        }
      } on AppException catch (failure) {
        if (!context.mounted) return;
        checking.value = false;
        error.value = failure.message;
      } finally {
        auth.releaseRouting();
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
                  child: AuthBackButton(onPressed: leave),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      left: 6,
                      top: 12,
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    children: [
                      const AuthHeadline(lead: 'Enter your', accent: 'code.'),
                      const SizedBox(height: 8),
                      Text(
                        askedCurrent.value
                            ? 'We also sent a code to $currentEmail.'
                            : 'We sent a 6-digit code to $email.',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          height: 20 / 14,
                          color: AppColors.onboardingBody,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check your spam folder if you cannot find the email.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          height: 18 / 13,
                          color: AppColors.onboardingBody.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => error.value = null,
                        style: GoogleFonts.dmMono(
                          fontSize: 22,
                          letterSpacing: 6,
                          color: AppColors.ink,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          errorText: error.value,
                          filled: true,
                          fillColor: AppColors.field,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => confirm(),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: secondsLeft.value == 0 && !resending.value ? resend : null,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.sproutGreen,
                            disabledForegroundColor: AppColors.onboardingBody,
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            resending.value
                                ? 'Sending'
                                : secondsLeft.value == 0
                                ? 'Resend code'
                                : 'Resend code in ${secondsLeft.value ~/ 60}:${(secondsLeft.value % 60).toString().padLeft(2, '0')}',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: secondsLeft.value == 0 && !resending.value
                                  ? AppColors.sproutGreen
                                  : AppColors.onboardingBody,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: SlabButton(
                    label: checking.value ? 'Checking' : 'Confirm',
                    enabled: code.text.trim().length == 6 && !checking.value,
                    busy: checking.value,
                    onPressed: confirm,
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
