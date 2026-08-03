// lib/src/db/app_db.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_db.g.dart';

// TABLES: habits, habit_instances, medications, medication_logs, goals
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get type => text()(); // 'end_of_day'/'timed'
  IntColumn get target => integer().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get recurrence =>
      text().nullable()(); // JSON encoded: {"days":["mon",...]}
  TextColumn get reminderTime => text().nullable()(); // HH:mm
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get isArchived => integer().withDefault(Constant(0))();
  TextColumn get emoji => text().withDefault(const Constant('✅'))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class HabitInstances extends Table {
  TextColumn get id => text()();
  TextColumn get habitId =>
      text().customConstraint('NOT NULL REFERENCES habits(id)')();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get completed => integer().withDefault(const Constant(0))();
  IntColumn get value => integer().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get updatedAt => integer()();
  IntColumn get synced => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Medications extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get dosage => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get timesJson => text()(); // JSON encoded: ["08:00","21:00"]
  IntColumn get isArchived => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class MedicationLogs extends Table {
  TextColumn get id => text()();
  TextColumn get medicationId =>
      text().customConstraint('NOT NULL REFERENCES medications(id)')();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get time => text()(); // HH:mm
  TextColumn get status => text()(); // taken | snoozed | skipped
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get habitId => text()();
  IntColumn get targetDays => integer()();
  TextColumn get rewardTitle => text()();
  TextColumn get rewardDescription => text().nullable()();
  TextColumn get rewardImageUrl => text().nullable()();
  IntColumn get isArchived => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get priority =>
      text().withDefault(const Constant('medium'))(); // low | medium | high
  IntColumn get dueAt => integer()(); // epoch ms
  IntColumn get allDay => integer().withDefault(const Constant(0))();
  TextColumn get recurrenceJson => text().nullable()();
  TextColumn get recurrenceParentId => text().nullable()();
  IntColumn get nagEnabled => integer().withDefault(const Constant(1))();
  IntColumn get nagIntervalMinutes =>
      integer().withDefault(const Constant(15))();
  TextColumn get status =>
      text().withDefault(const Constant('open'))(); // open | done | dismissed
  IntColumn get completedAt => integer().nullable()();
  IntColumn get isPinned => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get isArchived => integer().withDefault(const Constant(0))();
  TextColumn get emoji => text().withDefault(const Constant('☑️'))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class TodoSubtasks extends Table {
  TextColumn get id => text()();
  TextColumn get todoId =>
      text().customConstraint('NOT NULL REFERENCES todos(id)')();
  TextColumn get title => text()();
  IntColumn get completed => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class TodoTags extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class TodoTagMap extends Table {
  TextColumn get todoId =>
      text().customConstraint('NOT NULL REFERENCES todos(id)')();
  TextColumn get tagId =>
      text().customConstraint('NOT NULL REFERENCES todo_tags(id)')();

  @override
  Set<Column> get primaryKey => {todoId, tagId};
}

class TodoCompletions extends Table {
  TextColumn get id => text()();
  TextColumn get todoId =>
      text().customConstraint('NOT NULL REFERENCES todos(id)')();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get completedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Habits,
    HabitInstances,
    Medications,
    MedicationLogs,
    Goals,
    Todos,
    TodoSubtasks,
    TodoTags,
    TodoTagMap,
    TodoCompletions,
  ],
)
class AppDb extends _$AppDb {
  AppDb._(super.e);

  static Future<AppDb> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'app_db.sqlite'));
    return AppDb._(NativeDatabase(file));
  }

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(medications);
        await m.createTable(medicationLogs);
      }
      if (from < 3) {
        await m.addColumn(habits, habits.sortOrder);
        await m.addColumn(medications, medications.sortOrder);
        await customStatement(
          'UPDATE habits SET sort_order = created_at WHERE sort_order = 0',
        );
        await customStatement(
          'UPDATE medications SET sort_order = created_at WHERE sort_order = 0',
        );
      }
      if (from < 4) {
        await m.addColumn(habits, habits.reminderTime);
      }
      if (from < 5) {
        await customStatement(
          "ALTER TABLE habits ADD COLUMN emoji TEXT NOT NULL DEFAULT '✅'",
        );
        await customStatement(
          'ALTER TABLE habits ADD COLUMN color_index INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 6) {
        await m.createTable(goals);
      }
      if (from < 7) {
        await m.createTable(todos);
        await m.createTable(todoSubtasks);
        await m.createTable(todoTags);
        await m.createTable(todoTagMap);
        await m.createTable(todoCompletions);
      }
      if (from < 8) {
        await customStatement(
          "ALTER TABLE todos ADD COLUMN emoji TEXT NOT NULL DEFAULT '☑️'",
        );
        await customStatement(
          'ALTER TABLE todos ADD COLUMN color_index INTEGER NOT NULL DEFAULT 0',
        );
      }
    },
  );

  // HABIT CRUD
  Future<void> insertHabit(Insertable<Habit> habit) =>
      into(habits).insert(habit);
  Future<List<Habit>> getAllHabits(String userId) =>
      (select(habits)
            ..where((h) => h.isArchived.equals(0))
            ..orderBy([
              (h) => OrderingTerm(expression: h.sortOrder),
              (h) => OrderingTerm(expression: h.createdAt),
            ]))
          .get();

  Future<bool> updateHabitEntry(Insertable<Habit> h) =>
      update(habits).replace(h);

  // GOAL CRUD
  Future<void> insertGoal(Insertable<Goal> goal) => into(goals).insert(goal);

  Future<List<Goal>> getAllGoals(String userId) =>
      (select(goals)
            ..where((g) => g.userId.equals(userId) & g.isArchived.equals(0))
            ..orderBy([
              (g) => OrderingTerm(expression: g.createdAt),
            ]))
          .get();

  Future<bool> updateGoalEntry(Insertable<Goal> goal) =>
      update(goals).replace(goal);

  Future<int> archiveGoal(String id) =>
      (update(goals)..where((t) => t.id.equals(id))).write(
        GoalsCompanion(isArchived: const Value(1)),
      );

  Future<int> archiveHabit(String id) =>
      (update(habits)..where((t) => t.id.equals(id))).write(
        HabitsCompanion(isArchived: const Value(1)),
      );

  Future<int> getNextHabitSortOrder() async {
    final expr = habits.sortOrder.max();
    final query = selectOnly(habits)..addColumns([expr]);
    final row = await query.getSingleOrNull();
    final maxOrder = row?.read(expr) ?? 0;
    return maxOrder + 1;
  }

  Future<void> reorderHabits(List<String> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(habits)..where((h) => h.id.equals(orderedIds[i]))).write(
          HabitsCompanion(sortOrder: Value(i + 1)),
        );
      }
    });
  }

  // HABIT INSTANCES
  Future<HabitInstance?> getInstance(String habitId, String date) =>
      (select(habitInstances)
            ..where((i) => i.habitId.equals(habitId) & i.date.equals(date)))
          .getSingleOrNull();

  Future<List<HabitInstance>> getInstancesForDate(String date) {
    return (select(habitInstances)..where((i) => i.date.equals(date))).get();
  }

  Future<void> upsertInstance(Insertable<HabitInstance> instance) =>
      into(habitInstances).insertOnConflictUpdate(instance);

  Future<List<HabitInstance>> getInstancesForRange(
    String habitId,
    String startDate,
    String endDate,
  ) {
    return (select(habitInstances)
          ..where(
            (i) =>
                i.habitId.equals(habitId) &
                i.date.isBetweenValues(startDate, endDate),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .get();
  }

  Future<List<HabitInstance>> getInstancesForRangeAllHabits(
    String startDate,
    String endDate,
  ) {
    return (select(habitInstances)
          ..where((i) => i.date.isBetweenValues(startDate, endDate))
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .get();
  }

  // MEDICATIONS
  Future<void> insertMedication(Insertable<Medication> medication) =>
      into(medications).insert(medication);

  Future<List<Medication>> getAllMedications(String userId) =>
      (select(medications)
            ..where((m) => m.isArchived.equals(0))
            ..orderBy([
              (m) => OrderingTerm(expression: m.sortOrder),
              (m) => OrderingTerm(expression: m.createdAt),
            ]))
          .get();

  Future<int> archiveMedication(String id) =>
      (update(medications)..where((m) => m.id.equals(id))).write(
        const MedicationsCompanion(isArchived: Value(1)),
      );

  Future<int> getNextMedicationSortOrder() async {
    final expr = medications.sortOrder.max();
    final query = selectOnly(medications)..addColumns([expr]);
    final row = await query.getSingleOrNull();
    final maxOrder = row?.read(expr) ?? 0;
    return maxOrder + 1;
  }

  Future<void> reorderMedications(List<String> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(medications)..where((m) => m.id.equals(orderedIds[i])))
            .write(MedicationsCompanion(sortOrder: Value(i + 1)));
      }
    });
  }

  Future<bool> updateMedicationEntry(Insertable<Medication> m) =>
      update(medications).replace(m);

  Future<void> upsertMedicationLog(Insertable<MedicationLog> log) =>
      into(medicationLogs).insertOnConflictUpdate(log);

  Future<MedicationLog?> getMedicationLogFor(
    String medicationId,
    String date,
    String time,
  ) {
    return (select(medicationLogs)..where(
          (l) =>
              l.medicationId.equals(medicationId) &
              l.date.equals(date) &
              l.time.equals(time),
        ))
        .getSingleOrNull();
  }

  Future<List<MedicationLog>> getMedicationLogsForDate(String date) {
    return (select(medicationLogs)
          ..where((l) => l.date.equals(date))
          ..orderBy([(l) => OrderingTerm(expression: l.time)]))
        .get();
  }

  Future<List<MedicationLog>> getMedicationLogsForRange(
    String startDate,
    String endDate,
  ) {
    return (select(medicationLogs)
          ..where((l) => l.date.isBetweenValues(startDate, endDate))
          ..orderBy([
            (l) => OrderingTerm(expression: l.date),
            (l) => OrderingTerm(expression: l.time),
          ]))
        .get();
  }

  // TODOS
  Future<void> insertTodo(Insertable<Todo> todo) => into(todos).insert(todo);

  Future<List<Todo>> getAllTodos(String userId) =>
      (select(todos)
            ..where((t) => t.userId.equals(userId) & t.isArchived.equals(0))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.isPinned,
                mode: OrderingMode.desc,
              ),
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.dueAt),
            ]))
          .get();

  Future<Todo?> getTodoById(String id) =>
      (select(todos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> updateTodoEntry(Insertable<Todo> todo) =>
      update(todos).replace(todo);

  Future<int> archiveTodo(String id) =>
      (update(todos)..where((t) => t.id.equals(id))).write(
        const TodosCompanion(isArchived: Value(1)),
      );

  Future<int> getNextTodoSortOrder() async {
    final expr = todos.sortOrder.max();
    final query = selectOnly(todos)..addColumns([expr]);
    final row = await query.getSingleOrNull();
    final maxOrder = row?.read(expr) ?? 0;
    return maxOrder + 1;
  }

  Future<void> reorderTodos(List<String> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(todos)..where((t) => t.id.equals(orderedIds[i]))).write(
          TodosCompanion(sortOrder: Value(i + 1)),
        );
      }
    });
  }

  Future<List<Todo>> getOpenTodos(String userId) =>
      (select(todos)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.isArchived.equals(0) &
                  t.status.equals('open'),
            )
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.isPinned,
                mode: OrderingMode.desc,
              ),
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.dueAt),
            ]))
          .get();

  // TODO SUBTASKS
  Future<void> insertTodoSubtask(Insertable<TodoSubtask> subtask) =>
      into(todoSubtasks).insert(subtask);

  Future<List<TodoSubtask>> getSubtasksForTodo(String todoId) =>
      (select(todoSubtasks)
            ..where((s) => s.todoId.equals(todoId))
            ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
          .get();

  Future<bool> updateTodoSubtaskEntry(Insertable<TodoSubtask> subtask) =>
      update(todoSubtasks).replace(subtask);

  Future<int> deleteSubtasksForTodo(String todoId) =>
      (delete(todoSubtasks)..where((s) => s.todoId.equals(todoId))).go();

  Future<int> deleteTodoSubtask(String id) =>
      (delete(todoSubtasks)..where((s) => s.id.equals(id))).go();

  // TODO TAGS
  Future<void> insertTodoTag(Insertable<TodoTag> tag) =>
      into(todoTags).insert(tag);

  Future<List<TodoTag>> getAllTodoTags(String userId) =>
      (select(todoTags)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();

  Future<TodoTag?> getTodoTagById(String id) =>
      (select(todoTags)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> deleteTodoTag(String id) async {
    await (delete(todoTagMap)..where((m) => m.tagId.equals(id))).go();
    return (delete(todoTags)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setTodoTags(String todoId, List<String> tagIds) async {
    await transaction(() async {
      await (delete(todoTagMap)..where((m) => m.todoId.equals(todoId))).go();
      for (final tagId in tagIds) {
        await into(todoTagMap).insert(
          TodoTagMapCompanion.insert(todoId: todoId, tagId: tagId),
        );
      }
    });
  }

  Future<List<TodoTag>> getTagsForTodo(String todoId) {
    final query = select(todoTags).join([
      innerJoin(
        todoTagMap,
        todoTagMap.tagId.equalsExp(todoTags.id),
      ),
    ])..where(todoTagMap.todoId.equals(todoId));
    return query.map((row) => row.readTable(todoTags)).get();
  }

  Future<List<String>> getTodoIdsForTag(String tagId) async {
    final rows = await (select(
      todoTagMap,
    )..where((m) => m.tagId.equals(tagId))).get();
    return rows.map((r) => r.todoId).toList();
  }

  Future<Set<String>> getTodoIdsWithAnyTag(String userId) async {
    final rows = await select(todoTagMap).get();
    return rows.map((r) => r.todoId).toSet();
  }

  // TODO COMPLETIONS
  Future<void> insertTodoCompletion(Insertable<TodoCompletion> completion) =>
      into(todoCompletions).insert(completion);

  Future<List<TodoCompletion>> getTodoCompletionsForRange(
    String startDate,
    String endDate,
  ) {
    return (select(todoCompletions)
          ..where((c) => c.date.isBetweenValues(startDate, endDate))
          ..orderBy([(c) => OrderingTerm(expression: c.date)]))
        .get();
  }

  Future<List<TodoCompletion>> getTodoCompletionsForTodo(
    String todoId,
    String startDate,
    String endDate,
  ) {
    return (select(todoCompletions)
          ..where(
            (c) =>
                c.todoId.equals(todoId) &
                c.date.isBetweenValues(startDate, endDate),
          )
          ..orderBy([(c) => OrderingTerm(expression: c.date)]))
        .get();
  }

  Future<int> deleteTodoCompletionsForTodoOnDate(
    String todoId,
    String date,
  ) {
    return (delete(todoCompletions)..where(
          (c) => c.todoId.equals(todoId) & c.date.equals(date),
        ))
        .go();
  }
}