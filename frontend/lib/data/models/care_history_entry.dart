import 'package:sprout/data/models/care_enums.dart';

class CareHistoryEntry {
  const CareHistoryEntry({
    required this.id,
    required this.taskId,
    required this.subjectName,
    required this.action,
    required this.completedAt,
    this.subjectType = CareSubjectType.plant,
    this.note,
  });

  final String id;
  final String taskId;
  final String subjectName;
  final CareAction action;
  final DateTime completedAt;
  final CareSubjectType subjectType;
  final String? note;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'subjectName': subjectName,
      'action': action.toJson(),
      'completedAt': completedAt.toIso8601String(),
      'subjectType': subjectType.toJson(),
      'note': note,
    };
  }

  factory CareHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CareHistoryEntry(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      subjectName: json['subjectName'] as String,
      action: CareAction.fromJson(json['action'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      subjectType: json['subjectType'] == null
          ? CareSubjectType.plant
          : CareSubjectType.fromJson(json['subjectType'] as String),
      note: json['note'] as String?,
    );
  }
}
