import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../db/app_db.dart';
import '../utils/date_utils.dart';

class HabitStats {
  final int currentStreak;
  final int bestStreak;
  final double completionRate30d;

  const HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.completionRate30d,
  });
}

class HabitRepository {
  final AppDb db;
  final _uuid = const Uuid();

  HabitRepository(this.db);

  Future<List<Habit>> getAllHabits(String userId) => db.getAllHabits(userId);

  Future<List<Habit>> getTodayCompletedHabits(String userId) async {
    final habits = await getAllHabits(userId);
    final todayDate = todayIso();
    final weekday = weekdayKey(DateTime.now());
    final instances = await db.getInstancesForDate(todayDate);
    final instancesByHabit = {for (final i in instances) i.habitId: i};

    final completedHabits = <Habit>[];
    for (final habit in habits) {
      if (!isHabitScheduledOn(habit.recurrence, weekday)) continue;
      final instance = instancesByHabit[habit.id];
      if (instance != null && instance.completed == 1) {
        completedHabits.add(habit);
      }
    }
    return completedHabits;
  }

  Future<Habit> addHabit({
    required String userId,
    required String title,
    String? notes,
    List<String>? recurrenceDays,
    String habitType = 'end_of_day',
    String? reminderTime,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextSortOrder = await db.getNextHabitSortOrder();
    final recurrence = _encodeRecurrence(recurrenceDays);
    final habit = HabitsCompanion.insert(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      notes: Value(notes),
      type: habitType,
      target: Value(1),
      unit: Value('times'),
      recurrence: Value(recurrence),
      reminderTime: Value(reminderTime),
      createdAt: now,
      updatedAt: now,
      sortOrder: Value(nextSortOrder),
    );
    await db.insertHabit(habit);
    final all = await db.getAllHabits(userId);
    return all.firstWhere((h) => h.id == habit.id.value);
  }

  Future<void> updateHabit({
    required Habit habit,
    required String title,
    String? notes,
    List<String>? recurrenceDays,
    String? habitType,
    String? reminderTime,
  }) async {
    final updated = habit.copyWith(
      title: title,
      notes: Value(notes),
      type: habitType ?? habit.type,
      recurrence: Value(_encodeRecurrence(recurrenceDays)),
      reminderTime: Value(reminderTime),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.updateHabitEntry(updated);
  }

  Future<void> deleteHabit(String habitId) async {
    await db.archiveHabit(habitId);
  }

  Future<void> markHabitCompletionForToday(
    String habitId,
    bool completed,
  ) async {
    final date = todayIso();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.getInstance(habitId, date);
    if (existing != null) {
      await db.upsertInstance(
        existing.copyWith(completed: completed ? 1 : 0, updatedAt: now),
      );
      return;
    }
    await db.upsertInstance(
      HabitInstancesCompanion.insert(
        id: _uuid.v4(),
        habitId: habitId,
        date: date,
        completed: Value(completed ? 1 : 0),
        updatedAt: now,
      ),
    );
  }

  Future<void> toggleHabitInstance(String habitId, String date) async {
    final instance = await db.getInstance(habitId, date);
    if (instance != null) {
      final updated = instance.copyWith(
        completed: instance.completed == 1 ? 0 : 1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await db.upsertInstance(updated);
    } else {
      final newInstance = HabitInstancesCompanion.insert(
        id: _uuid.v4(),
        habitId: habitId,
        date: date,
        completed: Value(1),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await db.upsertInstance(newInstance);
    }
  }

  Future<void> reorderHabits(List<String> orderedIds) async {
    await db.reorderHabits(orderedIds);
  }

  Future<Map<String, HabitInstance?>> getTodayInstancesMap(
    String userId,
  ) async {
    final habits = await getAllHabits(userId);
    final instances = await db.getInstancesForDate(todayIso());
    final instancesByHabit = {for (final i in instances) i.habitId: i};
    final map = <String, HabitInstance?>{};
    for (final habit in habits) {
      map[habit.id] = instancesByHabit[habit.id];
    }
    return map;
  }

  Future<void> updateTodayNote({
    required String habitId,
    required String note,
  }) async {
    final date = todayIso();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.getInstance(habitId, date);
    if (existing != null) {
      await db.upsertInstance(
        existing.copyWith(note: Value(note), updatedAt: now),
      );
      return;
    }
    final newInstance = HabitInstancesCompanion.insert(
      id: _uuid.v4(),
      habitId: habitId,
      date: date,
      note: Value(note),
      completed: const Value(0),
      updatedAt: now,
    );
    await db.upsertInstance(newInstance);
  }

  Future<Map<String, HabitStats>> getHabitStats(
    String userId, {
    int lookbackDays = 30,
  }) async {
    final habits = await getAllHabits(userId);
    final today = DateTime.now();
    final start = today.subtract(Duration(days: lookbackDays - 1));
    final allInstances = await db.getInstancesForRangeAllHabits(
      toIsoDate(start),
      toIsoDate(today),
    );
    final instancesByHabit = <String, List<HabitInstance>>{};
    for (final instance in allInstances) {
      instancesByHabit
          .putIfAbsent(instance.habitId, () => <HabitInstance>[])
          .add(instance);
    }
    final stats = <String, HabitStats>{};

    for (final habit in habits) {
      final instances = instancesByHabit[habit.id] ?? const <HabitInstance>[];
      final completedDates = instances
          .where((i) => i.completed == 1)
          .map((i) => i.date)
          .toSet();
      final scheduledDates = _scheduledDates(habit.recurrence, start, today);
      stats[habit.id] = _calculateStats(scheduledDates, completedDates);
    }
    return stats;
  }

  Future<Map<String, List<HabitInstance>>> getHabitHistoryByDays(
    String userId,
    int days,
  ) async {
    final habits = await getAllHabits(userId);
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    final allInstances = await db.getInstancesForRangeAllHabits(
      toIsoDate(start),
      toIsoDate(end),
    );
    final out = {for (final habit in habits) habit.id: <HabitInstance>[]};
    for (final instance in allInstances) {
      final list = out[instance.habitId];
      if (list != null) {
        list.add(instance);
      }
    }
    return out;
  }

  HabitStats _calculateStats(
    List<String> scheduledDates,
    Set<String> completedDates,
  ) {
    if (scheduledDates.isEmpty) {
      return const HabitStats(
        currentStreak: 0,
        bestStreak: 0,
        completionRate30d: 0,
      );
    }

    var current = 0;
    for (var i = scheduledDates.length - 1; i >= 0; i--) {
      if (completedDates.contains(scheduledDates[i])) {
        current++;
      } else {
        break;
      }
    }

    var best = 0;
    var run = 0;
    for (final date in scheduledDates) {
      if (completedDates.contains(date)) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }

    final rate = completedDates.length / scheduledDates.length;
    return HabitStats(
      currentStreak: current,
      bestStreak: best,
      completionRate30d: rate,
    );
  }

  List<String> _scheduledDates(
    String? recurrenceJson,
    DateTime start,
    DateTime end,
  ) {
    final days = parseRecurrenceDays(recurrenceJson);
    final out = <String>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      if (days.contains(weekdayKey(cursor))) {
        out.add(toIsoDate(cursor));
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return out;
  }

  static String _encodeRecurrence(List<String>? recurrenceDays) {
    final normalized =
        (recurrenceDays == null || recurrenceDays.isEmpty)
              ? _allWeekdays
              : recurrenceDays
                    .map((d) => d.toLowerCase())
                    .where(_allWeekdays.contains)
                    .toSet()
                    .toList()
          ..sort();
    return jsonEncode(normalized);
  }

  static bool isHabitScheduledOn(String? recurrenceJson, String weekday) {
    return parseRecurrenceDays(recurrenceJson).contains(weekday.toLowerCase());
  }

  static Set<String> parseRecurrenceDays(String? recurrenceJson) {
    if (recurrenceJson == null || recurrenceJson.trim().isEmpty) {
      return _allWeekdays.toSet();
    }
    try {
      final decoded = jsonDecode(recurrenceJson);
      if (decoded is List) {
        final days = decoded
            .whereType<String>()
            .map((d) => d.toLowerCase())
            .where(_allWeekdays.contains)
            .toSet();
        if (days.isNotEmpty) return days;
      }
    } catch (_) {
      // Fallback to daily for malformed persisted recurrence data.
    }
    return _allWeekdays.toSet();
  }

  static const List<String> _allWeekdays = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];
}
