// lib/src/db/app_db.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_db.g.dart';

// TABLES: habits, habit_instances, medications, medication_logs
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

@DriftDatabase(tables: [Habits, HabitInstances, Medications, MedicationLogs])
class AppDb extends _$AppDb {
  AppDb._(super.e);

  static Future<AppDb> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'app_db.sqlite'));
    return AppDb._(NativeDatabase(file));
  }

  @override
  int get schemaVersion => 4;

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
}
