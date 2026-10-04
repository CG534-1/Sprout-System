import 'package:flutter/material.dart';
import 'package:sprout/data/models/care_enums.dart';

class SlotHours {
  const SlotHours(this.times);

  final Map<CareSlot, TimeOfDay> times;

  static const defaults = SlotHours({
    CareSlot.morning: TimeOfDay(hour: 9, minute: 0),
    CareSlot.afternoon: TimeOfDay(hour: 13, minute: 0),
    CareSlot.evening: TimeOfDay(hour: 18, minute: 0),
  });

  TimeOfDay of(CareSlot slot) => times[slot] ?? defaults.times[slot]!;

  String labelOf(CareSlot slot) => formatClock(of(slot));

  bool isCustom(CareSlot slot) {
    final clock = of(slot);
    return clock.hour != slot.hour || clock.minute != 0;
  }

  SlotHours copyWithSlot(CareSlot slot, TimeOfDay time) {
    return SlotHours({...times, slot: time});
  }

  SlotHours merge(SlotHours overrides) {
    return SlotHours({...times, ...overrides.times});
  }

  Map<String, dynamic> toJson() {
    return {
      for (final entry in times.entries)
        entry.key.name: {'hour': entry.value.hour, 'minute': entry.value.minute},
    };
  }

  factory SlotHours.fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    final next = Map<CareSlot, TimeOfDay>.from(defaults.times);
    for (final slot in CareSlot.values) {
      final parsed = parseClock(raw[slot.name]);
      if (parsed != null) next[slot] = parsed;
    }
    return SlotHours(next);
  }

  factory SlotHours.overridesFromJson(Object? raw) {
    if (raw is! Map) return const SlotHours({});
    final next = <CareSlot, TimeOfDay>{};
    for (final slot in CareSlot.values) {
      final parsed = parseClock(raw[slot.name]);
      if (parsed != null) next[slot] = parsed;
    }
    return SlotHours(next);
  }

  static TimeOfDay? parseClock(Object? value) {
    if (value is num) {
      final hour = value.toInt();
      if (hour < 0 || hour > 23) return null;
      return TimeOfDay(hour: hour, minute: 0);
    }
    if (value is Map) {
      final hour = (value['hour'] as num?)?.toInt();
      if (hour == null || hour < 0 || hour > 23) return null;
      final rawMinute = (value['minute'] as num?)?.toInt() ?? 0;
      final minute = rawMinute < 0 ? 0 : rawMinute > 59 ? 59 : rawMinute;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  static String formatClock(TimeOfDay time) {
    final hour = time.hour % 24;
    final period = hour >= 12 ? 'PM' : 'AM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$twelve:$minute $period';
  }
}
