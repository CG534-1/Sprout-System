import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/slot_hours.dart';
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
    this.existing,
  });

  final bool plant;
  final String name;
  final String species;
  final String breed;
  final String location;
  final String notes;
  final Uint8List? photo;
  final CareDraft? existing;
}

class CareSchedulePage extends StatefulWidget {
  const CareSchedulePage({super.key, required this.args});

  final CareScheduleArgs args;

  @override
  State<CareSchedulePage> createState() => _CareSchedulePageState();
}

class _CareSchedulePageState extends State<CareSchedulePage> {
  late final TextEditingController _everyDays;
  late final TextEditingController _bowlEveryDays;
  late final TextEditingController _walkEveryDays;
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
  var _accountClocks = SlotHours.defaults;
  final _waterClocks = <CareSlot, TimeOfDay>{};
  final _feedClocks = <CareSlot, TimeOfDay>{};
  final _bowlClocks = <CareSlot, TimeOfDay>{};
  final _walkClocks = <CareSlot, TimeOfDay>{};

  static const _leadChoices = [
    '15 min before',
    '30 min before',
    '1 hour before',
  ];

  bool get _plant => widget.args.plant;

  String get _name => widget.args.name;

  @override
  void initState() {
    super.initState();
    _everyDays = TextEditingController();
    _bowlEveryDays = TextEditingController();
    _walkEveryDays = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      _loadAccountDefaults();
    });
    final existing = widget.args.existing;
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
          _waterClocks.addAll(schedule.slotHours.times);
        case CareAction.feed:
          _feeds = schedule.timesPerDay;
          _feedTimes.addAll(schedule.reminders);
          _feedLead = schedule.lead;
          _feedClocks.addAll(schedule.slotHours.times);
        case CareAction.waterBowl:
          _bowl = true;
          _bowlFrequency = schedule.frequency;
          _bowlTimes.addAll(schedule.reminders);
          _bowlWeekdays.addAll(schedule.weekdays);
          if (schedule.everyDays != null) {
            _bowlEveryDays.text = '${schedule.everyDays}';
          }
          _bowlLead = schedule.lead;
          _bowlClocks.addAll(schedule.slotHours.times);
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
          _walkClocks.addAll(schedule.slotHours.times);
        case CareAction.mist:
        case CareAction.fertilize:
        case CareAction.groom:
          break;
      }
    }
  }

  @override
  void dispose() {
    _everyDays.dispose();
    _bowlEveryDays.dispose();
    _walkEveryDays.dispose();
    super.dispose();
  }

  Future<void> _loadAccountDefaults() async {
    try {
      final settings = await context.read<ProfileService>().settings();
      if (!mounted) return;
      setState(() {
        _accountLead = settings.lead;
        _accountClocks = settings.slotHours;
        if (widget.args.existing == null) {
          if (_plant && _waterTimes.isEmpty) {
            _waterTimes.addAll(settings.preferredSlots);
          }
          if (!_plant && _feedTimes.isEmpty) {
            _feedTimes.addAll(settings.preferredSlots);
          }
        }
      });
    } on AppException {
      // The per-schedule default just stays at 30 minutes and 9 / 1 / 6.
    }
  }

  SlotHours _clocksFor(Map<CareSlot, TimeOfDay> overrides) {
    return _accountClocks.merge(SlotHours(overrides));
  }

  Future<void> _pickClock(CareSlot slot, Map<CareSlot, TimeOfDay> overrides) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: overrides[slot] ?? _accountClocks.of(slot),
    );
    if (picked == null || !mounted) return;
    setState(() => overrides[slot] = picked);
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
    if (!(_plant ? _plantReady : _petReady)) return;
    setState(() => _saving = true);
    final args = widget.args;
    final existing = args.existing;
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
            name: args.name,
            species: args.species,
            photoUrl: args.photo == null ? existing.photoUrl : null,
            photoBytes: args.photo ?? existing.photoBytes,
            location: args.location.isEmpty ? null : args.location,
            notes: args.notes.isEmpty ? null : args.notes,
            createdAt: existing.createdAt,
          ),
        );
      } else if (existing != null) {
        id = existing.id;
        await pets.updatePet(
          Pet(
            id: id,
            name: args.name,
            species: args.species,
            breed: args.breed,
            photoUrl: args.photo == null ? existing.photoUrl : null,
            photoBytes: args.photo ?? existing.photoBytes,
            notes: args.notes.isEmpty ? null : args.notes,
            createdAt: existing.createdAt,
          ),
        );
      } else if (_plant) {
        final plant = await plants.createPlant(
          name: args.name,
          species: args.species,
          location: args.location,
          notes: args.notes,
          photoBytes: args.photo,
        );
        id = plant.id;
      } else {
        final pet = await pets.createPet(
          name: args.name,
          species: args.species,
          breed: args.breed,
          notes: args.notes,
          photoBytes: args.photo,
        );
        id = pet.id;
      }
      await care.savePlan(
        subjectId: id,
        subjectName: args.name,
        subjectType: _plant ? CareSubjectType.plant : CareSubjectType.pet,
        entries: entries,
      );
      if (!mounted) return;
      toast.show(
        existing == null
            ? '${args.name} is in your care now.'
            : "${args.name}'s care plan is saved.",
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
          lead: _waterLead ?? _accountLead,
          slotHours: SlotHours(Map.of(_waterClocks)),
        ),
      ];
    }
    final entries = <CarePlanEntry>[
      CarePlanEntry(
        action: CareAction.feed,
        frequency: CareFrequency.daily,
        timesPerDay: _feeds,
        reminders: _feedTimes.toList(),
        lead: _feedLead ?? _accountLead,
        slotHours: SlotHours(Map.of(_feedClocks)),
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
          lead: _bowlLead ?? _accountLead,
          slotHours: SlotHours(Map.of(_bowlClocks)),
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
          lead: _walkLead ?? _accountLead,
          slotHours: SlotHours(Map.of(_walkClocks)),
        ),
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _plant ? _plantReady : _petReady;
    return Focus(
      autofocus: true,
      child: Scaffold(
        backgroundColor: AppColors.onboardingPaper,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              CarePageHeader(
                title: _plant ? 'Water schedule' : 'Care plan',
                subtitle: _name,
                onBack: _saving ? null : _leave,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    20,
                    22,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  children: [...(_plant ? _plantPlan() : _petPlan())],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  0,
                  22,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  children: [
                    CareActionButton(
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
                    CareCancelButton(onPressed: _saving ? null : _leave),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _plantPlan() {
    final who = _name.isEmpty ? 'them' : _name;
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
          textInputAction: TextInputAction.done,
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
        clocks: _clocksFor(_waterClocks),
        onToggle: (slot) => setState(() {
          if (!_waterTimes.add(slot)) _waterTimes.remove(slot);
        }),
        onCustom: (slot) => _pickClock(slot, _waterClocks),
      ),
      ..._leadChips(_waterLead, (lead) => _waterLead = lead),
    ];
  }

  List<Widget> _petPlan() {
    return [
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
            clocks: _clocksFor(_feedClocks),
            onToggle: (slot) => setState(() {
              if (!_feedTimes.add(slot)) _feedTimes.remove(slot);
            }),
            onCustom: (slot) => _pickClock(slot, _feedClocks),
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
              clocks: _clocksFor(_bowlClocks),
              onToggle: (slot) => setState(() {
                if (!_bowlTimes.add(slot)) _bowlTimes.remove(slot);
              }),
              onCustom: (slot) => _pickClock(slot, _bowlClocks),
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
              clocks: _clocksFor(_walkClocks),
              onToggle: (slot) => setState(() {
                if (!_walkTimes.add(slot)) _walkTimes.remove(slot);
              }),
              onCustom: (slot) => _pickClock(slot, _walkClocks),
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
          textInputAction: TextInputAction.done,
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
