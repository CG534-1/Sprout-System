import 'package:sprout/data/models/care_enums.dart';

class CareSettings {
  const CareSettings({
    required this.reminders,
    required this.overdue,
    required this.summary,
    required this.tips,
    required this.preferred,
    required this.lead,
  });

  final bool reminders;
  final bool overdue;
  final bool summary;
  final bool tips;
  final CareSlot preferred;
  final String lead;

  static const defaults = CareSettings(
    reminders: true,
    overdue: true,
    summary: true,
    tips: false,
    preferred: CareSlot.morning,
    lead: '30 min before',
  );

  CareSettings copyWith({
    bool? reminders,
    bool? overdue,
    bool? summary,
    bool? tips,
    CareSlot? preferred,
    String? lead,
  }) {
    return CareSettings(
      reminders: reminders ?? this.reminders,
      overdue: overdue ?? this.overdue,
      summary: summary ?? this.summary,
      tips: tips ?? this.tips,
      preferred: preferred ?? this.preferred,
      lead: lead ?? this.lead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reminders': reminders,
      'overdue': overdue,
      'summary': summary,
      'tips': tips,
      'preferred': preferred.name,
      'lead': lead,
    };
  }

  factory CareSettings.fromJson(Map<String, dynamic> json) {
    return CareSettings(
      reminders: json['reminders'] as bool? ?? true,
      overdue: json['overdue'] as bool? ?? true,
      summary: json['summary'] as bool? ?? true,
      tips: json['tips'] as bool? ?? false,
      preferred: CareSlot.fromJson(json['preferred'] as String? ?? 'morning'),
      lead: json['lead'] as String? ?? '30 min before',
    );
  }
}
