class AppClock {
  AppClock._();

  static const jakartaOffset = Duration(hours: 7);

  static DateTime now({DateTime? utcNow}) {
    final jakarta = (utcNow ?? DateTime.timestamp()).toUtc().add(jakartaOffset);
    return DateTime.utc(
      jakarta.year,
      jakarta.month,
      jakarta.day,
      jakarta.hour,
      jakarta.minute,
      jakarta.second,
      jakarta.millisecond,
      jakarta.microsecond,
    );
  }

  static DateTime calendarDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
    if (match == null) {
      throw const FormatException('Tanggal transaksi tidak valid.');
    }
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static DateTime? parseJakartaTimestamp(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[T ]'
      r'(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?'
      r'(Z|[+-]\d{2}:?\d{2})?$',
    ).firstMatch(value);
    if (match == null) return null;

    final fraction = (match.group(7) ?? '').padRight(6, '0');
    final wallTime = DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6) ?? '0'),
      int.parse(fraction.substring(0, 3)),
      int.parse(fraction.substring(3, 6)),
    );
    final zone = match.group(8);
    if (zone == null) return wallTime;
    if (zone == 'Z') return wallTime.add(jakartaOffset);

    final digits = zone.substring(1).replaceAll(':', '');
    final zoneHours = int.parse(digits.substring(0, 2));
    final zoneMinutes = int.parse(digits.substring(2, 4));
    final zoneOffset = Duration(hours: zoneHours, minutes: zoneMinutes);
    final signedOffset = zone.startsWith('+') ? zoneOffset : -zoneOffset;
    return wallTime.subtract(signedOffset).add(jakartaOffset);
  }

  static String dateString(DateTime jakartaDate) =>
      '${jakartaDate.year.toString().padLeft(4, '0')}-'
      '${jakartaDate.month.toString().padLeft(2, '0')}-'
      '${jakartaDate.day.toString().padLeft(2, '0')}';

  static String timestampString(DateTime jakartaDate) =>
      '${dateString(jakartaDate)} '
      '${jakartaDate.hour.toString().padLeft(2, '0')}:'
      '${jakartaDate.minute.toString().padLeft(2, '0')}:'
      '${jakartaDate.second.toString().padLeft(2, '0')}';
}

/// Pagi starts right after midnight, matching everyday Indonesian usage
/// ("jam 3 pagi").
String greetingForJakartaTime(DateTime jakartaTime) {
  final hour = jakartaTime.hour;
  if (hour < 11) return 'Selamat Pagi';
  if (hour >= 11 && hour < 15) return 'Selamat Siang';
  if (hour >= 15 && hour < 19) return 'Selamat Sore';
  return 'Selamat Malam';
}
