import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_db.dart';
import '../providers.dart';
import '../repositories/goal_repository.dart';
import '../repositories/habit_repository.dart';
import '../theme/app_theme.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _titleController = TextEditingController();
  final _rewardController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  String? _selectedHabitId;
  int _targetDays = 7;

  @override
  void dispose() {
    _titleController.dispose();
    _rewardController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final goalsAsync = ref.watch(goalsProvider);
    final habitsAsync = ref.watch(habitsListProvider);
    final statsAsync = ref.watch(habitStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(isPhone ? 16 : 28, 18, isPhone ? 16 : 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GOALS',
                        style: TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reward streaks',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: isPhone ? 22 : 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _openCreateSheet,
                    icon: const Icon(Icons.emoji_events_rounded, size: 18),
                    label: const Text('New goal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                      foregroundColor: AppColors.accentSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: goalsAsync.when(
                  data: (goals) => habitsAsync.when(
                    data: (habits) => statsAsync.when(
                      data: (statsMap) {
                        final habitsById = {for (final h in habits) h.id: h};
                        final goalProgress = goals
                            .map((goal) => GoalProgress(
                                  goal: goal,
                                  habit: habitsById[goal.habitId],
                                  currentStreak: statsMap[goal.habitId]?.currentStreak ?? 0,
                                  progress: (statsMap[goal.habitId]?.currentStreak ?? 0).clamp(0, goal.targetDays),
                                  targetDays: goal.targetDays,
                                  unlocked: (statsMap[goal.habitId]?.currentStreak ?? 0) >= goal.targetDays,
                                ))
                            .toList();
                        if (goalProgress.isEmpty) {
                          return _EmptyGoalState(onCreate: _openCreateSheet);
                        }
                        return ListView.builder(
                          itemCount: goalProgress.length,
                          itemBuilder: (context, index) {
                            final item = goalProgress[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _GoalCard(progress: item),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                      error: (_, __) => const Center(child: Text('Could not load streaks', style: TextStyle(color: AppColors.danger))),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                    error: (_, __) => const Center(child: Text('Could not load habits', style: TextStyle(color: AppColors.danger))),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                  error: (_, __) => const Center(child: Text('Could not load goals', style: TextStyle(color: AppColors.danger))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final habitsAsync = await ref.read(habitsListProvider.future);
    final habitOptions = habitsAsync.where((h) => h.isArchived == 0).toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Create a new goal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Goal name', labelStyle: TextStyle(color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedHabitId,
                      decoration: const InputDecoration(labelText: 'Linked habit', labelStyle: TextStyle(color: AppColors.textMuted)),
                      items: habitOptions.map((habit) => DropdownMenuItem(value: habit.id, child: Text(habit.title, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (value) => setState(() => _selectedHabitId = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _targetDays,
                      decoration: const InputDecoration(labelText: 'Required streak', labelStyle: TextStyle(color: AppColors.textMuted)),
                      items: const [3, 5, 7, 10, 14].map((days) => DropdownMenuItem(value: days, child: Text('$days days', style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (value) => setState(() => _targetDays = value ?? 7),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _rewardController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Reward title', labelStyle: TextStyle(color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Reward note', labelStyle: TextStyle(color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _imageUrlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Photo URL (optional)', labelStyle: TextStyle(color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_selectedHabitId == null || _titleController.text.trim().isEmpty || _rewardController.text.trim().isEmpty) {
                            return;
                          }
                          final repo = await ref.read(goalRepositoryProvider.future);
                          await repo.addGoal(
                            userId: ref.read(userIdProvider),
                            title: _titleController.text.trim(),
                            habitId: _selectedHabitId!,
                            targetDays: _targetDays,
                            rewardTitle: _rewardController.text.trim(),
                            rewardDescription: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                            rewardImageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
                          );
                          if (!mounted) return;
                          Navigator.pop(sheetContext);
                          _titleController.clear();
                          _rewardController.clear();
                          _descriptionController.clear();
                          _imageUrlController.clear();
                          _selectedHabitId = null;
                          _targetDays = 7;
                          ref.invalidate(goalsProvider);
                          ref.invalidate(habitStatsProvider);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                        child: const Text('Save goal'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final ratio = progress.targetDays == 0 ? 0.0 : progress.progress / progress.targetDays;
    final accent = progress.unlocked ? AppColors.success : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.glassCard(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.goal.title,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Linked habit: ${progress.habit?.title ?? "Unknown"}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  progress.unlocked ? 'Unlocked' : '${progress.progress}/${progress.targetDays} days',
                  style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlassSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.goal.rewardTitle,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (progress.goal.rewardDescription != null && progress.goal.rewardDescription!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            progress.goal.rewardDescription!,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                ),
                if (progress.goal.rewardImageUrl != null && progress.goal.rewardImageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        progress.goal.rewardImageUrl!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress.unlocked ? 'Reward unlocked — great work!' : 'Keep going to unlock this reward.',
            style: TextStyle(color: progress.unlocked ? AppColors.success : AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyGoalState extends StatelessWidget {
  const _EmptyGoalState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 56, color: AppColors.accentSoft),
          const SizedBox(height: 12),
          const Text('No goals yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Create a streak reward and watch it unlock', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create your first goal'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
