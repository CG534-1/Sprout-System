import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/push_note.dart';
import 'package:sprout/features/today/today_providers.dart';

Future<void> showBellSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondary) {
      final width = math.min(340.0, MediaQuery.sizeOf(context).width - 28);
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AppColors.onboardingPaper,
          elevation: 8,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: const _BellPanel(),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      );
      return SlideTransition(position: slide, child: child);
    },
  );
}

class _BellPanel extends ConsumerWidget {
  const _BellPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(bellNotesProvider).value ?? const <PushNote>[];
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: GoogleFonts.fraunces(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.dotIdle),
          Expanded(
            child: notes.isEmpty
                ? const _EmptyNotes()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                    children: [
                      for (final note in notes) ...[
                        _NoteRow(note: note),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No notifications',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Care reminders, overdue care, and the daily summary show up here.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              height: 1.45,
              color: AppColors.onboardingBody,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final PushNote note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.title,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: note.read ? FontWeight.w600 : FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note.body,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.4,
              color: AppColors.onboardingBody,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              DateFormat('MMM d, h:mm a').format(note.createdAt.toLocal()),
              if (!note.read) 'New',
            ].join(' · '),
            style: GoogleFonts.dmMono(
              fontSize: 10,
              color: note.read ? AppColors.onboardingBody : AppColors.sproutGreen,
            ),
          ),
        ],
      ),
    );
  }
}
