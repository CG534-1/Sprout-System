import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/photo_picker.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/pet.dart';
import 'package:sprout/data/models/plant.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/data/services/profile_service.dart';
import 'package:sprout/features/care/add_care_sheet.dart';
import 'package:sprout/features/care/care_sheet.dart';

/// Everything the first sheet collected, handed to the schedule page.
class CareScheduleArgs {
  const CareScheduleArgs({
    required this.plant,
    this.name = '',
    this.species = '',
    this.breed = '',
    this.location = '',
    this.notes = '',
    this.photo,
    this.lastWatered,
    this.lastFed,
    this.lastBowl,
    this.lastWalk,
    this.existing,
  });

  final bool plant;
  final String name;
  final String species;
  final String breed;
  final String location;
  final String notes;
  final Uint8List? photo;
  final DateTime? lastWatered;
  final DateTime? lastFed;
  final DateTime? lastBowl;
  final DateTime? lastWalk;
  final CareDraft? existing;
}

class CareSchedulePage extends StatefulWidget {
  const CareSchedulePage({super.key, required this.args});

  final CareScheduleArgs args;

  @override
  State<CareSchedulePage> createState() => _CareSchedulePageState();
}

class _CareSchedulePageState extends State<CareSchedulePage> {
  late final TextEditingController _whoName;
  late final TextEditingController _whoSpecies;
  late final TextEditingController _whoBreed;
  late final TextEditingController _whoLocation;
  late final TextEditingController _whoNotes;
  late final TextEditingController _everyDays;
  late final TextEditingController _bowlEveryDays;
  late final TextEditingController _walkEveryDays;
  var _picking = false;
  Uint8List? _photo;
  DateTime? _lastWatered;
  DateTime? _lastFed;
  DateTime? _lastBowl;
  DateTime? _lastWalk;
  var _saving = false;
  CareFrequency? _frequency;
  final _waterTimes = <CareSlot>{};
  final _weekdays = <int>{};
  int? _feeds;
  final _feedTimes = <CareSlot>{};
  var _bowl = false;
  CareFrequency? _bowlFrequency;
  final _bowlTimes = <CareSlot>{};
  final _bowlWeekdays = <int>{};
  var _walks = false;
  CareFrequency? _walkFrequency;
  int? _walksPerDay;
  final _walkTimes = <CareSlot>{};
  final _walkWeekdays = <int>{};
  String? _waterLead;
  String? _feedLead;
  String? _bowlLead;
  String? _walkLead;
  var _accountLead = '30 min before';

  static const _leadChoices = [
    '15 min before',
    '30 min before',
    '1 hour before',
  ];

  bool get _plant => widget.args.plant;

  bool get _adding => widget.args.existing == null;

  String get _name => _whoName.text.trim();

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    _whoName = TextEditingController(text: args.name);
    _whoSpecies = TextEditingController(text: args.species);
    _whoBreed = TextEditingController(text: args.breed);
    _whoLocation = TextEditingController(text: args.location);
    _whoNotes = TextEditingController(text: args.notes);
    _photo = args.photo;
    _lastWatered = args.lastWatered;
    _lastFed = args.lastFed;
    _lastBowl = args.lastBowl;
    _lastWalk = args.lastWalk;
    _everyDays = TextEditingController();
    _bowlEveryDays = TextEditingController();
    _walkEveryDays = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccountLead());
    final existing = args.existing;
    if (existing == null) return;
    for (final schedule in existing.schedules) {
      switch (schedule.action) {
        case CareAction.water:
          _frequency = schedule.frequency;
          _waterTimes.addAll(schedule.reminders);
          _weekdays.addAll(schedule.weekdays);
          if (schedule.everyDays != null) {
            _everyDays.text = '${schedule.everyDays}';
          }
          _waterLead = schedule.lead;
        case CareAction.feed:
          _feeds = schedule.timesPerDay;
          _feedTimes.addAll(schedule.reminders);
          _feedLead = schedule.lead;
        case CareAction.waterBowl:
          _bowl = true;
          _bowlFrequency = schedule.frequency;
          _bowlTimes.addAll(schedule.reminders);
          _bowlWeekdays.addAll(schedule.weekdays);
          if (schedule.everyDays != null) {
            _bowlEveryDays.text = '${schedule.everyDays}';
          }
          _bowlLead = schedule.lead;
        case CareAction.walk:
          _walks = true;
          _walkFrequency = schedule.frequency;
          _walksPerDay = schedule.timesPerDay;
          _walkTimes.addAll(schedule.reminders);
          _walkWeekdays.addAll(schedule.weekdays);
          if (schedule.everyDays != null) {
            _walkEveryDays.text = '${schedule.everyDays}';
          }
          _walkLead = schedule.lead;
        case CareAction.mist:
        case CareAction.fertilize:
        case CareAction.groom:
          break;
      }
    }
  }

  @override
  void dispose() {
    _whoName.dispose();
    _whoSpecies.dispose();
    _whoBreed.dispose();
    _whoLocation.dispose();
    _whoNotes.dispose();
    _everyDays.dispose();
    _bowlEveryDays.dispose();
    _walkEveryDays.dispose();
    super.dispose();
  }

  Future<void> _loadAccountLead() async {
    try {
      final settings = await context.read<ProfileService>().settings();
      if (!mounted) return;
      setState(() => _accountLead = settings.lead);
    } on AppException {
      // The per-schedule default just stays at 30 minutes.
    }
  }

  int? get _customDays => int.tryParse(_everyDays.text.trim());

  bool get _plantReady {
    if (_frequency == null || _waterTimes.isEmpty) return false;
    if (_frequency == CareFrequency.custom) {
      final days = _customDays;
      if (days == null || days < 1) return false;
    }
    if (_frequency == CareFrequency.setDays && _weekdays.isEmpty) return false;
    return true;
  }

  bool get _petReady {
    final feeding = _feeds != null && _feedTimes.isNotEmpty;
    final bowl =
        !_bowl ||
        _cadenceReady(
          _bowlFrequency,
          _bowlEveryDays,
          _bowlWeekdays,
          _bowlTimes,
          false,
        );
    final walking =
        !_walks ||
        _cadenceReady(
          _walkFrequency,
          _walkEveryDays,
          _walkWeekdays,
          _walkTimes,
          true,
        );
    return feeding && bowl && walking;
  }

  bool _cadenceReady(
    CareFrequency? frequency,
    TextEditingController days,
    Set<int> weekdays,
    Set<CareSlot> times,
    bool needsCount,
  ) {
    if (frequency == null || times.isEmpty) return false;
    if (needsCount && _walksPerDay == null) return false;
    if (frequency == CareFrequency.custom) {
      final count = int.tryParse(days.text.trim());
      if (count == null || count < 1) return false;
    }
    if (frequency == CareFrequency.setDays && weekdays.isEmpty) return false;
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.isEmpty) return;
    if (!(_plant ? _plantReady : _petReady)) return;
    setState(() => _saving = true);
    final existing = widget.args.existing;
    final species = _whoSpecies.text.trim();
    final breed = _whoBreed.text.trim();
    final location = _whoLocation.text.trim();
    final notes = _whoNotes.text.trim();
    final entries = _entries();
    final plants = context.read<PlantService>();
    final pets = context.read<PetService>();
    final care = context.read<CareService>();
    final toast = sproutToaster(context);
    try {
      final String id;
      if (existing != null && _plant) {
        id = existing.id;
        await plants.updatePlant(
          Plant(
            id: id,
            name: _name,
            species: species,
            photoUrl: _photo == null ? existing.photoUrl : null,
            photoBytes: _photo ?? existing.photoBytes,
            location: location.isEmpty ? null : location,
            notes: notes.isEmpty ? null : notes,
            createdAt: existing.createdAt,
          ),
        );
      } else if (existing != null) {
        id = existing.id;
        await pets.updatePet(
          Pet(
            id: id,
            name: _name,
            species: species,
            breed: breed,
            photoUrl: _photo == null ? existing.photoUrl : null,
            photoBytes: _photo ?? existing.photoBytes,
            notes: notes.isEmpty ? null : notes,
            createdAt: existing.createdAt,
          ),
        );
      } else if (_plant) {
        final plant = await plants.createPlant(
          name: _name,
          species: species,
          location: location,
          notes: notes,
          photoBytes: _photo,
        );
        id = plant.id;
      } else {
        final pet = await pets.createPet(
          name: _name,
          species: species,
          breed: breed,
          notes: notes,
          photoBytes: _photo,
        );
        id = pet.id;
      }
      await care.savePlan(
        subjectId: id,
        subjectName: _name,
        subjectType: _plant ? CareSubjectType.plant : CareSubjectType.pet,
        entries: entries,
      );
      if (!mounted) return;
      toast.show(
        existing == null
            ? '$_name is in your care now.'
            : "$_name's care plan is saved.",
      );
      _leave();
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      toast.show(error.message, error: true);
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.myCare);
  }

  List<CarePlanEntry> _entries() {
    if (_plant) {
      return [
        CarePlanEntry(
          action: CareAction.water,
          frequency: _frequency!,
          reminders: _waterTimes.toList(),
          everyDays: _frequency == CareFrequency.custom ? _customDays : null,
          weekdays: _frequency == CareFrequency.setDays
              ? (_weekdays.toList()..sort())
              : const [],
          lastDone: _lastWatered,
          lead: _waterLead ?? _accountLead,
        ),
      ];
    }
    final entries = <CarePlanEntry>[
      CarePlanEntry(
        action: CareAction.feed,
        frequency: CareFrequency.daily,
        timesPerDay: _feeds,
        reminders: _feedTimes.toList(),
        lastDone: _lastFed,
        lead: _feedLead ?? _accountLead,
      ),
    ];
    if (_bowl && _bowlFrequency != null && _bowlTimes.isNotEmpty) {
      entries.add(
        CarePlanEntry(
          action: CareAction.waterBowl,
          frequency: _bowlFrequency!,
          reminders: _bowlTimes.toList(),
          everyDays: _bowlFrequency == CareFrequency.custom
              ? int.tryParse(_bowlEveryDays.text.trim())
              : null,
          weekdays: _bowlFrequency == CareFrequency.setDays
              ? (_bowlWeekdays.toList()..sort())
              : const [],
          lastDone: _lastBowl,
          lead: _bowlLead ?? _accountLead,
        ),
      );
    }
    if (_walks && _walkFrequency != null && _walksPerDay != null) {
      entries.add(
        CarePlanEntry(
          action: CareAction.walk,
          frequency: _walkFrequency!,
          timesPerDay: _walksPerDay,
          reminders: _walkTimes.toList(),
          everyDays: _walkFrequency == CareFrequency.custom
              ? int.tryParse(_walkEveryDays.text.trim())
              : null,
          weekdays: _walkFrequency == CareFrequency.setDays
              ? (_walkWeekdays.toList()..sort())
              : const [],
          lastDone: _lastWalk,
          lead: _walkLead ?? _accountLead,
        ),
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _name.isNotEmpty && (_plant ? _plantReady : _petReady);
    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            CarePageHeader(
              title: _adding
                  ? (_plant ? 'Add a plant' : 'Add a pet')
                  : (_plant ? 'Water schedule' : 'Care plan'),
              subtitle: _adding ? '' : _name,
              onBack: _saving ? null : _leave,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  6,
                  22,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  if (_adding) ..._whoFields(),
                  ...(_plant ? _plantPlan() : _petPlan()),
                ],
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
                label: _saving
                    ? 'Saving'
                    : widget.args.existing == null
                    ? 'Add $_name ${_plant ? '🌿' : '🐾'}'
                    : 'Save $_name ${_plant ? '🌿' : '🐾'}',
                enabled: ready && !_saving,
                busy: _saving,
                top: 10,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _whoFields() {
    final plant = _plant;
    final existing = widget.args.existing;
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
                    : _photo != null || existing?.photoUrl != null
                    ? CarePhoto(
                        url: _photo == null ? existing?.photoUrl : null,
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
                  : _photo == null && existing?.photoUrl == null
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
        controller: _whoName,
        hint: plant ? 'e.g. Monstera, Snake Plant…' : 'e.g. Milo',
        onChanged: (_) => setState(() {}),
      ),
      CareLabel(plant ? 'SPECIES (OPTIONAL)' : 'PET TYPE (OPTIONAL)'),
      CareNameField(
        controller: _whoSpecies,
        hint: plant ? 'e.g. Monstera deliciosa' : 'e.g. Dog',
        onChanged: (_) => setState(() {}),
      ),
      if (!plant) ...[
        const CareLabel('BREED (OPTIONAL)'),
        CareNameField(
          controller: _whoBreed,
          hint: 'e.g. Golden Retriever',
          onChanged: (_) => setState(() {}),
        ),
      ],
      if (plant) ...[
        const CareLabel('WHERE IT LIVES'),
        CareNameField(
          controller: _whoLocation,
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
        controller: _whoNotes,
        hint: 'Anything worth remembering',
        maxLines: 3,
        onChanged: (_) => setState(() {}),
      ),
    ];
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

  List<Widget> _plantPlan() {
    final who = _name.isEmpty ? 'them' : _name;
    return [
      CareLabel(
        'HOW OFTEN DOES ${who.toUpperCase()} NEED WATER?',
        top: _adding ? 22 : 0,
      ),
      Wrap(
        spacing: 7,
        runSpacing: 8,
        children: [
          for (final frequency in CareFrequency.values)
            CareChip(
              label: frequency.chip,
              selected: _frequency == frequency,
              onTap: () => setState(() => _frequency = frequency),
            ),
        ],
      ),
      if (_frequency == CareFrequency.custom) ...[
        const CareLabel('EVERY HOW MANY DAYS?'),
        CareNameField(
          controller: _everyDays,
          hint: 'e.g. 4',
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
      ],
      if (_frequency == CareFrequency.setDays) ...[
        const CareLabel('WHICH DAYS?'),
        Wrap(
          spacing: 7,
          runSpacing: 8,
          children: [
            for (final day in [1, 2, 3, 4, 5, 6, 7])
              CareChip(
                label: const [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ][day - 1],
                selected: _weekdays.contains(day),
                onTap: () => setState(() {
                  if (!_weekdays.add(day)) _weekdays.remove(day);
                }),
              ),
          ],
        ),
      ],
      const CareLabel('REMIND ME AT (select all that apply)'),
      CareSlots(
        selected: _waterTimes,
        onToggle: (slot) => setState(() {
          if (!_waterTimes.add(slot)) _waterTimes.remove(slot);
        }),
      ),
      ..._leadChips(_waterLead, (lead) => _waterLead = lead),
    ];
  }

  List<Widget> _petPlan() {
    return [
      if (_adding) const SizedBox(height: 22),
      _PlanCard(
        title: 'Feeding',
        children: [
          _CardNote('How many times a day?'),
          const SizedBox(height: 8),
          _CountRow(
            selected: _feeds,
            onSelected: (value) => setState(() => _feeds = value),
          ),
          const SizedBox(height: 10),
          _CardNote('Remind me at (multi-select)'),
          const SizedBox(height: 8),
          CareSlots(
            selected: _feedTimes,
            onToggle: (slot) => setState(() {
              if (!_feedTimes.add(slot)) _feedTimes.remove(slot);
            }),
          ),
          ..._leadChips(_feedLead, (lead) => _feedLead = lead),
        ],
      ),
      const SizedBox(height: 12),
      _PlanCard(
        title: 'Water bowl',
        trailing: _WalkSwitch(
          on: _bowl,
          onChanged: (value) => setState(() {
            _bowl = value;
            _bowlFrequency ??= CareFrequency.daily;
          }),
        ),
        children: [
          if (_bowl) ...[
            ..._cadence(
              frequency: _bowlFrequency,
              onPick: (value) => _bowlFrequency = value,
              days: _bowlEveryDays,
              weekdays: _bowlWeekdays,
            ),
            _CardNote('When should I remind you to refill it?'),
            const SizedBox(height: 8),
            CareSlots(
              selected: _bowlTimes,
              onToggle: (slot) => setState(() {
                if (!_bowlTimes.add(slot)) _bowlTimes.remove(slot);
              }),
            ),
            ..._leadChips(_bowlLead, (lead) => _bowlLead = lead),
          ],
        ],
      ),
      const SizedBox(height: 12),
      _PlanCard(
        title: 'Walks',
        trailing: _WalkSwitch(
          on: _walks,
          onChanged: (value) => setState(() {
            _walks = value;
            _walkFrequency ??= CareFrequency.daily;
          }),
        ),
        children: [
          if (_walks) ...[
            ..._cadence(
              frequency: _walkFrequency,
              onPick: (value) => _walkFrequency = value,
              days: _walkEveryDays,
              weekdays: _walkWeekdays,
            ),
            _CardNote('How many walks on those days?'),
            const SizedBox(height: 8),
            _CountRow(
              selected: _walksPerDay,
              onSelected: (value) => setState(() => _walksPerDay = value),
            ),
            const SizedBox(height: 10),
            _CardNote('Remind me at (multi-select)'),
            const SizedBox(height: 8),
            CareSlots(
              selected: _walkTimes,
              onToggle: (slot) => setState(() {
                if (!_walkTimes.add(slot)) _walkTimes.remove(slot);
              }),
            ),
            ..._leadChips(_walkLead, (lead) => _walkLead = lead),
          ],
        ],
      ),
    ];
  }

  List<Widget> _leadChips(String? selected, ValueChanged<String> onPick) {
    final current = selected ?? _accountLead;
    return [
      const SizedBox(height: 10),
      _CardNote('How far in advance?'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final lead in _leadChoices)
            CareChip(
              label: lead,
              selected: current == lead,
              onTap: () => setState(() => onPick(lead)),
            ),
        ],
      ),
    ];
  }

  List<Widget> _cadence({
    required CareFrequency? frequency,
    required ValueChanged<CareFrequency> onPick,
    required TextEditingController days,
    required Set<int> weekdays,
  }) {
    return [
      _CardNote('How often?'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        runSpacing: 8,
        children: [
          for (final item in CareFrequency.values)
            CareChip(
              label: item.chip,
              selected: frequency == item,
              onTap: () => setState(() => onPick(item)),
            ),
        ],
      ),
      if (frequency == CareFrequency.custom) ...[
        const SizedBox(height: 10),
        CareNameField(
          controller: days,
          hint: 'e.g. 4',
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
      ],
      if (frequency == CareFrequency.setDays) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 8,
          children: [
            for (final day in [1, 2, 3, 4, 5, 6, 7])
              CareChip(
                label: const [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ][day - 1],
                selected: weekdays.contains(day),
                onTap: () => setState(() {
                  if (!weekdays.add(day)) weekdays.remove(day);
                }),
              ),
          ],
        ),
      ],
      const SizedBox(height: 10),
    ];
  }
}

class _CardNote extends StatelessWidget {
  const _CardNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF4C7259)),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final count in [1, 2, 3])
          CareChip(
            label: '${count}x / day',
            selected: selected == count,
            onTap: () => onSelected(count),
          ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC6E5CC), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: careInk,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          if (children.isNotEmpty) ...[const SizedBox(height: 6), ...children],
        ],
      ),
    );
  }
}

class _WalkSwitch extends StatelessWidget {
  const _WalkSwitch({required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF179C46) : const Color(0xFFC6E5CC),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
