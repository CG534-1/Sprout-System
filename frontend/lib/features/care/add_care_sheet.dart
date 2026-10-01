import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/photo_picker.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/features/care/care_schedule_page.dart';
import 'package:sprout/features/care/care_sheet.dart';

class CareDraft {
  const CareDraft({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.species = '',
    this.breed = '',
    this.photoUrl,
    this.photoBytes,
    this.location,
    this.notes,
    this.schedules = const [],
  });

  final String id;
  final String name;
  final CareSubjectType type;
  final DateTime createdAt;
  final String species;
  final String breed;
  final String? photoUrl;
  final Uint8List? photoBytes;
  final String? location;
  final String? notes;
  final List<CareSchedule> schedules;
}

/// Who the details page is for: a new plant or pet, or someone already in
/// your care.
class CareDetailsArgs {
  const CareDetailsArgs({required this.plant, this.existing});

  final bool plant;
  final CareDraft? existing;
}

/// Asks only whether this is a plant or a pet. The fields and the plan are
/// long, so they each get a page of their own after this.
Future<void> showAddCareSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _KindSheet(),
  );
}

class _KindSheet extends StatefulWidget {
  const _KindSheet();

  @override
  State<_KindSheet> createState() => _KindSheetState();
}

class _KindSheetState extends State<_KindSheet> {
  var _plant = true;

  void _next() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(AppRoutes.schedule, extra: CareScheduleArgs(plant: _plant));
  }

  @override
  Widget build(BuildContext context) {
    return CareSheet(
      child: ListView(
        shrinkWrap: true,
        children: [
          const CareSheetHandle(),
          const CareSheetHeader(title: 'Add to your care'),
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
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CareChoice(
                        emoji: '🌿',
                        title: 'Plant',
                        subtitle: 'Watering reminders & schedule',
                        selected: _plant,
                        onTap: () => setState(() => _plant = true),
                      ),
                      const SizedBox(width: 10),
                      CareChoice(
                        emoji: '🐾',
                        title: 'Pet',
                        subtitle: 'Feeding, water bowl & walks',
                        selected: !_plant,
                        onTap: () => setState(() => _plant = false),
                      ),
                    ],
                  ),
                ),
                CareActionButton(
                  label: 'Next',
                  enabled: true,
                  onPressed: _next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The name, photo and notes, for a new plant or pet or for one already in
/// your care. A page rather than a sheet, because there is a lot to fill in
/// and the plan still has to follow.
class CareDetailsPage extends StatefulWidget {
  const CareDetailsPage({super.key, required this.args});

  final CareDetailsArgs args;

  @override
  State<CareDetailsPage> createState() => _CareDetailsPageState();
}

class _CareDetailsPageState extends State<CareDetailsPage> {
  late final TextEditingController _name;
  late final TextEditingController _species;
  late final TextEditingController _breed;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  var _picking = false;
  Uint8List? _photo;
  DateTime? _lastWatered;
  DateTime? _lastFed;
  DateTime? _lastBowl;
  DateTime? _lastWalk;

  CareDraft? get _existing => widget.args.existing;

  bool get _plant => widget.args.plant;

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _species = TextEditingController(text: existing?.species ?? '');
    _breed = TextEditingController(text: existing?.breed ?? '');
    _location = TextEditingController(text: existing?.location ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _photo = existing?.photoBytes;
    if (existing == null) return;
    for (final schedule in existing.schedules) {
      switch (schedule.action) {
        case CareAction.water:
          _lastWatered = schedule.lastDone;
        case CareAction.feed:
          _lastFed = schedule.lastDone;
        case CareAction.waterBowl:
          _lastBowl = schedule.lastDone;
        case CareAction.walk:
          _lastWalk = schedule.lastDone;
        case CareAction.mist:
        case CareAction.fertilize:
        case CareAction.groom:
          break;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _species.dispose();
    _breed.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _named => _name.text.trim().isNotEmpty;

  void _leave() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.myCare);
  }

  /// Hands over to the plan, which is a page of its own because pet plans are
  /// long. This step is left behind, so a back from the plan lands on My care
  /// rather than halfway through the form.
  void _openSchedule() {
    if (!_named) return;
    final args = CareScheduleArgs(
      plant: _plant,
      name: _name.text.trim(),
      species: _species.text.trim(),
      breed: _breed.text.trim(),
      location: _location.text.trim(),
      notes: _notes.text.trim(),
      photo: _photo,
      lastWatered: _lastWatered,
      lastFed: _lastFed,
      lastBowl: _lastBowl,
      lastWalk: _lastWalk,
      existing: _existing,
    );
    final router = GoRouter.of(context);
    if (router.canPop()) router.pop();
    router.push(AppRoutes.schedule, extra: args);
  }

  Future<void> _pickDate(
    DateTime? current,
    void Function(DateTime date) assign,
  ) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final initial = current == null
        ? day
        : DateTime(current.year, current.month, current.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(day) ? day : initial,
      firstDate: day.subtract(const Duration(days: 365)),
      lastDate: day,
    );
    if (picked == null || !mounted) return;
    setState(() => assign(DateTime(picked.year, picked.month, picked.day)));
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final bytes = await pickCarePhoto();
      if (!mounted) return;
      setState(() {
        _picking = false;
        if (bytes != null) _photo = bytes;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _picking = false);
      showSproutToast(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            CarePageHeader(
              title: existing != null
                  ? 'Edit details'
                  : _plant
                  ? 'Add a plant'
                  : 'Add a pet',
              subtitle: existing?.name ?? '',
              onBack: _leave,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  6,
                  22,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: _nameFields(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                0,
                22,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: CareActionButton(
                label: 'Set up care schedule →',
                enabled: _named,
                top: 10,
                onPressed: _openSchedule,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _nameFields() {
    final plant = _plant;
    return [
      const CareLabel('PHOTO', top: 18),
      GestureDetector(
        onTap: _pickPhoto,
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: _picking
                    ? ColoredBox(
                        color: careField,
                        child: const Center(
                          child: SproutSpinner(color: AppColors.sproutGreen),
                        ),
                      )
                    : _photo != null || _existing?.photoUrl != null
                    ? CarePhoto(
                        url: _photo == null ? _existing?.photoUrl : null,
                        bytes: _photo,
                      )
                    : ColoredBox(
                        color: careField,
                        child: Center(
                          child: Text(
                            plant ? '🌿' : '🐾',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _picking
                  ? 'Opening your photos'
                  : _photo == null && _existing?.photoUrl == null
                  ? 'Add a photo'
                  : 'Change photo',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF006134),
              ),
            ),
          ],
        ),
      ),
      CareLabel(plant ? 'PLANT NAME' : 'PET NAME'),
      CareNameField(
        controller: _name,
        hint: plant ? 'e.g. Monstera, Snake Plant…' : 'e.g. Milo',
        onChanged: (_) => setState(() {}),
      ),
      CareLabel(plant ? 'SPECIES (OPTIONAL)' : 'PET TYPE (OPTIONAL)'),
      CareNameField(
        controller: _species,
        hint: plant ? 'e.g. Monstera deliciosa' : 'e.g. Dog',
        onChanged: (_) => setState(() {}),
      ),
      if (!plant) ...[
        const CareLabel('BREED (OPTIONAL)'),
        CareNameField(
          controller: _breed,
          hint: 'e.g. Golden Retriever',
          onChanged: (_) => setState(() {}),
        ),
      ],
      if (plant) ...[
        const CareLabel('WHERE IT LIVES'),
        CareNameField(
          controller: _location,
          hint: 'e.g. Living room',
          onChanged: (_) => setState(() {}),
        ),
        const CareLabel('WHEN LAST WATERED (OPTIONAL)'),
        CareWhenField(
          value: _lastWatered,
          onTap: () => _pickDate(_lastWatered, (date) => _lastWatered = date),
        ),
      ] else ...[
        const CareLabel('WHEN LAST FED (OPTIONAL)'),
        CareWhenField(
          value: _lastFed,
          onTap: () => _pickDate(_lastFed, (date) => _lastFed = date),
        ),
        const CareLabel('WHEN WAS THE WATER BOWL LAST REFILLED (OPTIONAL)'),
        CareWhenField(
          value: _lastBowl,
          onTap: () => _pickDate(_lastBowl, (date) => _lastBowl = date),
        ),
        const CareLabel('WHEN LAST WALKED (OPTIONAL)'),
        CareWhenField(
          value: _lastWalk,
          onTap: () => _pickDate(_lastWalk, (date) => _lastWalk = date),
        ),
      ],
      const CareLabel('NOTES'),
      CareNameField(
        controller: _notes,
        hint: 'Anything worth remembering',
        maxLines: 3,
        onChanged: (_) => setState(() {}),
      ),
    ];
  }
}

class CareWhenField extends StatelessWidget {
  const CareWhenField({super.key, required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: careField,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.dotIdle, width: 0.8),
        ),
        child: Text(
          picked ? DateFormat('MMM d, y').format(value!) : 'Pick a date',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: picked ? careInk : AppColors.onboardingBody,
          ),
        ),
      ),
    );
  }
}
