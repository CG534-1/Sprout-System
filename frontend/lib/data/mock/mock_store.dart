import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_history_entry.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/care_task.dart';
import 'package:sprout/data/models/pet.dart';
import 'package:sprout/data/models/plant.dart';
import 'package:sprout/data/models/user_profile.dart';

class MockStore {
  MockStore({this.delay = const Duration(milliseconds: 300)});

  factory MockStore.seeded({
    Duration delay = const Duration(milliseconds: 300),
  }) {
    final store = MockStore(delay: delay);
    final now = DateTime.now();
    final morning = DateTime(now.year, now.month, now.day, 9);
    final noon = DateTime(now.year, now.month, now.day, 12);
    final evening = DateTime(now.year, now.month, now.day, 19);
    final tomorrow = morning.add(const Duration(days: 1));

    store.plants.addAll([
      Plant(
        id: 'plant-monstera',
        name: 'Monstera',
        species: 'Monstera deliciosa',
        location: 'Living room',
        photoUrl: 'assets/images/plant_monstera.png',
        notes: 'Likes bright indirect light.',
        createdAt: morning.subtract(const Duration(days: 40)),
      ),
      Plant(
        id: 'plant-aloe',
        name: 'Aloe Vera',
        species: 'Aloe vera',
        location: 'Kitchen sill',
        photoUrl: 'assets/images/plant_aloe.png',
        createdAt: morning.subtract(const Duration(days: 12)),
      ),
    ]);

    store.pets.addAll([
      Pet(
        id: 'pet-milo',
        name: 'Milo',
        species: 'Dog',
        photoUrl: 'assets/images/pet_milo.png',
        notes: 'Breakfast and an evening walk.',
        createdAt: morning.subtract(const Duration(days: 26)),
      ),
    ]);

    store.schedules.addAll([
      CareSchedule(
        id: 'schedule-water-monstera',
        subjectId: 'plant-monstera',
        subjectType: CareSubjectType.plant,
        action: CareAction.water,
        frequency: CareFrequency.everyTwoDays,
        nextDue: morning,
        reminders: const [CareSlot.morning],
      ),
      CareSchedule(
        id: 'schedule-feed-milo',
        subjectId: 'pet-milo',
        subjectType: CareSubjectType.pet,
        action: CareAction.feed,
        frequency: CareFrequency.daily,
        nextDue: noon,
        timesPerDay: 2,
        reminders: const [CareSlot.morning, CareSlot.evening],
      ),
      CareSchedule(
        id: 'schedule-walk-milo',
        subjectId: 'pet-milo',
        subjectType: CareSubjectType.pet,
        action: CareAction.walk,
        frequency: CareFrequency.daily,
        nextDue: evening,
        timesPerDay: 2,
        reminders: const [CareSlot.morning, CareSlot.evening],
      ),
      CareSchedule(
        id: 'schedule-water-aloe',
        subjectId: 'plant-aloe',
        subjectType: CareSubjectType.plant,
        action: CareAction.water,
        frequency: CareFrequency.everyThreeDays,
        nextDue: tomorrow,
        reminders: const [CareSlot.morning],
      ),
    ]);

    store.tasks.addAll([
      CareTask(
        id: 'task-water-monstera',
        scheduleId: 'schedule-water-monstera',
        subjectId: 'plant-monstera',
        subjectType: CareSubjectType.plant,
        subjectName: 'Monstera',
        action: CareAction.water,
        dueAt: morning,
        status: TaskStatus.due,
      ),
      CareTask(
        id: 'task-feed-milo',
        scheduleId: 'schedule-feed-milo',
        subjectId: 'pet-milo',
        subjectType: CareSubjectType.pet,
        subjectName: 'Milo',
        action: CareAction.feed,
        dueAt: noon,
        status: TaskStatus.due,
      ),
      CareTask(
        id: 'task-walk-milo',
        scheduleId: 'schedule-walk-milo',
        subjectId: 'pet-milo',
        subjectType: CareSubjectType.pet,
        subjectName: 'Milo',
        action: CareAction.walk,
        dueAt: evening,
        status: TaskStatus.due,
      ),
      CareTask(
        id: 'task-water-aloe',
        scheduleId: 'schedule-water-aloe',
        subjectId: 'plant-aloe',
        subjectType: CareSubjectType.plant,
        subjectName: 'Aloe Vera',
        action: CareAction.water,
        dueAt: tomorrow,
        status: TaskStatus.due,
      ),
    ]);

    final samples = <CareHistoryEntry>[
      CareHistoryEntry(
        id: 'history-walk',
        taskId: 'task-past-walk',
        subjectName: 'Milo',
        action: CareAction.walk,
        subjectType: CareSubjectType.pet,
        completedAt: DateTime(now.year, now.month, now.day - 6, 19, 2),
      ),
      CareHistoryEntry(
        id: 'history-aloe',
        taskId: 'task-past-aloe',
        subjectName: 'Aloe Vera',
        action: CareAction.water,
        subjectType: CareSubjectType.plant,
        completedAt: DateTime(now.year, now.month, now.day - 8, 9, 10),
      ),
      CareHistoryEntry(
        id: 'history-monstera',
        taskId: 'task-past-monstera',
        subjectName: 'Monstera',
        action: CareAction.water,
        subjectType: CareSubjectType.plant,
        completedAt: DateTime(now.year, now.month, now.day - 10, 9),
      ),
      CareHistoryEntry(
        id: 'history-feed',
        taskId: 'task-past-feed',
        subjectName: 'Milo',
        action: CareAction.feed,
        subjectType: CareSubjectType.pet,
        completedAt: DateTime(now.year, now.month, now.day - 11, 12),
      ),
    ];
    for (var daysAgo = 1; daysAgo <= 12; daysAgo++) {
      final known = samples.where(
        (entry) =>
            entry.completedAt.year == now.year &&
            entry.completedAt.month == now.month &&
            entry.completedAt.day == now.day - daysAgo,
      );
      if (known.isNotEmpty) {
        store.history.addAll(known);
        continue;
      }
      final pet = daysAgo.isEven;
      store.history.add(
        CareHistoryEntry(
          id: 'history-day-$daysAgo',
          taskId: 'task-past-$daysAgo',
          subjectName: pet ? 'Milo' : 'Monstera',
          action: pet ? CareAction.feed : CareAction.water,
          subjectType: pet ? CareSubjectType.pet : CareSubjectType.plant,
          completedAt: DateTime(now.year, now.month, now.day - daysAgo, 9),
        ),
      );
    }

    return store;
  }

  static const demoProfile = UserProfile(
    id: 'user-1',
    name: 'Alex Morgan',
    email: 'ama@sprout.app',
    avatarUrl: 'assets/images/memoji_freckles.png',
  );

  final Duration delay;
  UserProfile? currentUser;
  bool onboardingComplete = false;
  void Function()? onSubjectsChanged;
  final List<Plant> plants = [];
  final List<Pet> pets = [];
  final List<CareSchedule> schedules = [];
  final List<CareTask> tasks = [];
  final List<CareHistoryEntry> history = [];
  int _sequence = 0;

  Future<void> pause() {
    if (delay == Duration.zero) return Future<void>.value();
    return Future<void>.delayed(delay);
  }

  String nextId(String prefix) {
    _sequence += 1;
    return '$prefix-$_sequence';
  }

  void removeSubject(String subjectId) {
    schedules.removeWhere((item) => item.subjectId == subjectId);
    tasks.removeWhere(
      (item) => item.subjectId == subjectId && item.status != TaskStatus.done,
    );
    onSubjectsChanged?.call();
  }
}

String? emptyToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed;
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
