import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/slot_hours.dart';

class CareSchedule {
  const CareSchedule({
    required this.id,
    required this.subjectId,
    required this.subjectType,
    required this.action,
    required this.frequency,
    required this.nextDue,
    this.timesPerDay,
    this.reminders = const [],
    this.everyDays,
    this.weekdays = const [],
    this.lastDone,
    this.lead,
    this.slotHours = const SlotHours({}),
  });

  final String id;
  final String subjectId;
  final CareSubjectType subjectType;
  final CareAction action;
  final CareFrequency frequency;
  final DateTime nextDue;
  final int? timesPerDay;
  final List<CareSlot> reminders;
  final int? everyDays;
  final List<int> weekdays;
  final DateTime? lastDone;
  final String? lead;
  final SlotHours slotHours;

  String get whenLabel {
    if (frequency == CareFrequency.custom && everyDays != null) {
      return 'Every $everyDays days';
    }
    if (frequency == CareFrequency.setDays && weekdays.isNotEmpty) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays.map((day) => names[day - 1]).join(', ');
    }
    return frequency.card;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'subjectType': subjectType.toJson(),
      'action': action.toJson(),
      'frequency': frequency.toJson(),
      'nextDue': nextDue.toIso8601String(),
      'timesPerDay': timesPerDay,
      'reminders': reminders.map((slot) => slot.toJson()).toList(),
      'everyDays': everyDays,
      'weekdays': weekdays,
      'lastDone': lastDone?.toIso8601String(),
      'lead': lead,
      'slotHours': slotHours.toJson(),
    };
  }

  factory CareSchedule.fromJson(Map<String, dynamic> json) {
    return CareSchedule(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      subjectType: CareSubjectType.fromJson(json['subjectType'] as String),
      action: CareAction.fromJson(json['action'] as String),
      frequency: CareFrequency.fromJson(json['frequency'] as String),
      nextDue: DateTime.parse(json['nextDue'] as String),
      timesPerDay: json['timesPerDay'] as int?,
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((item) => CareSlot.fromJson(item as String))
              .toList() ??
          const [],
      everyDays: json['everyDays'] as int?,
      weekdays: (json['weekdays'] as List<dynamic>?)
              ?.map((item) => item as int)
              .toList() ??
          const [],
      lastDone: json['lastDone'] == null
          ? null
          : DateTime.parse(json['lastDone'] as String),
      lead: json['lead'] as String?,
      slotHours: SlotHours.overridesFromJson(json['slotHours']),
    );
  }
}

class CarePlanEntry {
  const CarePlanEntry({
    required this.action,
    required this.frequency,
    this.timesPerDay,
    this.reminders = const [],
    this.everyDays,
    this.weekdays = const [],
    this.lastDone,
    this.lead,
    this.slotHours = const SlotHours({}),
  });

  final CareAction action;
  final CareFrequency frequency;
  final int? timesPerDay;
  final List<CareSlot> reminders;
  final int? everyDays;
  final List<int> weekdays;
  final DateTime? lastDone;
  final String? lead;
  final SlotHours slotHours;
}
