import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import 'habit_repository.dart';

class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.habit,
    required this.currentStreak,
    required this.progress,
    required this.targetDays,
    required this.unlocked,
  });

  final Goal goal;
  final Habit? habit;
  final int currentStreak;
  final int progress;
  final int targetDays;
  final bool unlocked;
}

class GoalRepository {
  GoalRepository(this.db);

  final AppDb db;
  final _uuid = const Uuid();

  Future<List<Goal>> getAllGoals(String userId) => db.getAllGoals(userId);

  Future<Goal> addGoal({
    required String userId,
    required String title,
    required String habitId,
    required int targetDays,
    required String rewardTitle,
    String? rewardDescription,
    String? rewardImageUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = GoalsCompanion.insert(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      habitId: habitId,
      targetDays: targetDays,
      rewardTitle: rewardTitle,
      rewardDescription: Value(rewardDescription),
      rewardImageUrl: Value(rewardImageUrl),
      createdAt: now,
      updatedAt: now,
    );
    await db.insertGoal(entry);
    final goals = await db.getAllGoals(userId);
    return goals.firstWhere((goal) => goal.id == entry.id.value);
  }

  Future<void> updateGoal({
    required Goal goal,
    required String title,
    required String habitId,
    required int targetDays,
    required String rewardTitle,
    String? rewardDescription,
    String? rewardImageUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.updateGoalEntry(
      GoalsCompanion(
        id: Value(goal.id),
        userId: Value(goal.userId),
        title: Value(title),
        habitId: Value(habitId),
        targetDays: Value(targetDays),
        rewardTitle: Value(rewardTitle),
        rewardDescription: Value(rewardDescription),
        rewardImageUrl: Value(rewardImageUrl),
        isArchived: Value(goal.isArchived),
        createdAt: Value(goal.createdAt),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteGoal(String goalId) async {
    await db.archiveGoal(goalId);
  }

  Future<List<GoalProgress>> getGoalProgress(
    List<Goal> goals,
    Map<String, Habit> habitsById,
    Map<String, HabitStats> statsByHabitId,
  ) async {
    return goals.map((goal) {
      final habit = habitsById[goal.habitId];
      final stats = statsByHabitId[goal.habitId];
      final streak = stats?.currentStreak ?? 0;
      final progress = streak.clamp(0, goal.targetDays);
      return GoalProgress(
        goal: goal,
        habit: habit,
        currentStreak: streak,
        progress: progress,
        targetDays: goal.targetDays,
        unlocked: progress >= goal.targetDays,
      );
    }).toList();
  }
}
