import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/core/theme/app_colors.dart';

class SproutCheck extends StatelessWidget {
  const SproutCheck({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.sproutGreen,
        shape: BoxShape.circle,
      ),
      child: Text(
        '✓',
        style: GoogleFonts.dmSans(
          fontSize: size * 16 / 26,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}
