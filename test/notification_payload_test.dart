import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hab_track/src/services/app_notification_service.dart';

void main() {
  // Shapes mirror the payloads jsonEncode'd by scheduleMedicationDaily,
  // scheduleHabitDaily, scheduleTodoNagChain and scheduleSnooze.
  group('parseNotificationPayload', () {
    test('parses a complete medication payload', () {
      final payload = jsonEncode({
        'entityType': 'medication',
        'entityId': 'med-1',
        'time': '08:00',
        'title': 'Medication reminder',
        'body': 'Aspirin 100mg',
      });

      final parsed = parseNotificationPayload(payload);

      expect(parsed, isNotNull);
      expect(parsed!.entityType, 'medication');
      expect(parsed.entityId, 'med-1');
      expect(parsed.time, '08:00');
      expect(parsed.title, 'Medication reminder');
      expect(parsed.body, 'Aspirin 100mg');
      expect(parsed.nagInterval, 10); // default when absent
    });

    test('parses a habit payload', () {
      final parsed = parseNotificationPayload(
        jsonEncode({
          'entityType': 'habit',
          'entityId': 'habit-1',
          'time': '21:30',
          'title': 'End-of-day habit check-in',
          'body': 'Read a book',
        }),
      );

      expect(parsed, isNotNull);
      expect(parsed!.entityType, 'habit');
      expect(parsed.time, '21:30');
    });

    test('parses a todo payload with nagIntervalMinutes', () {
      final parsed = parseNotificationPayload(
        jsonEncode({
          'entityType': 'todo',
          'entityId': 'todo-1',
          'time': '1700000000000',
          'title': 'Todo reminder',
          'body': 'Buy milk',
          'nagIntervalMinutes': 15,
        }),
      );

      expect(parsed, isNotNull);
      expect(parsed!.entityType, 'todo');
      expect(parsed.nagInterval, 15);
    });

    test('truncates a double nagIntervalMinutes', () {
      final parsed = parseNotificationPayload(
        jsonEncode({
          'entityType': 'todo',
          'entityId': 'todo-1',
          'nagIntervalMinutes': 12.0,
        }),
      );

      expect(parsed!.nagInterval, 12);
    });

    test('returns null for null or empty payload', () {
      expect(parseNotificationPayload(null), isNull);
      expect(parseNotificationPayload(''), isNull);
    });

    test('returns null for malformed json instead of throwing', () {
      expect(parseNotificationPayload('{not json'), isNull);
      expect(parseNotificationPayload('["unexpected"]'), isNull);
    });

    test('returns null for non-object json', () {
      expect(parseNotificationPayload(jsonEncode(['todo-1'])), isNull);
      expect(parseNotificationPayload(jsonEncode('todo-1')), isNull);
      expect(parseNotificationPayload(jsonEncode(42)), isNull);
    });

    test('returns null when entityType or entityId is missing', () {
      expect(
        parseNotificationPayload(
          jsonEncode({'entityId': 'todo-1', 'time': '08:00'}),
        ),
        isNull,
      );
      expect(
        parseNotificationPayload(
          jsonEncode({'entityType': 'todo', 'time': '08:00'}),
        ),
        isNull,
      );
    });

    test('returns null when entityType or entityId is not a string', () {
      expect(
        parseNotificationPayload(
          jsonEncode({'entityType': 7, 'entityId': 'todo-1'}),
        ),
        isNull,
      );
      expect(
        parseNotificationPayload(
          jsonEncode({'entityType': 'todo', 'entityId': null}),
        ),
        isNull,
      );
    });

    test('applies defaults for missing optional fields', () {
      final parsed = parseNotificationPayload(
        jsonEncode({'entityType': 'medication', 'entityId': 'med-1'}),
      );

      expect(parsed, isNotNull);
      expect(parsed!.time, '');
      expect(parsed.title, 'Reminder');
      expect(parsed.body, '');
      expect(parsed.nagInterval, 10);
    });

    test('ignores non-string values in optional fields', () {
      final parsed = parseNotificationPayload(
        jsonEncode({
          'entityType': 'medication',
          'entityId': 'med-1',
          'time': 800,
          'title': 42,
          'body': true,
        }),
      );

      expect(parsed, isNotNull);
      expect(parsed!.time, '');
      expect(parsed.title, 'Reminder');
      expect(parsed.body, '');
    });
  });
}