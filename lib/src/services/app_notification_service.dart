import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../db/app_db.dart';
import '../providers.dart';
import '../repositories/habit_repository.dart';
import '../repositories/medication_repository.dart';
import '../repositories/todo_repository.dart';

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
    } catch (error) {
      // Scheduling continues with tz.local defaulting to UTC. Log it so wrong
      // reminder times (off by the local UTC offset) are traceable.
      debugPrint(
        'Failed to resolve local timezone, reminders may fire at UTC times: '
        '$error',
      );
    }

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
      onDidReceiveNotificationResponse: handleNotificationResponse,
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

  /// Cancels every pending OS notification. Debug cleanup only — prod startup
  /// must not call this without also resyncing med/habit schedules.
  Future<void> cancelAllPendingNotifications() async {
    final pending = await notifications.pendingNotificationRequests();
    for (final request in pending) {
      await notifications.cancel(id: request.id);
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
            const AndroidNotificationAction(
              actionDone,
              'Mark done',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              actionSnooze,
              'Remind in ${snoozeMinutes}m',
              showsUserInterface: true,
            ),
            if (entityType == 'todo')
              const AndroidNotificationAction(
                actionDismiss,
                'Dismiss',
                showsUserInterface: true,
              )
            else
              const AndroidNotificationAction(
                actionSkip,
                'Skip today',
                showsUserInterface: true,
              ),
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

  /// Handles a notification interaction end-to-end.
  ///
  /// Runs on the main isolate in all the common cases:
  ///  * iOS/macOS action presses and body taps.
  ///  * Android action presses (`showsUserInterface: true` foregrounds the
  ///    app, so the response is delivered here) and Android body taps.
  ///  * Cold starts, via getNotificationAppLaunchDetails in main.dart.
  /// `appProviderContainer` exists, so the shared repositories are used and
  /// UI providers are invalidated afterwards.
  ///
  /// The background-isolate fallback in notificationTapBackground only runs
  /// if Android delivers an action without opening the app; in that fresh
  /// isolate `appProviderContainer` is null and _processStandalone performs
  /// the work against a short-lived standalone DB connection (the UI then
  /// refreshes on the next resume).
  Future<void> handleNotificationResponse(NotificationResponse response) async {
    // Body taps only open the app — never record output or schedule snoozes.
    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      return;
    }

    final parsed = _parseNotificationPayload(response);
    if (parsed == null) return;

    // Belt-and-braces removal of the notification the user interacted with.
    // The Android ActionBroadcastReceiver already cancels it natively
    // (cancelNotification: true). Deliberately skipped on iOS/macOS, where the
    // id maps to the repeating UNCalendarNotificationTrigger — cancelling it
    // would kill the daily recurrence of med/habit reminders.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final responseId = response.id;
      if (responseId != null && responseId >= 0) {
        try {
          await notifications.cancel(id: responseId);
        } catch (_) {}
      }
    }

    final actionId = response.actionId ?? '';
    final container = appProviderContainer;
    if (container != null) {
      await _processNotificationAction(parsed, actionId, container);
    } else {
      await _processStandalone(parsed, actionId);
    }
  }

  Future<void> _processNotificationAction(
    NotificationPayloadData parsed,
    String actionId,
    ProviderContainer container,
  ) async {
    if (parsed.entityType == 'todo') {
      final repo = await container.read(todoRepositoryProvider.future);
      await _processTodoAction(repo, parsed, actionId);
      container.invalidate(todosProvider);
      container.invalidate(homeTodosProvider);
      container.invalidate(homeOverviewProvider);
    } else if (parsed.entityType == 'medication') {
      final repo = await container.read(medicationRepositoryProvider.future);
      await _processMedicationAction(repo, parsed, actionId);
      container.invalidate(medicationsProvider);
      container.invalidate(medicationDoseHistoryProvider);
      container.invalidate(medicationAdherenceProvider(7));
      container.invalidate(homeOverviewProvider);
    } else if (parsed.entityType == 'habit') {
      final repo = await container.read(habitRepositoryProvider.future);
      await _processHabitAction(repo, parsed, actionId);
      container.invalidate(todayHabitsProvider);
      container.invalidate(todayHabitInstancesProvider);
      container.invalidate(habitsListProvider);
      container.invalidate(homeOverviewProvider);
    }
  }

  Future<void> _processMedicationAction(
    MedicationRepository repo,
    NotificationPayloadData parsed,
    String actionId,
  ) async {
    if (actionId == actionDone) {
      await repo.markDose(
        medicationId: parsed.entityId,
        time: parsed.time,
        status: 'taken',
      );
      await notifications.cancel(
        id: _snoozeNotificationIdFor(
          parsed.entityType,
          parsed.entityId,
          parsed.time,
        ),
      );
    } else if (actionId == actionSkip) {
      await repo.markDose(
        medicationId: parsed.entityId,
        time: parsed.time,
        status: 'skipped',
      );
      await notifications.cancel(
        id: _snoozeNotificationIdFor(
          parsed.entityType,
          parsed.entityId,
          parsed.time,
        ),
      );
    } else if (actionId == actionSnooze) {
      await repo.markDose(
        medicationId: parsed.entityId,
        time: parsed.time,
        status: 'snoozed',
      );
      await scheduleSnooze(
        entityType: parsed.entityType,
        entityId: parsed.entityId,
        time: parsed.time,
        title: parsed.title,
        body: parsed.body,
      );
    }
  }

  Future<void> _processHabitAction(
    HabitRepository repo,
    NotificationPayloadData parsed,
    String actionId,
  ) async {
    if (actionId == actionDone) {
      await repo.markHabitCompletionForToday(parsed.entityId, true);
      await notifications.cancel(
        id: _snoozeNotificationIdFor(
          parsed.entityType,
          parsed.entityId,
          parsed.time,
        ),
      );
    } else if (actionId == actionSkip) {
      await repo.markHabitCompletionForToday(parsed.entityId, false);
      await notifications.cancel(
        id: _snoozeNotificationIdFor(
          parsed.entityType,
          parsed.entityId,
          parsed.time,
        ),
      );
    } else if (actionId == actionSnooze) {
      await scheduleSnooze(
        entityType: parsed.entityType,
        entityId: parsed.entityId,
        time: parsed.time,
        title: parsed.title,
        body: parsed.body,
      );
    }
  }

  NotificationPayloadData? _parseNotificationPayload(
    NotificationResponse response,
  ) {
    return parseNotificationPayload(response.payload);
  }

  /// Background-isolate path: opens a short-lived DB connection, performs the
  /// action, then closes it. No Riverpod container exists in this isolate.
  Future<void> _processStandalone(
    NotificationPayloadData parsed,
    String actionId,
  ) async {
    AppDb? db;
    try {
      db = await AppDb.open();
      if (parsed.entityType == 'todo') {
        await _processTodoAction(TodoRepository(db), parsed, actionId);
      } else if (parsed.entityType == 'medication') {
        await _processMedicationAction(
          MedicationRepository(db),
          parsed,
          actionId,
        );
      } else if (parsed.entityType == 'habit') {
        await _processHabitAction(HabitRepository(db), parsed, actionId);
      }
    } catch (error) {
      debugPrint('Background notification handling failed: $error');
    } finally {
      await db?.close();
    }
  }

  Future<void> _processTodoAction(
    TodoRepository repo,
    NotificationPayloadData parsed,
    String actionId,
  ) async {
    final details = await repo.getTodoDetails(parsed.entityId);
    if (details == null) {
      // Missing or archived — drop any leftover schedules for this id.
      await cancelTodoSchedules(parsed.entityId);
      return;
    }
    if (actionId == actionDone) {
      final updated = await repo.completeTodo(parsed.entityId);
      await cancelTodoSchedules(parsed.entityId);
      if (updated.status == 'open' && updated.nagEnabled == 1) {
        await scheduleTodoNagChain(updated);
      }
    } else if (actionId == actionDismiss) {
      await repo.dismissTodo(parsed.entityId);
      await cancelTodoSchedules(parsed.entityId);
    } else if (actionId == actionSnooze) {
      await scheduleSnooze(
        entityType: parsed.entityType,
        entityId: parsed.entityId,
        time: parsed.time,
        title: parsed.title,
        body: parsed.body,
        snoozeMinutes: parsed.nagInterval,
      );
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
            const AndroidNotificationAction(
              actionDone,
              'Mark done',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              actionSnooze,
              snoozeLabel,
              showsUserInterface: true,
            ),
            const AndroidNotificationAction(
              actionDismiss,
              'Dismiss',
              showsUserInterface: true,
            ),
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
            AndroidNotificationAction(
              actionDone,
              'Mark done',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              actionSnooze,
              'Remind in 10m',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              actionSkip,
              'Skip today',
              showsUserInterface: true,
            ),
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

class NotificationPayloadData {
  const NotificationPayloadData({
    required this.entityType,
    required this.entityId,
    required this.time,
    required this.title,
    required this.body,
    required this.nagInterval,
  });

  final String entityType;
  final String entityId;
  final String time;
  final String title;
  final String body;
  final int nagInterval;
}

/// Parses a notification payload produced by [jsonEncode] in the scheduling
/// helpers above. Returns null when the payload is absent, malformed, or
/// missing the required entity coordinates — callers must treat null as "no
/// actionable content". A malformed or stale payload must never terminate
/// handling before the action is persisted or leftover schedules are cleaned.
NotificationPayloadData? parseNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;
    final entityType = decoded['entityType'];
    final entityId = decoded['entityId'];
    if (entityType is! String || entityId is! String) return null;
    return NotificationPayloadData(
      entityType: entityType,
      entityId: entityId,
      time: decoded['time'] is String ? decoded['time'] as String : '',
      title: decoded['title'] is String
          ? decoded['title'] as String
          : 'Reminder',
      body: decoded['body'] is String ? decoded['body'] as String : '',
      nagInterval: decoded['nagIntervalMinutes'] is num
          ? (decoded['nagIntervalMinutes'] as num).toInt()
          : 10,
    );
  } catch (error) {
    debugPrint('Notification payload parse failed: $error');
    return null;
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  try {
    // Runs in a fresh isolate spawned by the plugin's ActionBroadcastReceiver
    // (only reached as a fallback now — Android action presses normally open
    // the app and are handled on the main isolate). Without this, platform
    // channels (path_provider, the notification plugin itself) can fail with
    // MissingPluginException in the spawned engine.
    DartPluginRegistrant.ensureInitialized();
    await AppNotificationService.instance.initialize();
    await AppNotificationService.instance.handleNotificationResponse(response);
  } catch (error) {
    debugPrint('Background notification tap handling failed: $error');
  }
}
