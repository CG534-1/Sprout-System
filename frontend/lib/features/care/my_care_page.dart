import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/pet.dart';
import 'package:sprout/data/models/plant.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/features/care/add_care_sheet.dart';
import 'package:sprout/features/care/care_detail_sheet.dart';
import 'package:sprout/features/care/care_sheet.dart';
import 'package:sprout/features/shell/care_nav.dart';
import 'package:sprout/features/shell/quiet_card.dart';

enum _Filter { all, plants, pets }

class MyCarePage extends StatefulWidget {
  const MyCarePage({super.key});

  @override
  State<MyCarePage> createState() => _MyCarePageState();
}

class _MyCarePageState extends State<MyCarePage> {
  var _filter = _Filter.all;
  var _loading = true;
  List<_Member> _members = [];
  PlantService? _plants;
  PetService? _pets;
  CareService? _care;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _plants = context.read<PlantService>()..addListener(_load);
      _pets = context.read<PetService>()..addListener(_load);
      _care = context.read<CareService>()..addListener(_load);
      _load();
    });
  }

  @override
  void dispose() {
    _plants?.removeListener(_load);
    _pets?.removeListener(_load);
    _care?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final plants = _plants;
    final pets = _pets;
    final care = _care;
    if (plants == null || pets == null || care == null) return;
    final bundled = await (plants.listPlants(), pets.listPets(), care.schedules()).wait;
    if (!mounted) return;
    final schedules = bundled.$3;
    final members = <_Member>[
      for (final plant in bundled.$1)
        _Member.plant(
          plant,
          schedules.where((item) => item.subjectId == plant.id).toList(),
        ),
      for (final pet in bundled.$2)
        _Member.pet(
          pet,
          schedules.where((item) => item.subjectId == pet.id).toList(),
        ),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  List<_Member> get _visible {
    return switch (_filter) {
      _Filter.all => _members,
      _Filter.plants =>
        _members.where((item) => item.type == CareSubjectType.plant).toList(),
      _Filter.pets =>
        _members.where((item) => item.type == CareSubjectType.pet).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR LITTLE FAMILY',
                            style: GoogleFonts.dmMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.9,
                              color: AppColors.sproutGreen,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'My care',
                            style: GoogleFonts.fraunces(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.6,
                              color: careInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      key: const Key('add-care'),
                      onTap: () => showAddCareSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.sproutGreen,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.splashTop,
                              offset: Offset(3, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '＋ Add',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_members.isNotEmpty) ...[
                  Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filter == _Filter.all,
                        onTap: () => setState(() => _filter = _Filter.all),
                      ),
                      const SizedBox(width: 7),
                      _FilterChip(
                        label: 'Plants',
                        selected: _filter == _Filter.plants,
                        onTap: () => setState(() => _filter = _Filter.plants),
                      ),
                      const SizedBox(width: 7),
                      _FilterChip(
                        label: 'Pets',
                        selected: _filter == _Filter.pets,
                        onTap: () => setState(() => _filter = _Filter.pets),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                if (_loading)
                  const SizedBox(height: 120)
                else if (_members.isEmpty)
                  QuietCard(
                    icon: Icons.yard_outlined,
                    title: 'No one to care for yet',
                    body: 'Add a plant or a pet. You can set their routine when you are ready.',
                    action: 'Add someone',
                    onAction: () => showAddCareSheet(context),
                  )
                else if (visible.isEmpty)
                  QuietCard(
                    icon: _filter == _Filter.pets ? Icons.pets_outlined : Icons.spa_outlined,
                    title: _filter == _Filter.pets ? 'No pets yet' : 'No plants yet',
                    body: 'This filter is empty. The rest of your home is still on All.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visible.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 208,
                    ),
                    itemBuilder: (context, index) => _Card(member: visible[index]),
                  ),
              ],
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CareNav(tab: CareTab.care),
            ),
          ],
        ),
      ),
    );
  }
}

class _Member {
  _Member({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.line,
    required this.schedules,
    this.species = '',
    this.breed = '',
    this.photoUrl,
    this.photoBytes,
    this.location,
    this.notes,
  });

  factory _Member.plant(Plant plant, List<CareSchedule> schedules) {
    final water = schedules.where((item) => item.action == CareAction.water);
    final line = water.isEmpty ? '' : _plantLine(water.first);
    return _Member(
      id: plant.id,
      name: plant.name,
      type: CareSubjectType.plant,
      species: plant.species,
      photoUrl: plant.photoUrl,
      photoBytes: plant.photoBytes,
      location: plant.location,
      notes: plant.notes,
      createdAt: plant.createdAt,
      line: line,
      schedules: schedules,
    );
  }

  factory _Member.pet(Pet pet, List<CareSchedule> schedules) {
    final parts = <String>[];
    for (final schedule in schedules) {
      final times = schedule.timesPerDay;
      if (schedule.action == CareAction.feed && times != null) {
        parts.add('Feed ${times}x/day');
      }
      if (schedule.action == CareAction.waterBowl) {
        parts.add(schedule.frequency == CareFrequency.daily ? 'Water bowl' : 'Water bowl · ${schedule.whenLabel}');
      }
      if (schedule.action == CareAction.walk && times != null) {
        parts.add(
          schedule.frequency == CareFrequency.daily
              ? 'Walk ${times}x/day'
              : 'Walk ${times}x · ${schedule.whenLabel}',
        );
      }
    }
    return _Member(
      id: pet.id,
      name: pet.name,
      type: CareSubjectType.pet,
      species: pet.species,
      breed: pet.breed,
      photoUrl: pet.photoUrl,
      photoBytes: pet.photoBytes,
      notes: pet.notes,
      createdAt: pet.createdAt,
      line: parts.join(' · '),
      schedules: schedules,
    );
  }

  final String id;
  final String name;
  final CareSubjectType type;
  final String species;
  final String breed;
  final String? photoUrl;
  final Uint8List? photoBytes;
  final String? location;
  final String? notes;
  final DateTime createdAt;
  final String line;
  final List<CareSchedule> schedules;
}

String _plantLine(CareSchedule schedule) {
  final reminder = schedule.reminders.isEmpty ? '' : ' · ${schedule.reminders.first.label}';
  return '${schedule.whenLabel}$reminder';
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
            color: selected ? Colors.white : AppColors.onboardingBody,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    final plant = member.type == CareSubjectType.plant;
    return GestureDetector(
      onTap: () => showCareDetailSheet(
        context,
        CareDraft(
          id: member.id,
          name: member.name,
          type: member.type,
          createdAt: member.createdAt,
          species: member.species,
          breed: member.breed,
          photoUrl: member.photoUrl,
          photoBytes: member.photoBytes,
          location: member.location,
          notes: member.notes,
          schedules: member.schedules,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.onboardingPaper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.dotIdle, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 126,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (member.photoBytes != null || member.photoUrl != null)
                    CarePhoto(url: member.photoUrl, bytes: member.photoBytes)
                  else
                    ColoredBox(color: careField),
                  const Positioned(
                    top: 4,
                    right: 10,
                    child: Text(
                      '›',
                      style: TextStyle(fontSize: 18, color: Color(0xFF4C7259)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 0),
              child: Text(
                plant ? 'Plant' : 'Pet',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  color: AppColors.sproutGreen,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 5, 11, 0),
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: careInk,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 5, 11, 0),
              child: Text(
                member.line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  height: 1.3,
                  color: AppColors.onboardingBody,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
