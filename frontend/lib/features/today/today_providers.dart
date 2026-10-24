import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_task.dart';
import 'package:sprout/data/models/push_note.dart';
import 'package:sprout/data/providers.dart';

class TodayCare {
  const TodayCare({
    required this.today,
    required this.upcoming,
    required this.photos,
    required this.hasHome,
  });

  static const empty = TodayCare(
    today: [],
    upcoming: [],
    photos: {},
    hasHome: false,
  );

  final List<CareTask> today;
  final List<CareTask> upcoming;
  final Map<String, String> photos;
  final bool hasHome;

  TodayCare withStatus(String taskId, TaskStatus status) {
    return TodayCare(
      today: [
        for (final task in today)
          if (task.id == taskId) task.copyWith(status: status) else task,
      ],
      upcoming: upcoming,
      photos: photos,
      hasHome: hasHome,
    );
  }
}

final todayCareProvider =
    AsyncNotifierProvider.autoDispose<TodayCareNotifier, TodayCare>(
      TodayCareNotifier.new,
    );

class TodayCareNotifier extends AsyncNotifier<TodayCare> {
  @override
  Future<TodayCare> build() async {
    // A new sign in swaps the user, so the greeting and the list move together.
    watchService(ref, ref.watch(authServiceProvider));
    final care = watchService(ref, ref.watch(careServiceProvider));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final loaded = await (
      care.tasksFor(today),
      care.upcomingAfter(today),
      ref.watch(homeProvider.future),
    ).wait;
    final home = loaded.$3;
    final ids = home.ids;
    return TodayCare(
      today: loaded.$1.where((task) => ids.contains(task.subjectId)).toList()
        ..sort((a, b) {
          final byOpen = _openRank(a).compareTo(_openRank(b));
          if (byOpen != 0) return byOpen;
          return a.dueAt.compareTo(b.dueAt);
        }),
      upcoming: loaded.$2.where((task) => ids.contains(task.subjectId)).toList(),
      photos: home.photosById,
      hasHome: ids.isNotEmpty,
    );
  }

  int _openRank(CareTask task) {
    if (task.isOverdue()) return 0;
    if (task.status == TaskStatus.due) return 1;
    return 2;
  }

  /// Marks [task] done, or reopens it when it already is.
  Future<void> toggle(CareTask task) {
    final done = task.status == TaskStatus.done;
    final care = ref.read(careServiceProvider);
    return _change(
      task,
      done ? TaskStatus.due : TaskStatus.done,
      () => done ? care.reopenTask(task.id) : care.completeTask(task.id),
    );
  }

  /// Skips [task], or brings it back when it was skipped.
  Future<void> skip(CareTask task) {
    final skipped = task.status == TaskStatus.skipped;
    final care = ref.read(careServiceProvider);
    return _change(
      task,
      skipped ? TaskStatus.due : TaskStatus.skipped,
      () => skipped ? care.reopenTask(task.id) : care.skipTask(task.id),
    );
  }

  /// Shows [status] at once, then saves it. A failed save reloads the list
  /// and rethrows so the page can say so.
  Future<void> _change(
    CareTask task,
    TaskStatus status,
    Future<void> Function() save,
  ) async {
    final current = state.value;
    if (current != null) state = AsyncData(current.withStatus(task.id, status));
    try {
      await save();
    } catch (_) {
      if (ref.mounted) ref.invalidateSelf();
      rethrow;
    }
  }
}

/// Unread bell notes. Today refreshes this after the bell panel closes.
final unreadNotesProvider = FutureProvider.autoDispose<int>((ref) async {
  final notes = await ref.watch(profileServiceProvider).notifications();
  return notes.where((note) => !note.read).length;
});

/// The bell panel's notes. Opening the panel marks them read.
final bellNotesProvider = FutureProvider.autoDispose<List<PushNote>>((ref) async {
  final profile = ref.watch(profileServiceProvider);
  try {
    final notes = await profile.notifications();
    if (notes.any((note) => !note.read)) {
      await profile.markNotificationsRead();
    }
    return notes;
  } catch (_) {
    return const [];
  }
});

/// One day of the calendar sheet.
final calendarTasksProvider = FutureProvider.autoDispose
    .family<List<CareTask>, DateTime>((ref, day) async {
      final tasks = await ref.watch(careServiceProvider).tasksFor(day);
      return tasks..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    });
