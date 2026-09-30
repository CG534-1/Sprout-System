enum CareSubjectType {
  plant,
  pet;

  String get label => switch (this) {
    CareSubjectType.plant => 'Plant',
    CareSubjectType.pet => 'Pet',
  };

  String toJson() => name;

  static CareSubjectType fromJson(String value) {
    return CareSubjectType.values.firstWhere((item) => item.name == value);
  }
}

enum CareAction {
  water,
  mist,
  fertilize,
  feed,
  walk,
  groom,
  waterBowl;

  String get label => switch (this) {
    CareAction.water => 'Water',
    CareAction.mist => 'Mist',
    CareAction.fertilize => 'Fertilize',
    CareAction.feed => 'Feed',
    CareAction.walk => 'Walk',
    CareAction.groom => 'Groom',
    CareAction.waterBowl => 'Water bowl',
  };

  String get past => switch (this) {
    CareAction.water => 'Watered',
    CareAction.mist => 'Misted',
    CareAction.fertilize => 'Fertilized',
    CareAction.feed => 'Fed',
    CareAction.walk => 'Walked',
    CareAction.groom => 'Groomed',
    CareAction.waterBowl => 'Refilled',
  };

  String toJson() => name;

  static CareAction fromJson(String value) {
    return CareAction.values.firstWhere((item) => item.name == value);
  }
}

enum CareSlot {
  morning,
  afternoon,
  evening;

  String get label => switch (this) {
    CareSlot.morning => 'Morning',
    CareSlot.afternoon => 'Afternoon',
    CareSlot.evening => 'Evening',
  };

  String get clock => switch (this) {
    CareSlot.morning => '9:00 AM',
    CareSlot.afternoon => '1:00 PM',
    CareSlot.evening => '6:00 PM',
  };

  String get mark => switch (this) {
    CareSlot.morning => '🌅',
    CareSlot.afternoon => '☀️',
    CareSlot.evening => '🌙',
  };

  int get hour => switch (this) {
    CareSlot.morning => 9,
    CareSlot.afternoon => 13,
    CareSlot.evening => 18,
  };

  String toJson() => name;

  static CareSlot fromJson(String value) {
    return CareSlot.values.firstWhere((item) => item.name == value);
  }
}

enum CareFrequency {
  daily,
  everyTwoDays,
  everyThreeDays,
  weekly,
  custom,
  setDays;

  String get label => switch (this) {
    CareFrequency.daily => 'Every day',
    CareFrequency.everyTwoDays => 'Every 2 days',
    CareFrequency.everyThreeDays => 'Every 3 days',
    CareFrequency.weekly => 'Every week',
    CareFrequency.custom => 'Custom',
    CareFrequency.setDays => 'Set days',
  };

  String get chip => switch (this) {
    CareFrequency.daily => 'Daily',
    CareFrequency.everyTwoDays => 'Every 2 d',
    CareFrequency.everyThreeDays => 'Every 3 d',
    CareFrequency.weekly => 'Weekly',
    CareFrequency.custom => 'Custom',
    CareFrequency.setDays => 'Set days',
  };

  String get card => switch (this) {
    CareFrequency.daily => 'Daily',
    CareFrequency.everyTwoDays => 'Every 2 days',
    CareFrequency.everyThreeDays => 'Every 3 days',
    CareFrequency.weekly => 'Weekly',
    CareFrequency.custom => 'Custom',
    CareFrequency.setDays => 'Set days',
  };

  int get intervalDays => switch (this) {
    CareFrequency.daily => 1,
    CareFrequency.everyTwoDays => 2,
    CareFrequency.everyThreeDays => 3,
    CareFrequency.weekly => 7,
    CareFrequency.custom => 1,
    CareFrequency.setDays => 1,
  };

  String toJson() => name;

  static CareFrequency fromJson(String value) {
    return CareFrequency.values.firstWhere((item) => item.name == value);
  }
}

enum TaskStatus {
  due,
  done,
  skipped;

  String get label => switch (this) {
    TaskStatus.due => 'Due',
    TaskStatus.done => 'Done',
    TaskStatus.skipped => 'Skipped',
  };

  String toJson() => name;

  static TaskStatus fromJson(String value) {
    return TaskStatus.values.firstWhere((item) => item.name == value);
  }
}
