# Delivery App

End-to-end Flutter + Firebase template for a sender/receiver/rider delivery workflow. The project integrates Firestore, Storage, FCM, Cloud Functions, OpenStreetMap tiles, Riverpod state management, and emulator tooling required by the rubric.

## Prerequisites

- Flutter (stable) with Dart 3.4+
- Node.js 18+
- Firebase CLI (`firebase-tools`) for emulators & deployment
- Optional: `npx` for running the TypeScript seed script

## Environment variables

Copy `.env.example` to `.env` and adjust when needed:

```
cp .env.example .env
```

The defaults point to public OpenStreetMap endpoints and enable emulator seeding when `DEBUG_SEED=1`.

## Local development

1. Install Flutter dependencies
   ```bash
   flutter pub get
   ```
2. Install Cloud Functions deps
   ```bash
   npm --prefix functions install
   ```
3. Start Firebase emulators (Firestore, Storage, Functions)
   ```bash
   firebase emulators:start
   ```
4. In another terminal, run the Flutter app (emulator or device)
   ```bash
   flutter run
   ```
5. Seed the emulators with demo users, addresses, riders, and shipments
   ```bash
   npx ts-node scripts/seed.emulator.ts
   ```

### Smoke tests & troubleshooting

- ✅ `flutter analyze` – ensures the Dart code is lint-clean.
- ✅ `flutter test` – runs widget/unit tests (none yet, but command should pass).
- If FCM fails in emulators ensure the device token is saved by calling any screen after login (token sync happens lazily).
- Location permissions are required for rider proximity checks; grant mock GPS when prompted.
- Firestore composite indexes required by queries:
  - `shipments`: `(senderUid, createdAt desc)`
  - `shipments`: `(receiverUid, createdAt desc)`
  - `shipments`: `(riderUid, statusCode)`
  - `shipments`: `(statusCode, updatedAt)`
  - `shipments`: `(sharedMap, senderUid)`

## Rubric checklist

| Step | Notes |
| ---- | ----- |
| 1 | `.env` support, Riverpod bootstrap (`lib/main.dart`, `lib/app.dart`, router/theme helpers). |
| 2 | Firestore models with `withConverter`, services for auth/geocoding/location/storage/FCM/shipments. |
| 3 | Login + sender & rider registration flows (camera uploads, map-picked addresses). |
| 4 | Shipment creator with receiver search, map preview, item photo upload. |
| 5 | Shared map aggregates live shipments with toggle between all vs per-shipment. |
| 6 | Sender & receiver dashboards with list + detail/history views. |
| 7 | Rider job board, transactional accept, active job flow with proximity and photo capture. |
| 8 | Cloud Functions (`assignRider`, `validateNear`, `onShipmentStatusWrite`). |
| 9 | Firestore & Storage security rules aligned with membership-based access. |
| 10 | Emulator config & TypeScript seeding for demo data. |
| 11 | UI polish via Material 3 theme, skeleton loaders, empty states (lists/pages show friendly messaging), README walkthrough + smoke tests. |

## Project structure (excerpt)

```
lib/
  main.dart
  app.dart
  core/
    env/env.dart
    router/app_router.dart
    theme/app_theme.dart
  data/
    models/...
    services/...
  features/
    auth/
    address_book/
    shipment_create/
    shipments_sender/
    shipments_receiver/
    shared_map/
    rider_jobs/
    rider_active/
    shipment_detail/
  widgets/
functions/
  src/index.ts
scripts/
  seed.emulator.ts
```

## Deployment notes

- Configure Firebase project aliases in `.firebaserc`.
- Deploy functions & rules when ready:
  ```bash
  npm --prefix functions run build
  firebase deploy --only functions,firestore:rules,storage:rules
  ```
- Ensure client `.env` values point to production tiles/attribution before release.
