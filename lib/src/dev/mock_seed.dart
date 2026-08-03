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
    final today = DateTime(refDate.year, refDate.month, refDate.day);
    final now = refDate.millisecondsSinceEpoch;

    if (clearExisting) {
      await db.delete(db.todoCompletions).go();
      await db.delete(db.todoTagMap).go();
      await db.delete(db.todoSubtasks).go();
      await db.delete(db.todoTags).go();
      await db.delete(db.todos).go();
      await db.delete(db.goals).go();
      await db.delete(db.medicationLogs).go();
      await db.delete(db.habitInstances).go();
      await db.delete(db.medications).go();
      await db.delete(db.habits).go();
    }

    // --- Habits ---
    final habits = [
      ('Morning Walk', ['mon', 'tue', 'wed', 'thu', 'fri'], '🚶', 0),
      ('Read 20 Min', ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], '📖', 1),
      ('Workout', ['mon', 'wed', 'fri'], '💪', 2),
    ];

    final habitIds = <String>[];
    for (var i = 0; i < habits.length; i++) {
      final habit = habits[i];
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
          emoji: Value(habit.$3),
          colorIndex: Value(habit.$4),
          reminderTime: const Value(null),
          createdAt: now,
          updatedAt: now,
          sortOrder: Value(i + 1),
        ),
      );
    }

    final habitStart = today.subtract(const Duration(days: 29));
    for (var d = 0; d < 30; d++) {
      final date = toIsoDate(habitStart.add(Duration(days: d)));
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

    // --- Goals (linked to seeded habits) ---
    await db.insertGoal(
      GoalsCompanion.insert(
        id: _uuid.v4(),
        userId: userId,
        title: '7-day walking streak',
        habitId: habitIds[0],
        targetDays: 7,
        rewardTitle: 'New walking shoes fund',
        rewardDescription: const Value(
          'Treat yourself to better shoes after a solid week.',
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertGoal(
      GoalsCompanion.insert(
        id: _uuid.v4(),
        userId: userId,
        title: 'Read for 14 days',
        habitId: habitIds[1],
        targetDays: 14,
        rewardTitle: 'Bookstore gift card',
        rewardDescription: const Value(
          'Pick up the next book on your list.',
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertGoal(
      GoalsCompanion.insert(
        id: _uuid.v4(),
        userId: userId,
        title: 'Workout consistency',
        habitId: habitIds[2],
        targetDays: 21,
        rewardTitle: 'Massage session',
        rewardDescription: const Value(
          'Recovery reward after three weeks of training.',
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // --- Medications ---
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
        sortOrder: const Value(1),
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
        sortOrder: const Value(2),
      ),
    );

    final medTimes = <String, List<String>>{
      medA: ['08:00'],
      medB: ['08:00', '20:00'],
    };

    final logsStart = today.subtract(const Duration(days: 13));
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

    // --- Todo tags ---
    final tagWork = _uuid.v4();
    final tagPersonal = _uuid.v4();
    final tagHealth = _uuid.v4();
    await db.insertTodoTag(
      TodoTagsCompanion.insert(
        id: tagWork,
        userId: userId,
        name: 'Work',
        colorIndex: const Value(0),
      ),
    );
    await db.insertTodoTag(
      TodoTagsCompanion.insert(
        id: tagPersonal,
        userId: userId,
        name: 'Personal',
        colorIndex: const Value(1),
      ),
    );
    await db.insertTodoTag(
      TodoTagsCompanion.insert(
        id: tagHealth,
        userId: userId,
        name: 'Health',
        colorIndex: const Value(2),
      ),
    );

    // --- Todos (overdue / today / upcoming / done / recurring) ---
    Future<String> insertTodo({
      required String title,
      String? notes,
      required String priority,
      required DateTime dueAt,
      bool allDay = false,
      String? recurrenceJson,
      bool nagEnabled = false,
      int nagIntervalMinutes = 15,
      String status = 'open',
      int? completedAt,
      bool isPinned = false,
      int sortOrder = 1,
      String emoji = '☑️',
      int colorIndex = 0,
      List<String> tagIds = const [],
      List<String> subtasks = const [],
    }) async {
      final id = _uuid.v4();
      await db.insertTodo(
        TodosCompanion.insert(
          id: id,
          userId: userId,
          title: title,
          notes: Value(notes),
          priority: Value(priority),
          dueAt: dueAt.millisecondsSinceEpoch,
          allDay: Value(allDay ? 1 : 0),
          recurrenceJson: Value(recurrenceJson),
          nagEnabled: Value(nagEnabled ? 1 : 0),
          nagIntervalMinutes: Value(nagIntervalMinutes),
          status: Value(status),
          completedAt: Value(completedAt),
          isPinned: Value(isPinned ? 1 : 0),
          sortOrder: Value(sortOrder),
          emoji: Value(emoji),
          colorIndex: Value(colorIndex),
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (tagIds.isNotEmpty) {
        await db.setTodoTags(id, tagIds);
      }
      for (var i = 0; i < subtasks.length; i++) {
        await db.insertTodoSubtask(
          TodoSubtasksCompanion.insert(
            id: _uuid.v4(),
            todoId: id,
            title: subtasks[i],
            completed: Value(i == 0 ? 1 : 0),
            sortOrder: Value(i + 1),
          ),
        );
      }
      return id;
    }

    // Overdue
    await insertTodo(
      title: 'Pay electricity bill',
      notes: 'Due last week — still open',
      priority: 'high',
      dueAt: today.subtract(const Duration(days: 2)).add(
        const Duration(hours: 10),
      ),
      isPinned: true,
      sortOrder: 1,
      emoji: '💰',
      colorIndex: 0,
      tagIds: [tagPersonal],
    );

    await insertTodo(
      title: 'Reply to dentist email',
      priority: 'medium',
      dueAt: today.subtract(const Duration(days: 1)).add(
        const Duration(hours: 14),
      ),
      sortOrder: 2,
      emoji: '✉️',
      colorIndex: 4,
      tagIds: [tagPersonal, tagHealth],
    );

    // Today
    await insertTodo(
      title: 'Ship habit tracker todos',
      notes: 'Finish review and polish UI',
      priority: 'high',
      dueAt: today.add(const Duration(hours: 17)),
      isPinned: true,
      sortOrder: 3,
      emoji: '🛠️',
      colorIndex: 5,
      tagIds: [tagWork],
      subtasks: [
        'Wire notifications',
        'Add calendar day view',
        'Seed sample data',
      ],
    );

    await insertTodo(
      title: 'Grocery run',
      priority: 'medium',
      dueAt: today.add(const Duration(hours: 19)),
      allDay: false,
      sortOrder: 4,
      emoji: '🛒',
      colorIndex: 2,
      tagIds: [tagPersonal],
      subtasks: ['Milk', 'Eggs', 'Oats'],
    );

    await insertTodo(
      title: 'Evening stretch',
      priority: 'low',
      dueAt: today.add(const Duration(hours: 21)),
      sortOrder: 5,
      emoji: '🧘',
      colorIndex: 7,
      tagIds: [tagHealth],
      recurrenceJson: jsonEncode({'freq': 'daily'}),
    );

    // Upcoming this week
    await insertTodo(
      title: 'Team standup notes',
      priority: 'medium',
      dueAt: today.add(const Duration(days: 1, hours: 9)),
      sortOrder: 6,
      emoji: '💼',
      colorIndex: 0,
      tagIds: [tagWork],
    );

    await insertTodo(
      title: 'Book flight for conference',
      notes: 'Compare morning vs evening flights',
      priority: 'high',
      dueAt: today.add(const Duration(days: 3, hours: 12)),
      sortOrder: 7,
      emoji: '✈️',
      colorIndex: 5,
      tagIds: [tagWork, tagPersonal],
    );

    await insertTodo(
      title: 'Weekly meal prep',
      priority: 'medium',
      dueAt: today.add(const Duration(days: 2, hours: 11)),
      allDay: true,
      sortOrder: 8,
      emoji: '🥗',
      colorIndex: 2,
      tagIds: [tagHealth],
      recurrenceJson: jsonEncode({
        'freq': 'weekly',
        'days': ['sun'],
      }),
      subtasks: ['Chop veggies', 'Cook protein', 'Portion containers'],
    );

    // Untagged (for "No tag" smart list)
    await insertTodo(
      title: 'Call landlord about lease',
      priority: 'high',
      dueAt: today.add(const Duration(days: 4, hours: 16)),
      sortOrder: 9,
      emoji: '📞',
      colorIndex: 3,
    );

    // Done today (shows on Home with strikethrough)
    final doneTodayId = await insertTodo(
      title: 'Submit weekly report',
      priority: 'medium',
      dueAt: today.add(const Duration(hours: 11)),
      status: 'done',
      completedAt: today
          .add(const Duration(hours: 10, minutes: 5))
          .millisecondsSinceEpoch,
      nagEnabled: false,
      sortOrder: 10,
      emoji: '🧾',
      colorIndex: 0,
      tagIds: [tagWork],
    );

    // Done earlier (still listed if due was recent)
    final doneTodoId = await insertTodo(
      title: 'Renew library card',
      priority: 'low',
      dueAt: today.subtract(const Duration(days: 1)).add(
        const Duration(hours: 11),
      ),
      status: 'done',
      completedAt: today
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 10, minutes: 20))
          .millisecondsSinceEpoch,
      nagEnabled: false,
      sortOrder: 11,
      emoji: '📚',
      colorIndex: 4,
      tagIds: [tagPersonal],
    );

    // Completion history across recent days (for History charts)
    await db.insertTodoCompletion(
      TodoCompletionsCompanion.insert(
        id: _uuid.v4(),
        todoId: doneTodayId,
        date: toIsoDate(today),
        completedAt: today
            .add(const Duration(hours: 10, minutes: 5))
            .millisecondsSinceEpoch,
      ),
    );

    for (var d = 0; d < 14; d++) {
      final day = today.subtract(Duration(days: d));
      final count = d == 0
          ? 0
          : (_rng.nextDouble() > 0.45 ? (_rng.nextInt(3) + 1) : 0);
      for (var i = 0; i < count; i++) {
        await db.insertTodoCompletion(
          TodoCompletionsCompanion.insert(
            id: _uuid.v4(),
            todoId: doneTodoId,
            date: toIsoDate(day),
            completedAt: day
                .add(Duration(hours: 9 + i, minutes: 10 * i))
                .millisecondsSinceEpoch,
          ),
        );
      }
    }
  }
}
