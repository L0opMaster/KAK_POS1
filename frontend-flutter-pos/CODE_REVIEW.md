# frontend-flutter-pos — Code Review

Date: 2026-07-16
Scope: `lib/` (142 non-generated Dart files, ~16.6k LOC) and `test/` (34 files, ~3.5k LOC). Static review only — the Flutter SDK was not available in this environment, so `flutter analyze` / tests were not executed. Findings are from reading the source.

## Summary

The app has a sound layering idea (screen → Riverpod provider → domain service → `ApiService`), a centralized theme, configured timeouts, and a real test foundation. But it is mid-migration and roughly **a third of the codebase is empty placeholder files**, two parallel module trees still coexist, money is computed in floating point, and auth token handling has security and correctness gaps. Prioritize consolidation and the money/auth fixes before building new features.

Severity legend: 🔴 high · 🟠 medium · 🟢 low / positive.

## Resolution Status (2026-07-16)

A follow-up pass applied the fixes that are safe to make by static editing. The Flutter toolchain is not available in this environment, so `flutter pub get` / `analyze` / tests were **not** run — please run them locally to confirm the build.

| # | Finding | Status |
| --- | --- | --- |
| 1 | 52 dead stub files | ✅ Deleted (142 → 91 real Dart files) |
| 3 | Floating-point money | ✅ Cart totals now computed in integer minor units via new `core/utils/money.dart`; unit tests added (`test/money_test.dart`) |
| 4 | Credentials in logs | ✅ Body/header logging removed; new logger prints only method/path/status/timing, and only in `kDebugMode` |
| 5 | 401 no-op | ✅ 401 now clears the token and fires `ApiService.onUnauthorized`, wired in `main.dart` to log out |
| 11 | Dead code / unused deps | ✅ Removed unused `AuthState` class and `riverpod_annotation` / `riverpod_generator` deps |
| 2 | Two module trees | ⏳ Not done — needs a compile/test loop (see below) |
| 6 | Offline queue | ⏳ Deferred (plan Phase 3) |
| 7 | Idempotency key | ⏳ Needs backend change (plan Phase 3) |
| 8 | Localization framework | ⏳ Not done — large, needs `gen-l10n` + codegen |
| 9 | `BuildContext` async gaps | ⏳ Needs `flutter analyze` to locate precisely |
| 10 | Blanket lint ignores | ⏳ Partially — logging ignores in `api_service` reduced; broad `ignore_for_file` blocks remain |

**Why the rest wasn't auto-applied:** items 2, 8, 9 require iterating against the Dart analyzer and test runner (merging two diverging implementations, generating localization classes, and fixing lint hits one by one) — doing them blind would likely leave the build red. Items 6 and 7 are Phase 3 in `FLUTTER_POS_PLAN.md` and 7 needs a backend change first. Recommended next step: run `flutter pub get && flutter analyze && flutter test`, then tackle #2 consolidation on a branch.



## 🔴 High-Priority Findings

### 1. ~37% of files are abandoned migration stubs
52 of 142 non-generated Dart files contain only a placeholder comment, e.g.:

```dart
// ...existing code from pos/screens/reports_hub_screen.dart...
```

These span providers, utils, models, screens, and widgets (`reports_hub_screen.dart`, `analytics_dashboard.dart`, `offline_mode_widget.dart`, `split_ticket_page.dart`, `payment_provider.dart`, `permission_utils.dart`, `sale_model.dart`, many dialogs, etc.). None are imported by live code (verified), so they are dead weight that inflates the file tree and misrepresents what is actually implemented. The real feature surface is ~90 files, not 142.

Action: delete the stubs, or finish porting the ones you actually need. Track the intended list so nothing real is lost.

### 2. Two parallel module trees (`lib/pos/` vs `lib/features/pos/`)
The legacy `lib/pos/` tree is still wired into the running app:
- `main.dart` registers `/cart` → `pos/screens/cart_screen.dart`, which uses the **legacy** `pos/providers/cart_provider.dart` (115 lines) — a second, diverging cart implementation alongside the active `features/pos/providers/cart_provider.dart` (330 lines).
- Five inventory screens import product code from the legacy tree: `import '../../pos/providers/product_provider.dart'` and `'../../pos/models/product_models.dart'`.
- Duplicate basenames exist for `auth_provider`, `cart_provider`, `cart_service`, `barcode_scanner_widget`, `pos_header`, `cash_management_screen`.

Two cart implementations that can drift is a correctness risk (totals computed differently in different entry points). Consolidate onto `lib/features/` and delete `lib/pos/` (Phase 0 of `FLUTTER_POS_PLAN.md`).

### 3. Money is computed in floating point
`features/pos/providers/cart_provider.dart` uses `double` throughout:

```dart
double get total => items.fold(0, (sum, item) => sum + item.product.price * item.qty);
double get discountAmount => discountType == DiscountType.fixed
    ? discount
    : (total * (discount / 100)).clamp(0, total);
double get finalTotal => (total - discountAmount - loyalty).clamp(0, double.infinity);
```

Floating-point currency accumulates rounding errors (e.g. percentage discounts, multi-line carts), which surface as receipts that are off by a cent and shift variances that never reconcile. For a POS this is a real defect, not a theoretical one.

Action: represent money as integer minor units (e.g. cents/riel) or use the `decimal` package, and centralize rounding. KHR has no minor unit while USD has two — the money type must carry currency and rounding rules. (Your own `DEVELOPER.md` already states "no floating-point math on totals"; the code doesn't follow it.)

### 4. Auth token stored in plaintext + credentials logged
- JWT and the full user object are written to `SharedPreferences` in plaintext (`AuthService._saveAuthData`). On a shared/rooted counter tablet this is readable. Use `flutter_secure_storage` for the token at least.
- The Dio `LogInterceptor` logs full request and response bodies:

  ```dart
  LogInterceptor(requestBody: true, responseBody: true,
    logPrint: (o) => debugPrint('API: $o'));
  ```

  This prints the login password and the bearer token to the device log. It is `debugPrint` (stripped in release), but it still leaks credentials in every debug/UAT session. Gate it behind `kDebugMode` explicitly and redact `Authorization` and password fields, or drop body logging.

### 5. Expired-token handling is a no-op
- The 401 error interceptor is empty (`// For now, just pass the error`).
- `AuthNotifier._initializeAuth()` restores the session by reading the token from prefs **without validating it** against the backend.

Combined effect: after the token expires, the app still shows the user as logged in, then every API call fails silently with a generic error and no re-login prompt. Implement one of: redirect-to-login on 401, or a token refresh flow. At minimum, validate the token on startup (a cheap `/me`-style call).

## 🟠 Medium-Priority Findings

### 6. "Offline support" is not actually implemented
`offline_mode_widget.dart` is a stub, and `sale_service.createSale()` posts directly to `/api/pos/sales` with no local queue and no retry. There is no offline sale path in the Flutter app today (only `table_service` references a queue). This matches `FLUTTER_POS_PLAN.md` (offline is Phase 3), but marketing/docs that imply offline selling works are premature. Don't ship an "offline" claim until the queue exists.

### 7. No idempotency key on sale creation
`createSale()` sends the sale with no client-generated unique id. On a flaky connection a retried POST can create duplicate sales. Add a `clientSaleId` (UUID) and have the backend dedupe on it — this is the prerequisite for safe offline sync and should be specced now.

### 8. Localization is ad-hoc, not a framework
There is an `AppLanguage` (en/km) toggle provider, but no `flutter_localizations`, no `AppLocalizations`, and no ARB files. Strings are translated inline with `isKhmer ? '…' : '…'` ternaries scattered in widgets, so coverage is inconsistent and every new string is a manual two-branch edit. Adopt Flutter's `gen-l10n` + ARB before the string count grows further.

### 9. Likely `BuildContext`-across-async-gap usages
There are ~47 `Navigator.of(context)` / `ScaffoldMessenger.of(context)` calls but only 7 `mounted` / `context.mounted` guards. Many of these calls almost certainly run after an `await` without a guard, which is the `use_build_context_synchronously` lint and can crash if the widget was disposed mid-request. Run `flutter analyze` and add guards. (I could not run analyze here.)

### 10. Blanket lint suppression hides debt
`ApiService` and `AuthService` start with wide `// ignore_for_file:` blocks silencing ~10 lints each (`public_member_api_docs`, `always_specify_types`, `avoid_catches_without_on_clauses`, `avoid_print`, …). The comment says "remove later." These blanket ignores make the two most critical files exempt from the analyzer. Tighten them to specific lines or fix the underlying issues.

### 11. Unused / dead abstractions
- `core/providers/auth_provider.dart` defines an `AuthState` class with `copyWith` that is never used — the notifier uses `AsyncValue<User?>`. Remove the dead class to avoid confusion.
- `riverpod_annotation` / `riverpod_generator` / `build_runner` are dependencies, but there are **zero** `@riverpod` annotations and only one `.g.dart` file. Either adopt codegen consistently or drop the dependencies.
- Duplicate `pos_header.dart` and `cash_management_screen.dart` exist in multiple trees but neither is imported anywhere — dead.

## 🟢 Low-Priority / Positives

- **Layering is clean**: screens watch providers, providers call services, services wrap a single Dio client. Keep this.
- **Timeouts configured** (30s connect/receive) and a **consistent error mapper** (`_handleError` → `ApiException` with status code and server message extraction).
- **Theme centralized** in `AppConfig` + `pos_theme.dart` with a Loyverse-style palette; feature-flag pattern (`AppConfig`) is reasonable.
- **Tests exist and are meaningful**: 34 files using in-memory fakes (`InMemoryCartService`) and a `cashier_golden_flow_test` (add → hold → reopen → charge). Good base.
  - Gaps: no tests for `payment_screen.dart` (856 LOC, the largest file), inventory flows, or auth. Add coverage there, and add money-math tests once #3 is fixed.
- `payment_screen.dart` at 856 lines is a candidate to split into smaller widgets, but it's real code, not a stub.
- Global `apiService` singleton is created at import time and also exposed via `apiServiceProvider`; minor testability smell but low impact.

## Suggested Order of Work

1. Consolidation (findings #1, #2, #11): delete stubs, merge `lib/pos/` into `lib/features/`, remove dead code. Biggest clarity win, unblocks everything else.
2. Money type (#3) + tests. Correctness-critical for a POS.
3. Auth hardening (#4, #5): secure storage, redact logs, handle 401.
4. `flutter analyze` clean-up (#9, #10) and CI gate.
5. Idempotency key (#7) and real offline queue (#6) — align with plan Phase 3.
6. Localization framework (#8) before adding more screens.

These map directly onto Phase 0–3 of `FLUTTER_POS_PLAN.md`; this review mainly adds the money-type and auth-security items, which the plan under-weights.
