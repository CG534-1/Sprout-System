import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/mock/mock_store.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_history_entry.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/care_task.dart';
import 'package:sprout/data/services/care_service.dart';

class MockCareService extends CareService {
  MockCareService(this._store) {
    _store.onSubjectsChanged = notifyListeners;
  }

  final MockStore _store;

  @override
  Future<List<CareTask>> tasksFor(DateTime day) async {
    await _store.pause();
    final tasks =
        _store.tasks.where((task) => isSameDay(task.dueAt, day)).toList()
          ..sort((a, b) {
            final statusCompare = _rank(a.status).compareTo(_rank(b.status));
            if (statusCompare != 0) return statusCompare;
            return a.subjectName.compareTo(b.subjectName);
          });
    return tasks;
  }

  @override
  Future<CareTask?> upcomingAfter(DateTime today) async {
    await _store.pause();
    for (var offset = 1; offset <= 7; offset++) {
      final day = today.add(Duration(days: offset));
      final open = _store.tasks
          .where((task) => isSameDay(task.dueAt, day) && task.status != TaskStatus.done)
          .toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      if (open.isNotEmpty) return open.first;
    }
    return null;
  }

  @override
  Future<void> completeTask(String taskId) async {
    await _store.pause();
    final index = _store.tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) throw const AppException('This task could not be found.');
    final task = _store.tasks[index];
    if (task.status == TaskStatus.done) return;
    _store.tasks[index] = task.copyWith(status: TaskStatus.done);
    _store.history.insert(
      0,
      CareHistoryEntry(
        id: _store.nextId('history'),
        taskId: task.id,
        subjectName: task.subjectName,
        action: task.action,
        subjectType: task.subjectType,
        completedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> reopenTask(String taskId) async {
    await _store.pause();
    final index = _store.tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) throw const AppException('This task could not be found.');
    final task = _store.tasks[index];
    if (task.status != TaskStatus.done) return;
    _store.tasks[index] = task.copyWith(status: TaskStatus.due);
    final historyIndex = _store.history.indexWhere(
      (entry) => entry.taskId == taskId,
    );
    if (historyIndex != -1) _store.history.removeAt(historyIndex);
    notifyListeners();
  }

  @override
  Future<List<CareHistoryEntry>> history() async {
    await _store.pause();
    return List<CareHistoryEntry>.of(_store.history);
  }

  @override
  Future<List<CareSchedule>> schedules() async {
    await _store.pause();
    return List<CareSchedule>.of(_store.schedules);
  }

  @override
  Future<List<CareSchedule>> schedulesFor(String subjectId) async {
    await _store.pause();
    return _store.schedules
        .where((item) => item.subjectId == subjectId)
        .toList();
  }

  @override
  Future<void> savePlan({
    required String subjectId,
    required String subjectName,
    required CareSubjectType subjectType,
    required List<CarePlanEntry> entries,
  }) async {
    await _store.pause();
    _store.schedules.removeWhere((item) => item.subjectId == subjectId);
    _store.tasks.removeWhere(
      (item) => item.subjectId == subjectId && item.status != TaskStatus.done,
    );
    final now = DateTime.now();
    for (final entry in entries) {
    final due = _nextDue(now, entry);
    final schedule = CareSchedule(
      id: _store.nextId('schedule'),
      subjectId: subjectId,
      subjectType: subjectType,
      action: entry.action,
      frequency: entry.frequency,
      nextDue: due,
      timesPerDay: entry.timesPerDay,
      reminders: entry.reminders,
      everyDays: entry.everyDays,
      weekdays: entry.weekdays,
      lastDone: entry.lastDone,
      lead: entry.lead,
    );
    _store.schedules.add(schedule);
    final slots = [...entry.reminders]..sort((a, b) => a.hour.compareTo(b.hour));
    final chosen = slots.isEmpty ? <CareSlot>[CareSlot.morning] : slots;
    final times = chosen
        .map((slot) => DateTime(due.year, due.month, due.day, slot.hour))
        .where((at) => !at.isBefore(now))
        .toList();
    final dues = times.isEmpty ? [due] : times;
    for (final at in dues) {
      _store.tasks.add(
        CareTask(
          id: _store.nextId('task'),
          scheduleId: schedule.id,
          subjectId: subjectId,
          subjectType: subjectType,
          subjectName: subjectName,
          action: entry.action,
          dueAt: at,
          status: TaskStatus.due,
        ),
      );
    }
  }
    notifyListeners();
  }

  DateTime _nextDue(DateTime now, CarePlanEntry entry) {
    final slots = [...entry.reminders]..sort((a, b) => a.hour.compareTo(b.hour));
    final hour = slots.isEmpty ? 9 : slots.first.hour;
    final interval = entry.frequency == CareFrequency.custom
        ? (entry.everyDays ?? 1)
        : entry.frequency.intervalDays;
    final last = entry.lastDone;
    if (last != null) {
      final fromLast = _afterLast(last, entry, hour, interval);
      if (!fromLast.isBefore(now)) return fromLast;
    }
    final start = DateTime(now.year, now.month, now.day);
    if (entry.frequency == CareFrequency.setDays && entry.weekdays.isNotEmpty) {
      for (var offset = 0; offset < 8; offset++) {
        final day = start.add(Duration(days: offset));
        if (!entry.weekdays.contains(day.weekday)) continue;
        for (final slot in slots) {
          final at = DateTime(day.year, day.month, day.day, slot.hour);
          if (!at.isBefore(now)) return at;
        }
      }
    }
    for (final slot in slots) {
      final at = DateTime(start.year, start.month, start.day, slot.hour);
      if (!at.isBefore(now)) return at;
    }
    return DateTime(start.year, start.month, start.day, hour).add(
      Duration(days: interval),
    );
  }

  DateTime _afterLast(DateTime last, CarePlanEntry entry, int hour, int interval) {
    final day = DateTime(last.year, last.month, last.day);
    if (entry.frequency == CareFrequency.setDays && entry.weekdays.isNotEmpty) {
      for (var offset = 1; offset <= 7; offset++) {
        final next = day.add(Duration(days: offset));
        if (entry.weekdays.contains(next.weekday)) {
          return DateTime(next.year, next.month, next.day, hour);
        }
      }
    }
    final next = day.add(Duration(days: interval));
    return DateTime(next.year, next.month, next.day, hour);
  }

  int _rank(TaskStatus status) => status == TaskStatus.due ? 0 : 1;
}
