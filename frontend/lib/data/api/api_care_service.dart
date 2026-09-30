import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_history_entry.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/care_task.dart';
import 'package:sprout/data/services/care_service.dart';

class ApiCareService extends CareService {
  ApiCareService(this._client);

  final ApiClient _client;

  @override
  Future<List<CareTask>> tasksFor(DateTime day) async {
    final date =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final data = await _client.send('GET', '/api/tasks', query: {'date': date});
    return (data as List)
        .map((item) => CareTask.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<void> completeTask(String taskId) async {
    await _client.send('POST', '/api/tasks/$taskId/complete');
    notifyListeners();
  }

  @override
  Future<void> reopenTask(String taskId) async {
    await _client.send('POST', '/api/tasks/$taskId/reopen');
    notifyListeners();
  }

  @override
  Future<List<CareHistoryEntry>> history() async {
    final data = await _client.send('GET', '/api/care-history');
    return (data as List)
        .map((item) => CareHistoryEntry.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<List<CareSchedule>> schedules() async {
    final data = await _client.send('GET', '/api/schedules');
    return _schedules(data);
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
    };
  }
}
