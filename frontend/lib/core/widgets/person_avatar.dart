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
    final rawBytes = bytes;
    final rawAsset = asset;
    final rawUrl = url?.trim() ?? '';
    final assetPath = rawAsset != null && rawAsset.isNotEmpty
        ? rawAsset
        : rawUrl.startsWith('assets/')
        ? rawUrl
        : null;

    final Widget face;
    if (rawBytes != null) {
      face = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.field,
          image: DecorationImage(
            image: MemoryImage(rawBytes),
            fit: BoxFit.cover,
          ),
        ),
        child: const SizedBox.expand(),
      );
    } else if (assetPath != null) {
      face = ClipOval(
        clipBehavior: Clip.hardEdge,
        child: ColoredBox(
          color: AppColors.field,
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
      );
    } else if (rawUrl.isNotEmpty) {
      face = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.field,
          image: DecorationImage(
            image: NetworkImage(rawUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: const SizedBox.expand(),
      );
    } else {
      face = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.field,
        ),
        child: Center(
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

    return SizedBox.expand(child: face);
  }
}
