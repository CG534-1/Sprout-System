import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_history_entry.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/care_task.dart';
import 'package:sprout/data/services/care_service.dart';

class ApiCareService extends CareService {
  ApiCareService(this._client);

  final ApiClient _client;
  final _tasks = <String, List<CareTask>>{};
  List<CareHistoryEntry>? _history;
  List<CareSchedule>? _schedulesCache;
  CareTask? _upcoming;
  var _upcomingReady = false;

  String _dayKey(DateTime day) {
    return '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  void _forget() {
    _tasks.clear();
    _history = null;
    _schedulesCache = null;
    _upcoming = null;
    _upcomingReady = false;
  }

  @override
  Future<List<CareTask>> tasksFor(DateTime day) async {
    final date = _dayKey(day);
    final cached = _tasks[date];
    if (cached != null) return cached;
    final data = await _client.send('GET', '/api/tasks', query: {'date': date});
    final tasks = (data as List)
        .map((item) => CareTask.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    _tasks[date] = tasks;
    return tasks;
  }

  @override
  Future<CareTask?> upcomingAfter(DateTime today) async {
    if (_upcomingReady) return _upcoming;
    final data = await _client.send('GET', '/api/tasks', query: {'upcoming': '1'});
    final tasks = (data as List)
        .map((item) => CareTask.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    _upcoming = tasks.isEmpty ? null : tasks.first;
    _upcomingReady = true;
    return _upcoming;
  }

  void _setStatus(String taskId, TaskStatus status) {
    for (final entry in _tasks.entries) {
      _tasks[entry.key] = [
        for (final task in entry.value)
          if (task.id == taskId) task.copyWith(status: status) else task,
      ];
    }
  }

  @override
  Future<void> completeTask(String taskId) async {
    _setStatus(taskId, TaskStatus.done);
    _history = null;
    notifyListeners();
    try {
      await _client.send('POST', '/api/tasks/$taskId/complete');
    } catch (_) {
      _setStatus(taskId, TaskStatus.due);
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> reopenTask(String taskId) async {
    _setStatus(taskId, TaskStatus.due);
    _history = null;
    notifyListeners();
    try {
      await _client.send('POST', '/api/tasks/$taskId/reopen');
    } catch (_) {
      _setStatus(taskId, TaskStatus.done);
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<List<CareHistoryEntry>> history() async {
    if (_history != null) return _history!;
    final data = await _client.send('GET', '/api/care-history');
    _history = (data as List)
        .map((item) => CareHistoryEntry.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return _history!;
  }

  @override
  Future<List<CareSchedule>> schedules() async {
    if (_schedulesCache != null) return _schedulesCache!;
    final data = await _client.send('GET', '/api/schedules');
    _schedulesCache = _schedules(data);
    return _schedulesCache!;
  }

  @override
  Future<List<CareSchedule>> schedulesFor(String subjectId) async {
    final data = await _client.send('GET', '/api/schedules', query: {'subjectId': subjectId});
    return _schedules(data);
  }

  @override
  Future<void> savePlan({
    required String subjectId,
    required String subjectName,
    required CareSubjectType subjectType,
    required List<CarePlanEntry> entries,
  }) async {
    await _client.send(
      'PUT',
      '/api/schedules',
      body: {
        'subjectId': subjectId,
        'subjectName': subjectName,
        'subjectType': subjectType.toJson(),
        'entries': entries.map(_entry).toList(),
      },
    );
    _forget();
    notifyListeners();
  }

  List<CareSchedule> _schedules(dynamic data) {
    return (data as List)
        .map((item) => CareSchedule.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Map<String, dynamic> _entry(CarePlanEntry entry) {
    return {
      'action': entry.action.toJson(),
      'frequency': entry.frequency.toJson(),
      'timesPerDay': entry.timesPerDay,
      'reminders': entry.reminders.map((slot) => slot.toJson()).toList(),
      'everyDays': entry.everyDays,
      'weekdays': entry.weekdays,
      'lastDone': entry.lastDone?.toIso8601String(),
      'lead': entry.lead,
    };
  }
}
