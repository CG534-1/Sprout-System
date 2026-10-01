import 'package:flutter/widgets.dart';
import 'package:web/web.dart';

/// Parks the hidden file input over [at] so iOS anchors its photo menu
/// to the control that was tapped, not the bottom of the page.
void parkWebPicker(BuildContext? at) {
  if (at == null || !at.mounted) {
    resetWebPicker();
    return;
  }
  final box = at.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    resetWebPicker();
    return;
  }
  final origin = box.localToGlobal(Offset.zero);
  parkWebPickerRect(
    left: origin.dx,
    top: origin.dy,
    width: box.size.width,
    height: box.size.height,
  );
}

void parkWebPickerRect({
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  _writePickerVars(
    left,
    top,
    width < 44 ? 44 : width,
    height < 44 ? 44 : height,
  );
}

void resetWebPicker() {
  _writePickerVars(-9999, -9999, 1, 1);
}

void _writePickerVars(double left, double top, double width, double height) {
  final root = document.documentElement as HTMLHtmlElement?;
  if (root == null) return;
  root.style.setProperty('--sprout-picker-left', '${left}px');
  root.style.setProperty('--sprout-picker-top', '${top}px');
  root.style.setProperty('--sprout-picker-width', '${width}px');
  root.style.setProperty('--sprout-picker-height', '${height}px');
}
