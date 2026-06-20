import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'src/dev/mock_seed.dart';
import 'src/providers.dart';
import 'src/screens/app_shell.dart';
import 'src/services/medication_notification_service.dart';

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
      if (kDebugMode) {
        final db = await ref.read(appDbProvider.future);
        final userId = ref.read(userIdProvider);
        await MockSeed(db).insertMockData(
          userId,
          anchorDate: DateTime(2026, 4, 24),
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
