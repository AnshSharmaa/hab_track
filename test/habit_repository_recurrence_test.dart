import 'package:flutter_test/flutter_test.dart';
import 'package:hab_track/src/repositories/habit_repository.dart';

void main() {
  group('HabitRepository recurrence parsing', () {
    test('falls back to daily on null recurrence', () {
      final days = HabitRepository.parseRecurrenceDays(null);
      expect(days.length, 7);
      expect(days.contains('mon'), true);
      expect(days.contains('sun'), true);
    });

    test('parses valid recurrence json', () {
      final days = HabitRepository.parseRecurrenceDays('["mon","wed","fri"]');
      expect(days, {'mon', 'wed', 'fri'});
    });

    test('falls back to daily on malformed recurrence json', () {
      final days = HabitRepository.parseRecurrenceDays('{"invalid":true}');
      expect(days.length, 7);
    });

    test('isHabitScheduledOn checks weekday membership', () {
      expect(HabitRepository.isHabitScheduledOn('["tue","thu"]', 'tue'), true);
      expect(HabitRepository.isHabitScheduledOn('["tue","thu"]', 'mon'), false);
    });
  });
}
