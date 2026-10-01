import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart';

/// Parks a leftover plugin input, if one exists, over [at].
void parkWebPicker(BuildContext? at) {
  final rect = _rectOf(at);
  if (rect == null) {
    resetWebPicker();
    return;
  }
  parkWebPickerRect(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
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

/// Opens a file input on `document.body` over the tapped control so iOS
/// anchors Photo Library / Take Photo to that widget, not a 0×0 host.
Future<Uint8List?> pickWebFile(BuildContext? from) {
  final rect = _rectOf(from);
  final left = rect?.left ?? 0;
  final top = rect?.top ?? 0;
  final width = (rect?.width ?? 44).clamp(44, 4000);
  final height = (rect?.height ?? 44).clamp(44, 4000);

  final input = HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..multiple = false;
  input.style
    ..setProperty('position', 'fixed', 'important')
    ..setProperty('left', '${left}px', 'important')
    ..setProperty('top', '${top}px', 'important')
    ..setProperty('width', '${width}px', 'important')
    ..setProperty('height', '${height}px', 'important')
    ..setProperty('bottom', 'auto', 'important')
    ..setProperty('right', 'auto', 'important')
    ..setProperty('opacity', '0.01', 'important')
    ..setProperty('margin', '0', 'important')
    ..setProperty('padding', '0', 'important')
    ..setProperty('border', '0', 'important')
    ..setProperty('z-index', '2147483647', 'important');

  final completer = Completer<Uint8List?>();
  var settled = false;

  void finish(Uint8List? bytes) {
    if (settled) return;
    settled = true;
    input.remove();
    if (!completer.isCompleted) completer.complete(bytes);
  }

  input.onchange = (Event _) {
    final files = input.files;
    final file = files != null && files.length > 0 ? files.item(0) : null;
    if (file == null) {
      finish(null);
      return;
    }
    file.arrayBuffer().toDart.then((buffer) {
      finish(Uint8List.view(buffer.toDart));
    }).catchError((_) {
      finish(null);
    });
  }.toJS;

  input.oncancel = (Event _) {
    finish(null);
  }.toJS;

  input.onerror = (Event _) {
    finish(null);
  }.toJS;

  document.body?.append(input);
  input.click();
  return completer.future;
}

Rect? _rectOf(BuildContext? at) {
  if (at == null || !at.mounted) return null;
  final box = at.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final origin = box.localToGlobal(Offset.zero);
  return origin & box.size;
}

void _writePickerVars(double left, double top, double width, double height) {
  final root = document.documentElement as HTMLHtmlElement?;
  if (root == null) return;
  root.style.setProperty('--sprout-picker-left', '${left}px');
  root.style.setProperty('--sprout-picker-top', '${top}px');
  root.style.setProperty('--sprout-picker-width', '${width}px');
  root.style.setProperty('--sprout-picker-height', '${height}px');
}
