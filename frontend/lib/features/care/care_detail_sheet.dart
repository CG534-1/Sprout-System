import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/features/care/add_care_sheet.dart';
import 'package:sprout/features/care/care_sheet.dart';

Future<void> showCareDetailSheet(BuildContext context, CareDraft subject) {
  final host = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _DetailSheet(host: host, subject: subject),
  );
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.host, required this.subject});

  final BuildContext host;
  final CareDraft subject;

  @override
  Widget build(BuildContext context) {
    final plant = subject.type == CareSubjectType.plant;
    final water = _first(CareAction.water);
    return CareSheet(
      child: ListView(
        shrinkWrap: true,
        children: [
          const CareSheetHandle(),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.dotIdle, width: 0.8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    subject.name,
                    style: GoogleFonts.fraunces(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: careInk,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    showAddCareSheet(host, existing: subject);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.sproutGreen, width: 0.8),
                    ),
                    child: Text(
                      'Edit',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sproutGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const CareCloseButton(),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              20,
              22,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Photo(subject: subject, plant: plant),
                if (subject.species.trim().isNotEmpty)
                  _DetailLine(
                    label: plant ? 'SPECIES' : 'PET TYPE',
                    value: subject.species,
                  ),
                if (!plant && subject.breed.trim().isNotEmpty)
                  _DetailLine(label: 'BREED', value: subject.breed),
                if (plant && (subject.location?.trim().isNotEmpty ?? false))
                  _DetailLine(label: 'WHERE IT LIVES', value: subject.location!),
                if (subject.notes?.trim().isNotEmpty ?? false)
                  _DetailLine(label: 'NOTES', value: subject.notes!),
                if (plant && water != null) ...[
                  const CareLabel('WATERING SCHEDULE'),
                  _ScheduleCard(
                    rows: [
                      _ScheduleRow(icon: '🗓', title: 'Frequency', value: water.whenLabel),
                      _ScheduleRow(icon: '⏰', title: 'Reminder', value: _reminders(water)),
                      if (water.lastDone != null)
                        _ScheduleRow(
                          icon: '💧',
                          title: 'Last watered',
                          value: DateFormat('MMM d, y').format(water.lastDone!),
                        ),
                    ],
                  ),
                ],
                if (!plant)
                  for (final schedule in _petSchedules()) ...[
                    CareLabel(_heading(schedule.action)),
                    _ScheduleCard(
                      rows: [
                        _ScheduleRow(icon: '🗓', title: 'Frequency', value: schedule.whenLabel),
                        if (schedule.timesPerDay != null)
                          _ScheduleRow(
                            icon: '↺',
                            title: 'Times',
                            value: '${schedule.timesPerDay}x',
                          ),
                        if (schedule.reminders.isNotEmpty || (schedule.lead?.isNotEmpty ?? false))
                          _ScheduleRow(
                            icon: '⏰',
                            title: 'Reminder',
                            value: _reminders(schedule),
                          ),
                        if (schedule.lastDone != null)
                          _ScheduleRow(
                            icon: '✓',
                            title: _lastTitle(schedule.action),
                            value: DateFormat('MMM d, y').format(schedule.lastDone!),
                          ),
                      ],
                    ),
                  ],
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: GestureDetector(
                    onTap: () => _remove(context),
                    child: Text(
                      'Remove ${subject.name} from my care',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: careRemove,
                        decoration: TextDecoration.underline,
                        decorationColor: careRemove,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  CareSchedule? _first(CareAction action) {
    for (final schedule in subject.schedules) {
      if (schedule.action == action) return schedule;
    }
    return null;
  }

  List<CareSchedule> _petSchedules() {
    const order = [CareAction.feed, CareAction.waterBowl, CareAction.walk];
    final items = [...subject.schedules];
    items.sort(
      (a, b) => order.indexOf(a.action).compareTo(order.indexOf(b.action)),
    );
    return items;
  }

  String _heading(CareAction action) {
    return switch (action) {
      CareAction.feed => 'FEEDING',
      CareAction.waterBowl => 'WATER BOWL',
      CareAction.walk => 'WALKS',
      _ => action.label.toUpperCase(),
    };
  }

  String _lastTitle(CareAction action) {
    return switch (action) {
      CareAction.feed => 'Last fed',
      CareAction.waterBowl => 'Last refilled',
      CareAction.walk => 'Last walked',
      _ => 'Last done',
    };
  }

  String _reminders(CareSchedule schedule) {
    final times = schedule.reminders
        .map((slot) => '${slot.mark} ${slot.label} (${slot.clock})')
        .join(', ');
    final lead = schedule.lead;
    if (lead == null || lead.isEmpty) return times;
    if (times.isEmpty) return lead;
    return '$lead · $times';
  }

  Future<void> _remove(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return CareSheet(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 8, 22, 24 + MediaQuery.paddingOf(sheetContext).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CareSheetHandle(),
                const SizedBox(height: 8),
                Text(
                  'Remove ${subject.name}?',
                  style: GoogleFonts.fraunces(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: careInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Their photo, notes, and care schedule are removed with them.',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.onboardingBody,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: careRemove,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(
                    'Remove ${subject.name}',
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: Text(
                    'Keep them',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    if (subject.type == CareSubjectType.plant) {
      await context.read<PlantService>().deletePlant(subject.id);
    } else {
      await context.read<PetService>().deletePet(subject.id);
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CareLabel(label),
        Text(
          value,
          style: GoogleFonts.dmSans(fontSize: 14, height: 1.4, color: careInk),
        ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.subject, required this.plant});

  final CareDraft subject;
  final bool plant;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CarePhoto(url: subject.photoUrl, bytes: subject.photoBytes),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x73000000),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  plant ? '🌿 Plant' : '🐾 Pet',
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow {
  const _ScheduleRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final String icon;
  final String title;
  final String value;
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.rows});

  final List<_ScheduleRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dotIdle, width: 0.8),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: index == rows.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(color: AppColors.dotIdle, width: 0.8),
                      ),
              ),
              child: Row(
                children: [
                  Text(rows[index].icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[index].title,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: careInk,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          rows[index].value,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.onboardingBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
