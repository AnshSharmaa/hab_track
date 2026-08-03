import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../db/app_db.dart';
import '../providers.dart';
import '../repositories/todo_repository.dart';
import '../services/todo_notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/habit_colors.dart';
import '../widgets/centered_emoji.dart';

class AddTodoScreen extends ConsumerStatefulWidget {
  const AddTodoScreen({super.key, this.existing});

  final TodoWithDetails? existing;

  @override
  ConsumerState<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends ConsumerState<AddTodoScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _subtaskController = TextEditingController();

  String _priority = 'medium';
  DateTime _dueDate = DateTime.now();
  TimeOfDay _dueTime = TimeOfDay.now();
  bool _allDay = false;
  bool _nagEnabled = true;
  int _nagInterval = 15;
  String _recurrenceFreq = 'none';
  final Set<String> _recurrenceDays = {};
  final Set<String> _selectedTagIds = {};
  final List<_SubtaskDraft> _subtasks = [];
  bool _saving = false;
  bool _pinned = false;
  String _selectedEmoji = '☑️';
  int _colorIndex = 0;
  bool _showEmojiPicker = false;

  static const _nagPresets = [5, 10, 15, 30, 60];
  static const _weekDays = [
    ('mon', 'Mon'),
    ('tue', 'Tue'),
    ('wed', 'Wed'),
    ('thu', 'Thu'),
    ('fri', 'Fri'),
    ('sat', 'Sat'),
    ('sun', 'Sun'),
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      final t = existing.todo;
      _titleController.text = t.title;
      _notesController.text = t.notes ?? '';
      _priority = t.priority;
      final due = DateTime.fromMillisecondsSinceEpoch(t.dueAt);
      _dueDate = DateTime(due.year, due.month, due.day);
      _dueTime = TimeOfDay(hour: due.hour, minute: due.minute);
      _allDay = t.allDay == 1;
      _nagEnabled = t.nagEnabled == 1;
      _nagInterval = t.nagIntervalMinutes;
      _pinned = t.isPinned == 1;
      _selectedEmoji = t.emoji;
      _colorIndex = t.colorIndex;
      final rec = TodoRepository.decodeRecurrence(t.recurrenceJson);
      _recurrenceFreq = rec.freq;
      _recurrenceDays.addAll(rec.days);
      _selectedTagIds.addAll(existing.tags.map((tag) => tag.id));
      for (final s in existing.subtasks) {
        _subtasks.add(
          _SubtaskDraft(id: s.id, title: s.title, completed: s.completed == 1),
        );
      }
    } else {
      final now = DateTime.now().add(const Duration(hours: 1));
      _dueDate = DateTime(now.year, now.month, now.day);
      _dueTime = TimeOfDay(hour: now.hour, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  DateTime get _combinedDue {
    if (_allDay) {
      return DateTime(_dueDate.year, _dueDate.month, _dueDate.day, 9, 0);
    }
    return DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final canSave = _titleController.text.trim().isNotEmpty;
    final tagsAsync = ref.watch(todoTagsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Todo',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderGlass),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isPhone ? 16 : 24,
          isPhone ? 16 : 24,
          isPhone ? 16 : 24,
          24,
        ),
        children: [
          const _SectionLabel('ICON & COLOR'),
          const SizedBox(height: 10),
          _EmojiColorPicker(
            selectedEmoji: _selectedEmoji,
            colorIndex: _colorIndex,
            expanded: _showEmojiPicker,
            onToggle: () =>
                setState(() => _showEmojiPicker = !_showEmojiPicker),
            onEmojiSelected: (e) {
              setState(() {
                _selectedEmoji = e;
                _showEmojiPicker = false;
              });
              HapticFeedback.selectionClick();
            },
            onColorSelected: (c) {
              setState(() => _colorIndex = c);
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(height: 20),
          const _SectionLabel('TODO DETAILS'),
          const SizedBox(height: 10),
          _DarkField(
            controller: _titleController,
            label: 'Title',
            placeholder: 'e.g. Call dentist, Pay rent…',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _DarkField(
            controller: _notesController,
            label: 'Notes',
            placeholder: 'Optional details…',
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          const _SectionLabel('PRIORITY'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['low', 'medium', 'high'].map((p) {
              final selected = _priority == p;
              return GestureDetector(
                onTap: () => setState(() => _priority = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: AppDecorations.glassChip(selected: selected),
                  child: Text(
                    p[0].toUpperCase() + p.substring(1),
                    style: TextStyle(
                      color: selected
                          ? AppColors.accentSoft
                          : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('DUE DATE & TIME'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('EEE, MMM d').format(_dueDate),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  label: _allDay ? 'All day' : _dueTime.format(context),
                  onTap: _allDay ? null : _pickTime,
                  muted: _allDay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ToggleRow(
            label: 'All day',
            value: _allDay,
            onChanged: (v) => setState(() => _allDay = v),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('RECURRENCE'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ('none', 'None'),
              ('daily', 'Daily'),
              ('weekly', 'Weekly'),
            ].map((e) {
              final selected = _recurrenceFreq == e.$1;
              return GestureDetector(
                onTap: () => setState(() => _recurrenceFreq = e.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: AppDecorations.glassChip(selected: selected),
                  child: Text(
                    e.$2,
                    style: TextStyle(
                      color: selected
                          ? AppColors.accentSoft
                          : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_recurrenceFreq == 'weekly') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weekDays.map((d) {
                final selected = _recurrenceDays.contains(d.$1);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _recurrenceDays.remove(d.$1);
                    } else {
                      _recurrenceDays.add(d.$1);
                    }
                  }),
                  child: Container(
                    width: 42,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: AppDecorations.glassChip(selected: selected),
                    child: Text(
                      d.$2,
                      style: TextStyle(
                        color: selected
                            ? AppColors.accentSoft
                            : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionLabel('REMINDERS'),
          const SizedBox(height: 10),
          _ToggleRow(
            label: 'Nag until done',
            value: _nagEnabled,
            onChanged: (v) => setState(() => _nagEnabled = v),
          ),
          if (_nagEnabled) ...[
            const SizedBox(height: 10),
            const Text(
              'Remind every',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _nagPresets.map((m) {
                final selected = _nagInterval == m;
                return GestureDetector(
                  onTap: () => setState(() => _nagInterval = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: AppDecorations.glassChip(selected: selected),
                    child: Text(
                      '${m}m',
                      style: TextStyle(
                        color: selected
                            ? AppColors.accentSoft
                            : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          _ToggleRow(
            label: 'Pin to top',
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('TAGS'),
          const SizedBox(height: 10),
          tagsAsync.when(
            data: (tags) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final selected = _selectedTagIds.contains(tag.id);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedTagIds.remove(tag.id);
                          } else {
                            _selectedTagIds.add(tag.id);
                          }
                        }),
                        onLongPress: () => _confirmDeleteTag(tag),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: AppDecorations.glassChip(
                            selected: selected,
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.accentSoft
                                  : AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _createTag,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: AppDecorations.glassCard(),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Create tag',
                          style: TextStyle(
                            color: AppColors.accentSoft,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('SUBTASKS'),
          const SizedBox(height: 10),
          ..._subtasks.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: AppDecorations.glassCard(),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(
                        () => _subtasks[i] = s.copyWith(
                          completed: !s.completed,
                        ),
                      ),
                      child: Icon(
                        s.completed
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 20,
                        color: s.completed
                            ? AppColors.success
                            : AppColors.textSubtle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          decoration: s.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSubtle,
                      ),
                      onPressed: () => setState(() => _subtasks.removeAt(i)),
                    ),
                  ],
                ),
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subtaskController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add a subtask…',
                    hintStyle: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceGlassSoft,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _addSubtask(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addSubtask,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: AppDecorations.glassChip(selected: true),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.accentSoft,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SaveButton(
            saving: _saving,
            enabled: canSave,
            label: widget.existing == null ? 'Save Todo' : 'Save Changes',
            onTap: _save,
          ),
        ],
      ),
    );
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(_SubtaskDraft(title: text));
      _subtaskController.clear();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            surface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            surface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _createTag() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'New tag',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Tag name',
            hintStyle: TextStyle(color: AppColors.textSubtle),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final repo = await ref.read(todoRepositoryProvider.future);
    final userId = ref.read(userIdProvider);
    final tag = await repo.createTag(userId: userId, name: name);
    ref.invalidate(todoTagsProvider);
    setState(() => _selectedTagIds.add(tag.id));
  }

  Future<void> _confirmDeleteTag(TodoTag tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete tag?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "${tag.name}" from all todos?',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = await ref.read(todoRepositoryProvider.future);
    await repo.deleteTag(tag.id);
    ref.invalidate(todoTagsProvider);
    setState(() => _selectedTagIds.remove(tag.id));
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(todoRepositoryProvider.future);
      final userId = ref.read(userIdProvider);
      final recurrence = TodoRepository.encodeRecurrence(
        freq: _recurrenceFreq,
        days: _recurrenceDays.toList(),
      );
      final notes = _notesController.text.trim();

      late Todo saved;
      if (widget.existing == null) {
        saved = await repo.addTodo(
          userId: userId,
          title: title,
          notes: notes.isEmpty ? null : notes,
          priority: _priority,
          dueAt: _combinedDue,
          allDay: _allDay,
          recurrenceJson: recurrence,
          nagEnabled: _nagEnabled,
          nagIntervalMinutes: _nagInterval,
          tagIds: _selectedTagIds.toList(),
          subtaskTitles: _subtasks.map((s) => s.title).toList(),
          isPinned: _pinned,
          emoji: _selectedEmoji,
          colorIndex: _colorIndex,
        );
      } else {
        await repo.updateTodo(
          todo: widget.existing!.todo,
          title: title,
          notes: notes.isEmpty ? null : notes,
          priority: _priority,
          dueAt: _combinedDue,
          allDay: _allDay,
          recurrenceJson: recurrence,
          nagEnabled: _nagEnabled,
          nagIntervalMinutes: _nagInterval,
          tagIds: _selectedTagIds.toList(),
          subtasks: _subtasks
              .map(
                (s) => (
                  id: s.id,
                  title: s.title,
                  completed: s.completed,
                ),
              )
              .toList(),
          isPinned: _pinned,
          emoji: _selectedEmoji,
          colorIndex: _colorIndex,
        );
        saved = (await repo.getTodoDetails(widget.existing!.todo.id))!.todo;
      }

      await TodoNotificationService.instance.cancelTodo(saved);
      await TodoNotificationService.instance.scheduleTodo(saved);

      ref.invalidate(todosProvider);
      ref.invalidate(homeTodosProvider);
      ref.invalidate(homeOverviewProvider);
      ref.invalidate(todoTagsProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save todo. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SubtaskDraft {
  const _SubtaskDraft({this.id, required this.title, this.completed = false});
  final String? id;
  final String title;
  final bool completed;

  _SubtaskDraft copyWith({String? title, bool? completed}) => _SubtaskDraft(
    id: id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
  );
}

class _EmojiColorPicker extends StatelessWidget {
  const _EmojiColorPicker({
    required this.selectedEmoji,
    required this.colorIndex,
    required this.expanded,
    required this.onToggle,
    required this.onEmojiSelected,
    required this.onColorSelected,
  });

  final String selectedEmoji;
  final int colorIndex;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<int> onColorSelected;

  @override
  Widget build(BuildContext context) {
    final currentColor = HabitColors.getColor(colorIndex);
    final emojis = [
      ...HabitColors.todoEmojis,
      ...HabitColors.defaultEmojis,
    ];
    return Container(
      decoration: AppDecorations.glassCard(),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: CenteredEmoji(selectedEmoji, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Choose icon & color',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textSubtle,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EMOJI',
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: emojis.map((e) {
                      final selected = selectedEmoji == e;
                      return GestureDetector(
                        onTap: () => onEmojiSelected(e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: selected
                                ? currentColor.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? currentColor.withValues(alpha: 0.5)
                                  : AppColors.borderGlass,
                            ),
                          ),
                          child: Center(child: CenteredEmoji(e, size: 16)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'COLOR',
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(
                      HabitColors.accentColors.length,
                      (i) => GestureDetector(
                        onTap: () => onColorSelected(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: HabitColors.getColor(i),
                            shape: BoxShape.circle,
                            border: colorIndex == i
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                            boxShadow: colorIndex == i
                                ? [
                                    BoxShadow(
                                      color: HabitColors.getColor(
                                        i,
                                      ).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    required this.label,
    required this.placeholder,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String placeholder;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          autofocus: autofocus,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(
              color: AppColors.textSubtle,
              fontSize: 15,
            ),
            filled: true,
            fillColor: AppColors.surfaceGlassSoft,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saving,
    required this.enabled,
    required this.label,
    required this.onTap,
  });
  final bool saving;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !saving;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.95)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: AppColors.accentGlow,
                    blurRadius: 16,
                    spreadRadius: -4,
                    offset: Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: Center(
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textSubtle,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: AppDecorations.glassCard(),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: muted ? AppColors.textSubtle : AppColors.accentSoft,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: muted ? AppColors.textSubtle : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: AppDecorations.glassCard(),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
            activeThumbColor: AppColors.accentSoft,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
