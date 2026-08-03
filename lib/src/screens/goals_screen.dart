import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_db.dart';
import '../providers.dart';
import '../repositories/goal_repository.dart';
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
  final _streakController = TextEditingController(text: '7');
  String? _selectedHabitId;
  int _targetDays = 7;
  String? _selectedImagePath;

  @override
  void dispose() {
    _titleController.dispose();
    _rewardController.dispose();
    _descriptionController.dispose();
    _streakController.dispose();
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
                  ),
                  const SizedBox(width: 12),
                  _AddButton(onTap: _openCreateSheet),
                ],
              ),
            ),
            SizedBox(height: isPhone ? 14 : 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 28),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: AppDecorations.glassCard(),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.accentSoft,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          goalsAsync.when(
                            data: (goals) => Text(
                              '${goals.length} goal${goals.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            loading: () => const Text(
                              '0 goals',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            error: (_, __) => const Text(
                              '0 goals',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Create streak rewards and keep the momentum going.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isPhone ? 12 : 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isPhone ? 16 : 28,
                  0,
                  isPhone ? 16 : 28,
                  24,
                ),
                child: goalsAsync.when(
                  data: (goals) => habitsAsync.when(
                    data: (habits) => statsAsync.when(
                      data: (statsMap) {
                        final habitsById = {for (final h in habits) h.id: h};
                        final goalProgress = goals
                            .map((goal) => GoalProgress(
                                  goal: goal,
                                  habit: habitsById[goal.habitId],
                                  currentStreak:
                                      statsMap[goal.habitId]?.currentStreak ?? 0,
                                  progress: (statsMap[goal.habitId]?.currentStreak ?? 0)
                                      .clamp(0, goal.targetDays)
                                      .toInt(),
                                  targetDays: goal.targetDays,
                                  unlocked: (statsMap[goal.habitId]?.currentStreak ?? 0) >=
                                      goal.targetDays,
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
                              child: _GoalCard(
                                progress: item,
                                onDelete: () => _deleteGoal(item.goal),
                              ),
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRewardImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(docsDir.path, 'goal_images'));
    await targetDir.create(recursive: true);

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFile.path)}';
    final targetPath = p.join(targetDir.path, fileName);
    await File(pickedFile.path).copy(targetPath);

    if (!mounted) return;
    setState(() => _selectedImagePath = targetPath);
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete goal?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will remove the goal from your list and archive it.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = await ref.read(goalRepositoryProvider.future);
    await repo.deleteGoal(goal.id);
    if (!mounted) return;
    ref.invalidate(goalsProvider);
    ref.invalidate(habitStatsProvider);
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
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create a new goal',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Goal name',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedHabitId,
                      decoration: const InputDecoration(
                        labelText: 'Linked habit',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                      items: habitOptions
                          .map(
                            (habit) => DropdownMenuItem(
                              value: habit.id,
                              child: Text(
                                habit.title,
                                style: const TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setModalState(() => _selectedHabitId = value),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _streakController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Required streak (days)',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        setModalState(() => _targetDays = parsed != null && parsed > 0 ? parsed : 7);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _rewardController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Reward title',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Reward note',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickRewardImage,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderGlass),
                          color: AppColors.surfaceGlassSoft,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.image_outlined, color: AppColors.accentSoft),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedImagePath == null
                                    ? 'Upload a reward image'
                                    : 'Image selected ✓',
                                style: const TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedImagePath != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(_selectedImagePath!),
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_selectedHabitId == null ||
                              _titleController.text.trim().isEmpty ||
                              _rewardController.text.trim().isEmpty) {
                            return;
                          }
                          final repo = await ref.read(goalRepositoryProvider.future);
                          await repo.addGoal(
                            userId: ref.read(userIdProvider),
                            title: _titleController.text.trim(),
                            habitId: _selectedHabitId!,
                            targetDays: _targetDays,
                            rewardTitle: _rewardController.text.trim(),
                            rewardDescription: _descriptionController.text.trim().isEmpty
                                ? null
                                : _descriptionController.text.trim(),
                            rewardImageUrl: _selectedImagePath,
                          );
                          if (!mounted) return;
                          Navigator.pop(sheetContext);
                          _titleController.clear();
                          _rewardController.clear();
                          _descriptionController.clear();
                          _streakController.text = '7';
                          _selectedHabitId = null;
                          _selectedImagePath = null;
                          _targetDays = 7;
                          ref.invalidate(goalsProvider);
                          ref.invalidate(habitStatsProvider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
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
  const _GoalCard({required this.progress, required this.onDelete});

  final GoalProgress progress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ratio = progress.targetDays == 0 ? 0.0 : progress.progress / progress.targetDays;
    final accent = progress.unlocked ? AppColors.success : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.glassCard(),
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
              Row(
                children: [
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
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: AppColors.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
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
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: _buildRewardImage(progress.goal.rewardImageUrl!),
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

Widget _buildRewardImage(String imagePath) {
  final uri = Uri.tryParse(imagePath);
  final isRemote = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');

  if (isRemote) {
    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  final file = File(imagePath);
  if (!file.existsSync()) {
    return const SizedBox.shrink();
  }

  return Image.file(
    file,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
  );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: AppDecorations.glassChip(selected: true),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: AppColors.accentSoft),
            SizedBox(width: 4),
            Text(
              'New goal',
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
