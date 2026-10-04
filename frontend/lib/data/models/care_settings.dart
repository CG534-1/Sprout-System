import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/slot_hours.dart';

class CareSettings {
  const CareSettings({
    required this.reminders,
    required this.overdue,
    required this.summary,
    required this.tips,
    required this.preferredSlots,
    required this.lead,
    this.slotHours = SlotHours.defaults,
  });

  final bool reminders;
  final bool overdue;
  final bool summary;
  final bool tips;

  bool get wantsPush => reminders || overdue || summary;
  final List<CareSlot> preferredSlots;
  CareSlot get preferred =>
      preferredSlots.isEmpty ? CareSlot.morning : preferredSlots.first;
  final String lead;
  final SlotHours slotHours;

  static const defaults = CareSettings(
    reminders: true,
    overdue: true,
    summary: true,
    tips: false,
    preferredSlots: [CareSlot.morning],
    lead: '30 min before',
  );

  CareSettings copyWith({
    bool? reminders,
    bool? overdue,
    bool? summary,
    bool? tips,
    List<CareSlot>? preferredSlots,
    String? lead,
    SlotHours? slotHours,
  }) {
    return CareSettings(
      reminders: reminders ?? this.reminders,
      overdue: overdue ?? this.overdue,
      summary: summary ?? this.summary,
      tips: tips ?? this.tips,
      preferredSlots: preferredSlots ?? this.preferredSlots,
      lead: lead ?? this.lead,
      slotHours: slotHours ?? this.slotHours,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reminders': reminders,
      'overdue': overdue,
      'summary': summary,
      'tips': tips,
      'preferred': preferred.name,
      'preferredSlots': preferredSlots.map((slot) => slot.name).toList(),
      'lead': lead,
      'slotHours': slotHours.toJson(),
    };
  }

  factory CareSettings.fromJson(Map<String, dynamic> json) {
    return CareSettings(
      reminders: json['reminders'] as bool? ?? true,
      overdue: json['overdue'] as bool? ?? true,
      summary: json['summary'] as bool? ?? true,
      tips: json['tips'] as bool? ?? false,
      preferredSlots: slotsFrom(json['preferredSlots'] ?? json['preferred']),
      lead: json['lead'] as String? ?? '30 min before',
      slotHours: SlotHours.fromJson(json['slotHours']),
    );
  }

  static List<CareSlot> slotsFrom(Object? raw) {
    final names = <String>[];
    if (raw is List) {
      names.addAll(raw.map((item) => item.toString()));
    } else if (raw is String) {
      names.addAll(raw.split(',').map((item) => item.trim()));
    }
    final slots = [
      for (final name in names)
        if (CareSlot.values.any((slot) => slot.name == name)) CareSlot.fromJson(name),
    ];
    return slots.isEmpty ? const [CareSlot.morning] : slots;
  }
}
