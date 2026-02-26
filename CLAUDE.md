# DataBabe — Baby Care Tracking App

## What this is
A cloud-first baby care tracking app for parents and caregivers. Tracks feeds, diapers, medications, growth, play, and other daily care activities.

## Tech stack
- **Flutter + Dart** — Android native + Flutter Web (for iOS/desktop browsers)
- **Firebase** — Firestore (database), Firebase Auth (authentication)
- **Riverpod** — State management
- **go_router** — Declarative routing
- **fl_chart** — Charts and data visualisation
- **csv** — CSV import

## Architecture
- Cloud-first: all data in Firestore, synced across devices
- Firebase Auth with Google Sign-In
- Multi-carer: Family groups with parent/carer roles
- Repository pattern: abstract interfaces with Firebase implementations

## Project structure
```
lib/
  main.dart              — App entry point (Firebase init)
  app.dart               — MaterialApp with router + auth guard
  firebase_options.dart  — Generated Firebase config
  models/                — Data model classes + enums
  repositories/          — Abstract + Firebase repository implementations
  providers/             — Riverpod providers (auth, repositories, UI state)
  screens/               — Feature screens (auth, home, timeline, log_entry, charts, etc.)
  widgets/               — Shared UI components
  import/                — CSV import logic
  utils/                 — Helpers
```

## Key commands
```bash
flutter pub get                          # Install dependencies
flutter analyze                          # Lint check
flutter test                             # Run tests
flutter run -d chrome                    # Run on web
flutter run -d <device>                  # Run on Android
```

## Firestore data model
```
users/{uid}                              — User profile + familyIds
families/{familyId}                      — Family name + memberUids
families/{familyId}/children/{childId}   — Child records
families/{familyId}/activities/{id}      — Activity entries
families/{familyId}/carers/{carerId}     — Carer records
```

## Conventions
- No code generation needed (no Drift, no build_runner)
- Activity types: each type has its own typed fields (not generic columns)
- UUIDs for all entity IDs (not auto-increment)
- Soft delete via `isDeleted` flag
- Dates stored as Firestore Timestamps

## Privacy
- Never commit real user data (CSV files, personal names, health data)
- Sample/test data uses fake values only
- `.gitignore` excludes `*.csv`, `data/`, `private/`, `instructions.txt`
