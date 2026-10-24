import 'package:dompetku/services/app_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Jakarta clock', () {
    test('uses UTC+7 and rolls to the next calendar day', () {
      final jakartaTime = AppClock.now(utcNow: DateTime.utc(2026, 10, 7, 17));

      expect(jakartaTime, DateTime.utc(2026, 10, 8));
      expect(AppClock.dateString(jakartaTime), '2026-10-08');
      expect(AppClock.timestampString(jakartaTime), '2026-10-08 00:00:00');
    });

    test(
      'serializes the selected Jakarta wall time without timezone changes',
      () {
        expect(
          AppClock.timestampString(DateTime.utc(2026, 10, 5, 23, 36, 12)),
          '2026-10-05 23:36:12',
        );
      },
    );

    test('formats greeting for all Jakarta day periods', () {
      expect(
        greetingForJakartaTime(DateTime.utc(2026, 10, 7, 8)),
        'Selamat Pagi 🌅',
      );
      expect(
        greetingForJakartaTime(DateTime.utc(2026, 10, 7, 12)),
        'Selamat Siang ☀️',
      );
      expect(
        greetingForJakartaTime(DateTime.utc(2026, 10, 7, 16)),
        'Selamat Sore 🌇',
      );
      expect(
        greetingForJakartaTime(DateTime.utc(2026, 10, 7, 21)),
        'Selamat Malam 🌙',
      );
      expect(
        greetingForJakartaTime(DateTime.utc(2026, 10, 7, 4)),
        'Selamat Malam 🌙',
      );
    });

    test('converts API timestamps to Jakarta without host timezone', () {
      expect(
        AppClock.parseJakartaTimestamp('2026-10-06T15:51:00.000Z'),
        DateTime.utc(2026, 10, 6, 22, 51),
      );
      expect(
        AppClock.parseJakartaTimestamp('2026-10-07T00:30:00+07:00'),
        DateTime.utc(2026, 10, 7, 0, 30),
      );
      expect(
        AppClock.parseJakartaTimestamp('2026-10-07T22:51:00'),
        DateTime.utc(2026, 10, 7, 22, 51),
      );
    });
  });
}
