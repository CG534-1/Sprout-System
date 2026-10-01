import 'package:flutter/material.dart';

/// Scrolls the focused field up so the keyboard does not cover it.
///
/// Auth Scaffolds keep `resizeToAvoidBottomInset: false`, so this is what
/// actually makes a tapped field stay readable.
void revealFieldAboveKeyboard(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null || !scrollable.position.hasContentDimensions) {
      return;
    }
    final position = scrollable.position;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset < 1) return;
    final visibleBottom = MediaQuery.sizeOf(context).height - inset - 16;
    final origin = object.localToGlobal(Offset.zero);
    final overflow = origin.dy + object.size.height - visibleBottom;
    if (overflow <= 1) return;
    final target = (position.pixels + overflow).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target <= position.pixels + 0.5) return;
    position.jumpTo(target);
  });
}
