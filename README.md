# HabTrack

A habit and medication tracker built with Flutter.

## Features

- **Habits** – daily check-ins, timed reminders, recurrence scheduling, streak tracking, reorderable list, daily notes
- **Medications** – multi-dose scheduling, dosage tracking, dose logging (taken/snoozed/skipped), adherence analytics
- **Analytics** – trend chart, GitHub-style heatmap, per-habit & per-medication stats, custom time ranges (7d/30d/90d/365d/custom)
- **Notifications** – local push reminders with interactive actions (done, snooze 10m, skip)
- **UI** – dark glassmorphic theme, responsive layout (bottom nav on mobile, sidebar on desktop), Riverpod state management

## Tech Stack

Flutter 3.9+, Dart 3.9+, Riverpod, Drift (SQLite), shadcn_ui, fl_chart, flutter_local_notifications

## Getting Started

```bash
git clone https://github.com/AnshSharmaa/hab_track.git
cd hab_track
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Debug mode seeds mock data (3 habits, 2 medications, 30 days). Disable by removing the `MockSeed` call in `lib/main.dart`.

## Project Structure

```
lib/
├── main.dart
├── src/
│   ├── dev/mock_seed.dart
│   ├── db/app_db.dart
│   ├── providers.dart
│   ├── repositories/
│   │   ├── habit_repository.dart
│   │   └── medication_repository.dart
│   ├── screens/
│   │   ├── app_shell.dart
│   │   ├── home_screen.dart
│   │   ├── today_screen.dart
│   │   ├── add_habit_screen.dart
│   │   ├── medications_screen.dart
│   │   ├── add_medication_screen.dart
│   │   └── history_screen.dart
│   ├── services/
│   │   ├── app_notification_service.dart
│   │   ├── habit_notification_service.dart
│   │   └── medication_notification_service.dart
│   ├── theme/app_theme.dart
│   └── utils/date_utils.dart
```

## Database Migrations (schema v4)

| Version | Changes |
|---|---|
| 1 | `habits` + `habit_instances` |
| 2 | `medications` + `medication_logs` |
| 3 | `sort_order` columns for reordering |
| 4 | `reminder_time` on habits |

## License

MIT