import 'package:sprout/data/models/care_enums.dart';

class CareTask {
  const CareTask({
    required this.id,
    required this.scheduleId,
    required this.subjectId,
    required this.subjectType,
    required this.subjectName,
    required this.action,
    required this.dueAt,
    required this.status,
  });

  final String id;
  final String scheduleId;
  final String subjectId;
  final CareSubjectType subjectType;
  final String subjectName;
  final CareAction action;
  final DateTime dueAt;
  final TaskStatus status;

  bool get closed =>
      status == TaskStatus.done || status == TaskStatus.skipped;

  bool isOverdue([DateTime? now]) {
    if (status != TaskStatus.due) return false;
    return dueAt.isBefore(now ?? DateTime.now());
  }

  CareTask copyWith({TaskStatus? status}) {
    return CareTask(
      id: id,
      scheduleId: scheduleId,
      subjectId: subjectId,
      subjectType: subjectType,
      subjectName: subjectName,
      action: action,
      dueAt: dueAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'subjectId': subjectId,
      'subjectType': subjectType.toJson(),
      'subjectName': subjectName,
      'action': action.toJson(),
      'dueAt': dueAt.toIso8601String(),
      'status': status.toJson(),
    };
  }

  factory CareTask.fromJson(Map<String, dynamic> json) {
    return CareTask(
      id: json['id'] as String,
      scheduleId: json['scheduleId'] as String,
      subjectId: json['subjectId'] as String,
      subjectType: CareSubjectType.fromJson(json['subjectType'] as String),
      subjectName: json['subjectName'] as String,
      action: CareAction.fromJson(json['action'] as String),
      dueAt: DateTime.parse(json['dueAt'] as String),
      status: TaskStatus.fromJson(json['status'] as String),
    );
  }
}
