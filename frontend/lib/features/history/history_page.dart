import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_history_entry.dart';
import 'package:sprout/data/providers.dart';
import 'package:sprout/features/care/care_sheet.dart';
import 'package:sprout/features/history/history_providers.dart';
import 'package:sprout/features/shell/care_nav.dart';
import 'package:sprout/features/shell/quiet_card.dart';

const _mint = Color(0xFF87DB6C);

enum _Filter { all, plants, pets }

class HistoryPage extends HookConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = useState(_Filter.all);
    final selectedFilter = filter.value;
    final load = ref.watch(careHistoryProvider);
    final history = load.value;
    final failed = load.failedEmpty;
    final loading = history == null && !failed;
    final entries = history?.entries ?? const <CareHistoryEntry>[];
    final photos = history?.photos ?? const <String, String>{};
    final now = DateTime.now();
    final visible = entries.where((entry) {
      return switch (selectedFilter) {
        _Filter.all => true,
        _Filter.plants => entry.subjectType == CareSubjectType.plant,
        _Filter.pets => entry.subjectType == CareSubjectType.pet,
      };
    }).toList();
    final monthCount = entries
        .where((entry) => entry.completedAt.year == now.year && entry.completedAt.month == now.month)
        .length;

    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(20, 22, 20, CareNav.scrollClearance(context)),
              children: [
                Text(
                  'A LITTLE PROGRESS, EVERY DAY',
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.9,
                    color: AppColors.sproutGreen,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Care history',
                  style: GoogleFonts.fraunces(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.6,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entries.isEmpty
                            ? 'No moments yet'
                            : monthCount == 0
                            ? 'None this month'
                            : monthCount == 1
                            ? '1 care moment'
                            : '$monthCount care moments',
                        style: GoogleFonts.fraunces(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entries.isEmpty
                            ? 'Completed care will gather here.'
                            : 'completed this month',
                        style: GoogleFonts.dmSans(fontSize: 11, height: 1.5, color: _mint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                if (entries.isNotEmpty)
                  Row(
                    children: [
                      _HistoryChip(
                        label: 'All',
                        selected: selectedFilter == _Filter.all,
                        onTap: () => filter.value = _Filter.all,
                      ),
                      const SizedBox(width: 7),
                      _HistoryChip(
                        label: 'Plants',
                        selected: selectedFilter == _Filter.plants,
                        onTap: () => filter.value = _Filter.plants,
                      ),
                      const SizedBox(width: 7),
                      _HistoryChip(
                        label: 'Pets',
                        selected: selectedFilter == _Filter.pets,
                        onTap: () => filter.value = _Filter.pets,
                      ),
                    ],
                  ),
                if (failed)
                  LoadFailedCard(
                    title: 'Your history could not load',
                    onRetry: () => ref
                      ..invalidate(homeProvider)
                      ..invalidate(careHistoryProvider),
                  )
                else if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 28),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (entries.isEmpty)
                  const QuietCard(
                    icon: Icons.history,
                    title: 'History starts later',
                    body: 'When you complete a task, it will be kept here.',
                  )
                else if (visible.isEmpty)
                  const QuietCard(
                    icon: Icons.history,
                    title: 'Nothing in this filter',
                    body: 'Completed care for the other group is still under All.',
                  )
                else
                  for (var index = 0; index < visible.length; index++) ...[
                    if (index == 0 || !_sameDay(visible[index].completedAt, visible[index - 1].completedAt))
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          DateFormat('EEEE, MMM d').format(visible[index].completedAt).toUpperCase(),
                          style: GoogleFonts.dmMono(
                            fontSize: 10,
                            color: AppColors.onboardingBody,
                          ),
                        ),
                      ),
                    _HistoryRow(
                      entry: visible[index],
                      photo: photos[visible[index].subjectName],
                    ),
                  ],
              ],
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: CareNav(tab: CareTab.history),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.dotIdle,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            height: 1.5,
            color: selected ? Colors.white : AppColors.onboardingBody,
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.photo});

  final CareHistoryEntry entry;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = entry.completedAt.year == now.year &&
        entry.completedAt.month == now.month &&
        entry.completedAt.day == now.day;
    final when = today
        ? 'Today, ${DateFormat('h:mm a').format(entry.completedAt)}'
        : DateFormat('MMM d, h:mm a').format(entry.completedAt);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.dotIdle, width: 0.8)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 43,
              height: 43,
              child: photo == null
                  ? ColoredBox(color: AppColors.field)
                  : careImage(url: photo),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.action.past} ${entry.subjectName}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  when,
                  style: GoogleFonts.dmMono(fontSize: 10, color: AppColors.onboardingBody),
                ),
              ],
            ),
          ),
          Container(
            width: 21,
            height: 21,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.field,
              shape: BoxShape.circle,
            ),
            child: Text(
              '✓',
              style: GoogleFonts.dmSans(fontSize: 12, height: 1, color: AppColors.sproutGreen),
            ),
          ),
        ],
      ),
    );
  }
}
