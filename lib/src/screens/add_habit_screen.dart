import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_db.dart';
import '../providers.dart';
import '../repositories/habit_repository.dart';
import '../services/habit_notification_service.dart';
import '../theme/app_theme.dart';

class AddHabitScreen extends ConsumerStatefulWidget {
  const AddHabitScreen({super.key, this.existingHabit});
  final Habit? existingHabit;

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final Set<String> _selectedDays = <String>{};
  String _habitType = 'end_of_day';
  TimeOfDay? _reminderTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingHabit;
    if (existing != null) {
      _titleController.text = existing.title;
      _notesController.text = existing.notes ?? '';
      _selectedDays
        ..clear()
        ..addAll(HabitRepository.parseRecurrenceDays(existing.recurrence));
      _habitType = (existing.type == 'timed' || existing.type == 'end_of_day')
          ? existing.type
          : 'end_of_day';
      _reminderTime =
          _parseTime(existing.reminderTime) ??
          (_habitType == 'end_of_day'
              ? const TimeOfDay(hour: 21, minute: 0)
              : null);
    } else {
      _selectedDays.addAll(const [
        'mon',
        'tue',
        'wed',
        'thu',
        'fri',
        'sat',
        'sun',
      ]);
      _habitType = 'end_of_day';
      _reminderTime = const TimeOfDay(hour: 21, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Habit',
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
          _SectionLabel('HABIT DETAILS'),
          const SizedBox(height: 10),
          _DarkField(
            controller: _titleController,
            label: 'What habit do you want to build?',
            placeholder: 'e.g. Drink water, Read 20 minutes…',
            autofocus: true,
          ),
          const SizedBox(height: 12),
          _DarkField(
            controller: _notesController,
            label: 'Notes',
            placeholder: 'Optional reminder or motivation…',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _SectionLabel('REMINDER TYPE'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DayChip(
                label: 'End of day check-in',
                selected: _habitType == 'end_of_day',
                onTap: () => setState(() {
                  _habitType = 'end_of_day';
                  _reminderTime ??= const TimeOfDay(hour: 21, minute: 0);
                }),
              ),
              _DayChip(
                label: 'Timed reminder',
                selected: _habitType == 'timed',
                onTap: () => setState(() {
                  _habitType = 'timed';
                  _reminderTime ??= const TimeOfDay(hour: 8, minute: 0);
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickReminderTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: AppDecorations.glassCard(),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.accentSoft,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _reminderTime == null
                        ? 'Set reminder time'
                        : 'Reminder: ${_fmt12(_reminderTime!)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel('REPEAT ON'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _weekdayOrder
                .map(
                  (day) => _DayChip(
                    label: _weekdayLabels[day]!,
                    selected: _selectedDays.contains(day),
                    onTap: () {
                      setState(() {
                        if (_selectedDays.contains(day)) {
                          if (_selectedDays.length > 1) {
                            _selectedDays.remove(day);
                          }
                        } else {
                          _selectedDays.add(day);
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          _SaveButton(
            saving: _saving,
            label: widget.existingHabit == null
                ? 'Create Habit'
                : 'Save Changes',
            onTap: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(habitRepositoryProvider.future);
      Habit? habitForNotification;
      if (widget.existingHabit == null) {
        final userId = ref.read(userIdProvider);
        habitForNotification = await repo.addHabit(
          userId: userId,
          title: title,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          recurrenceDays: _selectedDays.toList(),
          habitType: _habitType,
          reminderTime: _reminderTime == null ? null : _fmt24(_reminderTime!),
        );
      } else {
        final oldHabit = widget.existingHabit!;
        await HabitNotificationService.instance.cancelHabit(oldHabit);
        await repo.updateHabit(
          habit: oldHabit,
          title: title,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          recurrenceDays: _selectedDays.toList(),
          habitType: _habitType,
          reminderTime: _reminderTime == null ? null : _fmt24(_reminderTime!),
        );
        final latestHabits = await repo.getAllHabits(ref.read(userIdProvider));
        habitForNotification = latestHabits.firstWhere(
          (h) => h.id == oldHabit.id,
          orElse: () => oldHabit,
        );
      }

      await HabitNotificationService.instance.scheduleHabit(
        habitForNotification,
      );

      if (mounted) {
        ref.invalidate(habitsListProvider);
        ref.invalidate(todayHabitsProvider);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save habit. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            secondary: Color(0xFF6366F1),
            surface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (selected != null) {
      setState(() => _reminderTime = selected);
    }
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmt12(TimeOfDay t) {
    final hour = t.hour;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$displayHour:$minute $period';
  }
}

const _weekdayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _weekdayLabels = {
  'mon': 'Mon',
  'tue': 'Tue',
  'wed': 'Wed',
  'thu': 'Thu',
  'fri': 'Fri',
  'sat': 'Sat',
  'sun': 'Sun',
};

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
  });

  final TextEditingController controller;
  final String label;
  final String placeholder;
  final int maxLines;
  final bool autofocus;

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
    required this.label,
    required this.onTap,
  });
  final bool saving;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          color: saving
              ? AppColors.accent.withValues(alpha: 0.85)
              : AppColors.accent.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: AppColors.accentGlow,
              blurRadius: 16,
              spreadRadius: -4,
              offset: Offset(0, 10),
            ),
          ],
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: AppDecorations.glassChip(selected: selected),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accentSoft : AppColors.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
