import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';

enum CareTab { today, care, history, profile }

class CareNav extends StatelessWidget {
  const CareNav({super.key, required this.tab});

  final CareTab tab;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.nav,
            border: Border(top: BorderSide(color: AppColors.dotIdle, width: 0.8)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: CareTab.today,
                    label: 'Today',
                    active: tab == CareTab.today,
                    onTap: tab == CareTab.today
                        ? null
                        : () => context.go(AppRoutes.today),
                  ),
                  _NavItem(
                    icon: CareTab.care,
                    label: 'My Care',
                    active: tab == CareTab.care,
                    onTap: tab == CareTab.care
                        ? null
                        : () => context.go(AppRoutes.myCare),
                  ),
                  _NavItem(
                    icon: CareTab.history,
                    label: 'History',
                    active: tab == CareTab.history,
                    onTap: tab == CareTab.history
                        ? null
                        : () => context.go(AppRoutes.history),
                  ),
                  _NavItem(
                    icon: CareTab.profile,
                    label: 'Profile',
                    active: tab == CareTab.profile,
                    onTap: tab == CareTab.profile
                        ? null
                        : () => context.go(AppRoutes.profile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final CareTab icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.sproutGreen : AppColors.navIdle;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(20, 20),
              painter: _NavIconPainter(kind: icon, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIconPainter extends CustomPainter {
  const _NavIconPainter({required this.kind, required this.color});

  final CareTab kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case CareTab.today:
        final path = Path()
          ..moveTo(size.width / 2, 2)
          ..lineTo(2, 9)
          ..lineTo(2, size.height - 2)
          ..lineTo(size.width - 2, size.height - 2)
          ..lineTo(size.width - 2, 9)
          ..close();
        canvas.drawPath(path, paint);
      case CareTab.care:
        final fill = Paint()..color = color;
        for (final dx in [3.0, 12.0]) {
          for (final dy in [3.0, 12.0]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(dx, dy, 5, 5),
                const Radius.circular(1.4),
              ),
              fill,
            );
          }
        }
      case CareTab.history:
        canvas.drawCircle(size.center(Offset.zero), 7.2, paint);
        canvas.drawLine(size.center(Offset.zero), Offset(size.width / 2, 5.5), paint);
        canvas.drawLine(
          size.center(Offset.zero),
          Offset(size.width - 5.5, size.height / 2),
          paint,
        );
      case CareTab.profile:
        canvas.drawCircle(Offset(size.width / 2, 6.2), 3.1, paint);
        canvas.drawArc(
          Rect.fromLTWH(3, 9, size.width - 6, 12),
          3.4,
          2.6,
          false,
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _NavIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.kind != kind;
  }
}
