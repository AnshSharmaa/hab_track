import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../db/app_db.dart';
import '../providers.dart';
import '../repositories/habit_repository.dart';
import '../services/habit_notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/habit_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/ring_progress.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/achievement_badge.dart';
import 'add_habit_screen.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  String? _justCompletedHabitId;
  bool _showConfetti = false;

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
                      return _EmptyStateLottie(
                        message: 'No habits for today',
                        sub: 'Create a habit or adjust recurrence days.',
                      );
                    }
                    final doneIds = doneHabits.map((h) => h.id).toSet();
                    return todayInstancesAsync.when(
                      data: (instanceMap) => statsAsync.when(
                        data: (statsMap) => ConfettiOverlay(
                          show: _showConfetti,
                          child: ReorderableListView.builder(
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
                              final justCompleted =
                                  _justCompletedHabitId == habit.id;
                              return Padding(
                                key: ValueKey(habit.id),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ReorderActivator(
                                  index: index,
                                  child: _HabitCard(
                                    habit: habit,
                                    isDone: doneIds.contains(habit.id),
                                    justCompleted: justCompleted,
                                    stats: stat,
                                    note: note,
                                    onToggle: () => _toggleHabit(habit),
                                  ),
                                ),
                              );
                            },
                          ),
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

  Future<void> _toggleHabit(Habit habit) async {
    final repo = await ref.read(habitRepositoryProvider.future);
    final wasDone = ref.read(todayHabitsProvider).asData?.value.contains(habit) ?? false;

    await repo.toggleHabitInstance(habit.id, todayIso());
    HapticFeedback.mediumImpact();

    if (!wasDone) {
      setState(() {
        _justCompletedHabitId = habit.id;
        _showConfetti = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() {
          _justCompletedHabitId = null;
          _showConfetti = false;
        });
      });
    }

    ref.invalidate(todayHabitsProvider);
    ref.invalidate(todayHabitInstancesProvider);
    ref.invalidate(habitStatsProvider);
  }
}

class _HabitCard extends ConsumerWidget {
  final Habit habit;
  final bool isDone;
  final bool justCompleted;
  final HabitStats? stats;
  final String note;
  final VoidCallback onToggle;

  const _HabitCard({
    required this.habit,
    required this.isDone,
    this.justCompleted = false,
    required this.stats,
    required this.note,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorIndex = habit.colorIndex;
    final emoji = habit.emoji;
    final habitColor = HabitColors.getColor(colorIndex);

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? habitColor.withValues(alpha: 0.55)
                : AppColors.borderGlass,
          ),
          gradient: isDone
              ? LinearGradient(
                  colors: [
                    habitColor.withValues(alpha: 0.20),
                    habitColor.withValues(alpha: 0.05),
                  ],
                )
              : HabitColors.habitGradient(colorIndex),
          boxShadow: isDone
              ? [
                  BoxShadow(
                    color: habitColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: -4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: habitColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Ring progress
            RingProgress(
              progress: isDone ? 1.0 : 0.0,
              size: 36,
              strokeWidth: 3,
              colorIndex: colorIndex,
              child: Text(
                emoji,
                style: TextStyle(fontSize: justCompleted ? 18 : 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          habit.title,
                          style: TextStyle(
                            color: isDone
                                ? habitColor
                                : AppColors.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: habitColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      if (stats != null && stats!.currentStreak >= 7)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: AchievementBadge(
                            streak: stats!.currentStreak,
                            size: 22,
                          ),
                        ),
                    ],
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
                      style: TextStyle(
                        color: habitColor.withValues(alpha: 0.8),
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
                decoration: BoxDecoration(
                  color: habitColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: habitColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: habitColor,
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
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
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

class _EmptyStateLottie extends StatelessWidget {
  final String message;
  final String sub;

  const _EmptyStateLottie({required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Lottie.network(
              'https://assets5.lottiefiles.com/packages/lf20_n48jwtqr.json',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
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
  final int index;
  final Widget child;

  const _ReorderActivator({required this.index, required this.child});

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