import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import '../utils/date_utils.dart';

class MockSeed {
  MockSeed(this.db);

  final AppDb db;
  final _uuid = const Uuid();
  final _rng = Random(42);

  Future<void> insertMockData(
    String userId, {
    DateTime? anchorDate,
    bool clearExisting = true,
  }) async {
    final refDate = anchorDate ?? DateTime.now();
    final now = refDate.millisecondsSinceEpoch;

    if (clearExisting) {
      await db.delete(db.medicationLogs).go();
      await db.delete(db.habitInstances).go();
      await db.delete(db.medications).go();
      await db.delete(db.habits).go();
    }

    final habits = [
      ('Morning Walk', ['mon', 'tue', 'wed', 'thu', 'fri']),
      ('Read 20 Min', ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']),
      ('Workout', ['mon', 'wed', 'fri']),
    ];

    final habitIds = <String>[];
    for (final habit in habits) {
      final id = _uuid.v4();
      habitIds.add(id);
      await db.insertHabit(
        HabitsCompanion.insert(
          id: id,
          userId: userId,
          title: habit.$1,
          notes: const Value(null),
          type: 'end_of_day',
          target: const Value(1),
          unit: const Value('times'),
          recurrence: Value(jsonEncode(habit.$2)),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final start = DateTime(
      refDate.year,
      refDate.month,
      refDate.day,
    ).subtract(const Duration(days: 29));
    for (var d = 0; d < 30; d++) {
      final date = toIsoDate(start.add(Duration(days: d)));
      for (final habitId in habitIds) {
        final completed = _rng.nextDouble() > 0.3 ? 1 : 0;
        await db.upsertInstance(
          HabitInstancesCompanion.insert(
            id: _uuid.v4(),
            habitId: habitId,
            date: date,
            completed: Value(completed),
            note: Value(
              completed == 1 && _rng.nextDouble() > 0.85
                  ? 'Great consistency today.'
                  : null,
            ),
            updatedAt: now,
          ),
        );
      }
    }

    final medA = _uuid.v4();
    final medB = _uuid.v4();

    await db.insertMedication(
      MedicationsCompanion.insert(
        id: medA,
        userId: userId,
        name: 'Vitamin D',
        dosage: const Value('1 tablet'),
        notes: const Value('After breakfast'),
        timesJson: jsonEncode(['08:00']),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.insertMedication(
      MedicationsCompanion.insert(
        id: medB,
        userId: userId,
        name: 'Metformin',
        dosage: const Value('500mg'),
        notes: const Value('Morning and evening'),
        timesJson: jsonEncode(['08:00', '20:00']),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final medTimes = <String, List<String>>{
      medA: ['08:00'],
      medB: ['08:00', '20:00'],
    };

    final logsStart = DateTime(
      refDate.year,
      refDate.month,
      refDate.day,
    ).subtract(const Duration(days: 13));
    for (var d = 0; d < 14; d++) {
      final date = toIsoDate(logsStart.add(Duration(days: d)));
      for (final entry in medTimes.entries) {
        for (final time in entry.value) {
          final roll = _rng.nextDouble();
          final status = roll > 0.75
              ? 'skipped'
              : roll > 0.6
              ? 'snoozed'
              : 'taken';
          await db.upsertMedicationLog(
            MedicationLogsCompanion(
              id: Value(_uuid.v4()),
              medicationId: Value(entry.key),
              date: Value(date),
              time: Value(time),
              status: Value(status),
              updatedAt: Value(now),
            ),
          );
        }
      }
    }
  }
}
