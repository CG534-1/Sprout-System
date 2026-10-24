import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/pet.dart';
import 'package:sprout/data/models/plant.dart';
import 'package:sprout/data/providers.dart';

/// Everyone in the home with their schedules, oldest first.
final careMembersProvider = FutureProvider.autoDispose<List<CareMember>>((ref) async {
  final care = watchService(ref, ref.watch(careServiceProvider));
  final loaded = await (ref.watch(homeProvider.future), care.schedules()).wait;
  final home = loaded.$1;
  final schedules = loaded.$2;
  return [
    for (final plant in home.plants)
      CareMember.plant(
        plant,
        schedules.where((item) => item.subjectId == plant.id).toList(),
      ),
    for (final pet in home.pets)
      CareMember.pet(
        pet,
        schedules.where((item) => item.subjectId == pet.id).toList(),
      ),
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
});

class CareMember {
  CareMember({
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

  factory CareMember.plant(Plant plant, List<CareSchedule> schedules) {
    final water = schedules.where((item) => item.action == CareAction.water);
    final line = water.isEmpty ? '' : _plantLine(water.first);
    return CareMember(
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

  factory CareMember.pet(Pet pet, List<CareSchedule> schedules) {
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
    return CareMember(
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
