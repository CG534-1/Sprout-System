import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sprout/core/theme/app_colors.dart';

class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child});

  final Widget child;

  static const double phoneWidth = 430;
  static const double frameAt = 700;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final framed = constraints.maxWidth >= frameAt;
        final width = framed ? phoneWidth : constraints.maxWidth;
        return ColoredBox(
          color: framed ? AppColors.frame : AppColors.background,
          child: Center(
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
