import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/photo_crop.dart';
import 'package:sprout/core/picker_anchor.dart';

/// Opens the system photo picker and returns the chosen image.
///
/// Pass [from] as the control that was tapped so the web file input sits
/// on that widget. iOS otherwise parks its menu on a leftover input.
///
/// Returns null when the picker is dismissed, and throws an [AppException]
/// with something readable when the platform refuses.
Future<Uint8List?> pickCarePhoto({BuildContext? from}) async {
  parkWebPicker(from);
  try {
    final bytes = kIsWeb
        ? await pickWebFile(from)
        : await _pickNative();
    if (bytes == null) return null;
    if (from == null || !from.mounted) return bytes;
    return await showPhotoCrop(from, bytes);
  } on AppException {
    rethrow;
  } on PlatformException catch (error) {
    if (error.code == 'photo_access_denied' ||
        error.code == 'camera_access_denied') {
      throw const AppException('Sprout needs permission to open your photos.');
    }
    throw const AppException(
      'That photo could not be opened. Try a different one.',
    );
  } catch (_) {
    throw const AppException(
      'That photo could not be opened. Try a different one.',
    );
  } finally {
    resetWebPicker();
  }
}

Future<Uint8List?> _pickNative() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    imageQuality: 85,
  );
  if (file == null) return null;
  return file.readAsBytes();
}
