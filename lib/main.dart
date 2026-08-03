import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'src/dev/mock_seed.dart';
import 'src/providers.dart';
import 'src/screens/app_shell.dart';
import 'src/services/medication_notification_service.dart';
import 'src/services/todo_notification_service.dart';

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

class _MainAppState extends ConsumerState<MainApp> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await MedicationNotificationService.instance.initialize();
      await TodoNotificationService.instance.initialize();
      if (kDebugMode) {
        // Drop orphaned todo schedules before reseed (new UUIDs each run).
        await TodoNotificationService.instance.cancelAllPendingTodos();
        final db = await ref.read(appDbProvider.future);
        final userId = ref.read(userIdProvider);
        await MockSeed(db).insertMockData(
          userId,
          // Use "today" so Home / Todos / History all look current.
          anchorDate: DateTime.now(),
          clearExisting: true,
        );
      }
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
      final openTodos = await todoRepo.getOpenTodosWithDetails(userId);
      await TodoNotificationService.instance.resyncOpenTodos(
        openTodos.map((t) => t.todo).toList(),
      );
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
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
      ),
      home: const AppShell(),
    );
  }
}
