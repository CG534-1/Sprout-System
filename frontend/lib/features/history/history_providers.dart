import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/data/models/care_history_entry.dart';
import 'package:sprout/data/providers.dart';

class CareHistory {
  const CareHistory({required this.entries, required this.photos});

  /// Newest first.
  final List<CareHistoryEntry> entries;

  /// Photo URLs by subject name, since history rows carry the name.
  final Map<String, String> photos;
}

final careHistoryProvider = FutureProvider.autoDispose<CareHistory>((ref) async {
  final care = watchService(ref, ref.watch(careServiceProvider));
  final loaded = await (care.history(), ref.watch(homeProvider.future)).wait;
  final entries = List<CareHistoryEntry>.of(loaded.$1)
    ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return CareHistory(entries: entries, photos: loaded.$2.photosByName);
});
