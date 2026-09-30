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
    final bytes = avatarBytes;
    final url = avatarUrl;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('assets/')) {
        return Image.asset(url, fit: BoxFit.contain);
      }
      return Image.network(url, fit: BoxFit.cover);
    }
    return ColoredBox(
      color: AppColors.field,
      child: Center(
        child: Text(
          sproutInitials(name),
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.sproutGreen,
          ),
        ),
      ),
    );
  }
}
