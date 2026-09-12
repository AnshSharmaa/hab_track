import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'src/dev/first_run_seed.dart';
import 'src/providers.dart';
import 'src/screens/app_shell.dart';
import 'src/services/app_notification_service.dart';
import 'src/services/medication_notification_service.dart';
import 'src/services/todo_notification_service.dart';
import 'src/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  appProviderContainer = container;
  runApp(
    UncontrolledProviderScope(container: container, child: const MainApp()),
  );
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Android notification quick-actions run in a separate background isolate
    // that cannot reach this container. Refresh here on resume so
    // already-open views reflect actions recorded while the app was away.
    _refreshData();
  }

  Future<void> _refreshData() async {
    ref.invalidate(habitsListProvider);
    ref.invalidate(todayHabitsProvider);
    ref.invalidate(todayHabitInstancesProvider);
    ref.invalidate(habitStatsProvider);
    ref.invalidate(medicationsProvider);
    ref.invalidate(medicationDoseHistoryProvider);
    ref.invalidate(medicationAdherenceProvider(7));
    ref.invalidate(todosProvider);
    ref.invalidate(homeTodosProvider);
    ref.invalidate(todoIdsCompletedTodayProvider);
    ref.invalidate(homeOverviewProvider);
  }

  /// If the app was launched by the user tapping a notification, the response
  /// is only available via launch details — it is never re-delivered through
  /// onDidReceiveNotificationResponse on a cold start.
  Future<void> _processColdStartNotificationTap() async {
    try {
      final launchDetails = await AppNotificationService.instance.notifications
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp != true) return;
      final response = launchDetails!.notificationResponse;
      if (response == null) return;
      await AppNotificationService.instance.handleNotificationResponse(
        response,
      );
    } catch (error) {
      debugPrint('Cold-start notification handling failed: $error');
    }
  }

  Future<void> _bootstrap() async {
    try {
      await MedicationNotificationService.instance.initialize();
      await TodoNotificationService.instance.initialize();
      await _processColdStartNotificationTap();
      // ONE-TIME SEED -------------------------------------------------------
      // Seeds the starter todo list on first launch only (skips if any todo
      // already exists). To build a clean bundle without the seed: set
      // kFirstRunSeedEnabled to false in lib/src/dev/first_run_seed.dart
      // (or delete that file and this block), then rebuild.
      if (kFirstRunSeedEnabled) {
        final db = await ref.read(appDbProvider.future);
        final userId = ref.read(userIdProvider);
        await FirstRunSeed(db).seedIfNeeded(userId);
      }
      // ----------------------------------------------------------------------
      ref.invalidate(habitsListProvider);
      ref.invalidate(todayHabitsProvider);
      ref.invalidate(todayHabitInstancesProvider);
      ref.invalidate(habitStatsProvider);
      ref.invalidate(medicationsProvider);
      ref.invalidate(medicationDoseHistoryProvider);
      ref.invalidate(medicationAdherenceProvider(7));
      ref.invalidate(todosProvider);
      ref.invalidate(homeTodosProvider);
      ref.invalidate(todoTagsProvider);
      ref.invalidate(goalsProvider);

      final todoRepo = await ref.read(todoRepositoryProvider.future);
      final userId = ref.read(userIdProvider);
      if (!kDebugMode) {
        final openTodos = await todoRepo.getOpenTodosWithDetails(userId);
        await TodoNotificationService.instance.resyncOpenTodos(
          openTodos.map((t) => t.todo).toList(),
        );
      }
    } catch (error, _) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Startup failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.shadDark,
      materialThemeBuilder: AppTheme.materialBuilder,
      home: const AppShell(),
    );
  }
}
