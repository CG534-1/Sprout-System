import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/core/theme/app_colors.dart';

/// Shows a short confirmation inside the phone frame.
void showSproutToast(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  sproutToaster(context).show(message, error: error);
}

/// Grab this before popping a sheet or page, then show the message after. The
/// handle outlives the widget that asked for it.
SproutToaster sproutToaster(BuildContext context) {
  return SproutToaster(Overlay.maybeOf(context, rootOverlay: true));
}

class SproutToaster {
  const SproutToaster(this._overlay);

  final OverlayState? _overlay;

  void show(String message, {bool error = false}) {
    final overlay = _overlay;
    if (overlay == null || !overlay.mounted) return;
    _dismissToast();
    final entry = OverlayEntry(
      builder: (context) => _SproutToast(message: message, error: error),
    );
    _toast = entry;
    overlay.insert(entry);
  }
}

OverlayEntry? _toast;

void _dismissToast([OverlayEntry? only]) {
  final entry = _toast;
  if (entry == null) return;
  if (only != null && only != entry) return;
  _toast = null;
  entry.remove();
}

class _SproutToast extends StatefulWidget {
  const _SproutToast({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  State<_SproutToast> createState() => _SproutToastState();
}

class _SproutToastState extends State<_SproutToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  Timer? _life;
  OverlayEntry? _mine;

  @override
  void initState() {
    super.initState();
    _mine = _toast;
    _life = Timer(Duration(milliseconds: widget.error ? 3800 : 2600), _close);
  }

  Future<void> _close() async {
    if (!mounted) return;
    await _show.reverse();
    if (!mounted) return;
    _dismissToast(_mine);
  }

  @override
  void dispose() {
    _life?.cancel();
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top + 10,
      left: 16,
      right: 16,
      // A toast must never eat a tap meant for the header underneath it.
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _show,
          builder: (context, child) {
            final shown = Curves.easeOutCubic.transform(_show.value);
            return Opacity(
              opacity: shown,
              child: Transform.translate(
                offset: Offset(0, (shown - 1) * 16),
                child: child,
              ),
            );
          },
          child: _ToastBody(message: widget.message, error: widget.error),
        ),
      ),
    );
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: error ? AppColors.error : AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      elevation: 6,
      shadowColor: const Color(0x40000000),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              error ? '⚠' : '🌿',
              style: const TextStyle(fontSize: 15, height: 1.2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small inline spinner for buttons that are mid-save.
class SproutSpinner extends StatelessWidget {
  const SproutSpinner({super.key, this.size = 16, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
