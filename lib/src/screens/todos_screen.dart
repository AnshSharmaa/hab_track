import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers.dart';
import '../repositories/todo_repository.dart';
import '../services/todo_notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/habit_colors.dart';
import '../widgets/centered_emoji.dart';
import 'add_todo_screen.dart';

class TodosScreen extends ConsumerStatefulWidget {
  const TodosScreen({super.key});

  @override
  ConsumerState<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends ConsumerState<TodosScreen> {
  bool _calendarMode = false;
  TodoSmartList _smartList = TodoSmartList.all;
  String? _tagFilterId;
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final todosAsync = ref.watch(todosProvider);
    final tagsAsync = ref.watch(todoTagsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isPhone ? 16 : 28,
                isPhone ? 18 : 36,
                isPhone ? 16 : 28,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TODOS',
                          style: AppTextStyles.eyebrow,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tasks & reminders',
                          style: AppTextStyles.title.copyWith(fontSize: isPhone ? 22 : 26),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AddButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddTodoScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: isPhone ? 14 : 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 28),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeToggle(
                      calendarMode: _calendarMode,
                      onChanged: (v) => setState(() => _calendarMode = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 28),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected:
                        _smartList == TodoSmartList.all && _tagFilterId == null,
                    onTap: () => setState(() {
                      _smartList = TodoSmartList.all;
                      _tagFilterId = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'This week',
                    selected: _smartList == TodoSmartList.thisWeek,
                    onTap: () => setState(() {
                      _smartList = TodoSmartList.thisWeek;
                      _tagFilterId = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'High priority',
                    selected: _smartList == TodoSmartList.highPriority,
                    onTap: () => setState(() {
                      _smartList = TodoSmartList.highPriority;
                      _tagFilterId = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'No tag',
                    selected: _smartList == TodoSmartList.noTag,
                    onTap: () => setState(() {
                      _smartList = TodoSmartList.noTag;
                      _tagFilterId = null;
                    }),
                  ),
                  ...tagsAsync.maybeWhen(
                    data: (tags) => tags.expand(
                      (tag) => [
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: tag.name,
                          selected: _tagFilterId == tag.id,
                          onTap: () => setState(() {
                            _tagFilterId = tag.id;
                            _smartList = TodoSmartList.all;
                          }),
                        ),
                      ],
                    ),
                    orElse: () => const <Widget>[],
                  ),
                ],
              ),
            ),
            SizedBox(height: isPhone ? 12 : 16),
            Expanded(
              child: todosAsync.when(
                data: (all) {
                  if (_calendarMode) {
                    return _CalendarView(
                      all: all,
                      selectedDay: _selectedDay,
                      onSelectDay: (d) => setState(() => _selectedDay = d),
                      smartList: _smartList,
                      tagFilterId: _tagFilterId,
                      onComplete: _complete,
                      onTogglePin: _togglePin,
                      onToggleSubtask: _toggleSubtask,
                      onEdit: _edit,
                      onDelete: _delete,
                      onReopen: _reopen,
                    );
                  }
                  return _ListViewBody(
                    all: all,
                    smartList: _smartList,
                    tagFilterId: _tagFilterId,
                    onReorder: _reorder,
                    onComplete: _complete,
                    onTogglePin: _togglePin,
                    onToggleSubtask: _toggleSubtask,
                    onEdit: _edit,
                    onDelete: _delete,
                    onReopen: _reopen,
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                error: (_, _) => const Center(
                  child: Text(
                    'Could not load todos.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete(TodoWithDetails item) async {
    HapticFeedback.lightImpact();
    final repo = await ref.read(todoRepositoryProvider.future);
    final updated = await repo.completeTodo(item.todo.id);
    await TodoNotificationService.instance.cancelTodo(item.todo);
    if (updated.status == 'open') {
      await TodoNotificationService.instance.scheduleTodo(updated);
    }
    _invalidate();
  }

  Future<void> _reopen(TodoWithDetails item) async {
    final repo = await ref.read(todoRepositoryProvider.future);
    await repo.reopenTodo(item.todo.id);
    final details = await repo.getTodoDetails(item.todo.id);
    if (details != null) {
      await TodoNotificationService.instance.scheduleTodo(details.todo);
    }
    _invalidate();
  }

  Future<void> _togglePin(TodoWithDetails item) async {
    final repo = await ref.read(todoRepositoryProvider.future);
    await repo.setPinned(item.todo.id, item.todo.isPinned != 1);
    _invalidate();
  }

  Future<void> _toggleSubtask(String subtaskId, bool completed) async {
    HapticFeedback.selectionClick();
    final repo = await ref.read(todoRepositoryProvider.future);
    await repo.toggleSubtask(subtaskId, completed);
    _invalidate();
  }

  Future<void> _delete(TodoWithDetails item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete todo?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "${item.todo.title}"?',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = await ref.read(todoRepositoryProvider.future);
    await TodoNotificationService.instance.cancelTodo(item.todo);
    await repo.deleteTodo(item.todo.id);
    _invalidate();
  }

  Future<void> _edit(TodoWithDetails item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddTodoScreen(existing: item)),
    );
    _invalidate();
  }

  Future<void> _reorder(List<TodoWithDetails> items, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = [...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final repo = await ref.read(todoRepositoryProvider.future);
    await repo.reorderTodos(reordered.map((t) => t.todo.id).toList());
    _invalidate();
  }

  void _invalidate() {
    ref.invalidate(todosProvider);
    ref.invalidate(homeTodosProvider);
    ref.invalidate(homeOverviewProvider);
    ref.invalidate(todoHistoryProvider(30));
  }
}

List<TodoWithDetails> _applyFilter(
  List<TodoWithDetails> all,
  TodoSmartList smartList,
  String? tagFilterId,
) {
  if (tagFilterId != null) {
    return all.where((t) => t.tags.any((tag) => tag.id == tagFilterId)).toList();
  }
  switch (smartList) {
    case TodoSmartList.all:
      return all;
    case TodoSmartList.thisWeek:
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final nextMonday = monday.add(const Duration(days: 7));
      return all.where((t) {
        if (t.todo.status != 'open') return false;
        final due = DateTime.fromMillisecondsSinceEpoch(t.todo.dueAt);
        return !due.isBefore(monday) && due.isBefore(nextMonday);
      }).toList();
    case TodoSmartList.highPriority:
      return all
          .where((t) => t.todo.status == 'open' && t.todo.priority == 'high')
          .toList();
    case TodoSmartList.noTag:
      return all
          .where((t) => t.todo.status == 'open' && t.tags.isEmpty)
          .toList();
  }
}

class _ListViewBody extends StatelessWidget {
  const _ListViewBody({
    required this.all,
    required this.smartList,
    required this.tagFilterId,
    required this.onReorder,
    required this.onComplete,
    required this.onTogglePin,
    required this.onToggleSubtask,
    required this.onEdit,
    required this.onDelete,
    required this.onReopen,
  });

  final List<TodoWithDetails> all;
  final TodoSmartList smartList;
  final String? tagFilterId;
  final Future<void> Function(List<TodoWithDetails>, int, int) onReorder;
  final Future<void> Function(TodoWithDetails) onComplete;
  final Future<void> Function(TodoWithDetails) onTogglePin;
  final Future<void> Function(String subtaskId, bool completed) onToggleSubtask;
  final Future<void> Function(TodoWithDetails) onEdit;
  final Future<void> Function(TodoWithDetails) onDelete;
  final Future<void> Function(TodoWithDetails) onReopen;

  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final filtered = _applyFilter(all, smartList, tagFilterId);

    if (filtered.isEmpty) {
      return const _EmptyState();
    }

    final useSections =
        smartList == TodoSmartList.all && tagFilterId == null;

    if (!useSections) {
      return ReorderableListView.builder(
        padding: EdgeInsets.fromLTRB(
          isPhone ? 12 : 24,
          0,
          isPhone ? 12 : 24,
          32,
        ),
        buildDefaultDragHandles: false,
        itemCount: filtered.length,
        onReorder: (o, n) => onReorder(filtered, o, n),
        itemBuilder: (context, i) => Padding(
          key: ValueKey(filtered[i].todo.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: _ReorderActivator(
            index: i,
            child: _TodoCard(
              item: filtered[i],
              onComplete: () => onComplete(filtered[i]),
              onTogglePin: () => onTogglePin(filtered[i]),
              onToggleSubtask: onToggleSubtask,
              onEdit: () => onEdit(filtered[i]),
              onDelete: () => onDelete(filtered[i]),
              onReopen: () => onReopen(filtered[i]),
            ),
          ),
        ),
      );
    }

    final overdue = <TodoWithDetails>[];
    final today = <TodoWithDetails>[];
    final upcoming = <TodoWithDetails>[];
    final done = <TodoWithDetails>[];
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (final t in filtered) {
      if (t.todo.status != 'open') {
        done.add(t);
        continue;
      }
      final due = DateTime.fromMillisecondsSinceEpoch(t.todo.dueAt);
      if (due.isBefore(dayStart)) {
        overdue.add(t);
      } else if (due.isBefore(dayEnd)) {
        today.add(t);
      } else {
        upcoming.add(t);
      }
    }

    final sections = <(String, List<TodoWithDetails>)>[
      if (overdue.isNotEmpty) ('Overdue', overdue),
      if (today.isNotEmpty) ('Today', today),
      if (upcoming.isNotEmpty) ('Upcoming', upcoming),
      if (done.isNotEmpty) ('Done', done),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isPhone ? 12 : 24,
        0,
        isPhone ? 12 : 24,
        32,
      ),
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              section.$1.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textSubtle,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          ...section.$2.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TodoCard(
                item: item,
                onComplete: () => onComplete(item),
                onTogglePin: () => onTogglePin(item),
                onToggleSubtask: onToggleSubtask,
                onEdit: () => onEdit(item),
                onDelete: () => onDelete(item),
                onReopen: () => onReopen(item),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.all,
    required this.selectedDay,
    required this.onSelectDay,
    required this.smartList,
    required this.tagFilterId,
    required this.onComplete,
    required this.onTogglePin,
    required this.onToggleSubtask,
    required this.onEdit,
    required this.onDelete,
    required this.onReopen,
  });

  final List<TodoWithDetails> all;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final TodoSmartList smartList;
  final String? tagFilterId;
  final Future<void> Function(TodoWithDetails) onComplete;
  final Future<void> Function(TodoWithDetails) onTogglePin;
  final Future<void> Function(String subtaskId, bool completed) onToggleSubtask;
  final Future<void> Function(TodoWithDetails) onEdit;
  final Future<void> Function(TodoWithDetails) onDelete;
  final Future<void> Function(TodoWithDetails) onReopen;

  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final weekStart = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    ).subtract(Duration(days: selectedDay.weekday - 1));
    final filtered = _applyFilter(all, smartList, tagFilterId);
    final dayItems = filtered.where((t) {
      final due = DateTime.fromMillisecondsSinceEpoch(t.todo.dueAt);
      return due.year == selectedDay.year &&
          due.month == selectedDay.month &&
          due.day == selectedDay.day;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isPhone ? 12 : 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: AppDecorations.glassCard(elevated: true),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => onSelectDay(
                        selectedDay.subtract(const Duration(days: 7)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy').format(selectedDay),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => onSelectDay(
                        selectedDay.add(const Duration(days: 7)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(7, (i) {
                    final day = weekStart.add(Duration(days: i));
                    final selected =
                        day.year == selectedDay.year &&
                        day.month == selectedDay.month &&
                        day.day == selectedDay.day;
                    final hasTodos = filtered.any((t) {
                      final due =
                          DateTime.fromMillisecondsSinceEpoch(t.todo.dueAt);
                      return due.year == day.year &&
                          due.month == day.month &&
                          due.day == day.day;
                    });
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onSelectDay(day),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: AppDecorations.glassChip(
                            selected: selected,
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('E').format(day).substring(0, 1),
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.accentSoft
                                      : AppColors.textSubtle,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasTodos
                                      ? AppColors.accent
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 28),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              DateFormat('EEEE, MMM d').format(selectedDay),
              style: const TextStyle(
                color: AppColors.textSubtle,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: dayItems.isEmpty
              ? const Center(
                  child: Text(
                    'No todos for this day.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    isPhone ? 12 : 24,
                    0,
                    isPhone ? 12 : 24,
                    32,
                  ),
                  itemCount: dayItems.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TodoCard(
                      item: dayItems[i],
                      onComplete: () => onComplete(dayItems[i]),
                      onTogglePin: () => onTogglePin(dayItems[i]),
                      onToggleSubtask: onToggleSubtask,
                      onEdit: () => onEdit(dayItems[i]),
                      onDelete: () => onDelete(dayItems[i]),
                      onReopen: () => onReopen(dayItems[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.item,
    required this.onComplete,
    required this.onTogglePin,
    required this.onEdit,
    required this.onDelete,
    required this.onReopen,
    this.onToggleSubtask,
  });

  final TodoWithDetails item;
  final VoidCallback onComplete;
  final VoidCallback onTogglePin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReopen;
  final Future<void> Function(String subtaskId, bool completed)? onToggleSubtask;

  static const _highPriorityColor = AppColors.highPriority;

  @override
  Widget build(BuildContext context) {
    final done = item.todo.status != 'open';
    final due = DateTime.fromMillisecondsSinceEpoch(item.todo.dueAt);
    final dueLabel = item.todo.allDay == 1
        ? DateFormat('MMM d').format(due)
        : DateFormat('MMM d · h:mm a').format(due);
    final accentColor = HabitColors.getColor(item.todo.colorIndex);
    final emoji = item.todo.emoji.isNotEmpty ? item.todo.emoji : '☑️';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: AppDecorations.glassCard(
        elevated: true,
      ).copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: done ? onReopen : onComplete,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accentColor.withValues(alpha: done ? 0.22 : 0.14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: done ? 0.5 : 0.35),
                    ),
                  ),
                  child: done
                      ? Icon(
                          Icons.check_rounded,
                          color: accentColor,
                          size: 18,
                        )
                      : CenteredEmoji(emoji, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.todo.isPinned == 1) ...[
                          const Icon(
                            Icons.push_pin_rounded,
                            size: 12,
                            color: AppColors.accentSoft,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            item.todo.title,
                            style: TextStyle(
                              color: done
                                  ? accentColor
                                  : AppColors.textPrimary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: accentColor.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dueLabel,
                      style: TextStyle(
                        color: item.isOverdue && !done
                            ? AppColors.danger
                            : AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.todo.priority == 'high')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: _highPriorityColor.withValues(alpha: 0.14),
                              border: Border.all(
                                color: _highPriorityColor.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: const Text(
                              'High',
                              style: TextStyle(
                                color: _highPriorityColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ...item.tags.map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: AppDecorations.glassChip(
                              selected: false,
                            ),
                            child: Text(
                              tag.name,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surface,
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSubtle,
                  size: 18,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'pin':
                      onTogglePin();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(
                      item.todo.isPinned == 1 ? 'Unpin' : 'Pin to top',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item.subtasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.completedSubtasks}/${item.subtasks.length} subtasks',
                    style: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...item.subtasks.map((subtask) {
                    final completed = subtask.completed == 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: onToggleSubtask == null
                            ? null
                            : () => onToggleSubtask!(
                                subtask.id,
                                !completed,
                              ),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Icon(
                              completed
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 18,
                              color: completed
                                  ? AppColors.success
                                  : AppColors.textSubtle,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                subtask.title,
                                style: TextStyle(
                                  color: completed
                                      ? AppColors.textSubtle
                                      : AppColors.textMuted,
                                  fontSize: 13,
                                  decoration: completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.calendarMode, required this.onChanged});

  final bool calendarMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: AppDecorations.glassCard(),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'List',
              icon: Icons.view_list_rounded,
              selected: !calendarMode,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Calendar',
              icon: Icons.calendar_view_week_rounded,
              selected: calendarMode,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: AppDecorations.glassChip(selected: selected),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.accentSoft : AppColors.textSubtle,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.accentSoft : AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: AppDecorations.glassChip(selected: selected),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accentSoft : AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: AppDecorations.glassChip(selected: true),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: AppColors.accentSoft),
            SizedBox(width: 4),
            Text(
              'Add todo',
              style: TextStyle(
                color: AppColors.accentSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceGlass,
              border: Border.all(color: AppColors.borderGlass),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.accentGlow,
                  blurRadius: 16,
                  spreadRadius: -6,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_box_outlined,
              size: 36,
              color: AppColors.textSubtle,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No todos yet',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a task with a due time and reminders.',
            style: TextStyle(color: AppColors.textSubtle, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ReorderActivator extends StatelessWidget {
  const _ReorderActivator({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(index: index, child: child);
  }
}
