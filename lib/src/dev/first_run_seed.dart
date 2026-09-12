import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';

/// ONE-TIME SEED FLAG
///
/// While this is `true`, the app seeds the starter todo list on first launch
/// (only if the todo table is empty). Once you've installed and opened the
/// seeded build on your device, set this to `false` — or delete this file and
/// the marked block in `lib/main.dart` — and rebuild a clean bundle.
/// Your data lives in SQLite on the device and survives the replacement.
const bool kFirstRunSeedEnabled = true;

/// Seeds the starter todos exactly once.
///
/// - Never clears or overwrites existing data.
/// - Skips itself if any todo already exists (one-time guard).
/// - All todos are created with nagEnabled = 0 (no nags / notifications).
class FirstRunSeed {
  FirstRunSeed(this.db);

  final AppDb db;
  final _uuid = const Uuid();

  static const List<String> _titles = [
    'Start usign YOUR OWN APPP!!!!',
    'Axis rewards points',
    'Gym',
    'DL',
    'Start getting fit',
    'new led light',
    'Buggu potfolio/CV',
    'personal fan',
    'buguuu phone',
    'Kashish cursor auto apply bot',
    'Sarthak birthday gift',
    'Golu birthday gift',
    'Mf',
    'Therapist buguuu',
    'cleanup',
    'meds',
    'clean table',
  ];

  Future<void> seedIfNeeded(String userId) async {
    final existing = await db.select(db.todos).get();
    if (existing.isNotEmpty) return; // Already seeded — do nothing.

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    // Due tonight, so everything shows up in Today on first launch.
    final dueAt = DateTime(
      now.year,
      now.month,
      now.day,
      21,
    ).millisecondsSinceEpoch;

    for (var i = 0; i < _titles.length; i++) {
      await db.insertTodo(
        TodosCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          title: _titles[i],
          notes: const Value(null),
          priority: const Value('medium'),
          dueAt: dueAt,
          allDay: const Value(1),
          recurrenceJson: const Value(null),
          // No nags on any todo.
          nagEnabled: const Value(0),
          nagIntervalMinutes: const Value(15),
          status: const Value('open'),
          completedAt: const Value(null),
          isPinned: const Value(0),
          sortOrder: Value(i + 1),
          emoji: const Value('☑️'),
          colorIndex: const Value(0),
          createdAt: nowMs,
          updatedAt: nowMs,
        ),
      );
    }
  }
}