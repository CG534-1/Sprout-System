import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/data/providers.dart';

class ProfileStats {
  const ProfileStats({
    required this.plants,
    required this.pets,
    required this.streak,
    required this.filled,
  });

  static const empty = ProfileStats(plants: 0, pets: 0, streak: 0, filled: {});

  final int plants;
  final int pets;
  final int streak;

  /// Weekdays this week with at least one care moment, Monday as 0.
  final Set<int> filled;
}

final profileStatsProvider = FutureProvider.autoDispose<ProfileStats>((ref) async {
  final care = watchService(ref, ref.watch(careServiceProvider));
  final loaded = await (ref.watch(homeProvider.future), care.history()).wait;
  final home = loaded.$1;
  final days = loaded.$2
      .map((entry) => DateTime(entry.completedAt.year, entry.completedAt.month, entry.completedAt.day))
      .toSet();
  return ProfileStats(
    plants: home.plants.length,
    pets: home.pets.length,
    streak: _careStreak(days),
    filled: _thisWeek(days),
  );
});

int _careStreak(Set<DateTime> days) {
  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  var count = 0;
  while (days.contains(cursor)) {
    count += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}

Set<int> _thisWeek(Set<DateTime> days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return {
    for (var index = 0; index < 7; index++)
      if (days.contains(monday.add(Duration(days: index)))) index,
  };
}
