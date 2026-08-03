import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers.dart';
import '../repositories/habit_repository.dart';
import '../utils/date_utils.dart';
import '../theme/app_theme.dart';
import '../theme/habit_colors.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/centered_emoji.dart';
import '../widgets/confetti_overlay.dart';
import 'add_habit_screen.dart';
import 'add_medication_screen.dart';
import 'add_todo_screen.dart';
import '../services/todo_notification_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showConfetti = false;

  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final overviewAsync = ref.watch(homeOverviewProvider);
    final statsAsync = ref.watch(habitStatsProvider);

    final today = DateFormat('EEEE, MMM d').format(DateTime.now());
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return ConfettiOverlay(
      show: _showConfetti,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isPhone ? 16 : 28,
              isPhone ? 18 : 36,
              isPhone ? 16 : 28,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                today,
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$greeting 👋',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: isPhone ? 24 : 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 14),
              _dailyProgress(overviewAsync),
              const SizedBox(height: 12),
              // Badge summary row
              statsAsync.when(
                data: (stats) {
                  final badges = stats.values
                      .where((s) => s.currentStreak >= 7)
                      .length;
                  if (badges == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: AppDecorations.glassCard(),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$badges active badge${badges == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          ...stats.entries
                              .where((e) => e.value.currentStreak >= 7)
                              .take(3)
                              .map((e) => Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: AchievementBadge(
                                      streak: e.value.currentStreak,
                                      size: 24,
                                    ),
                                  )),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppDecorations.glassCard(elevated: true),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        label: 'Add habit',
                        icon: Icons.add_task_rounded,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddHabitScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        label: 'Add todo',
                        icon: Icons.checklist_rounded,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddTodoScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        label: 'Add med',
                        icon: Icons.medication_rounded,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddMedicationScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Today's full list",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: overviewAsync.when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  data: (overview) {
                    final doneIds =
                        overview.doneHabits.map((h) => h.id).toSet();
                    final todaysHabits = overview.habits
                        .where(
                          (h) => HabitRepository.isHabitScheduledOn(
                            h.recurrence,
                            weekdayKey(DateTime.now()),
                          ),
                        )
                        .toList();
                    final items = <_HomeEntry>[
                      ...overview.homeTodos.map((todo) {
                        final due = DateTime.fromMillisecondsSinceEpoch(
                          todo.todo.dueAt,
                        );
                        final dueLabel = todo.todo.allDay == 1
                            ? DateFormat('MMM d').format(due)
                            : DateFormat('h:mm a').format(due);
                        final done =
                            todo.todo.status != 'open' ||
                            overview.todoIdsCompletedToday.contains(
                              todo.todo.id,
                            );
                        final overdueLabel =
                            !done && todo.isOverdue ? 'Overdue · ' : '';
                        return _HomeEntry.todo(
                          id: todo.todo.id,
                          title: todo.todo.title,
                          subtitle: '$overdueLabel$dueLabel',
                          done: done,
                          emoji: todo.todo.emoji.isNotEmpty
                              ? todo.todo.emoji
                              : '☑️',
                          colorIndex: todo.todo.colorIndex,
                        );
                      }),
                      ...todaysHabits.map(
                        (habit) => _HomeEntry.habit(
                          id: habit.id,
                          title: habit.title,
                          subtitle: (habit.notes ?? '').trim(),
                          done: doneIds.contains(habit.id),
                          emoji: habit.emoji,
                          colorIndex: habit.colorIndex,
                        ),
                      ),
                      ...overview.medications.map((med) {
                        final statuses =
                            overview.doseStatusMap[med.medication.id] ??
                            const <String, String>{};
                        final allTaken =
                            med.times.isNotEmpty &&
                            med.times.every((t) => statuses[t] == 'taken');
                        return _HomeEntry.med(
                          id: med.medication.id,
                          title: med.medication.name,
                          subtitle: med.medication.dosage ?? '',
                          times: med.times.length,
                          scheduleTimes: med.times,
                          done: allTaken,
                          emoji: '💊',
                          colorIndex: 0,
                        );
                      }),
                    ];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'No habits, todos, or meds for today.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HomeItemCard(
                            entry: items[index],
                            onToggle: () => _toggleEntry(items[index]),
                          ),
                        );
                      },
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
                      'Could not load today data.',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _dailyProgress(AsyncValue<HomeOverviewData> overviewAsync) {
    return overviewAsync.when(
      data: (overview) {
        final total = overview.habits
            .where(
              (h) => HabitRepository.isHabitScheduledOn(
                h.recurrence,
                weekdayKey(DateTime.now()),
              ),
            )
            .length;
        return _DailyProgressCard(
          done: overview.doneHabits.length,
          total: total,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _toggleEntry(_HomeEntry entry) async {
    HapticFeedback.mediumImpact();

    if (entry.type == _HomeEntryType.habit) {
      final repo = await ref.read(habitRepositoryProvider.future);
      await repo.toggleHabitInstance(entry.id, todayIso());

      if (!entry.done) {
        setState(() => _showConfetti = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _showConfetti = false);
          }
        });
      }

      ref.invalidate(todayHabitsProvider);
      ref.invalidate(todayHabitInstancesProvider);
      ref.invalidate(homeOverviewProvider);
      return;
    }

    if (entry.type == _HomeEntryType.todo) {
      final repo = await ref.read(todoRepositoryProvider.future);
      if (entry.done) {
        await repo.reopenTodo(entry.id);
        final details = await repo.getTodoDetails(entry.id);
        if (details != null) {
          await TodoNotificationService.instance.scheduleTodo(details.todo);
        }
      } else {
        final updated = await repo.completeTodo(entry.id);
        await TodoNotificationService.instance.cancelTodo(updated);
        if (updated.status == 'open') {
          await TodoNotificationService.instance.scheduleTodo(updated);
        }
        setState(() => _showConfetti = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _showConfetti = false);
          }
        });
      }
      ref.invalidate(todosProvider);
      ref.invalidate(homeTodosProvider);
      ref.invalidate(todoIdsCompletedTodayProvider);
      ref.invalidate(homeOverviewProvider);
      return;
    }

    final medRepo = await ref.read(medicationRepositoryProvider.future);
    final nextStatus = entry.done ? 'skipped' : 'taken';
    for (final time in entry.scheduleTimes) {
      await medRepo.markDose(
        medicationId: entry.id,
        time: time,
        status: nextStatus,
      );
    }

    if (!entry.done) {
      setState(() => _showConfetti = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showConfetti = false);
        }
      });
    }

    ref.invalidate(medicationDoseHistoryProvider);
    ref.invalidate(medicationLogsHistoryProvider(30));
    ref.invalidate(homeOverviewProvider);
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: AppDecorations.glassChip(selected: true),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.accentSoft),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.accentSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeItemCard extends StatelessWidget {
  const _HomeItemCard({required this.entry, required this.onToggle});

  final _HomeEntry entry;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isHabit = entry.type == _HomeEntryType.habit;
    final isTodo = entry.type == _HomeEntryType.todo;
    final statusText = isTodo
        ? (entry.done
              ? 'Done'
              : (entry.subtitle.startsWith('Overdue') ? 'Overdue' : 'Due'))
        : isHabit
        ? (entry.done ? 'Completed' : 'Pending')
        : (entry.done
              ? 'Taken'
              : '${entry.times} reminder${entry.times == 1 ? '' : 's'}');

    final accentColor = HabitColors.getColor(entry.colorIndex);
    final statusColor = entry.done
        ? accentColor
        : (!entry.done &&
              isTodo &&
              entry.subtitle.startsWith('Overdue'))
        ? AppColors.danger
        : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGlass),
        gradient: entry.done
            ? LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.10),
                  accentColor.withValues(alpha: 0.02),
                ],
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: entry.done
                    ? accentColor.withValues(alpha: 0.15)
                    : AppColors.surfaceGlassSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: entry.done
                      ? accentColor.withValues(alpha: 0.4)
                      : AppColors.borderGlass,
                ),
              ),
              child: CenteredEmoji(
                entry.emoji.isNotEmpty
                    ? entry.emoji
                    : (isTodo ? '☑️' : (isHabit ? '✅' : '💊')),
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    color: entry.done ? accentColor : AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    decoration: entry.done ? TextDecoration.lineThrough : null,
                    decorationColor: accentColor.withValues(alpha: 0.5),
                  ),
                ),
                if (entry.subtitle.trim().isNotEmpty)
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: !entry.done &&
                              isTodo &&
                              entry.subtitle.startsWith('Overdue')
                          ? AppColors.danger
                          : AppColors.textMuted,
                      fontSize: 12,
                      height: 1.25,
                      decoration: entry.done && isTodo
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: accentColor.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyProgressCard extends StatelessWidget {
  const _DailyProgressCard({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: AppDecorations.glassCard(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Progress',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$done / $total',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(
                ratio == 1.0 ? AppColors.success : AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _HomeEntryType { habit, med, todo }

class _HomeEntry {
  const _HomeEntry._({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.times,
    required this.scheduleTimes,
    required this.emoji,
    required this.colorIndex,
  });

  factory _HomeEntry.habit({
    required String id,
    required String title,
    required String subtitle,
    required bool done,
    String emoji = '✅',
    int colorIndex = 0,
  }) {
    return _HomeEntry._(
      type: _HomeEntryType.habit,
      id: id,
      title: title,
      subtitle: subtitle,
      done: done,
      times: 0,
      scheduleTimes: const [],
      emoji: emoji,
      colorIndex: colorIndex,
    );
  }

  factory _HomeEntry.med({
    required String id,
    required String title,
    required String subtitle,
    required int times,
    required List<String> scheduleTimes,
    required bool done,
    String emoji = '💊',
    int colorIndex = 0,
  }) {
    return _HomeEntry._(
      type: _HomeEntryType.med,
      id: id,
      title: title,
      subtitle: subtitle,
      done: done,
      times: times,
      scheduleTimes: scheduleTimes,
      emoji: emoji,
      colorIndex: colorIndex,
    );
  }

  factory _HomeEntry.todo({
    required String id,
    required String title,
    required String subtitle,
    required bool done,
    String emoji = '☑️',
    int colorIndex = 0,
  }) {
    return _HomeEntry._(
      type: _HomeEntryType.todo,
      id: id,
      title: title,
      subtitle: subtitle,
      done: done,
      times: 0,
      scheduleTimes: const [],
      emoji: emoji,
      colorIndex: colorIndex,
    );
  }

  final _HomeEntryType type;
  final String id;
  final String title;
  final String subtitle;
  final bool done;
  final int times;
  final List<String> scheduleTimes;
  final String emoji;
  final int colorIndex;
}