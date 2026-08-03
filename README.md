# HabTrack

A client-only habit, medication, todo, and goals tracker built with Flutter. All data is stored locally in SQLite via Drift — no backend or account required.

## Features

- **Home** – daily overview of habits, todos, and medications; quick check-offs; streak badges and confetti on completion
- **Habits** – daily check-ins, timed/end-of-day reminders, recurrence scheduling, streak tracking, reorderable list, daily notes, emoji & color
- **Todos** – due dates, priorities, subtasks, tags, smart lists (this week, high priority, no tag), calendar day view, recurring tasks, configurable nag reminders
- **Goals** – habit-linked streak targets with reward title, description, and optional reward image
- **Medications** – multi-dose scheduling, dosage tracking, dose logging (taken/snoozed/skipped), adherence analytics
- **History** – trend chart, GitHub-style heatmap, per-habit & per-medication stats, custom time ranges (7d/30d/90d/365d/custom)
- **Notifications** – local push reminders for habits, medications, and todos with interactive actions (done, snooze, skip/dismiss)
- **UI** – dark glassmorphic theme via ShadApp/shadcn_ui, responsive layout (bottom nav on mobile, sidebar on desktop), Riverpod state management

## Tech Stack

Flutter 3.9+, Dart 3.9+, Riverpod, Drift (SQLite), shadcn_ui, fl_chart, flutter_heatmap_calendar, flutter_local_notifications, lottie, flutter_confetti

## Getting Started

```bash
git clone https://github.com/AnshSharmaa/hab_track.git
cd hab_track
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```


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
│   │   ├── medication_repository.dart
│   │   ├── goal_repository.dart
│   │   └── todo_repository.dart
│   ├── screens/
│   │   ├── app_shell.dart
│   │   ├── home_screen.dart
│   │   ├── today_screen.dart
│   │   ├── todos_screen.dart
│   │   ├── add_todo_screen.dart
│   │   ├── goals_screen.dart
│   │   ├── add_habit_screen.dart
│   │   ├── medications_screen.dart
│   │   ├── add_medication_screen.dart
│   │   └── history_screen.dart
│   ├── services/
│   │   ├── app_notification_service.dart
│   │   ├── habit_notification_service.dart
│   │   ├── medication_notification_service.dart
│   │   └── todo_notification_service.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_widgets.dart
│   │   └── habit_colors.dart
│   ├── widgets/
│   │   ├── achievement_badge.dart
│   │   ├── centered_emoji.dart
│   │   ├── confetti_overlay.dart
│   │   └── ring_progress.dart
│   └── utils/date_utils.dart
```

## Database Migrations (schema v8)

| Version | Changes |
|---|---|
| 1 | `habits` + `habit_instances` |
| 2 | `medications` + `medication_logs` |
| 3 | `sort_order` columns for reordering |
| 4 | `reminder_time` on habits |
| 5 | `emoji` and `color_index` on habits |
| 6 | `goals` |
| 7 | `todos`, `todo_subtasks`, `todo_tags`, `todo_tag_map`, `todo_completions` |
| 8 | `emoji` and `color_index` on todos |

## License

MIT
