# Repository Guidelines

## Project Structure & Module Organization
- `lib/` holds app code:
    - `main.dart`: Entry point, dashboard, and platform channel bridge.
    - `editor/`: Contains the Low-Code Editor logic.
        - `config_screen.dart`: Main flow editor (Drag & Drop list).
        - `action_tile.dart`: Visual representation of actions (supporting expandable IF blocks).
        - `sheets/`: Bottom sheets for configuring specific actions (`fetch_editor.dart`, `common_sheets.dart`).
    - `models.dart`: JSON serialization and Action definitions.
    - `theme.dart`: Centralized colors and typography.
- `android/` contains the native execution engine:
    - `MainActivity.kt`: MethodChannel handlers (`com.shortcuts.shortcuts/widget`).
    - `engine/LogicEngine.kt`: Background execution engine (Kotlin) for running flows without UI.
    - `data/`: Room Database definitions (`WidgetDefinition`, `AppDatabase`).
- `test/widget_test.dart`: Widget and rendering tests.
- `build/` is generated; do not hand-edit or commit output artifacts.

## Build, Test, and Development Commands
- Install deps: `flutter pub get`.
- Static checks: `flutter analyze` (uses `analysis_options.yaml` via `flutter_lints`).
- Format: `dart format lib test`.
- Unit/UI tests: `flutter test` (add `--coverage` when needed).
- Run locally: `flutter run -d chrome` for web or `flutter run -d <device-id>` for device/emulator.

## Coding Style & Naming Conventions
- Dart defaults: 2-space indentation, prefer `final` over `var`, and use `const` constructors where possible to reduce rebuilds.
- Strings: prefer single quotes unless interpolation/escaping is clearer.
- Files: snake_case (`action_picker.dart`), classes in `PascalCase`, methods/fields in `camelCase`, constants in `lowerCamelCase` unless enum-like.
- Keep UI colors and typography in `theme.dart`; extend `AppColors`/`AppStyles` instead of inlining magic values.
- Use trailing commas in widget trees to keep formatter-friendly diffs.
## UI Design Language
- Visual style: blue-toned palette with a clean, borderless look.
- Prefer edge-to-edge list items without card borders; use spacing and subtle fills for separation.
- Keep background fills light and cool (blue-white), especially for code/detail blocks.

## Testing Guidelines
- Place tests under `test/` mirroring `lib/` structure; name files `*_test.dart` and test widgets with `testWidgets`.
- Cover platform-channel-facing logic by stubbing `MethodChannel` with `setMockMethodCallHandler`.
- Gate PRs by running `flutter analyze` and `flutter test`; include coverage deltas when meaningful (`flutter test --coverage`).

## Commit & Pull Request Guidelines
- Use short, imperative commit subjects; Conventional Commit prefixes (e.g., `feat:`, `fix:`, `chore:`) are preferred for clarity.
- Each PR should describe the change, affected platforms (Flutter/web/android), and include screenshots or screen recordings for UI updates.
- Link related issues/task IDs when available; call out platform channel contract changes so native reviewers can mirror updates.
- Before requesting review, run `flutter analyze`, `dart format`, and `flutter test`; note any known gaps or follow-ups in the PR description.

## Security & Configuration Tips
- Keep secrets out of the repo; use platform-appropriate secure storage or CI variables.
- When touching the `MethodChannel`, validate argument shapes and surface user-friendly errors (e.g., toasts/snackbars) rather than silent failures.
