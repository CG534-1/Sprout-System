import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/auth/auth_widgets.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  String? _error;
  var _saving = false;
  var _obscure = true;

  bool get _ready {
    final value = _password.text;
    return value.length >= 8 &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_ready || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().setNewPassword(password: _password.text);
      if (!mounted) return;
      context.go(AppRoutes.today);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 26, 16),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    left: 6,
                    top: 12,
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  children: [
                    const AuthHeadline(lead: 'Choose a new', accent: 'password.'),
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
                      controller: _password,
                      hint: 'New password',
                      error: _error,
                      obscure: _obscure,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: SlabButton(
                  label: _saving ? 'Saving' : 'Save password',
                  enabled: _ready && !_saving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
