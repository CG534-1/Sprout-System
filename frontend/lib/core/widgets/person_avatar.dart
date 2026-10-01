import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/core/theme/app_colors.dart';

String sproutInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return ('$first$last').toUpperCase();
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.avatarBytes,
  });

  final String name;
  final String? avatarUrl;
  final Uint8List? avatarBytes;

  @override
  Widget build(BuildContext context) {
    return SproutCirclePhoto(
      bytes: avatarBytes,
      url: avatarUrl,
      fallback: sproutInitials(name),
    );
  }
}

/// A photo painted as a circle. Decoration images stay inside the oval on
/// web, where [ClipOval] plus [Image] often leaks past the ring.
class SproutCirclePhoto extends StatelessWidget {
  const SproutCirclePhoto({
    super.key,
    this.bytes,
    this.asset,
    this.url,
    this.fallback = '',
    this.fallbackSize = 18,
    this.iconSize = 36,
  });

  final Uint8List? bytes;
  final String? asset;
  final String? url;
  final String fallback;
  final double fallbackSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image;
    var fit = BoxFit.cover;
    final rawBytes = bytes;
    final rawAsset = asset;
    final rawUrl = url?.trim() ?? '';
    if (rawBytes != null) {
      image = MemoryImage(rawBytes);
    } else if (rawAsset != null && rawAsset.isNotEmpty) {
      image = AssetImage(rawAsset);
      fit = BoxFit.contain;
    } else if (rawUrl.startsWith('assets/')) {
      image = AssetImage(rawUrl);
      fit = BoxFit.contain;
    } else if (rawUrl.isNotEmpty) {
      image = NetworkImage(rawUrl);
    } else {
      image = null;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.field,
        image: image == null ? null : DecorationImage(image: image, fit: fit),
      ),
      child: image != null
          ? null
          : Center(
              child: fallback.isEmpty
                  ? Icon(
                      Icons.person_outline,
                      color: AppColors.sproutGreen,
                      size: iconSize,
                    )
                  : Text(
                      fallback,
                      style: GoogleFonts.fraunces(
                        fontSize: fallbackSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sproutGreen,
                      ),
                    ),
            ),
    );
  }
}
