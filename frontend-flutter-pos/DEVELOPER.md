# frontend-flutter-pos — Developer Guide

Version: 2026-07-16
Audience: developers working on the KAKNNEA POS Flutter cashier app.
Related docs: `README.md` (quick start), `ARCHITECTURE.md` (flows), `../FLUTTER_POS_PLAN.md` (roadmap), `../docs/API.md` (backend API).

## 1. Prerequisites

- Flutter SDK, stable channel (Dart >= 3.0). Verify with `flutter doctor`.
- Android Studio (emulator) or Xcode (simulator).
- Docker + docker-compose for MySQL; JDK 17 + Maven for the backend.

## 2. Run the Stack

```bash
# 1. Database (repo root) — MySQL on host port 3310
docker-compose up -d mysql

# 2. Backend (Spring Boot on port 8081)
cd backend-spring-boot && ./mvnw spring-boot:run

# 3. App
cd frontend-flutter-pos
flutter pub get
flutter run            # pick device; use -d chrome for web
```

Demo login: `cashier@kaknnea.local` / `Password123!` (see `../USER_MANUAL.md` for all demo users).

### Base URL

`lib/core/config/app_config.dart` selects the API host automatically:

| Target | baseUrl |
| --- | --- |
| Android emulator | `http://10.0.2.2:8081` |
| iOS simulator / desktop / web | `http://localhost:8081` |

Physical device: change `baseUrl` to your machine's LAN IP (TODO: move to `--dart-define`).

## 3. Project Layout

```text
lib/
  main.dart                  # app entry, theme, routes
  core/
    config/                  # AppConfig (flags, base URL, colors), pos_theme
    models/                  # auth models (json_serializable)
    providers/               # auth, connectivity, language
    services/                # ApiService (Dio), AuthService
  features/
    auth/screens/            # login
    pos/                     # ACTIVE module: screens, widgets, providers, services, models, theme, utils
    inventory/               # stock screens (being trimmed to read-only lookup — see plan §7 Phase 0)
  pos/                       # LEGACY module — being merged into features/pos; do not add code here
```

Rule: new code goes in `lib/features/<feature>/`. The legacy `lib/pos/` tree is retired incrementally (Phase 0 of `FLUTTER_POS_PLAN.md`).

## 4. Architecture

Layering (see `ARCHITECTURE.md` for the sequence diagram):

```text
Screen (widget) -> Riverpod provider (StateNotifier/FutureProvider)
  -> domain service (lib/features/pos/services)
    -> ApiService (Dio singleton)
      -> Spring Boot API (:8081)
```

- **Screens** never call Dio directly; they watch providers.
- **Providers** hold UI state and orchestrate async calls. Keep them thin.
- **Services** wrap `ApiService` and map JSON to models. They propagate exceptions so UI can show retry/fallback.
- **ApiService** (`lib/core/services/api_service.dart`): single Dio client — base URL from `AppConfig`, JWT attach interceptor (token from `SharedPreferences` under `auth_token`), 401 hook (currently pass-through), request/response logging in debug, `get/post/put/patch/delete/getBytes` with optional `fromJson`.

### State management

`flutter_riverpod` v2. Conventions:

- One provider file per domain in `lib/features/pos/providers/` (`cart_provider`, `shift_provider`, `held_ticket_provider`, …).
- Don't use `ref` after an `await` in widgets without checking `mounted`.
- Business calculations (cart totals, discounts, change) live in providers/services so they are unit-testable.

### Feature flags (`AppConfig`)

| Flag | Default | Meaning |
| --- | --- | --- |
| `enableHeldTicketSync` | `kDebugMode` | Sync held tickets with backend |
| `useApiCartService` | `false` | Persist cart on backend (cart syncs at finalization otherwise) |
| `useApiTableService` | `kDebugMode` | Tables from backend vs local sample data |

Release builds default to safe/off. Flip in `debug_settings_screen.dart` at runtime for testing.

## 5. Key Flows

### Sale
`pos_screen.dart` → product grid + cart panel → `cart_provider` → Pay → `payment_page.dart` / `payment_screen.dart` → `sale_service.dart` posts to `/api/sales` → receipt via `receipt_service.dart`.

### Held tickets
`held_ticket_provider` + `held_ticket_service`; offline operations queue under SharedPreferences key `held_order_ops_queue` and replay on reconnect.

### Shift & cash
`shift_provider` / `shift_service` mirror the backend rules (see backend `ShiftService.java`): close precheck blocks on in-progress tickets (manager credential override), expected cash = opening + cash sales − cash refunds ± cash in/out, variance > 10.00 puts a cashier shift into `PENDING_APPROVAL`.

### Offline
`connectivity_provider` + `offline_mode_widget`; queued sales retried on reconnect. Known gap: no idempotency key yet — do not "improve" retry logic without the backend `clientSaleId` change (plan §7 Phase 3).

### Auth
`AuthService.login()` → stores JWT + user in SharedPreferences → `ApiService` interceptor adds `Authorization: Bearer`. Logout clears keys `auth_token`, `user_data`.

## 6. Coding Conventions

- Lints: `flutter_lints` via `analysis_options.yaml`. `flutter analyze` must be clean before PR. Don't add new `ignore_for_file` blocks (existing ones in `api_service.dart` are temporary).
- Models: `json_serializable` — run `dart run build_runner build --delete-conflicting-outputs` after model changes.
- Strings: all user-facing text goes through the language provider (Khmer + English). No hard-coded UI strings.
- Theme: use `AppConfig` colors / `pos_theme.dart`; never `Colors.green.shade700`-style literals.
- Money: `intl` formatting; KHR has no decimals, USD has two. Keep amounts as `String`/decimal from API — no floating-point math on totals.
- IDs: client-generated UUIDs via `uuid` where offline creation is possible.

## 7. Testing

```bash
flutter test                          # unit + widget tests (test/)
flutter test integration_test        # integration tests (device/emulator required)
flutter test --coverage             # lcov to coverage/
```

Existing suites worth knowing: `cashier_golden_flow_test.dart` (end-to-end sale flow), `cart_provider_resilience_test.dart`, `held_ticket_provider_*`, `payment_*`, `product_grid_*`. Mocks via `mockito` (`test/mocks`, `*.mocks.dart` generated by build_runner).

Requirements for PRs: new calculation logic gets unit tests; new screens get at least a smoke widget test; sale/shift flow changes update `cashier_golden_flow_test.dart`.

## 8. Printing & Scanning

- Receipts: `pdf` + `printing` packages (share/print via OS dialog). ESC/POS Bluetooth/LAN printing is planned (plan §7 Phase 4) — test Khmer rendering before choosing a package.
- Barcode: `mobile_scanner` (camera). Hardware HID scanners work as keyboard input; ensure search fields accept scanner Enter-terminated bursts.

## 9. Troubleshooting

| Symptom | Fix |
| --- | --- |
| API errors on Android emulator | Use `10.0.2.2`, not `localhost` (already handled by `AppConfig`) |
| 401 on every call | Token missing/expired — re-login; check `auth_token` in SharedPreferences |
| `build_runner` conflicts | `dart run build_runner build --delete-conflicting-outputs` |
| Tables/products empty in release build | Feature flags default off in release — check `AppConfig` |
| MySQL connection refused | `docker-compose up -d mysql`; backend expects port 3310 (see repo root compose file) |
| Duplicate-looking screens | You're in legacy `lib/pos/` — the active module is `lib/features/pos/` |

## 10. Contributing Workflow

1. Branch from `main`; keep PRs scoped to one feature/fix.
2. `flutter analyze` + `flutter test` green locally.
3. Update Khmer + English strings together.
4. If a cashier-visible flow changes, update `../USER_MANUAL.md` and the training checklist.
5. Roadmap alignment: check `../FLUTTER_POS_PLAN.md` — back-office features (purchasing, payroll, settings) belong in the Angular admin, not this app.
