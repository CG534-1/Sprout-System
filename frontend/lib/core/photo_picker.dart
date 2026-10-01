import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sprout/core/app_exception.dart';

/// Opens the system photo picker and returns the chosen image.
///
/// Returns null when the picker is dismissed, and throws an [AppException]
/// with something readable when the platform refuses.
Future<Uint8List?> pickCarePhoto() async {
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;
    return await file.readAsBytes();
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
  }
}
