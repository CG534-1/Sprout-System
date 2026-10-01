import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/pet.dart';
import 'package:sprout/data/models/plant.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/data/services/profile_service.dart';
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

Future<void> showAddCareSheet(BuildContext context, {CareDraft? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddCareSheet(existing: existing),
  );
}

enum _Kind { plant, pet }

class _AddCareSheet extends StatefulWidget {
  const _AddCareSheet({this.existing});

  final CareDraft? existing;

  @override
  State<_AddCareSheet> createState() => _AddCareSheetState();
}

class _AddCareSheetState extends State<_AddCareSheet> {
  late final TextEditingController _name;
  late final TextEditingController _species;
  late final TextEditingController _breed;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late final TextEditingController _everyDays;
  late final TextEditingController _bowlEveryDays;
  late final TextEditingController _walkEveryDays;
  late _Kind _kind;
  var _plan = false;
  var _saving = false;
  Uint8List? _photo;
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
  DateTime? _lastWatered;
  DateTime? _lastFed;
  DateTime? _lastBowl;
  DateTime? _lastWalk;
  String? _waterLead;
  String? _feedLead;
  String? _bowlLead;
  String? _walkLead;
  var _accountLead = '30 min before';

  static const _leadChoices = ['15 min before', '30 min before', '1 hour before'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _species = TextEditingController(text: existing?.species ?? '');
    _breed = TextEditingController(text: existing?.breed ?? '');
    _location = TextEditingController(text: existing?.location ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _everyDays = TextEditingController();
    _bowlEveryDays = TextEditingController();
    _walkEveryDays = TextEditingController();
    _photo = existing?.photoBytes;
    _kind = existing?.type == CareSubjectType.pet ? _Kind.pet : _Kind.plant;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccountLead());
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
          _lastWatered = schedule.lastDone;
          _waterLead = schedule.lead;
        case CareAction.feed:
          _feeds = schedule.timesPerDay;
          _feedTimes.addAll(schedule.reminders);
          _lastFed = schedule.lastDone;
          _feedLead = schedule.lead;
        case CareAction.waterBowl:
          _bowl = true;
          _bowlFrequency = schedule.frequency;
          _bowlTimes.addAll(schedule.reminders);
          _bowlWeekdays.addAll(schedule.weekdays);
          if (schedule.everyDays != null) {
            _bowlEveryDays.text = '${schedule.everyDays}';
          }
          _lastBowl = schedule.lastDone;
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
          _lastWalk = schedule.lastDone;
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
    _name.dispose();
    _species.dispose();
    _breed.dispose();
    _location.dispose();
    _notes.dispose();
    _everyDays.dispose();
    _bowlEveryDays.dispose();
    _walkEveryDays.dispose();
    super.dispose();
  }

  Future<void> _loadAccountLead() async {
    final settings = await context.read<ProfileService>().settings();
    if (!mounted) return;
    setState(() => _accountLead = settings.lead);
  }

  List<Widget> _leadChips(String? selected, ValueChanged<String> onPick) {
    final current = selected ?? _accountLead;
    return [
      const SizedBox(height: 10),
      Text(
        'How far in advance?',
        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF4C7259)),
      ),
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

  bool get _named => _name.text.trim().isNotEmpty;

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
    final bowl = !_bowl || _cadenceReady(_bowlFrequency, _bowlEveryDays, _bowlWeekdays, _bowlTimes, false);
    final walking = !_walks || _cadenceReady(_walkFrequency, _walkEveryDays, _walkWeekdays, _walkTimes, true);
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
    final ready = _kind == _Kind.plant ? _plantReady : _petReady;
    if (!ready) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final species = _species.text.trim();
    final breed = _breed.text.trim();
    final location = _location.text.trim();
    final notes = _notes.text.trim();
    try {
      final existing = widget.existing;
      final String id;
      if (existing != null && _kind == _Kind.plant) {
        id = existing.id;
        await context.read<PlantService>().updatePlant(
          Plant(
            id: id,
            name: name,
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
        await context.read<PetService>().updatePet(
          Pet(
            id: id,
            name: name,
            species: species,
            breed: breed,
            photoUrl: _photo == null ? existing.photoUrl : null,
            photoBytes: _photo ?? existing.photoBytes,
            notes: notes.isEmpty ? null : notes,
            createdAt: existing.createdAt,
          ),
        );
      } else if (_kind == _Kind.plant) {
        final plant = await context.read<PlantService>().createPlant(
          name: name,
          species: species,
          location: location,
          notes: notes,
          photoBytes: _photo,
        );
        id = plant.id;
      } else {
        final pet = await context.read<PetService>().createPet(
          name: name,
          species: species,
          breed: breed,
          notes: notes,
          photoBytes: _photo,
        );
        id = pet.id;
      }
      if (!mounted) return;
      await context.read<CareService>().savePlan(
        subjectId: id,
        subjectName: name,
        subjectType: _kind == _Kind.plant
            ? CareSubjectType.plant
            : CareSubjectType.pet,
        entries: _entries(),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<CarePlanEntry> _entries() {
    if (_kind == _Kind.plant) {
      return [
        CarePlanEntry(
          action: CareAction.water,
          frequency: _frequency!,
          reminders: _waterTimes.toList(),
          everyDays: _frequency == CareFrequency.custom ? _customDays : null,
          weekdays: _frequency == CareFrequency.setDays ? (_weekdays.toList()..sort()) : const [],
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

  Future<void> _pickDate(DateTime? current, void Function(DateTime date) assign) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final initial = current == null ? day : DateTime(current.year, current.month, current.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(day) ? day : initial,
      firstDate: day.subtract(const Duration(days: 365)),
      lastDate: day,
    );
    if (picked == null || !mounted) return;
    setState(() => assign(DateTime(picked.year, picked.month, picked.day)));
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    final title = !_plan
        ? 'Add to your care'
        : _kind == _Kind.plant
        ? 'Water schedule for $name'
        : 'Care plan for $name';
    return CareSheet(
      child: ListView(
        shrinkWrap: true,
        children: [
          const CareSheetHandle(),
          CareSheetHeader(
            title: title,
            onBack: _plan ? () => setState(() => _plan = false) : null,
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
              children: _plan ? _planFields(name) : _nameFields(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photo = bytes);
  }

  List<Widget> _nameFields() {
    final plant = _kind == _Kind.plant;
    final editing = widget.existing != null;
    return [
      if (!editing)
        IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CareChoice(
              emoji: '🌿',
              title: 'Plant',
              subtitle: 'Watering reminders & schedule',
              selected: plant,
              onTap: () => setState(() => _kind = _Kind.plant),
            ),
            const SizedBox(width: 10),
            CareChoice(
              emoji: '🐾',
              title: 'Pet',
              subtitle: 'Feeding, water bowl & walks',
              selected: !plant,
              onTap: () => setState(() => _kind = _Kind.pet),
            ),
          ],
        ),
        ),
      const CareLabel('PHOTO', top: 18),
      GestureDetector(
        onTap: _pickPhoto,
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: _photo != null || widget.existing?.photoUrl != null
                    ? CarePhoto(
                        url: _photo == null ? widget.existing?.photoUrl : null,
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
              _photo == null && widget.existing?.photoUrl == null
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
        _WhenField(
          value: _lastWatered,
          onTap: () => _pickDate(_lastWatered, (date) => _lastWatered = date),
        ),
      ] else ...[
        const CareLabel('WHEN LAST FED (OPTIONAL)'),
        _WhenField(
          value: _lastFed,
          onTap: () => _pickDate(_lastFed, (date) => _lastFed = date),
        ),
        const CareLabel('WHEN WAS THE WATER BOWL LAST REFILLED (OPTIONAL)'),
        _WhenField(
          value: _lastBowl,
          onTap: () => _pickDate(_lastBowl, (date) => _lastBowl = date),
        ),
        const CareLabel('WHEN LAST WALKED (OPTIONAL)'),
        _WhenField(
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
      CareActionButton(
        label: 'Set up care schedule →',
        enabled: _named,
        onPressed: () => setState(() => _plan = true),
      ),
    ];
  }

  List<Widget> _planFields(String name) {
    if (_kind == _Kind.plant) return _plantPlan(name);
    return _petPlan(name);
  }

  List<Widget> _plantPlan(String name) {
    final who = name.isEmpty ? 'them' : name;
    return [
      CareLabel('HOW OFTEN DOES ${who.toUpperCase()} NEED WATER?', top: 0),
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
                label: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1],
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
      CareActionButton(
        label: widget.existing == null ? 'Add $name 🌿' : 'Save $name 🌿',
        enabled: _plantReady && !_saving,
        onPressed: _save,
      ),
    ];
  }

  List<Widget> _petPlan(String name) {
    return [
      _PlanCard(
        title: 'Feeding',
        children: [
          Text(
            'How many times a day?',
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF4C7259)),
          ),
          const SizedBox(height: 8),
          _CountRow(
            selected: _feeds,
            onSelected: (value) => setState(() => _feeds = value),
          ),
          const SizedBox(height: 10),
          Text(
            'Remind me at (multi-select)',
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF4C7259)),
          ),
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
            Text(
              'When should I remind you to refill it?',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF4C7259)),
            ),
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
            Text(
              'How many walks on those days?',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF4C7259)),
            ),
            const SizedBox(height: 8),
            _CountRow(
              selected: _walksPerDay,
              onSelected: (value) => setState(() => _walksPerDay = value),
            ),
            const SizedBox(height: 10),
            Text(
              'Remind me at (multi-select)',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF4C7259)),
            ),
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
      CareActionButton(
        label: widget.existing == null ? 'Add $name 🐾' : 'Save $name 🐾',
        enabled: _petReady && !_saving,
        onPressed: _save,
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
      Text(
        'How often?',
        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF4C7259)),
      ),
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
                label: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1],
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
  const _PlanCard({
    required this.title,
    required this.children,
    this.trailing,
  });

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
          if (children.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...children,
          ],
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

class _WhenField extends StatelessWidget {
  const _WhenField({required this.value, required this.onTap});

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
