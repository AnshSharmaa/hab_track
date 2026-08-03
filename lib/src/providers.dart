import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'db/app_db.dart';
import 'repositories/goal_repository.dart';
import 'repositories/habit_repository.dart';
import 'repositories/medication_repository.dart';
import 'repositories/todo_repository.dart';
import 'utils/date_utils.dart';

const deviceOwnerUserId = 'device_owner';
final userIdProvider = Provider<String>((ref) => deviceOwnerUserId);
ProviderContainer? appProviderContainer;

class HomeOverviewData {
  const HomeOverviewData({
    required this.habits,
    required this.doneHabits,
    required this.medications,
    required this.doseStatusMap,
    required this.homeTodos,
    required this.todoIdsCompletedToday,
  });

  final List<Habit> habits;
  final List<Habit> doneHabits;
  final List<MedicationWithTimes> medications;
  final Map<String, Map<String, String>> doseStatusMap;
  final List<TodoWithDetails> homeTodos;
  final Set<String> todoIdsCompletedToday;
}

// DB provider
final appDbProvider = FutureProvider<AppDb>((ref) async => await AppDb.open());

// Repository provider
final habitRepositoryProvider = FutureProvider<HabitRepository>((ref) async {
  final db = await ref.watch(appDbProvider.future);
  return HabitRepository(db);
});

// Habits list provider
final habitsListProvider = FutureProvider<List<Habit>>((ref) async {
  final repo = await ref.watch(habitRepositoryProvider.future);
  final userId = ref.watch(userIdProvider);
  return repo.getAllHabits(userId);
});

// Today habits with instance provider
final todayHabitsProvider = FutureProvider<List<Habit>>((ref) async {
  final repo = await ref.watch(habitRepositoryProvider.future);
  final userId = ref.watch(userIdProvider);
  return repo.getTodayCompletedHabits(userId);
});

final todayHabitInstancesProvider = FutureProvider<Map<String, HabitInstance?>>(
  (ref) async {
    final repo = await ref.watch(habitRepositoryProvider.future);
    final userId = ref.watch(userIdProvider);
    return repo.getTodayInstancesMap(userId);
  },
);

final habitStatsProvider = FutureProvider<Map<String, HabitStats>>((ref) async {
  final repo = await ref.watch(habitRepositoryProvider.future);
  final userId = ref.watch(userIdProvider);
  return repo.getHabitStats(userId, lookbackDays: 30);
});

final habitHistoryProvider =
    FutureProvider.family<Map<String, List<HabitInstance>>, int>((
      ref,
      days,
    ) async {
      final repo = await ref.watch(habitRepositoryProvider.future);
      final userId = ref.watch(userIdProvider);
      return repo.getHabitHistoryByDays(userId, days);
    });

final goalRepositoryProvider = FutureProvider<GoalRepository>((ref) async {
  final db = await ref.watch(appDbProvider.future);
  return GoalRepository(db);
});

final medicationRepositoryProvider = FutureProvider<MedicationRepository>((
  ref,
) async {
  final db = await ref.watch(appDbProvider.future);
  return MedicationRepository(db);
});

final medicationsProvider = FutureProvider<List<MedicationWithTimes>>((
  ref,
) async {
  final repo = await ref.watch(medicationRepositoryProvider.future);
  final userId = ref.watch(userIdProvider);
  return repo.getAllMedications(userId);
});

final medicationDoseHistoryProvider =
    FutureProvider<Map<String, Map<String, String>>>((ref) async {
      final repo = await ref.watch(medicationRepositoryProvider.future);
      return repo.getDoseStatusForDate(todayIso());
    });

final medicationAdherenceProvider =
    FutureProvider.family<Map<String, double>, int>((ref, days) async {
      final repo = await ref.watch(medicationRepositoryProvider.future);
      final userId = ref.watch(userIdProvider);
      return repo.getAdherenceForRecentDays(userId, days: days);
    });

final medicationLogsHistoryProvider =
    FutureProvider.family<List<MedicationLog>, int>((ref, days) async {
      final repo = await ref.watch(medicationRepositoryProvider.future);
      final end = DateTime.now();
      final start = end.subtract(Duration(days: days - 1));
      return repo.db.getMedicationLogsForRange(
        toIsoDate(start),
        toIsoDate(end),
      );
    });

final goalsProvider = FutureProvider<List<Goal>>((ref) async {
  final repo = await ref.watch(goalRepositoryProvider.future);
  final userId = ref.watch(userIdProvider);
  return repo.getAllGoals(userId);
});

final todoRepositoryProvider = FutureProvider<TodoRepository>((ref) async {
  final db = await ref.watch(appDbProvider.future);
  return TodoRepository(db);
});

final todosProvider = FutureProvider<List<TodoWithDetails>>((ref) async {
  final repo = await ref.watch(todoRepositoryProvider.future);
  final userId = ref.watch(userIdProvider);
  return repo.getAllTodosWithDetails(userId);
});

final todoTagsProvider = FutureProvider<List<TodoTag>>((ref) async {
  final repo = await ref.watch(todoRepositoryProvider.future);
  final userId = ref.watch(userIdProvider);
  return repo.getAllTags(userId);
});

final todosForDateProvider =
    FutureProvider.family<List<TodoWithDetails>, DateTime>((ref, date) async {
      final repo = await ref.watch(todoRepositoryProvider.future);
      final userId = ref.watch(userIdProvider);
      return repo.getTodosForDate(userId, date);
    });

final homeTodosProvider = FutureProvider<List<TodoWithDetails>>((ref) async {
  final repo = await ref.watch(todoRepositoryProvider.future);
  final userId = ref.watch(userIdProvider);
  return repo.getHomeTodos(userId);
});

final todoIdsCompletedTodayProvider = FutureProvider<Set<String>>((ref) async {
  final repo = await ref.watch(todoRepositoryProvider.future);
  return repo.getTodoIdsCompletedOn(todayIso());
});

final todoHistoryProvider =
    FutureProvider.family<Map<String, int>, int>((ref, days) async {
      final repo = await ref.watch(todoRepositoryProvider.future);
      return repo.getDailyCompletionCounts(days);
    });

final todoCompletionsProvider =
    FutureProvider.family<List<TodoCompletion>, int>((ref, days) async {
      final repo = await ref.watch(todoRepositoryProvider.future);
      return repo.getCompletionsForRange(days);
    });

final homeOverviewProvider = FutureProvider<HomeOverviewData>((ref) async {
  final habits = await ref.watch(habitsListProvider.future);
  final doneHabits = await ref.watch(todayHabitsProvider.future);
  final medications = await ref.watch(medicationsProvider.future);
  final doseStatusMap = await ref.watch(medicationDoseHistoryProvider.future);
  final homeTodos = await ref.watch(homeTodosProvider.future);
  final todoIdsCompletedToday =
      await ref.watch(todoIdsCompletedTodayProvider.future);
  return HomeOverviewData(
    habits: habits,
    doneHabits: doneHabits,
    medications: medications,
    doseStatusMap: doseStatusMap,
    homeTodos: homeTodos,
    todoIdsCompletedToday: todoIdsCompletedToday,
  );
});
