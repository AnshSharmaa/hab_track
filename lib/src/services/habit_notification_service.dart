import '../db/app_db.dart';
import 'app_notification_service.dart';

class HabitNotificationService {
  HabitNotificationService._();
  static final instance = HabitNotificationService._();

  Future<void> initialize() => AppNotificationService.instance.initialize();

  Future<void> scheduleHabit(Habit habit) =>
      AppNotificationService.instance.scheduleHabitDaily(habit);

  Future<void> cancelHabit(Habit habit) => AppNotificationService.instance
      .cancelHabitSchedules(habit.id, habit.reminderTime);
}
