import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/keyboard.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';

Color get authInk => AppColors.ink;
Color get authField => AppColors.field;
Color get authHint => AppColors.ink.withValues(alpha: 0.5);

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 22),
    );
  }
}

class AuthHeadline extends StatelessWidget {
  const AuthHeadline({super.key, required this.lead, required this.accent});

  final String lead;
  final String accent;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.fraunces(
      fontSize: 33,
      fontWeight: FontWeight.w600,
      height: 35 / 33,
      letterSpacing: -1.4,
      color: authInk,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$lead\n'),
          TextSpan(
            text: accent,
            style: base.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.sproutGreen,
            ),
          ),
        ],
      ),
      style: base,
    );
  }
}

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.error,
    this.fieldKey,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.mark,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String? error;
  final Key? fieldKey;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final Widget? mark;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> with WidgetsBindingObserver {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onFocus() {
    setState(() {});
    if (_focus.hasFocus) revealFieldAboveKeyboard(context);
  }

  @override
  void didChangeMetrics() {
    if (_focus.hasFocus) revealFieldAboveKeyboard(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.error;
    final focused = _focus.hasFocus;
    const none = InputBorder.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: authField,
            borderRadius: BorderRadius.circular(10),
            border: message != null
                ? Border.all(color: AppColors.error, width: 1.4)
                : focused
                ? Border.all(color: AppColors.primary, width: 1.6)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: GoogleFonts.dmMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.66,
                          color: message != null
                              ? AppColors.error
                              : focused
                              ? AppColors.primary
                              : AppColors.onboardingBody,
                        ),
                      ),
                      TextField(
                        key: widget.fieldKey,
                        focusNode: _focus,
                        controller: widget.controller,
                        obscureText: widget.obscure,
                        autofocus: false,
                        keyboardType: widget.keyboardType,
                        cursorColor: AppColors.primary,
                        style: GoogleFonts.dmSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: authInk,
                        ),
                        decoration: InputDecoration(
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.only(top: 6),
                          border: none,
                          enabledBorder: none,
                          focusedBorder: none,
                          disabledBorder: none,
                          errorBorder: none,
                          focusedErrorBorder: none,
                          hintText: widget.hint,
                          hintStyle: GoogleFonts.dmSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: authHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ?widget.suffix,
                ?widget.mark,
              ],
            ),
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              message,
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class SlabButton extends StatelessWidget {
  const SlabButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: SizedBox(
        height: 61,
        child: Stack(
          children: [
            Positioned(
              left: 6.5,
              right: 0,
              top: 3,
              height: 53,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x9C006134),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 7,
              top: 0,
              height: 58,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: enabled ? onPressed : null,
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fraunces(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (busy)
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(child: SproutSpinner()),
                            )
                          else
                            const ButtonArrow(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The password rule chips shared by sign up and reset password.
class PasswordRules extends StatelessWidget {
  const PasswordRules({super.key, required this.value});

  final String value;

  static bool satisfied(String value) {
    return value.length >= 8 &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: authField,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RuleChip('8+ characters', value.length >= 8),
              _RuleChip('1 number', RegExp(r'\d').hasMatch(value)),
              _RuleChip('1 uppercase', RegExp(r'[A-Z]').hasMatch(value)),
              _RuleChip('1 special', RegExp(r'[^A-Za-z0-9]').hasMatch(value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip(this.label, this.met);

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: met ? AppColors.primary : const Color(0xFFD7EBD9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: met ? FontWeight.w700 : FontWeight.w500,
            color: met ? Colors.white : AppColors.onboardingBody,
          ),
        ),
      ),
    );
  }
}

class ButtonArrow extends StatelessWidget {
  const ButtonArrow({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(painter: _ButtonArrowPainter()),
    );
  }
}

class _ButtonArrowPainter extends CustomPainter {
  const _ButtonArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.shortestSide / 2 - 1.6, ring);

    final arrow = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.30, size.height * 0.50)
      ..lineTo(size.width * 0.64, size.height * 0.50)
      ..moveTo(size.width * 0.50, size.height * 0.34)
      ..lineTo(size.width * 0.68, size.height * 0.50)
      ..lineTo(size.width * 0.50, size.height * 0.66);
    canvas.drawPath(path, arrow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SignupProgress extends StatelessWidget {
  const SignupProgress({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: i <= step ? 44 : 24,
            height: 4,
            decoration: BoxDecoration(
              color: i <= step ? AppColors.primary : AppColors.dotIdle,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ],
      ],
    );
  }
}

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.tall = true,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? authField : AppColors.onboardingPaper,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: tall ? 112 : 92,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.sproutGreen : AppColors.dotIdle,
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Image.asset(
                icon,
                width: 28,
                height: 28,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: authInk,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.onboardingBody,
                      ),
                    ),
                  ],
                ),
              ),
              _Mark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.sproutGreen : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.sproutGreen : AppColors.dotIdle,
          width: 1.1,
        ),
      ),
      child: selected
          ? Text(
              '✓',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                height: 1,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}

class FieldClover extends StatelessWidget {
  const FieldClover({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final filled = controller.text.trim().isNotEmpty;
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            filled ? const Color(0xFF179C46) : const Color(0xFFC6E5CC),
            BlendMode.srcIn,
          ),
          child: child,
        );
      },
      child: const Image(
        image: AssetImage('assets/icons/field_clover.png'),
        width: 18,
        height: 18,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
