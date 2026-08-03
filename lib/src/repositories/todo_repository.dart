import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import '../services/todo_notification_service.dart';
import '../utils/date_utils.dart';

enum TodoSmartList { all, thisWeek, highPriority, noTag }

class TodoWithDetails {
  const TodoWithDetails({
    required this.todo,
    required this.subtasks,
    required this.tags,
  });

  final Todo todo;
  final List<TodoSubtask> subtasks;
  final List<TodoTag> tags;

  int get completedSubtasks => subtasks.where((s) => s.completed == 1).length;

  bool get isOverdue {
    if (todo.status != 'open') return false;
    return todo.dueAt < DateTime.now().millisecondsSinceEpoch;
  }

  bool get isDueToday {
    final due = DateTime.fromMillisecondsSinceEpoch(todo.dueAt);
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }
}

class TodoRepository {
  TodoRepository(this.db);

  final AppDb db;
  final _uuid = const Uuid();

  Future<List<TodoWithDetails>> getAllTodosWithDetails(String userId) async {
    final todos = await db.getAllTodos(userId);
    return _attachDetails(todos);
  }

  Future<List<TodoWithDetails>> getOpenTodosWithDetails(String userId) async {
    final todos = await db.getOpenTodos(userId);
    return _attachDetails(todos);
  }

  Future<List<TodoWithDetails>> getTodosForSmartList(
    String userId,
    TodoSmartList list, {
    String? tagId,
  }) async {
    var items = await getAllTodosWithDetails(userId);
    if (tagId != null) {
      items = items.where((t) => t.tags.any((tag) => tag.id == tagId)).toList();
      return items;
    }

    switch (list) {
      case TodoSmartList.all:
        return items;
      case TodoSmartList.thisWeek:
        final range = _currentWeekRange();
        return items
            .where((t) {
              if (t.todo.status != 'open') return false;
              final due = DateTime.fromMillisecondsSinceEpoch(t.todo.dueAt);
              return !due.isBefore(range.$1) && due.isBefore(range.$2);
            })
            .toList();
      case TodoSmartList.highPriority:
        return items
            .where(
              (t) => t.todo.status == 'open' && t.todo.priority == 'high',
            )
            .toList();
      case TodoSmartList.noTag:
        return items
            .where((t) => t.todo.status == 'open' && t.tags.isEmpty)
            .toList();
    }
  }

  Future<List<TodoWithDetails>> getTodosForDate(
    String userId,
    DateTime date,
  ) async {
    final items = await getAllTodosWithDetails(userId);
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return items.where((t) {
      final due = DateTime.fromMillisecondsSinceEpoch(t.todo.dueAt);
      return !due.isBefore(dayStart) && due.isBefore(dayEnd);
    }).toList();
  }

  Future<List<TodoWithDetails>> getHomeTodos(String userId) async {
    final items = await getAllTodosWithDetails(userId);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = todayStart.add(const Duration(days: 1));
    final today = todayIso();
    final completedTodayIds = await getTodoIdsCompletedOn(today);
    final todayStartMs = todayStart.millisecondsSinceEpoch;
    final tomorrowMs = tomorrow.millisecondsSinceEpoch;

    final filtered = items.where((t) {
      final due = DateTime.fromMillisecondsSinceEpoch(t.todo.dueAt);
      final completedToday = completedTodayIds.contains(t.todo.id);

      // Still open and due today or overdue — show as pending
      // (unless already completed today via recurring roll-forward).
      if (t.todo.status == 'open') {
        if (completedToday) return true;
        return due.isBefore(tomorrow);
      }

      // Completed — keep on Home with strikethrough for the day.
      if (t.todo.status == 'done') {
        if (completedToday) return true;
        final completedAt = t.todo.completedAt;
        if (completedAt != null &&
            completedAt >= todayStartMs &&
            completedAt < tomorrowMs) {
          return true;
        }
        return due.isBefore(tomorrow);
      }

      return false;
    }).toList();

    filtered.sort((a, b) {
      final aDone =
          a.todo.status != 'open' || completedTodayIds.contains(a.todo.id)
          ? 1
          : 0;
      final bDone =
          b.todo.status != 'open' || completedTodayIds.contains(b.todo.id)
          ? 1
          : 0;
      if (aDone != bDone) return aDone.compareTo(bDone);
      if (a.todo.isPinned != b.todo.isPinned) {
        return b.todo.isPinned.compareTo(a.todo.isPinned);
      }
      return a.todo.sortOrder.compareTo(b.todo.sortOrder);
    });
    return filtered;
  }

  Future<Set<String>> getTodoIdsCompletedOn(String date) async {
    final rows = await db.getTodoCompletionsForRange(date, date);
    return rows.map((r) => r.todoId).toSet();
  }

  Future<TodoWithDetails?> getTodoDetails(String id) async {
    final todo = await db.getTodoById(id);
    if (todo == null || todo.isArchived == 1) return null;
    final subtasks = await db.getSubtasksForTodo(id);
    final tags = await db.getTagsForTodo(id);
    return TodoWithDetails(todo: todo, subtasks: subtasks, tags: tags);
  }

  Future<Todo> addTodo({
    required String userId,
    required String title,
    String? notes,
    String priority = 'medium',
    required DateTime dueAt,
    bool allDay = false,
    String? recurrenceJson,
    bool nagEnabled = true,
    int nagIntervalMinutes = 15,
    List<String> tagIds = const [],
    List<String> subtaskTitles = const [],
    bool isPinned = false,
    String emoji = '☑️',
    int colorIndex = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextSort = await db.getNextTodoSortOrder();
    final id = _uuid.v4();
    final companion = TodosCompanion.insert(
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
      status: const Value('open'),
      isPinned: Value(isPinned ? 1 : 0),
      sortOrder: Value(nextSort),
      emoji: Value(emoji),
      colorIndex: Value(colorIndex),
      createdAt: now,
      updatedAt: now,
    );
    await db.insertTodo(companion);
    await db.setTodoTags(id, tagIds);
    for (var i = 0; i < subtaskTitles.length; i++) {
      final titleText = subtaskTitles[i].trim();
      if (titleText.isEmpty) continue;
      await db.insertTodoSubtask(
        TodoSubtasksCompanion.insert(
          id: _uuid.v4(),
          todoId: id,
          title: titleText,
          sortOrder: Value(i + 1),
        ),
      );
    }
    return (await db.getTodoById(id))!;
  }

  Future<void> updateTodo({
    required Todo todo,
    required String title,
    String? notes,
    required String priority,
    required DateTime dueAt,
    required bool allDay,
    String? recurrenceJson,
    required bool nagEnabled,
    required int nagIntervalMinutes,
    required List<String> tagIds,
    required List<({String? id, String title, bool completed})> subtasks,
    bool? isPinned,
    String? emoji,
    int? colorIndex,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.updateTodoEntry(
      todo.copyWith(
        title: title,
        notes: Value(notes),
        priority: priority,
        dueAt: dueAt.millisecondsSinceEpoch,
        allDay: allDay ? 1 : 0,
        recurrenceJson: Value(recurrenceJson),
        nagEnabled: nagEnabled ? 1 : 0,
        nagIntervalMinutes: nagIntervalMinutes,
        isPinned: isPinned == null ? todo.isPinned : (isPinned ? 1 : 0),
        emoji: emoji ?? todo.emoji,
        colorIndex: colorIndex ?? todo.colorIndex,
        updatedAt: now,
      ),
    );
    await db.setTodoTags(todo.id, tagIds);

    final existing = await db.getSubtasksForTodo(todo.id);
    final keepIds = subtasks
        .where((s) => s.id != null)
        .map((s) => s.id!)
        .toSet();
    for (final old in existing) {
      if (!keepIds.contains(old.id)) {
        await db.deleteTodoSubtask(old.id);
      }
    }
    for (var i = 0; i < subtasks.length; i++) {
      final s = subtasks[i];
      final titleText = s.title.trim();
      if (titleText.isEmpty) continue;
      if (s.id != null) {
        final match = existing.where((e) => e.id == s.id).firstOrNull;
        if (match != null) {
          await db.updateTodoSubtaskEntry(
            match.copyWith(
              title: titleText,
              completed: s.completed ? 1 : 0,
              sortOrder: i + 1,
            ),
          );
        }
      } else {
        await db.insertTodoSubtask(
          TodoSubtasksCompanion.insert(
            id: _uuid.v4(),
            todoId: todo.id,
            title: titleText,
            completed: Value(s.completed ? 1 : 0),
            sortOrder: Value(i + 1),
          ),
        );
      }
    }
  }

  Future<void> deleteTodo(String todoId) async {
    await TodoNotificationService.instance.cancelTodoById(todoId);
    await db.deleteSubtasksForTodo(todoId);
    await db.setTodoTags(todoId, const []);
    await db.archiveTodo(todoId);
  }

  Future<void> setPinned(String todoId, bool pinned) async {
    final todo = await db.getTodoById(todoId);
    if (todo == null) return;
    await db.updateTodoEntry(
      todo.copyWith(
        isPinned: pinned ? 1 : 0,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> reorderTodos(List<String> orderedIds) =>
      db.reorderTodos(orderedIds);

  Future<Todo> completeTodo(String todoId) async {
    final todo = await db.getTodoById(todoId);
    if (todo == null) {
      throw StateError('Todo not found');
    }
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    // Always log against "today" so Home can keep the row with strikethrough.
    final date = todayIso();

    await db.insertTodoCompletion(
      TodoCompletionsCompanion.insert(
        id: _uuid.v4(),
        todoId: todoId,
        date: date,
        completedAt: nowMs,
      ),
    );

    final recurrence = todo.recurrenceJson;
    if (recurrence != null && recurrence.isNotEmpty) {
      final nextDue = nextOccurrence(
        from: DateTime.fromMillisecondsSinceEpoch(todo.dueAt),
        recurrenceJson: recurrence,
      );
      if (nextDue != null) {
        final updated = todo.copyWith(
          dueAt: nextDue.millisecondsSinceEpoch,
          status: 'open',
          completedAt: const Value(null),
          updatedAt: nowMs,
        );
        await db.updateTodoEntry(updated);
        return updated;
      }
    }

    final done = todo.copyWith(
      status: 'done',
      completedAt: Value(nowMs),
      updatedAt: nowMs,
    );
    await db.updateTodoEntry(done);
    return done;
  }

  Future<void> dismissTodo(String todoId) async {
    final todo = await db.getTodoById(todoId);
    if (todo == null) return;
    await db.updateTodoEntry(
      todo.copyWith(
        status: 'dismissed',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> reopenTodo(String todoId) async {
    final todo = await db.getTodoById(todoId);
    if (todo == null) return;
    final today = todayIso();
    await db.deleteTodoCompletionsForTodoOnDate(todoId, today);

    final now = DateTime.now();
    final todayDue = DateTime(
      now.year,
      now.month,
      now.day,
      DateTime.fromMillisecondsSinceEpoch(todo.dueAt).hour,
      DateTime.fromMillisecondsSinceEpoch(todo.dueAt).minute,
    );

    // If recurrence already rolled the due date forward, pull it back to today
    // so the item stays on Home as pending again.
    final due = DateTime.fromMillisecondsSinceEpoch(todo.dueAt);
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final shouldRestoreDue = !due.isBefore(tomorrow);

    await db.updateTodoEntry(
      todo.copyWith(
        status: 'open',
        completedAt: const Value(null),
        dueAt: shouldRestoreDue ? todayDue.millisecondsSinceEpoch : todo.dueAt,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> toggleSubtask(String subtaskId, bool completed) async {
    final rows = await (db.select(
      db.todoSubtasks,
    )..where((s) => s.id.equals(subtaskId))).get();
    if (rows.isEmpty) return;
    final s = rows.first;
    await db.updateTodoSubtaskEntry(
      s.copyWith(completed: completed ? 1 : 0),
    );
  }

  Future<List<TodoTag>> getAllTags(String userId) =>
      db.getAllTodoTags(userId);

  Future<TodoTag> createTag({
    required String userId,
    required String name,
    int colorIndex = 0,
  }) async {
    final id = _uuid.v4();
    await db.insertTodoTag(
      TodoTagsCompanion.insert(
        id: id,
        userId: userId,
        name: name.trim(),
        colorIndex: Value(colorIndex),
      ),
    );
    return (await db.getTodoTagById(id))!;
  }

  Future<void> deleteTag(String tagId) => db.deleteTodoTag(tagId);

  Future<List<TodoCompletion>> getCompletionsForRange(int days) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    return db.getTodoCompletionsForRange(toIsoDate(start), toIsoDate(end));
  }

  Future<Map<String, int>> getDailyCompletionCounts(int days) async {
    final completions = await getCompletionsForRange(days);
    final map = <String, int>{};
    for (final c in completions) {
      map[c.date] = (map[c.date] ?? 0) + 1;
    }
    return map;
  }

  Future<List<TodoWithDetails>> _attachDetails(List<Todo> todos) async {
    final result = <TodoWithDetails>[];
    for (final todo in todos) {
      final subtasks = await db.getSubtasksForTodo(todo.id);
      final tags = await db.getTagsForTodo(todo.id);
      result.add(
        TodoWithDetails(todo: todo, subtasks: subtasks, tags: tags),
      );
    }
    return result;
  }

  static (DateTime, DateTime) _currentWeekRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    return (monday, nextMonday);
  }

  static DateTime? nextOccurrence({
    required DateTime from,
    required String recurrenceJson,
  }) {
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(recurrenceJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final freq = decoded['freq'] as String? ?? 'daily';
    if (freq == 'daily') {
      return from.add(const Duration(days: 1));
    }
    if (freq == 'weekly') {
      final days = (decoded['days'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      if (days.isEmpty) {
        return from.add(const Duration(days: 7));
      }
      var cursor = from.add(const Duration(days: 1));
      for (var i = 0; i < 14; i++) {
        if (days.contains(weekdayKey(cursor))) {
          return DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
            from.hour,
            from.minute,
          );
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return null;
  }

  static String? encodeRecurrence({
    required String? freq,
    List<String>? days,
  }) {
    if (freq == null || freq.isEmpty || freq == 'none') return null;
    if (freq == 'daily') return jsonEncode({'freq': 'daily'});
    if (freq == 'weekly') {
      return jsonEncode({
        'freq': 'weekly',
        'days': days ?? const <String>[],
      });
    }
    return null;
  }

  static ({String freq, List<String> days}) decodeRecurrence(String? json) {
    if (json == null || json.isEmpty) {
      return (freq: 'none', days: const <String>[]);
    }
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final freq = decoded['freq'] as String? ?? 'none';
      final days = (decoded['days'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      return (freq: freq, days: days);
    } catch (_) {
      return (freq: 'none', days: const <String>[]);
    }
  }
}
