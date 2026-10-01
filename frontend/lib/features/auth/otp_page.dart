import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/auth/auth_widgets.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.email, required this.purpose});

  final String email;
  final String purpose;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _code = TextEditingController();
  String? _error;
  var _checking = false;
  var _resending = false;
  static const _resendWait = 120;
  var _secondsLeft = _resendWait;
  Timer? _wait;

  bool get _recovery => widget.purpose == 'recovery';

  @override
  void initState() {
    super.initState();
    _startWait();
  }

  void _startWait() {
    _wait?.cancel();
    _secondsLeft = _resendWait;
    _wait = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending || _checking) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().resendEmailCode(
        email: widget.email,
        recovery: _recovery,
      );
      if (!mounted) return;
      setState(() => _resending = false);
      _startWait();
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = error.message;
      });
    }
  }

  Future<void> _confirm() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      if (_recovery) {
        await auth.confirmRecoveryCode(email: widget.email, code: _code.text);
        if (!mounted) return;
        context.go(AppRoutes.resetPassword);
        return;
      }
      await auth.confirmEmailCode(email: widget.email, code: _code.text);
      if (!mounted) return;
      context.pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = error.message;
      });
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
                      const AuthHeadline(lead: 'Enter your', accent: 'code.'),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a 6-digit code to ${widget.email}.',
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
                        controller: _code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() => _error = null),
                        style: GoogleFonts.dmMono(
                          fontSize: 22,
                          letterSpacing: 6,
                          color: AppColors.ink,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          errorText: _error,
                          filled: true,
                          fillColor: AppColors.field,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _confirm(),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _secondsLeft == 0 && !_resending ? _resend : null,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.sproutGreen,
                            disabledForegroundColor: AppColors.onboardingBody,
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _resending
                                ? 'Sending'
                                : _secondsLeft == 0
                                ? 'Resend code'
                                : 'Resend code in ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _secondsLeft == 0 && !_resending
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
                    label: _checking ? 'Checking' : 'Confirm',
                    enabled: _code.text.trim().length == 6 && !_checking,
                    onPressed: _confirm,
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
