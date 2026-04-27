/// PRD: time buckets 6–7, 7–8, 8–9, 9–10, or custom; days Sun–Thu or custom.
enum CommuteTimeSlot {
  sixToSeven,
  sevenToEight,
  eightToNine,
  nineToTen,
  custom,
}

enum CommuteDayMode {
  sundayToThursday,
  custom,
}

class CommutePreferences {
  const CommutePreferences({
    required this.timeSlot,
    this.customTime,
    this.dayMode = CommuteDayMode.sundayToThursday,
    this.customWeekdays = const {},
  });

  final CommuteTimeSlot timeSlot;
  final DateTime? customTime; // time-of-day only; date ignored
  final CommuteDayMode dayMode;
  final Set<int> customWeekdays; // DateTime.monday = 1 … sunday = 7

  Map<String, dynamic> toJson() => {
        'timeSlot': timeSlot.name,
        'customHour': customTime?.hour,
        'customMinute': customTime?.minute,
        'dayMode': dayMode.name,
        'customWeekdays': customWeekdays.toList(),
      };

  static CommutePreferences? fromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    final slotName = m['timeSlot'] as String?;
    CommuteTimeSlot timeSlot;
    try {
      timeSlot = CommuteTimeSlot.values.firstWhere(
        (e) => e.name == slotName,
      );
    } on Object catch (_) {
      timeSlot = CommuteTimeSlot.sevenToEight;
    }
    final h = m['customHour'] as int?;
    final min = m['customMinute'] as int?;
    DateTime? custom;
    if (h != null && min != null) {
      final now = DateTime.now();
      custom = DateTime(now.year, now.month, now.day, h, min);
    }
    final dm = m['dayMode'] as String?;
    CommuteDayMode dayMode;
    try {
      dayMode = CommuteDayMode.values.firstWhere(
        (e) => e.name == dm,
      );
    } on Object catch (_) {
      dayMode = CommuteDayMode.sundayToThursday;
    }
    final wd = m['customWeekdays'] as List<dynamic>?;
    final customWeekdays = <int>{...?wd?.map((e) => (e as num).toInt())};
    return CommutePreferences(
      timeSlot: timeSlot,
      customTime: custom,
      dayMode: dayMode,
      customWeekdays: customWeekdays,
    );
  }
}
