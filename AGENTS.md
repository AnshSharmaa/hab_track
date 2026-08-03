# AGENTS.md

## Cursor Cloud specific instructions

HabTrack is a **client-only Flutter app** (no backend, Docker, or `.env` files). All data is stored locally in SQLite via Drift.

### Prerequisites (VM image)

The Flutter SDK is installed at `~/flutter` and added to `PATH` via `~/.bashrc`. Linux desktop builds also require system packages: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `g++`, and **`libstdc++-14-dev`** (clang++ needs this for `-lstdc++` linking).

Enable Linux desktop once per VM: `flutter config --enable-linux-desktop`.

### Standard commands

See `README.md` for the canonical getting-started flow. Quick reference:

| Task | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Codegen (Drift) | `dart run build_runner build --delete-conflicting-outputs` |
| Lint | `flutter analyze` |
| Test | `flutter test` |
| Run (Linux) | `flutter run -d linux` |
| Run (Web) | `flutter run -d chrome` |

**Codegen is required** after changing `lib/src/db/app_db.dart` or other Drift-annotated files. Generated output lives in `lib/src/db/app_db.g.dart`.

### Running the app

- Preferred target in this environment: **Linux desktop** (`flutter run -d linux`). Chrome (`-d chrome`) also works.
- Long-running dev server: use a tmux session (e.g. `habtrack-linux`) so the process survives across commands.
- First Linux build is slow (~2–3 min); subsequent hot-reloads are fast.
- Debug mode auto-seeds mock data via `MockSeed` in `lib/main.dart` with anchor date **2026-04-24**. If the VM system date is far from that anchor, Today views may appear empty even though seed data exists for the anchor window.

### Gotchas

- **No Android SDK** in the cloud VM — `flutter doctor` will warn about Android; ignore for Linux/web development.
- **Notifications** require OS integration and are optional for core CRUD/analytics flows.
- **ScaffoldMessenger**: some screens call `ScaffoldMessenger.of(context)` while the app root is `ShadApp` (not `MaterialApp`). Saving habits/goals may log a `debugCheckHasScaffoldMessenger` error in the console; navigation may still partially work but SnackBars will fail.
