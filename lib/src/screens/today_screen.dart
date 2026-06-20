import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_db.dart';
import '../providers.dart';
import '../repositories/habit_repository.dart';
import '../services/habit_notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import 'add_habit_screen.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final todayHabitsAsync = ref.watch(todayHabitsProvider);
    final allHabitsAsync = ref.watch(habitsListProvider);
    final todayInstancesAsync = ref.watch(todayHabitInstancesProvider);
    final statsAsync = ref.watch(habitStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                isPhone ? 16 : 28,
                isPhone ? 18 : 36,
                isPhone ? 16 : 28,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HABITS',
                        style: TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Today\'s habits',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: isPhone ? 22 : 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  _AddButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddHabitScreen()),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isPhone ? 12 : 16),

            // Section label
            Padding(
              padding: EdgeInsets.fromLTRB(
                isPhone ? 16 : 28,
                0,
                isPhone ? 16 : 28,
                12,
              ),
              child: const Text(
                'Daily checklist',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Habit list
            Expanded(
              child: allHabitsAsync.when(
                data: (allHabits) => todayHabitsAsync.when(
                  data: (doneHabits) {
                    final visibleHabits = allHabits
                        .where(
                          (h) => HabitRepository.isHabitScheduledOn(
                            h.recurrence,
                            weekdayKey(DateTime.now()),
                          ),
                        )
                        .toList();
                    if (visibleHabits.isEmpty) {
                      return _EmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        message: 'No habits for today',
                        sub: 'Create a habit or adjust recurrence days.',
                      );
                    }
                    final doneIds = doneHabits.map((h) => h.id).toSet();
                    return todayInstancesAsync.when(
                      data: (instanceMap) => statsAsync.when(
                        data: (statsMap) => ReorderableListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            isPhone ? 12 : 24,
                            0,
                            isPhone ? 12 : 24,
                            32,
                          ),
                          buildDefaultDragHandles: false,
                          itemCount: visibleHabits.length,
                          onReorder: (oldIndex, newIndex) async {
                            final repo = await ref.read(
                              habitRepositoryProvider.future,
                            );
                            final reordered = [...visibleHabits];
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, item);

                            final visibleIds = reordered
                                .map((h) => h.id)
                                .toSet();
                            final remaining = allHabits.where(
                              (h) => !visibleIds.contains(h.id),
                            );
                            final finalOrder = [
                              ...reordered,
                              ...remaining,
                            ].map((h) => h.id).toList();

                            await repo.reorderHabits(finalOrder);
                            ref.invalidate(habitsListProvider);
                            ref.invalidate(todayHabitsProvider);
                          },
                          itemBuilder: (context, index) {
                            final habit = visibleHabits[index];
                            final stat = statsMap[habit.id];
                            final note = instanceMap[habit.id]?.note ?? '';
                            return Padding(
                              key: ValueKey(habit.id),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ReorderActivator(
                                index: index,
                                child: _HabitCard(
                                  habit: habit,
                                  isDone: doneIds.contains(habit.id),
                                  stats: stat,
                                  note: note,
                                ),
                              ),
                            );
                          },
                        ),
                        loading: () => const Center(child: _Loader()),
                        error: (_, _) => const Center(
                          child: Text(
                            'Could not load habit stats.',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),
                      loading: () => const Center(child: _Loader()),
                      error: (_, _) => const Center(
                        child: Text(
                          'Could not load today notes.',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: _Loader()),
                  error: (_, _) => const Center(
                    child: Text(
                      'Could not load habits.',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
                loading: () => const Center(child: _Loader()),
                error: (_, _) => const Center(
                  child: Text(
                    'Could not load habits.',
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
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({
    required this.habit,
    required this.isDone,
    required this.stats,
    required this.note,
  });
  final Habit habit;
  final bool isDone;
  final HabitStats? stats;
  final String note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final repo = await ref.read(habitRepositoryProvider.future);
        await repo.toggleHabitInstance(habit.id, todayIso());
        ref.invalidate(todayHabitsProvider);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration:
            (isDone
                    ? AppDecorations.glassCard()
                    : AppDecorations.glassCard(elevated: true))
                .copyWith(
                  border: Border.all(
                    color: isDone
                        ? AppColors.success.withValues(alpha: 0.55)
                        : AppColors.borderGlass,
                  ),
                ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDone ? AppColors.success : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? AppColors.success : AppColors.border,
                  width: 2,
                ),
              ),
              child: isDone
                  ? const Icon(
                      Icons.check_rounded,
                      color: AppColors.textPrimary,
                      size: 15,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      color: isDone ? AppColors.success : AppColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.success,
                    ),
                  ),
                  if (note.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        note.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (stats != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '🔥 ${stats!.currentStreak}',
                      style: const TextStyle(
                        color: AppColors.accentSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (isDone)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: AppDecorations.glassChip(selected: true),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              color: AppColors.surface,
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textSubtle,
                size: 18,
              ),
              onSelected: (value) async {
                if (value == 'edit') {
                  if (context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddHabitScreen(existingHabit: habit),
                      ),
                    );
                    ref.invalidate(habitsListProvider);
                    ref.invalidate(todayHabitsProvider);
                  }
                } else if (value == 'note') {
                  final controller = TextEditingController(text: note);
                  final saved = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text(
                        'Today note',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: TextField(
                        controller: controller,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Write a quick note...',
                          hintStyle: TextStyle(color: AppColors.textSubtle),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (saved == true) {
                    final repo = await ref.read(habitRepositoryProvider.future);
                    await repo.updateTodayNote(
                      habitId: habit.id,
                      note: controller.text.trim(),
                    );
                    ref.invalidate(todayHabitInstancesProvider);
                  }
                } else if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text(
                        'Delete habit?',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'This will remove it from your active list.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final repo = await ref.read(habitRepositoryProvider.future);
                    await HabitNotificationService.instance.cancelHabit(habit);
                    await repo.deleteHabit(habit.id);
                    ref.invalidate(habitsListProvider);
                    ref.invalidate(todayHabitsProvider);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'note',
                  child: Text(
                    'Add note',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
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
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: AppDecorations.glassChip(selected: true),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 16, color: AppColors.accentSoft),
            SizedBox(width: 4),
            Text(
              'Add habit',
              style: TextStyle(
                color: AppColors.accentSoft,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });
  final IconData icon;
  final String message;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.surfaceAlt),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(color: AppColors.textSubtle, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      strokeWidth: 2,
      color: AppColors.accent,
    );
  }
}

class _ReorderActivator extends StatelessWidget {
  const _ReorderActivator({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop = switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    if (isDesktop) {
      return ReorderableDragStartListener(index: index, child: child);
    }
    return ReorderableDelayedDragStartListener(index: index, child: child);
  }
}
