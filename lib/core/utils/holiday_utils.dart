class HolidayInfo {
  final bool isHoliday;
  final bool isSunday;
  final bool isCustom;
  final String dateKey;
  final String title;
  final String reason;
  final String type;

  const HolidayInfo({
    required this.isHoliday,
    this.isSunday = false,
    this.isCustom = false,
    required this.dateKey,
    required this.title,
    required this.reason,
    required this.type,
  });
}

class HolidayUtils {
  static const Map<String, Map<String, String>> presetHolidays = {
    '01-01': {'title': "New Year's Day (नव वर्ष)", 'reason': 'Public Holiday', 'type': 'national'},
    '01-26': {'title': 'Republic Day (गणतंत्र दिवस)', 'reason': 'National Holiday', 'type': 'national'},
    '03-03': {'title': 'Holika Dahan (होलिका दहन)', 'reason': 'Festival Holiday', 'type': 'festival'},
    '03-04': {'title': 'Holi (धुलंडी / रंगों का त्योहार)', 'reason': 'Festival Holiday', 'type': 'festival'},
    '04-14': {'title': 'Ambedkar Jayanti (आंबेडकर जयंती)', 'reason': 'Gazetted Holiday', 'type': 'national'},
    '08-15': {'title': 'Independence Day (स्वतंत्रता दिवस)', 'reason': 'National Holiday', 'type': 'national'},
    '10-02': {'title': 'Gandhi Jayanti (गांधी जयंती)', 'reason': 'National Holiday', 'type': 'national'},
    '10-20': {'title': 'Dussehra / Vijayadashami (दशहरा)', 'reason': 'Festival Holiday', 'type': 'festival'},
    '11-08': {'title': 'Diwali / Deepavali (दीपावली)', 'reason': 'Festival Holiday', 'type': 'festival'},
    '11-09': {'title': 'Govardhan Puja (गोवर्धन पूजा)', 'reason': 'Festival Holiday', 'type': 'festival'},
    '11-10': {'title': 'Bhai Dooj (भाई दूज)', 'reason': 'Festival Holiday', 'type': 'festival'},
    '11-15': {'title': 'Chhath Puja (छठ पूजा - संध्या अर्घ्य)', 'reason': 'Festival Holiday', 'type': 'festival'},
    '11-16': {'title': 'Chhath Puja (छठ पूजा - प्रातः अर्घ्य)', 'reason': 'Festival Holiday', 'type': 'festival'},
    '12-25': {'title': 'Christmas Day (क्रिसमस)', 'reason': 'Festival Holiday', 'type': 'festival'},
  };

  static HolidayInfo? getHolidayInfo(DateTime date, [Map<String, dynamic>? customHolidays]) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final dateKey = '$y-$m-$d';
    final mdKey = '$m-$d';

    // 1. Custom declared holiday
    if (customHolidays != null && customHolidays.containsKey(dateKey)) {
      final custom = customHolidays[dateKey];
      final title = custom is Map ? (custom['title'] ?? 'School Holiday') : 'School Holiday';
      final reason = custom is Map ? (custom['reason'] ?? custom['cause'] ?? 'Declared by School Management') : 'Declared by School Management';
      return HolidayInfo(
        isHoliday: true,
        isSunday: false,
        isCustom: true,
        dateKey: dateKey,
        title: title.toString(),
        reason: reason.toString(),
        type: 'declared',
      );
    }

    // 2. Sunday check
    if (date.weekday == DateTime.sunday) {
      return HolidayInfo(
        isHoliday: true,
        isSunday: true,
        isCustom: false,
        dateKey: dateKey,
        title: 'Sunday (रविवार)',
        reason: 'Weekly Off / साप्ताहिक अवकाश',
        type: 'sunday',
      );
    }

    // 3. Preset calendar festival
    if (presetHolidays.containsKey(mdKey)) {
      final preset = presetHolidays[mdKey]!;
      return HolidayInfo(
        isHoliday: true,
        isSunday: false,
        isCustom: false,
        dateKey: dateKey,
        title: preset['title'] ?? 'Holiday',
        reason: preset['reason'] ?? 'Festival Holiday',
        type: preset['type'] ?? 'festival',
      );
    }

    return null;
  }
}

