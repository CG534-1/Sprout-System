import 'package:flutter/foundation.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_history_entry.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/data/models/care_task.dart';

abstract class CareService extends ChangeNotifier {
  Future<List<CareTask>> tasksFor(DateTime day);

  Future<void> completeTask(String taskId);

  Future<void> reopenTask(String taskId);

  Future<List<CareHistoryEntry>> history();

  Future<List<CareSchedule>> schedules();

  Future<List<CareSchedule>> schedulesFor(String subjectId);

  Future<void> savePlan({
    required String subjectId,
    required String subjectName,
    required CareSubjectType subjectType,
    required List<CarePlanEntry> entries,
  });
}
