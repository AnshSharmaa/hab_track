import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../db/app_db.dart';
import '../providers.dart';
import '../repositories/medication_repository.dart';

const actionDone = 'action_done';
const actionSnooze = 'action_snooze';
const actionSkip = 'action_skip';
const actionDismiss = 'action_dismiss';

const _todoNagMaxSlots = 24;
const _todoNagWindowHours = 6;

class AppNotificationService {
  AppNotificationService._();
  static final instance = AppNotificationService._();

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _medsChannel =
      AndroidNotificationChannel(
        'medication_reminders',
        'Medication Reminders',
        description: 'Daily reminders to take medications',
        importance: Importance.max,
      );

  static const AndroidNotificationChannel _habitsChannel =
      AndroidNotificationChannel(
        'habit_reminders',
        'Habit Reminders',
        description: 'Daily reminders for habits',
        importance: Importance.max,
      );

  static const AndroidNotificationChannel _todosChannel =
      AndroidNotificationChannel(
        'todo_reminders',
        'Todo Reminders',
        description: 'Reminders and nags for todos',
        importance: Importance.max,
      );

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      final String timezoneId = localTz is String
          ? (localTz as String)
          : localTz.identifier.toString();
      tz.setLocalLocation(tz.getLocation(timezoneId));
    } catch (_) {}

    final darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'task_actions',
          actions: [
            DarwinNotificationAction.plain(actionDone, 'Mark done'),
            DarwinNotificationAction.plain(actionSnooze, 'Remind in 10m'),
            DarwinNotificationAction.plain(actionSkip, 'Skip today'),
          ],
          options: {
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            DarwinNotificationCategoryOption.customDismissAction,
          },
        ),
        DarwinNotificationCategory(
          'todo_actions',
          actions: [
            DarwinNotificationAction.plain(actionDone, 'Mark done'),
            DarwinNotificationAction.plain(actionSnooze, 'Snooze'),
            DarwinNotificationAction.plain(actionDismiss, 'Dismiss'),
          ],
          options: {
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            DarwinNotificationCategoryOption.customDismissAction,
          },
        ),
      ],
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    await notifications.initialize(
      settings: InitializationSettings(
        android: android,
        macOS: darwin,
        iOS: darwin,
      ),
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final androidPlugin = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_medsChannel);
    await androidPlugin?.createNotificationChannel(_habitsChannel);
    await androidPlugin?.createNotificationChannel(_todosChannel);
    await androidPlugin?.requestNotificationsPermission();
    await notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> scheduleMedicationDaily(MedicationWithTimes med) async {
    for (final time in med.times) {
      await _scheduleDaily(
        id: _notificationIdFor('med', med.medication.id, time),
        time: time,
        channelId: _medsChannel.id,
        channelName: _medsChannel.name,
        channelDescription: _medsChannel.description ?? '',
        title: 'Medication reminder',
        body: '${med.medication.name} ${med.medication.dosage ?? ''}'.trim(),
        payload: {
          'entityType': 'medication',
          'entityId': med.medication.id,
          'time': time,
          'title': 'Medication reminder',
          'body': '${med.medication.name} ${med.medication.dosage ?? ''}'
              .trim(),
        },
      );
    }
  }

  Future<void> scheduleHabitDaily(Habit habit) async {
    final time = habit.reminderTime;
    if (time == null || time.isEmpty) return;
    final title = habit.type == 'timed'
        ? 'Timed habit reminder'
        : 'End-of-day habit check-in';
    await _scheduleDaily(
      id: _notificationIdFor('habit', habit.id, time),
      time: time,
      channelId: _habitsChannel.id,
      channelName: _habitsChannel.name,
      channelDescription: _habitsChannel.description ?? '',
      title: title,
      body: habit.title,
      payload: {
        'entityType': 'habit',
        'entityId': habit.id,
        'time': time,
        'title': title,
        'body': habit.title,
      },
    );
  }

  Future<void> scheduleTodoNagChain(Todo todo) async {
    await cancelTodoSchedules(todo.id);
    if (todo.nagEnabled != 1 || todo.status != 'open') return;

    final interval = todo.nagIntervalMinutes <= 0
        ? 15
        : todo.nagIntervalMinutes;
    final due = DateTime.fromMillisecondsSinceEpoch(todo.dueAt);
    final windowEnd = due.add(const Duration(hours: _todoNagWindowHours));
    final now = DateTime.now();

    final payload = {
      'entityType': 'todo',
      'entityId': todo.id,
      'time': todo.dueAt.toString(),
      'title': 'Todo reminder',
      'body': todo.title,
      'nagIntervalMinutes': interval,
    };

    var slot = 0;
    var scheduledAt = due;
    while (slot < _todoNagMaxSlots && !scheduledAt.isAfter(windowEnd)) {
      if (scheduledAt.isAfter(now)) {
        await _scheduleOneShot(
          id: _todoSlotId(todo.id, slot),
          when: scheduledAt,
          title: slot == 0 ? 'Todo due' : 'Todo reminder',
          body: todo.title,
          payload: payload,
          snoozeLabel: 'Remind in ${interval}m',
        );
      }
      slot++;
      scheduledAt = due.add(Duration(minutes: interval * slot));
    }
  }

  Future<void> cancelTodoSchedules(String todoId) async {
    for (var slot = 0; slot < _todoNagMaxSlots; slot++) {
      await notifications.cancel(id: _todoSlotId(todoId, slot));
    }
    await notifications.cancel(id: _todoSnoozeId(todoId));
  }

  /// Cancels every pending OS notification whose payload is a todo.
  /// Clears orphans from deleted/reseeded IDs that cancelTodoSchedules can't reach.
  Future<void> cancelAllPendingTodoNotifications() async {
    final pending = await notifications.pendingNotificationRequests();
    for (final request in pending) {
      final payload = request.payload;
      if (payload == null || payload.isEmpty) continue;
      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        if (decoded['entityType'] == 'todo') {
          await notifications.cancel(id: request.id);
        }
      } catch (_) {
        // Ignore malformed payloads from other notification sources.
      }
    }
  }

  Future<void> resyncTodoSchedules(List<Todo> todos) async {
    await cancelAllPendingTodoNotifications();
    for (final todo in todos) {
      if (todo.status == 'open' && todo.nagEnabled == 1) {
        await scheduleTodoNagChain(todo);
      }
    }
  }

  Future<void> cancelMedicationSchedules(
    String medicationId,
    List<String> times,
  ) async {
    for (final time in times) {
      await notifications.cancel(
        id: _notificationIdFor('med', medicationId, time),
      );
      await notifications.cancel(
        id: _snoozeNotificationIdFor('med', medicationId, time),
      );
    }
  }

  Future<void> cancelHabitSchedules(String habitId, String? time) async {
    if (time == null || time.isEmpty) return;
    await notifications.cancel(id: _notificationIdFor('habit', habitId, time));
    await notifications.cancel(
      id: _snoozeNotificationIdFor('habit', habitId, time),
    );
  }

  Future<void> scheduleSnooze({
    required String entityType,
    required String entityId,
    required String time,
    required String title,
    required String body,
    int snoozeMinutes = 10,
  }) async {
    final payload = jsonEncode({
      'entityType': entityType,
      'time': time,
      'entityId': entityId,
      'title': title,
      'body': body,
      if (entityType == 'todo') 'nagIntervalMinutes': snoozeMinutes,
    });

    final channel = entityType == 'habit'
        ? _habitsChannel
        : entityType == 'todo'
        ? _todosChannel
        : _medsChannel;
    final categoryId = entityType == 'todo' ? 'todo_actions' : 'task_actions';

    await notifications.zonedSchedule(
      id: entityType == 'todo'
          ? _todoSnoozeId(entityId)
          : _snoozeNotificationIdFor(entityType, entityId, time),
      title: '$title (snoozed)',
      body: body,
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(Duration(minutes: snoozeMinutes)),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(actionDone, 'Mark done'),
            AndroidNotificationAction(
              actionSnooze,
              'Remind in ${snoozeMinutes}m',
            ),
            if (entityType == 'todo')
              const AndroidNotificationAction(actionDismiss, 'Dismiss')
            else
              const AndroidNotificationAction(actionSkip, 'Skip today'),
          ],
        ),
        macOS: DarwinNotificationDetails(
          categoryIdentifier: categoryId,
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: categoryId,
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> _handleResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    final entityType = decoded['entityType'] as String;
    final entityId = decoded['entityId'] as String;
    final time = decoded['time'] as String? ?? '';
    final title = decoded['title'] as String? ?? 'Reminder';
    final body = decoded['body'] as String? ?? '';
    final actionId = response.actionId ?? '';
    final nagInterval =
        (decoded['nagIntervalMinutes'] as num?)?.toInt() ?? 10;

    final container = appProviderContainer;
    if (container == null) return;

    if (entityType == 'todo') {
      final repo = await container.read(todoRepositoryProvider.future);
      final details = await repo.getTodoDetails(entityId);
      if (details == null) {
        // Missing or archived — drop any leftover schedules for this id.
        await cancelTodoSchedules(entityId);
        return;
      }
      if (actionId == actionDone) {
        final updated = await repo.completeTodo(entityId);
        await cancelTodoSchedules(entityId);
        if (updated.status == 'open' && updated.nagEnabled == 1) {
          await scheduleTodoNagChain(updated);
        }
      } else if (actionId == actionDismiss) {
        await repo.dismissTodo(entityId);
        await cancelTodoSchedules(entityId);
      } else if (actionId == actionSnooze) {
        await scheduleSnooze(
          entityType: entityType,
          entityId: entityId,
          time: time,
          title: title,
          body: body,
          snoozeMinutes: nagInterval,
        );
      }
      container.invalidate(todosProvider);
      container.invalidate(homeTodosProvider);
      container.invalidate(homeOverviewProvider);
      return;
    }

    if (entityType == 'medication') {
      final repo = await container.read(medicationRepositoryProvider.future);
      if (actionId == actionDone) {
        await repo.markDose(
          medicationId: entityId,
          time: time,
          status: 'taken',
        );
        await notifications.cancel(
          id: _snoozeNotificationIdFor(entityType, entityId, time),
        );
      } else if (actionId == actionSkip) {
        await repo.markDose(
          medicationId: entityId,
          time: time,
          status: 'skipped',
        );
        await notifications.cancel(
          id: _snoozeNotificationIdFor(entityType, entityId, time),
        );
      } else {
        await repo.markDose(
          medicationId: entityId,
          time: time,
          status: 'snoozed',
        );
        await scheduleSnooze(
          entityType: entityType,
          entityId: entityId,
          time: time,
          title: title,
          body: body,
        );
      }
      container.invalidate(medicationsProvider);
      return;
    }

    if (entityType == 'habit') {
      final repo = await container.read(habitRepositoryProvider.future);
      if (actionId == actionDone) {
        await repo.markHabitCompletionForToday(entityId, true);
        await notifications.cancel(
          id: _snoozeNotificationIdFor(entityType, entityId, time),
        );
      } else if (actionId == actionSkip) {
        await repo.markHabitCompletionForToday(entityId, false);
        await notifications.cancel(
          id: _snoozeNotificationIdFor(entityType, entityId, time),
        );
      } else {
        await scheduleSnooze(
          entityType: entityType,
          entityId: entityId,
          time: time,
          title: title,
          body: body,
        );
      }
      container.invalidate(todayHabitsProvider);
      container.invalidate(todayHabitInstancesProvider);
      container.invalidate(habitsListProvider);
    }
  }

  Future<void> _scheduleOneShot({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
    required String snoozeLabel,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    await notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _todosChannel.id,
          _todosChannel.name,
          channelDescription: _todosChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(actionDone, 'Mark done'),
            AndroidNotificationAction(actionSnooze, snoozeLabel),
            const AndroidNotificationAction(actionDismiss, 'Dismiss'),
          ],
        ),
        macOS: const DarwinNotificationDetails(
          categoryIdentifier: 'todo_actions',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'todo_actions',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode(payload),
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required String time,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    await notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextOccurrence(time),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(actionDone, 'Mark done'),
            AndroidNotificationAction(actionSnooze, 'Remind in 10m'),
            AndroidNotificationAction(actionSkip, 'Skip today'),
          ],
        ),
        macOS: const DarwinNotificationDetails(
          categoryIdentifier: 'task_actions',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'task_actions',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode(payload),
    );
  }

  tz.TZDateTime _nextOccurrence(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  int _notificationIdFor(String kind, String id, String time) {
    return '$kind-$id-$time'.hashCode & 0x7fffffff;
  }

  int _snoozeNotificationIdFor(String kind, String id, String time) {
    return 'snooze-$kind-$id-$time'.hashCode & 0x7fffffff;
  }

  int _todoSlotId(String todoId, int slot) {
    return 'todo-$todoId-$slot'.hashCode & 0x7fffffff;
  }

  int _todoSnoozeId(String todoId) {
    return 'todo-snooze-$todoId'.hashCode & 0x7fffffff;
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  await AppNotificationService.instance.initialize();
  await AppNotificationService.instance._handleResponse(response);
}
