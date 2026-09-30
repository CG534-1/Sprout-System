import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_task.dart';
import 'package:sprout/data/services/care_service.dart';


Future<void> showCalendarSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _CalendarSheet(),
  );
}

class _CalendarSheet extends StatefulWidget {
  const _CalendarSheet();

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late final List<DateTime> _days;
  late DateTime _selected;
  List<CareTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = List.generate(7, (index) => today.add(Duration(days: index)));
    _selected = today;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final tasks = await context.read<CareService>().tasksFor(_selected);
    if (!mounted) return;
    setState(() {
      _tasks = tasks..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final heading = DateUtils.isSameDay(_selected, today)
        ? 'Today · ${DateFormat('EEE, MMM d').format(_selected)}'
        : DateFormat('EEE, MMM d').format(_selected);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
          ),
        ),
        Container(
      decoration: BoxDecoration(
        color: AppColors.onboardingPaper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dotIdle,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'This week',
                    style: GoogleFonts.fraunces(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '✕',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.onboardingBody,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 0.8, color: AppColors.dotIdle),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final day in _days)
                    Expanded(
                      child: _DayChip(
                        day: day,
                        selected: DateUtils.isSameDay(day, _selected),
                        onTap: () {
                          setState(() => _selected = day);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  heading,
                  style: GoogleFonts.dmMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    color: AppColors.onboardingBody,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_tasks.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Nothing scheduled',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.onboardingBody,
                      ),
                    ),
                  ),
                )
              else
                for (final task in _tasks) ...[
                  _CalendarTask(task: task),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            DateFormat('EEE').format(day).toUpperCase(),
            style: GoogleFonts.dmMono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.sproutGreen : AppColors.onboardingBody,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.primary : Colors.transparent,
            ),
            child: Text(
              '${day.day}',
              style: GoogleFonts.fraunces(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarTask extends StatelessWidget {
  const _CalendarTask({required this.task});

  final CareTask task;

  @override
  Widget build(BuildContext context) {
    final plant = task.subjectType == CareSubjectType.plant;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.onboardingPaper,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: plant ? AppColors.sproutGreen : AppColors.splashTop,
            width: 4,
          ),
          top: BorderSide(
            color: plant ? AppColors.sproutGreen : AppColors.splashTop,
            width: 0.8,
          ),
          right: BorderSide(
            color: plant ? AppColors.sproutGreen : AppColors.splashTop,
            width: 0.8,
          ),
          bottom: BorderSide(
            color: plant ? AppColors.sproutGreen : AppColors.splashTop,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(plant ? '🌿' : '🐾', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${task.action.label} ${task.subjectName}',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              Text(
                DateFormat('h:mm a').format(task.dueAt),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.onboardingBody,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
