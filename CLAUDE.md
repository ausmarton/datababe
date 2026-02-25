# Filho — Baby Care Tracking App

## What this is
A privacy-first baby care tracking app for parents and caregivers. Tracks feeds, diapers, medications, growth, play, and other daily care activities.

## Tech stack
- **Flutter + Dart** — Android native + Flutter Web (for iOS/desktop browsers)
- **Drift** — Type-safe SQLite ORM with code generation
- **Riverpod** — State management
- **go_router** — Declarative routing
- **fl_chart** — Charts and data visualisation
- **csv** — CSV import/export

## Architecture
- Local-first: all data in SQLite on the user's device
- Multi-carer: Family groups with parent/carer roles
- CRDT sync planned for Phase 2 (not yet implemented)

## Project structure
```
lib/
  main.dart          — App entry point
  app.dart           — MaterialApp with router
  models/            — Enums and data types
  database/          — Drift DB, tables, DAOs
  providers/         — Riverpod providers
  screens/           — Feature screens (home, timeline, log_entry, charts, etc.)
  widgets/           — Shared UI components
  import/            — CSV import logic
  utils/             — Helpers
```

## Key commands
```bash
flutter pub get                          # Install dependencies
dart run build_runner build              # Generate Drift & Riverpod code
dart run build_runner build --delete-conflicting-outputs  # Regen from scratch
flutter analyze                          # Lint check
flutter test                             # Run tests
flutter run -d chrome                    # Run on web
flutter run -d <device>                  # Run on Android
```

## Conventions
- Generated files: `*.g.dart` — never edit manually, always regenerate
- Database changes: update tables in `lib/database/tables/`, then run build_runner
- Activity types: each type has its own typed fields (not generic columns)
- UUIDs for all entity IDs (not auto-increment)
- Soft delete via `isDeleted` flag (for future CRDT sync)
- Dates stored as integer (milliseconds since epoch) in DB

## Privacy
- Never commit real user data (CSV files, personal names, health data)
- Sample/test data uses fake values only
- `.gitignore` excludes `*.csv`, `data/`, `private/`, `instructions.txt`
