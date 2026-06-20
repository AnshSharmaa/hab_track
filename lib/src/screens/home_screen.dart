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
import '../widgets/confetti_overlay.dart';
import 'add_habit_screen.dart';
import 'add_medication_screen.dart';

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
        body: Padding(
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
                            color: Color(0xFFF59E0B),
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
                          'No habits or meds for today.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: _ComingSoonCard(),
                          );
                        }
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
    final statusText = isHabit
        ? (entry.done ? 'Completed' : 'Pending')
        : '${entry.times} reminder${entry.times == 1 ? '' : 's'}';
    final statusColor = isHabit && entry.done
        ? HabitColors.getColor(entry.colorIndex)
        : AppColors.textMuted;
    final accentColor = HabitColors.getColor(entry.colorIndex);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGlass),
        gradient: entry.done
            ? LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.12),
                  accentColor.withValues(alpha: 0.03),
                ],
              )
            : null,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 34,
              height: 34,
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
              child: Center(
                child: Text(
                  entry.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    color: entry.done
                        ? accentColor
                        : AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    decoration: entry.done ? TextDecoration.lineThrough : null,
                    decorationColor: accentColor.withValues(alpha: 0.5),
                  ),
                ),
                if (entry.subtitle.trim().isNotEmpty)
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.glassCard(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'More features coming soon!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
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

enum _HomeEntryType { habit, med }

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