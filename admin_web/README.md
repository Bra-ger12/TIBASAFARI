# Tiba Safari — Flutter Web Admin Portal

A complete medical-transport admin portal built with **Flutter Web** (Dart) +
a **Next.js 16** JSON API backend (Prisma + SQLite).

## What's in this zip

```
flutter_app/                  ← Flutter Web app (Dart source)
├── lib/
│   ├── main.dart             ← app entry point
│   ├── app_shell.dart        ← sidebar + topbar + footer shell
│   ├── models/               ← typed Dart domain models
│   ├── services/             ← api_service.dart, format.dart, csv.dart
│   ├── theme/                ← Material 3 theme + status-tone colors
│   ├── widgets/              ← sidebar, data_table, live_map, kpi_card,
│   │                           status_badge, assign_driver_dialog, shared
│   └── screens/              ← 22 screens (dashboard, bookings, trips,
│                               patients, drivers, vehicles, billing,
│                               reports, notifications, settings)
├── web/                      ← Flutter web bootstrap (index.html, manifest)
├── pubspec.yaml              ← dependencies: http, intl, fl_chart
├── analysis_options.yaml
└── README.md                 ← this file

backend/                      ← Next.js API + Prisma schema (see below)
├── prisma/
│   └── schema.prisma         ← database models
├── api-routes/               ← all 22 API route handlers (TS)
└── seed.ts                   ← realistic Tanzanian seed data
```

## Prerequisites

1. **Flutter SDK** ≥ 3.44.2 (includes Dart 3.12) — https://docs.flutter.dev/get-started/install
2. **Node.js** ≥ 20 and **bun** (or npm) for the backend API
3. Verify Flutter: `flutter doctor`

## How to run it locally

### Option A — Flutter frontend + Next.js backend (full stack)

1. **Start the backend** (from the project root that contains `prisma/` and
   the Next.js app):
   ```bash
   bun install
   bun run db:push        # create SQLite tables
   bun run prisma/seed.ts # seed realistic data
   bun run dev            # starts API on http://localhost:3000
   ```

2. **Run the Flutter app** (in another terminal, from `flutter_app/`):
   ```bash
   flutter pub get
   flutter run -d chrome   # OR: flutter build web
   ```
   The Flutter app calls the API at the relative path `/api/...`, so it must
   be served from the same origin as the Next.js backend
   (`http://localhost:3000`).

### Option B — Build Flutter to static files, host inside Next.js

```bash
cd flutter_app
flutter build web --base-href /flutter/ --release
cp -r build/web/* ../public/flutter/
```
Then `bun run dev` serves both the API and the Flutter app at
`http://localhost:3000/` (the Next.js `/` route embeds `/flutter/index.html`
in a full-viewport iframe).

## Rebuilding after Dart changes

Any time you edit a `.dart` file under `flutter_app/lib/`:

```bash
cd flutter_app
flutter build web --base-href /flutter/ --release
cp -r build/web/* ../public/flutter/
```

## Features

- **Dashboard** — 4 KPI cards (Active Trips, Pending Bookings, Drivers Online,
  Revenue Today) with trend indicators + live custom-painted map of active
  vehicles
- **Bookings** — Pending (Approve / Assign Driver / Cancel), All Bookings,
  Detail with action panel
- **Trips** — Active (live map), All Trips, Detail
- **Patients** — List (activate/deactivate), Profile with trip history
- **Drivers** — List, Profile with ratings/stats + Assign Vehicle dialog
- **Vehicles** — List, Add, Edit forms
- **Billing** — Invoices (filter by payment status), Invoice detail with
  status updates and breakdown
- **Reports** — Trip Report (CSV export), Driver Report (performance metrics),
  Revenue Report (fl_chart line chart + CSV export)
- **Notifications** — Broadcast to roles (all / drivers / patients / admins)
  via push / SMS / email
- **Settings** — Admin Profile, System Configuration

## Tech stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.44 (Dart 3.12), Material 3 |
| Charts | fl_chart |
| HTTP | http package |
| Backend API | Next.js 16 App Router (TypeScript) |
| ORM | Prisma 6 (SQLite) |
| State | Flutter StatefulWidget + ChangeNotifier (NavState) |

## Data theme

Realistic Tanzanian medical-transport operations centered on Dar es Salaam:
drivers (Juma, Asha, Fredrick, Neema…), patients with special needs
(wheelchair, oxygen tank), hospitals (Muhimbili, Aga Khan, Regency), and
fare currency in TZS.

---

© Tiba Safari · Medical Transport Operations · Dar es Salaam, Tanzania
