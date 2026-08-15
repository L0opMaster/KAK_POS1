# Mobile (Android/iOS) 20-Day Build Plan — Two-Project Edition

Status: **planning/teaching document only**. No production code was changed to produce this. Every function body, class, endpoint, and backend trace was read directly from the current source (`frontend-flutter-pos/lib/`, `backend-spring-boot/src/main/java/`) — not carried over from assumption or memory.

**Architecture correction (this revision)**: an earlier version of this document recommended building the mobile app *inside* `frontend-flutter-pos` (adding Android/iOS targets to the existing project, with mobile screens under `lib/features/pos/mobile/`). **That recommendation was wrong for this plan and has been reversed.** The mobile app is a **separate, independently-compilable Flutter project**. `frontend-flutter-pos` is read-only reference material for this entire plan — studied, never modified, never extended with mobile code.

---

## The Two-Project Architecture

```text
                         backend-spring-boot/
                        (unchanged, shared, single backend)
                          /                        \
                         /                          \
                REST API /                            \ REST API
                       /                                \
      frontend-flutter-pos/                    mobile-flutter-pos/
      Existing web/desktop POS                 NEW — Android + iOS
      (Project A — SOURCE OF TRUTH)             (Project B — being built)
      READ-ONLY for this plan                   its own android/ ios/ lib/ test/ pubspec.yaml
```

```text
frontend-flutter-pos
        |
        | STUDY / REFERENCE ONLY
        | (architecture, models, Riverpod patterns, business logic,
        |  API contracts, cart/payment/shift/inventory/receipt/printing
        |  logic, Khmer handling, reports, localization terminology)
        v
mobile-flutter-pos
        |
        | IMPLEMENT / ADAPT
        | (own files, own project, compiles independently)
        v
   Android + iOS
```

- **Project A — `frontend-flutter-pos/`**: the existing POS. Source of truth for architecture, models, Riverpod patterns, business logic, API contracts, cart/payment/shift/inventory/receipt/printing logic, Khmer handling, reports, and localization terminology. **Read-only for this entire plan** — every "Day" below studies it, none of them modify it. If you discover an actual bug in this project while studying it, **stop and report it separately** — do not silently fix it as part of the mobile build.
- **Project B — `mobile-flutter-pos/`**: the new mobile app, created fresh on Day 2. Has its own `android/`, `ios/`, `lib/`, `test/`, `integration_test/`, `pubspec.yaml`. Compiles and runs independently of `frontend-flutter-pos`. Its Android/iOS platform folders are the *only* ones this plan ever touches — `frontend-flutter-pos/android/` and `frontend-flutter-pos/ios/` are never configured or modified by this plan.
- **`backend-spring-boot/`**: unchanged, shared by both clients. This plan never creates a second backend and never modifies backend code (unless a genuine shared bug is found — see above, still handled as a separate, reported issue, not a silent fix).

### Naming this project

`mobile-flutter-pos` is used as the placeholder name throughout this document. Confirm the real name with whoever owns the repo/org naming convention before Day 2 actually runs `flutter create` — renaming a Flutter project after creation is possible but annoying (package name, Android `applicationId`, iOS bundle ID, and every internal import path all need to agree), so it's worth 30 seconds to confirm before Day 2, not after.

### What "same architecture" means here

It does **not** mean sharing Dart files between the two projects at the source level. It means: study the implementation in `frontend-flutter-pos`, then write the *corresponding* code in `mobile-flutter-pos` — same class shapes, same method signatures, same state-management pattern, same API contract — as new files that happen to live in a different project. The new project must compile independently; it must never `import` a relative path reaching into `../frontend-flutter-pos/lib/...`. Every "copy" instruction in this plan means *copy-and-adapt into a new file in the new project*, not a symlink or a cross-project import.

### Two options for how much actually gets shared — discussed, not decided here

**Option A — Phase 1 (what this 20-day plan builds)**: two fully separate projects, with `mobile-flutter-pos`'s Dart files independently written, studying `frontend-flutter-pos` as reference and adapting its logic. Fastest to build and to learn from, since every file in the new project is self-contained and there's no package-publishing/versioning overhead to manage while the mobile UI itself is still being designed and iterated on.

```text
frontend-flutter-pos          mobile-flutter-pos
(independent)                 (independent)
```

**Option B — Later, only if duplication becomes a real maintenance cost**: extract the genuinely-shared, UI-free logic (candidates: model classes, `Money`, `ReceiptViewModel`, some service interfaces, pure business-rule utilities like `bilingual.dart`/`khmer_text.dart`) into a proper shared Dart package:

```text
frontend-flutter-pos
      ↓
   pos_core   (packages/pos_core/ — a local Dart package, path-dependency in both apps' pubspec.yaml)
      ↑
mobile-flutter-pos
```

**This plan does not build `packages/pos_core/`.** It's named here so the idea isn't a surprise later, and so you can recognize the signal for when to revisit it (e.g., the same bug getting fixed twice, once per project, more than once) — but introducing it is a deliberate future decision to make explicitly, not something to back into accidentally during these 20 days.

---

## How to Read This Document

Every day (1–20) has the same section structure as before, with one addition: **every file reference is now labeled with which project it belongs to.**

- `[OLD/SOURCE — READ]` — a file in `frontend-flutter-pos/`. You open it, study it, understand the function bodies inside it. **You never edit it.**
- `[NEW/MOBILE — CREATE]` or `[NEW/MOBILE — CREATE/MODIFY]` — a file in `mobile-flutter-pos/`. You write this file, adapting the logic you just studied in the paired `[OLD/SOURCE]` file.

A file reference with no label is a mistake — if you ever see a bare `Open cart_provider.dart` anywhere below without one of these two tags and a full project-prefixed path, treat it as a documentation bug and use the surrounding context to infer which project it means (day sections were re-verified for this, but flag it if you spot one).

Each day still has: **A. Where Do I Start?**, **B. Existing [OLD/SOURCE] Function Chain**, **C. Backend/API Chain**, **D. Exact [OLD/SOURCE] Functions to Study → [NEW/MOBILE] Functions to Write**, **E. Exact [NEW/MOBILE] Files to Create**, **F. Exact [NEW/MOBILE] Function Skeleton**, **G. Function Inputs and Outputs**, **H. State Before and After**, **I. Classification** (see taxonomy below), **J. Build Order**, **K. "When I Click This, What Happens?"**, **L. "Where Does This Value Come From?"**, **M. Navigation Flow**, **N. Error Flow**, **O. Test Flow**. Every day additionally opens with two explicit lists:

```text
## SOURCE FILES TO STUDY          (all paths start with frontend-flutter-pos/)
## NEW MOBILE FILES TO CREATE/MODIFY   (all paths start with mobile-flutter-pos/)
```

### Project structure this document assumes

**`[OLD/SOURCE]` — `frontend-flutter-pos/` (existing, unchanged):**
```text
frontend-flutter-pos/
  lib/
    main.dart
    core/{config,models,providers,services,utils}/
    core/services/printing/            # a4_report_pdf.dart, khmer_text_rasterizer.dart
    features/
      auth/screens/                    # login_screen.dart
      pos/{models,providers,services,screens,widgets}/
      pos/services/printing/           # thermal_printer_service.dart, escpos_receipt_builder.dart, ...
      inventory/{models,providers,services,screens}/
      reports/{models,services,screens,widgets}/
    l10n/                              # app_en.arb, app_km.arb (source strings)
    l10n/generated/                    # AppLocalizations — never hand-edit
  lib/pos/                             # LEGACY — retired, do not study or copy from this either
  android/  ios/                       # this project's OWN platform folders — NEVER touched by this plan
```

**`[NEW/MOBILE]` — `mobile-flutter-pos/` (created Day 2, this plan's actual deliverable):**
```text
mobile-flutter-pos/
  android/
  ios/
  lib/
    main.dart
    core/{config,providers,services,utils}/
    core/services/printing/
    features/
      auth/screens/
      pos/{models,providers,services,screens,widgets}/
      pos/services/printing/
      inventory/{models,providers,services,screens}/
      reports/{models,services,screens,widgets}/
      settings/
      customers/
    l10n/
  test/
  integration_test/
  pubspec.yaml
```
Note: `mobile-flutter-pos`'s `lib/features/pos/screens/` holds the mobile screens directly — there is no `mobile/` subfolder nested inside it, because the whole project *is* the mobile app now; nesting `mobile/` only made sense under the old (wrong) single-project plan. Screen file names still carry a `mobile_` prefix where useful for clarity against the pattern studied in `[OLD/SOURCE]` (e.g. `mobile_cart_screen.dart`), but that's a naming convention, not a folder-isolation mechanism.

---

## Where Should I Write Code?

| I need... | Belongs in project | Write it under... |
|---|---|---|
| A new **screen** | `mobile-flutter-pos` | `lib/features/pos/screens/` (or `lib/features/inventory/screens/`, etc.) |
| A reusable **widget** | `mobile-flutter-pos` | `lib/features/pos/widgets/` |
| New **business state** (provider/notifier) | `mobile-flutter-pos` | `lib/features/pos/providers/` — but first read the `[OLD/SOURCE]` equivalent in `frontend-flutter-pos/lib/features/pos/providers/`, since you're adapting it, not inventing from scratch |
| A new **API operation** | `mobile-flutter-pos` | `lib/features/pos/services/` — same rule: read the `[OLD/SOURCE]` service first |
| New **JSON data shape** (model) | `mobile-flutter-pos` | `lib/features/pos/models/` |
| A new **translated string** | `mobile-flutter-pos` | its own `lib/l10n/app_en.arb` + `app_km.arb`, then `flutter gen-l10n` **inside `mobile-flutter-pos`** — this project gets its own generated localization files, entirely separate from `frontend-flutter-pos`'s |
| A new **printer transport** | `mobile-flutter-pos` | `lib/features/pos/services/printing/`, implementing a `PrinterTransport` interface you write in this project (studied from `[OLD/SOURCE]`'s `printer_transport.dart`) |
| An Android/iOS **permission** | `mobile-flutter-pos` | `mobile-flutter-pos/android/app/src/main/AndroidManifest.xml` / `mobile-flutter-pos/ios/Runner/Info.plist` — **never** `frontend-flutter-pos/android/` or `frontend-flutter-pos/ios/` |
| Understanding an existing **business rule** | `frontend-flutter-pos` (read-only) | open the relevant `[OLD/SOURCE]` file, read the function, then go write its `[NEW/MOBILE]` counterpart |

## Do Not Put Code Here

- **Do not** create any file under `frontend-flutter-pos/lib/.../mobile/` or anywhere else inside `frontend-flutter-pos/lib/` — this entire project is read-only reference for this plan, full stop.
- **Do not** touch `frontend-flutter-pos/android/` or `frontend-flutter-pos/ios/` — the mobile app's platform folders live exclusively in `mobile-flutter-pos/android/` and `mobile-flutter-pos/ios/`, created on Day 2.
- **Do not** import across projects (e.g. `import '../../frontend-flutter-pos/lib/...';` from inside `mobile-flutter-pos`). `mobile-flutter-pos` must compile completely on its own.
- **Do not** put money/discount/tax math inside a widget's `build()` method — study `[OLD/SOURCE]`'s `CartState` getters (`total`, `discountAmount`, `taxAmount`, `finalTotal`) and recreate the same computed-getter shape in `[NEW/MOBILE]`'s `CartState`.
- **Do not** call `Dio`/`ApiService` directly from a widget in `mobile-flutter-pos` — always through a service, mirroring `[OLD/SOURCE]`'s pattern.
- **Do not** study or copy from `frontend-flutter-pos/lib/pos/` (the legacy module, retired even within Project A itself — irrelevant to this plan twice over).
- **Do not** hand-edit `mobile-flutter-pos/lib/l10n/generated/*.dart` — generated by `flutter gen-l10n` from that project's own two `.arb` files.
- **Do not** fork or duplicate `[OLD/SOURCE]`'s `ReceiptContent`/`ReceiptViewModel` design *within* `mobile-flutter-pos` once you've written its own version — that project should have exactly one receipt-rendering widget, reused by preview/PDF/ESC-POS, exactly like `frontend-flutter-pos` does.
- **Do not** silently fix an `[OLD/SOURCE]` bug as part of building `[NEW/MOBILE]`. If you find one while studying `frontend-flutter-pos`, stop, report it separately, and continue building the mobile equivalent around documented (even if imperfect) current behavior unless told otherwise.

---

## Classification Taxonomy — Used for Every File/Function Below

- **COPY/ADAPT NEARLY EXACTLY** — the `[OLD/SOURCE]` logic is platform-neutral and correct; write a `[NEW/MOBILE]` file with the same class/method shapes, same signatures, same business rules. Example: `CartNotifier`, `Money`, `ReceiptViewModel`.
- **RECREATE USING SAME LOGIC** — the business rule/algorithm must match exactly, but the `[OLD/SOURCE]` implementation has incidental details (e.g. a desktop-only helper it leans on) that don't carry over 1:1; recreate the rule faithfully rather than transcribing the file verbatim. Example: `ApiService` (same interceptor behavior, but base-URL resolution needs mobile-specific logic — see Day 4).
- **MOBILE UI REIMPLEMENT** — the `[OLD/SOURCE]` screen/widget's *layout* is desktop-specific and must not be copied; the state/logic it calls into is what you're preserving. Example: `PosScreen`'s 380px sidebar, `PaymentScreen`'s 2-column `Row`.
- **PLATFORM IMPLEMENTATION** — the interface/shape is shared, but the concrete implementation is inherently platform-specific and needs its own mobile-appropriate code (often with new permission-handling). Example: `NetworkPrinterTransport`, `BluetoothPrinterTransport`, `UsbPrinterTransport`.
- **DO NOT COPY** — dead code, legacy code, or code that solves a problem that no longer exists once the app itself runs on a phone. Example: `frontend-flutter-pos/lib/pos/` (legacy), `product.dart`/`product_api_service.dart` (confirmed dead code), the phone-to-phone barcode relay (solved a "desktop has no camera" problem that a phone doesn't have).

---

# Day 1 — Architecture Mapping: Read-Only Study of `frontend-flutter-pos`

**No `mobile-flutter-pos` project exists yet — it is created Day 2.** Today is 100% reading. Nothing is written to disk in either project.

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/main.dart
frontend-flutter-pos/lib/core/config/app_config.dart
frontend-flutter-pos/lib/core/config/pos_theme.dart
frontend-flutter-pos/lib/core/config/currency_utils.dart
frontend-flutter-pos/lib/core/services/api_service.dart
frontend-flutter-pos/lib/core/services/auth_service.dart
frontend-flutter-pos/lib/core/providers/auth_provider.dart
frontend-flutter-pos/lib/core/providers/language_provider.dart
frontend-flutter-pos/lib/core/providers/theme_provider.dart
frontend-flutter-pos/lib/core/providers/company_provider.dart
frontend-flutter-pos/lib/core/providers/currency_provider.dart
frontend-flutter-pos/lib/core/models/auth_models.dart
frontend-flutter-pos/lib/core/utils/money.dart
frontend-flutter-pos/lib/core/utils/khmer_text.dart
frontend-flutter-pos/lib/core/utils/bilingual.dart
frontend-flutter-pos/lib/core/utils/l10n_extensions.dart
frontend-flutter-pos/lib/core/utils/receipt_date_format.dart
frontend-flutter-pos/lib/features/auth/screens/login_screen.dart
frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart  (full module inventory)
frontend-flutter-pos/lib/features/pos/providers/  (all files — skim for now, deep-dive per day below)
frontend-flutter-pos/lib/features/pos/services/  (all files, including services/printing/)
frontend-flutter-pos/lib/features/inventory/  (models/providers/services/screens)
frontend-flutter-pos/lib/features/reports/  (models/services/screens/widgets)
frontend-flutter-pos/lib/l10n/app_en.arb, app_km.arb
```
**Explicitly do NOT open** `frontend-flutter-pos/lib/pos/` (legacy, retired even within Project A).

## NEW MOBILE FILES TO CREATE/MODIFY

None today.

## A. Where Do I Start?

Open `[OLD/SOURCE — READ] frontend-flutter-pos/lib/main.dart`. Read `PosApp.build(BuildContext context, WidgetRef ref)`. This one function decides both the initial screen and how every screen gets to the network — everything else in this document traces back to it, and the `[NEW/MOBILE]` `mobile-flutter-pos/lib/main.dart` you'll write on Day 2/4 will do the same job for the new project.

## B. Existing `[OLD/SOURCE]` Function Chain — `main()` and `PosApp.build`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  await SharedPreferences.getInstance();
  unawaited(_prewarmPrinting());
  runApp(const ProviderScope(child: PosApp()));
}
```
Order matters: Flutter bindings → `AppConfig.initialize()` (currently a no-op) → pre-warm `SharedPreferences` (so the auth check next is instant) → fire-and-forget printing font pre-load → `runApp` wrapped in `ProviderScope`.

```dart
Widget build(final BuildContext context, final WidgetRef ref) {
  final authState = ref.watch(authProvider);
  ApiService.onUnauthorized = () => ref.read(authProvider.notifier).logout();
  return MaterialApp(
    theme: PosTheme.lightTheme, darkTheme: PosTheme.darkTheme,
    themeMode: ref.watch(themeModeProvider).value,
    locale: ref.watch(appLanguageProvider).toLocale(),
    supportedLocales: const [Locale('en'), Locale('km')],
    localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    routes: <String, WidgetBuilder>{ /* ~40 routes, see Day 5 */ },
    home: authState.maybeWhen(
        data: (final User? user) => user != null ? const PosScreen() : const LoginScreen(),
        orElse: () => const LoginScreen()),
  );
}
```
`authState` is `AsyncValue<User?>` from `authProvider`. `home:` uses `AsyncValue.maybeWhen`: only the `data` case checks `user != null`; `loading`/`error` fall through to `LoginScreen()`.

## C. Backend/API Chain — three complete chains to internalize before Day 2

**LOGIN** (full detail Day 4):
```text
[NEW/MOBILE] MobileLoginScreen._login()
  -> [NEW/MOBILE] AuthNotifier.login(email, password)          (adapted from [OLD/SOURCE] AuthNotifier)
  -> [NEW/MOBILE] AuthService.login()                           (adapted from [OLD/SOURCE] AuthService)
  -> [NEW/MOBILE] ApiService.post('/api/auth/login', ...)       (adapted from [OLD/SOURCE] ApiService)
  -> POST /api/auth/login  (SAME backend endpoint both projects call)
  -> AuthController.login(...) -> AuthService.login(...) [backend, unchanged, shared]
  -> UserRepository.findByEmail -> password check -> JwtUtil.generateToken
  -> AuthDtos.LoginResponse{token, user}
  -> [NEW/MOBILE] AuthResponse.fromJson(response)
  -> [NEW/MOBILE] AuthService._saveAuthData()
  -> [NEW/MOBILE] AuthNotifier.state = AsyncValue.data(user)
  -> [NEW/MOBILE] MobileHomeShell appears (Day 5)
```

**PRODUCT** (full detail Day 6):
```text
[NEW/MOBILE] MobilePosScreen.initState -> [NEW/MOBILE] ProductNotifier.loadProducts()
  -> [NEW/MOBILE] ProductService.getProducts(...)
  -> [NEW/MOBILE] ApiService.get('/api/products/pos-catalog')
  -> GET /api/products/pos-catalog  (SAME endpoint)
  -> ProductController.posCatalog(storeId) [backend, unchanged, shared]
  -> List<Product>
  -> [NEW/MOBILE] ProductState.products
  -> [NEW/MOBILE] MobileProductGrid rebuilds
```

**SALE** (full detail Day 11):
```text
[NEW/MOBILE] product tap -> CartNotifier.addItemFromProduct/addItem
  -> Charge -> MobilePaymentScreen -> MobilePaymentScreen._submitSaleToBackend()
  -> [NEW/MOBILE] SaleService.createSale(request) -> POST /api/pos/sales
  -> SaleController.create -> SaleService.create [backend, unchanged, shared]
  -> (if payments present) [NEW/MOBILE] SaleService.paySale(saleId, payments) -> POST /api/pos/sales/{id}/pay
  -> SaleResponse
  -> [NEW/MOBILE] SaleService.getReceipt(saleId) -> GET /api/pos/sales/{id}/receipt -> ReceiptResponse map
  -> [NEW/MOBILE] ReceiptViewModel.fromReceiptResponse(...)
  -> [NEW/MOBILE] ReceiptContent (preview / PDF / ESC-POS all read this one model)
```
Every chain above is identical in *shape* on both sides of the `[OLD/SOURCE]` → `[NEW/MOBILE]` line — same layering, same backend endpoints, same request/response contracts. Only the concrete Dart files differ (one project's files, not the other's), and only the UI at the very front of each chain differs deliberately (Day 5 onward).

## D. Old File → Purpose → New Mobile Destination

This table is today's actual deliverable — the architecture map. Every row: study the `[OLD/SOURCE]` file's purpose, note its `[NEW/MOBILE]` destination (same relative path inside the new project unless noted).

| `[OLD/SOURCE]` (frontend-flutter-pos/lib/...) | Purpose | `[NEW/MOBILE]` destination (mobile-flutter-pos/lib/...) |
|---|---|---|
| `main.dart` | app entry, routes map, auth-gated `home:` | `main.dart` |
| `core/config/app_config.dart` | feature flags, base URL, SharedPreferences keys | `core/config/app_config.dart` |
| `core/config/pos_theme.dart` | light/dark `ThemeData`, spacing/radius scale | `core/config/pos_theme.dart` |
| `core/config/currency_utils.dart` | currency symbols/formatting | `core/config/currency_utils.dart` |
| `core/services/api_service.dart` | Dio client, JWT interceptor, error mapping | `core/services/api_service.dart` |
| `core/services/auth_service.dart` | login/logout/token persistence | `core/services/auth_service.dart` |
| `core/providers/auth_provider.dart` | `AuthNotifier`, session state | `core/providers/auth_provider.dart` |
| `core/providers/language_provider.dart` | EN/KM selection, persisted | `core/providers/language_provider.dart` |
| `core/providers/theme_provider.dart` | light/dark toggle | `core/providers/theme_provider.dart` |
| `core/providers/company_provider.dart` | company profile fetch/cache | `core/providers/company_provider.dart` |
| `core/providers/currency_provider.dart` | active currency, tender rates | `core/providers/currency_provider.dart` |
| `core/models/auth_models.dart` | `User`, `AuthResponse`, `LoginRequest` | `core/models/auth_models.dart` |
| `core/utils/money.dart` | integer-minor-unit money math | `core/utils/money.dart` |
| `core/utils/khmer_text.dart` | `containsKhmerText` | `core/utils/khmer_text.dart` |
| `core/utils/bilingual.dart` | `resolveBilingual` EN/KM field picker | `core/utils/bilingual.dart` |
| `core/utils/l10n_extensions.dart` | `context.l10n` shorthand | `core/utils/l10n_extensions.dart` |
| `core/utils/receipt_date_format.dart` | UTC→local date/time formatting | `core/utils/receipt_date_format.dart` |
| `core/services/printing/a4_report_pdf.dart` | A4 report/invoice PDF builder | `core/services/printing/a4_report_pdf.dart` |
| `core/services/printing/khmer_text_rasterizer.dart` | per-string Khmer rasterization (reports) | `core/services/printing/khmer_text_rasterizer.dart` |
| `features/auth/screens/login_screen.dart` | desktop login UI (layout reference only) | `features/auth/screens/mobile_login_screen.dart` |
| `features/pos/models/cart_models.dart` | `CartItem`, `SelectedModifier`, `HeldOrder` | `features/pos/models/cart_models.dart` |
| `features/pos/models/product_models.dart` | `Product`, `Category` (the real, active models) | `features/pos/models/product_models.dart` |
| `features/pos/providers/cart_provider.dart` | `CartState`, `CartNotifier` — cart business logic | `features/pos/providers/cart_provider.dart` |
| `features/pos/providers/product_provider.dart` | `ProductState`, `ProductNotifier` | `features/pos/providers/product_provider.dart` |
| `features/pos/providers/category_provider.dart` | category list state | `features/pos/providers/category_provider.dart` |
| `features/pos/providers/customer_provider.dart` | customer list/search state | `features/pos/providers/customer_provider.dart` |
| `features/pos/providers/table_selection_provider.dart` | current-table UI state | `features/pos/providers/table_selection_provider.dart` |
| `features/pos/providers/held_ticket_provider.dart` | hold/resume ticket state | `features/pos/providers/held_ticket_provider.dart` |
| `features/pos/providers/shift_provider.dart` | shift open/close state | `features/pos/providers/shift_provider.dart` |
| `features/pos/providers/receipt_provider.dart` | receipt history + status filters | `features/pos/providers/receipt_provider.dart` |
| `features/pos/services/cart_service.dart` | `ApiCartService`/`LocalCartService` | `features/pos/services/cart_service.dart` |
| `features/pos/services/product_service.dart` | `ApiProductService` + demo fallback | `features/pos/services/product_service.dart` |
| `features/pos/services/sale_service.dart` | `createSale`/`paySale`/`getReceipt`/`refundSale` | `features/pos/services/sale_service.dart` |
| `features/pos/services/settings_service.dart` | company/tax/printer/currency settings | `features/pos/services/settings_service.dart` |
| `features/pos/services/waiting_number_service.dart` | offline waiting-ticket numbering | `features/pos/services/waiting_number_service.dart` |
| `features/pos/services/scanner_relay_role.dart` | phone-to-phone barcode relay | **DO NOT COPY** — solves a "desktop has no camera" problem a phone doesn't have (Day 8) |
| `features/pos/screens/pos_screen.dart` | desktop POS layout (reference only) | `features/pos/screens/mobile_pos_screen.dart` |
| `features/pos/screens/payment_screen.dart` | desktop 2-column payment layout + `_submitSaleToBackend` logic | `features/pos/screens/mobile_payment_screen.dart` |
| `features/pos/screens/phone_screen_scan.dart` | `mobile_scanner` camera scan setup | `features/pos/screens/mobile_scan_screen.dart` (direct-to-cart, no relay) |
| `features/pos/screens/receipts_screen.dart` | receipt history + filters | `features/pos/screens/mobile_receipts_screen.dart` |
| `features/pos/screens/settings_modules_screen.dart` | company/tax/printer settings UI | `features/pos/screens/mobile_settings_screen.dart` |
| `features/pos/widgets/product_grid.dart` | fixed-5-column grid | `features/pos/widgets/mobile_product_grid.dart` (responsive columns) |
| `features/pos/widgets/product_card.dart` | product tile | `features/pos/widgets/product_card.dart` (reused near-as-is) |
| `features/pos/widgets/cart_items_list.dart` | swipe-to-delete cart list | `features/pos/widgets/cart_items_list.dart` (reused near-as-is) |
| `features/pos/widgets/table_selector.dart` | fixed-width table dialog | `features/pos/screens/mobile_table_selector_screen.dart` |
| `features/pos/widgets/product_modifier_sheet.dart` | modifier bottom sheet (already mobile-friendly) | `features/pos/widgets/product_modifier_sheet.dart` (reused near-as-is) |
| `features/pos/services/printing/receipt_view_model.dart` | `ReceiptViewModel` | `features/pos/services/printing/receipt_view_model.dart` |
| `features/pos/widgets/receipt_paper_view.dart` | `ReceiptContent` shared widget | `features/pos/widgets/receipt_paper_view.dart` |
| `features/pos/services/print_service.dart` | PDF build + print dispatch | `features/pos/services/print_service.dart` |
| `features/pos/services/printing/thermal_printer_service.dart` | transport dispatch, connect/build/write/disconnect | `features/pos/services/printing/thermal_printer_service.dart` |
| `features/pos/services/printing/escpos_receipt_builder.dart` | ESC/POS byte builder | `features/pos/services/printing/escpos_receipt_builder.dart` |
| `features/pos/services/printing/receipt_bitmap_renderer.dart` | Khmer whole-document rasterizer | `features/pos/services/printing/receipt_bitmap_renderer.dart` |
| `features/pos/services/printing/khmer_pdf_font.dart` | PDF font theme (Khmer fallback-only) | `features/pos/services/printing/khmer_pdf_font.dart` |
| `features/pos/services/printing/printer_profile.dart` | `PrinterConfig`/`PrinterPaperSize`/`PrinterTransportType` | `features/pos/services/printing/printer_profile.dart` |
| `features/pos/services/printing/printer_transport.dart` | `PrinterTransport` interface | `features/pos/services/printing/printer_transport.dart` |
| `features/pos/services/printing/network_printer_transport.dart` | TCP socket transport | `features/pos/services/printing/network_printer_transport.dart` |
| `features/pos/services/printing/usb_printer_transport.dart` | USB transport | `features/pos/services/printing/usb_printer_transport.dart` |
| `features/pos/services/printing/bluetooth_printer_transport.dart` | Bluetooth transport | `features/pos/services/printing/bluetooth_printer_transport.dart` |
| `features/inventory/providers/inventory_provider.dart` | movements/counts/suppliers/purchase/transfer orders | `features/inventory/providers/inventory_provider.dart` |
| `features/inventory/providers/production_provider.dart` | recipes/production orders | `features/inventory/providers/production_provider.dart` |
| `features/inventory/services/inventory_service.dart` | inventory endpoints | `features/inventory/services/inventory_service.dart` |
| `features/reports/services/report_service.dart` | `fetchAllPages`, per-report endpoints | `features/reports/services/report_service.dart` |
| `features/reports/widgets/report_charts.dart` | `fl_chart` wrappers | `features/reports/widgets/report_charts.dart` |
| `l10n/app_en.arb`, `app_km.arb` | source translation strings | `l10n/app_en.arb`, `app_km.arb` — **own copies**, not shared files (Day 3) |

Everything **not** in this table but present under `frontend-flutter-pos/lib/pos/` (the legacy tree) has no `[NEW/MOBILE]` destination at all — it is never studied, never adapted, never referenced again in this plan.

## E. Exact `[NEW/MOBILE]` Files to Create

None today.

## F–H

Not applicable — read-only day, no code, no state.

## I. Classification (see taxonomy above) — headline calls, detailed per-day

```text
CartNotifier, ProductNotifier, SaleService, ReceiptViewModel, Money, ApiService's interceptor behavior
COPY/ADAPT NEARLY EXACTLY

ApiService's base-URL resolution
RECREATE USING SAME LOGIC (mobile-specific device/emulator/simulator branching, Day 4)

PosScreen, PaymentScreen, ProductGrid, TableSelector layouts
MOBILE UI REIMPLEMENT

NetworkPrinterTransport, UsbPrinterTransport, BluetoothPrinterTransport
PLATFORM IMPLEMENTATION

frontend-flutter-pos/lib/pos/ (legacy), product.dart, product_api_service.dart,
cart_panel_footer.dart, cart_footer.dart, status_bar.dart, scanner_relay_role.dart's ROLE
  (the FILE's logic is portable — see Day 8 — but its reason to exist mostly disappears)
DO NOT COPY
```

## J. Build Order Inside the Day

1. Open `[OLD/SOURCE] frontend-flutter-pos/lib/main.dart`. Read `main()` and `PosApp.build` top to bottom.
2. Open `[OLD/SOURCE] frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart` — the full module inventory (every route the app has).
3. Open `[OLD/SOURCE] frontend-flutter-pos/lib/core/providers/auth_provider.dart`, `core/services/auth_service.dart`, `core/services/api_service.dart` — read `login()`/`post()` fully.
4. Open `[OLD/SOURCE] frontend-flutter-pos/lib/features/pos/providers/product_provider.dart`, `services/product_service.dart` — read `loadProducts()`/`getProducts()`.
5. Open `[OLD/SOURCE] frontend-flutter-pos/lib/features/pos/screens/payment_screen.dart` — skim `_submitSaleToBackend()`'s shape (Day 11 goes deep).
6. Fill in the table in section D yourself, from the actual files, cross-checking against the table above — don't just trust this document, verify it against the real repo, since this table is the map you'll navigate the rest of this plan by.
7. Run the EXISTING web app (`cd frontend-flutter-pos && flutter run -d chrome`) against the real backend and do one full login → browse → checkout, watching the `ApiService` debug logging interceptor's console output — confirms the chains in section C are real, not theoretical.

## K–O

Not applicable in the usual sense — see the Login/Product/Sale chains in section C for the "when I click this" content this early; concrete K–O sections resume Day 4 once `mobile-flutter-pos` exists to click things in.

## Definition of Done

You can reproduce the three chains in section C from memory, using the correct `[OLD/SOURCE]`/`[NEW/MOBILE]` labels, and you can name every file in section D's table without looking.

## What I Should Understand Before Day 2

That `mobile-flutter-pos` does not exist yet, and that every file in section D's right-hand column is something *you* will write on the day that feature comes up — not something already sitting in a folder waiting to be discovered. Day 2 creates the empty project these files will live in.

---

# Day 2 — Create the New Project: `mobile-flutter-pos`

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/pubspec.yaml            # for package version reference (Day 3 onward)
frontend-flutter-pos/android/app/build.gradle.kts   # READ for reference/comparison only — do not edit
frontend-flutter-pos/ios/Runner/Info.plist          # READ for reference/comparison only — do not edit
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/                          # ENTIRE PROJECT, created by `flutter create`
mobile-flutter-pos/android/app/build.gradle.kts     # edited after creation
mobile-flutter-pos/android/app/src/main/AndroidManifest.xml
mobile-flutter-pos/ios/Runner/Info.plist
mobile-flutter-pos/ios/Runner.xcodeproj/project.pbxproj
```

## A. Where Do I Start?

A terminal, in the parent directory that contains `frontend-flutter-pos/` and `backend-spring-boot/` as siblings (i.e. the repo root / workspace root) — **not** inside `frontend-flutter-pos/`.

## B. The Actual Command

```bash
cd /path/to/workspace-root          # sibling of frontend-flutter-pos/, backend-spring-boot/
flutter create --org com.kaknnea --project-name mobile_flutter_pos mobile-flutter-pos
```
- `--project-name mobile_flutter_pos` (underscore — Dart package names can't have hyphens) is the Dart package name used inside `pubspec.yaml`'s `name:` field and Dart import statements; `mobile-flutter-pos` (hyphen, matching `frontend-flutter-pos`'s naming convention) is the folder name.
- `--org com.kaknnea` sets the reverse-domain prefix used to derive the initial Android `applicationId` and iOS bundle identifier (`com.kaknnea.mobileFlutterPos` by default — confirm/adjust to the real desired IDs before shipping, same as any Flutter project).
- This generates a **complete, independent** Flutter project: `mobile-flutter-pos/{android,ios,lib,test,pubspec.yaml,...}` — none of it lives inside or depends on `frontend-flutter-pos`.

Confirm the exact `--org`/final package/app IDs with whoever owns the org's naming convention before running this — same reasoning as the project name itself (Day 1's naming note).

## C. Backend/API Chain

None — this is tooling/scaffolding, not application code.

## D–H

Not applicable (no Dart functions yet).

## Generated Structure — What Belongs Where

```text
mobile-flutter-pos/
├── android/            # THIS project's Android platform folder — configure here, Day 8/15/16
├── ios/                # THIS project's iOS platform folder — configure here, Day 8/15/16
├── lib/
│   └── main.dart       # Flutter's default counter-app placeholder — replaced Day 4/5
├── test/                # THIS project's tests — Day 20's "own project" test suite
├── integration_test/    # created manually if not scaffolded by `flutter create` — device tests
└── pubspec.yaml         # THIS project's own dependencies — add packages here, matching
                          # frontend-flutter-pos's versions where the same package is needed
                          # (flutter_riverpod, dio, mobile_scanner, pdf, printing, esc_pos_utils_plus,
                          # print_bluetooth_thermal, flutter_pos_printer_platform_image_3, image,
                          # permission_handler, shared_preferences, uuid, equatable, intl, ...)
```
`frontend-flutter-pos/android/` and `frontend-flutter-pos/ios/` are **not touched today or ever in this plan** — read them only as a reference for how a given permission/config line was expressed there (e.g. what `frontend-flutter-pos/android/app/src/main/AndroidManifest.xml` already has for `CAMERA`), then write the equivalent line into `mobile-flutter-pos`'s own copy.

## I. Classification

```text
flutter create scaffolding itself
COPY/ADAPT NEARLY EXACTLY (standard Flutter template — no reason to hand-write it)

Application ID / bundle ID / display name
RECREATE USING SAME LOGIC (new, real values — not frontend-flutter-pos's placeholders,
    and not a copy of them either, since these must be globally unique per app)
```

## J. Build Order Inside the Day

1. Confirm the real project name/org with the repo owner (Day 1's naming note) — do this before running the command, not after.
2. Run `flutter create --org <real-org> --project-name mobile_flutter_pos mobile-flutter-pos` from the workspace root (sibling of `frontend-flutter-pos/`).
3. `cd mobile-flutter-pos && flutter run -d android` — confirm the default counter-app boots on an emulator.
4. `flutter run -d ios` — confirm the same on a simulator.
5. Open `[NEW/MOBILE] mobile-flutter-pos/android/app/build.gradle.kts` — set the real `applicationId`/`namespace` if not already correct from `--org`.
6. Open `[NEW/MOBILE] mobile-flutter-pos/ios/Runner.xcodeproj` in Xcode — confirm the real bundle identifier across Debug/Release/Profile configs.
7. Add `mobile-flutter-pos/integration_test/` if `flutter create` didn't scaffold it (`flutter pub add --dev integration_test --sdk=flutter` from inside `mobile-flutter-pos`).
8. Confirm `mobile-flutter-pos` builds and runs with ZERO references to `frontend-flutter-pos` anywhere in its `pubspec.yaml` or Dart imports — it must be a fully independent project from this point forward.

## K–O

Not applicable — tooling day.

## Definition of Done

`mobile-flutter-pos/` exists as a sibling of `frontend-flutter-pos/` and `backend-spring-boot/`, boots its default placeholder app on both an Android emulator and an iOS simulator, has real (not placeholder) application/bundle identifiers, and contains zero references to `frontend-flutter-pos`.

## What I Should Understand Before Day 3

That from this point forward, **every "CREATE" instruction in this plan means "create inside `mobile-flutter-pos`"** — the project now exists, and Day 3 onward starts actually filling it in, always by first reading the paired file in `frontend-flutter-pos`.

---

# Day 3 — Core Foundation: Theme, Localization, Money, Bilingual

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/core/config/pos_theme.dart
frontend-flutter-pos/lib/core/providers/language_provider.dart
frontend-flutter-pos/lib/core/providers/theme_provider.dart
frontend-flutter-pos/lib/core/providers/main_color_provider.dart
frontend-flutter-pos/lib/core/utils/khmer_text_scaler.dart
frontend-flutter-pos/lib/core/utils/l10n_extensions.dart
frontend-flutter-pos/lib/core/utils/money.dart
frontend-flutter-pos/lib/core/utils/bilingual.dart
frontend-flutter-pos/lib/l10n.yaml
frontend-flutter-pos/lib/l10n/app_en.arb
frontend-flutter-pos/lib/l10n/app_km.arb
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/l10n.yaml
mobile-flutter-pos/lib/l10n/app_en.arb
mobile-flutter-pos/lib/l10n/app_km.arb
mobile-flutter-pos/lib/core/config/pos_theme.dart
mobile-flutter-pos/lib/core/providers/language_provider.dart
mobile-flutter-pos/lib/core/providers/theme_provider.dart
mobile-flutter-pos/lib/core/providers/main_color_provider.dart
mobile-flutter-pos/lib/core/utils/khmer_text_scaler.dart
mobile-flutter-pos/lib/core/utils/l10n_extensions.dart
mobile-flutter-pos/lib/core/utils/money.dart
mobile-flutter-pos/lib/core/utils/bilingual.dart
```

## A. Where Do I Start?

Open `[OLD/SOURCE — READ] frontend-flutter-pos/l10n.yaml` (repo root, four lines) — it tells you the whole localization mechanism before you open a single `.dart` file.

## B. Existing `[OLD/SOURCE]` Function Chain — key to widget

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/generated
nullable-getter: false
```
`[OLD/SOURCE] frontend-flutter-pos/lib/l10n/app_en.arb` (~990 keys) / `app_km.arb` (~615 keys) are the source strings. Running `flutter gen-l10n` (or `flutter run`, since `pubspec.yaml` has `flutter: generate: true`) writes `lib/l10n/generated/app_localizations.dart` — an `abstract class AppLocalizations` with one getter per key, plus `AppLocalizationsEn`/`AppLocalizationsKm` concrete overrides. `AppLocalizations.of(context)` picks the right subclass from `MaterialApp.locale`.

`[OLD/SOURCE] frontend-flutter-pos/lib/core/utils/l10n_extensions.dart` (full file, 8 lines):
```dart
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

`[OLD/SOURCE] frontend-flutter-pos/lib/core/providers/language_provider.dart`:
```dart
class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.en) { _loadPreference(); }
  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getString('app_language') == AppLanguage.km.name) ? AppLanguage.km : AppLanguage.en;
  }
  Future<void> setLanguage(final AppLanguage language) async {
    state = language;   // synchronous — triggers rebuild immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', language.name);   // persistence, non-blocking
  }
}
```

`[OLD/SOURCE] frontend-flutter-pos/lib/core/utils/money.dart` — integer-minor-unit math, avoids float rounding on totals:
```dart
class Money {
  static const int scale = 100;
  static int toMinor(double major) => ...;
  static double toMajor(int minor) => ...;
  static int lineTotalMinor(double unitPrice, int qty) => ...;
  static int percentOfMinor(int minor, double percent) => ...;
}
```

`[OLD/SOURCE] frontend-flutter-pos/lib/core/utils/bilingual.dart::resolveBilingual({required String en, String? km, required AppLanguage language})` — the central EN/KM field picker every bilingual model (`Product`, `Category`, `Customer`, ...) uses.

`[OLD/SOURCE] frontend-flutter-pos/lib/core/config/pos_theme.dart` — as of the "configurable main app color" work, `primaryGreen`/`primaryGreenDark`/`primaryGreenLight` are no longer `static const`. They're computed getters backed by a private mutable field, so every one of the ~150 existing call sites across the app that reads `PosTheme.primaryGreen` picks up a newly-selected color automatically, with zero per-call-site changes:
```dart
static Color _mainColor = const Color(0xFF4CAF50);   // original brand green, default
static Color get primaryGreen => _mainColor;
static Color get primaryGreenDark => _shade(_mainColor, -0.11);
static Color get primaryGreenLight => _shade(_mainColor, 0.35);
static void applyMainColor(Color color) { _mainColor = color; }
static Color _shade(Color color, double amount) { /* HSL lightness shift, clamped 0..1 */ }
```
Semantic colors (`errorRed`, `warningAmber`, `successGreen`) stay plain `static const Color` — they are NEVER touched by `applyMainColor`, because a status/error/warning/success meaning must stay fixed no matter which main color a merchant picks. `[NEW/MOBILE]`'s own `PosTheme` must reproduce this getter-vs-const split exactly, not flatten it back to all-`const`.

`[OLD/SOURCE] frontend-flutter-pos/lib/core/providers/main_color_provider.dart` — the state owner behind `applyMainColor`, following the EXACT same shape as `AppLanguageNotifier` above (device-local `SharedPreferences`, no backend field — there is no backend "appearance" concept, same reasoning as `language`/`themeMode` already living device-local):
```dart
const _mainColorPreferenceKey = 'app_main_color';
const List<Color> kMainColorOptions = [
  Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFF9C27B0),
  Color(0xFFFF9800), Color(0xFFE53935), Color(0xFF009688),
];
final mainColorProvider = StateNotifierProvider<MainColorNotifier, Color>((ref) => MainColorNotifier());
class MainColorNotifier extends StateNotifier<Color> {
  MainColorNotifier() : super(kMainColorOptions.first) { _loadPreference(); }
  Future<void> _loadPreference() async { /* reads int from SharedPreferences['app_main_color'], matches
      against kMainColorOptions by .value, falls back to kMainColorOptions.first on miss */ }
  Future<void> setMainColor(Color color) async { state = color; /* persist color.value, fire-and-forget */ }
}
```
`[OLD/SOURCE] frontend-flutter-pos/lib/main.dart`'s `PosApp.build()` is the ONE place these two files meet: `PosTheme.applyMainColor(ref.watch(mainColorProvider));` runs once per build, immediately before `MaterialApp(theme: PosTheme.lightTheme, darkTheme: PosTheme.darkTheme, ...)` is constructed. Because `PosApp` is a `ConsumerWidget` watching `mainColorProvider`, picking a new color in Settings (Day 19) rebuilds `PosApp` immediately — no restart needed, and it works identically for light and dark theme (dark mode's contrast is handled by `ColorScheme.fromSeed`, unaffected by this mechanism). The full chain, to reproduce identically in `[NEW/MOBILE]`:
```text
Settings swatch tap (Day 19)
↓
ref.read(mainColorProvider.notifier).setMainColor(color)
↓
state = color   (synchronous — SharedPreferences write happens after, fire-and-forget)
↓
PosApp rebuilds (ConsumerWidget watching mainColorProvider)
↓
PosTheme.applyMainColor(ref.watch(mainColorProvider))
↓
PosTheme.lightTheme / darkTheme rebuilt using the mutable primaryGreen getters
↓
every screen/widget reading PosTheme.primaryGreen (POS category tabs, buttons, chips, ...) reflects the
new color automatically — zero per-widget code changes
```

`[OLD/SOURCE] frontend-flutter-pos/lib/core/utils/khmer_text_scaler.dart` — a second, unrelated "core foundation" piece that landed on the same branch: a custom `TextScaler` that makes Khmer UI text easier to read without touching English typography at all.
```dart
class KhmerTextScaler extends TextScaler {
  const KhmerTextScaler(this._base);
  final TextScaler _base;   // whatever scaler was already in effect (platform accessibility setting)
  @override
  double scale(double fontSize) {
    final scaled = _base.scale(fontSize);
    if (scaled >= 28) return scaled;        // large display text (e.g. cart totals) — left alone
    if (scaled >= 20) return scaled + 3;    // titles
    return scaled + 2;                      // everything else
  }
}
TextScaler khmerAwareTextScaler(TextScaler base, {required bool isKhmer}) =>
    isKhmer ? KhmerTextScaler(base) : base;   // English path returns base UNCHANGED
```
The bump is a flat ADDITIVE offset on top of whatever scale is already in effect — deliberately NOT `TextScaler.linear(1.x)`, which would over-inflate large headings and under-inflate small labels relative to each other — and it composes with the platform's own accessibility text-size setting rather than overriding it. `[OLD/SOURCE] frontend-flutter-pos/lib/main.dart` wires this in `MaterialApp.builder`, wrapping `child` in a `MediaQuery` that overrides `textScaler`:
```dart
builder: (context, child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaler: khmerAwareTextScaler(MediaQuery.of(context).textScaler, isKhmer: ...)),
  child: child,
),
```
This is a Flutter-widget-tree-level change only, applied via `MediaQuery`/`MaterialApp.builder` — study the ACTUAL final `khmer_text_scaler.dart` and its `MaterialApp.builder` wiring directly rather than inventing a separate scaling scheme from scratch; `[NEW/MOBILE]` should port this file close to verbatim. **This has nothing to do with, and must never be applied to, receipt/PDF/thermal-print font sizing** — see Day 14 for why those render through a completely separate system and must stay untouched by this mechanism.

## C. Backend/API Chain

None — localization/theme/Money are entirely client-side, no network call.

## D. `[OLD/SOURCE]` Functions to Study → `[NEW/MOBILE]` Functions to Write

| `[OLD/SOURCE]` file | Function/Class | `[NEW/MOBILE]` action |
|---|---|---|
| `core/utils/money.dart` | `Money` (all static methods) | **COPY/ADAPT NEARLY EXACTLY** — write `mobile-flutter-pos/lib/core/utils/money.dart` with identical logic; this is pure arithmetic, no platform dependency at all |
| `core/utils/bilingual.dart` | `resolveBilingual` | **COPY/ADAPT NEARLY EXACTLY** |
| `core/providers/language_provider.dart` | `AppLanguageNotifier` | **COPY/ADAPT NEARLY EXACTLY** — same SharedPreferences key `app_language`, same synchronous-state-then-persist pattern |
| `core/providers/theme_provider.dart` | `ThemeModeNotifier` | **COPY/ADAPT NEARLY EXACTLY** |
| `core/config/pos_theme.dart` | `PosTheme` (colors/spacing constants, `primaryGreen`/`primaryGreenDark`/`primaryGreenLight` mutable getters, `applyMainColor`) | **RECREATE USING SAME LOGIC** — reuse the color palette/spacing scale values AND the getter-backed-by-mutable-field pattern for the main-color trio specifically (not plain `static const`), so `[NEW/MOBILE]`'s own Settings color picker (Day 19) can drive it the same way; semantic colors (`errorRed`/`warningAmber`/`successGreen`) stay `static const`, untouched; expect to retune specific widget-level constants (font sizes, touch-target heights) for phone screens as mobile screens get built (Days 5+) |
| `core/providers/main_color_provider.dart` | `MainColorNotifier`, `kMainColorOptions` | **COPY/ADAPT NEARLY EXACTLY** — same SharedPreferences key `app_main_color`, same synchronous-state-then-persist pattern as `AppLanguageNotifier` |
| `core/utils/khmer_text_scaler.dart` | `KhmerTextScaler`, `khmerAwareTextScaler` | **COPY/ADAPT NEARLY EXACTLY** — port near-verbatim, then wire into `[NEW/MOBILE] main.dart`'s own `MaterialApp.builder` exactly as `[OLD/SOURCE]` does |
| `core/utils/l10n_extensions.dart` | `L10nX` extension | **COPY/ADAPT NEARLY EXACTLY** — points at `mobile-flutter-pos`'s own generated `AppLocalizations`, not `frontend-flutter-pos`'s |
| `l10n/app_en.arb`, `app_km.arb` | source strings | **RECREATE USING SAME LOGIC** — `mobile-flutter-pos` gets its OWN `.arb` files; copy every key/value pair you'll actually use as a starting point (don't blindly copy all ~990/~615 keys — many are desktop-screen-specific labels that won't exist in the mobile UI, and mobile will need some new keys of its own), then let both projects' translation vocabularies diverge naturally over time as each app's screens diverge |

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/l10n.yaml                          # same 6 lines as frontend-flutter-pos's
mobile-flutter-pos/lib/l10n/app_en.arb                # own file, seeded from frontend-flutter-pos's
mobile-flutter-pos/lib/l10n/app_km.arb                # own file, seeded from frontend-flutter-pos's
mobile-flutter-pos/lib/core/config/pos_theme.dart
mobile-flutter-pos/lib/core/providers/language_provider.dart
mobile-flutter-pos/lib/core/providers/theme_provider.dart
mobile-flutter-pos/lib/core/providers/main_color_provider.dart
mobile-flutter-pos/lib/core/utils/khmer_text_scaler.dart
mobile-flutter-pos/lib/core/utils/l10n_extensions.dart
mobile-flutter-pos/lib/core/utils/money.dart
mobile-flutter-pos/lib/core/utils/bilingual.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/core/providers/language_provider.dart
// Adapted from [OLD/SOURCE] frontend-flutter-pos/lib/core/providers/language_provider.dart —
// same shape, same SharedPreferences key, so a cashier's language choice concept stays
// recognizable across both apps even though the apps don't share code.
enum AppLanguage { en, km }

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.en) { _loadPreference(); }
  // STEP 1: same key 'app_language' — not required to match [OLD/SOURCE], but there's no
  // reason to diverge, and it keeps cross-project mental mapping easy for future maintainers.
  Future<void> _loadPreference() async { /* identical to [OLD/SOURCE] */ }
  Future<void> setLanguage(AppLanguage language) async { /* identical to [OLD/SOURCE] */ }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] AppLanguageNotifier.setLanguage(AppLanguage language)`
INPUT: `AppLanguage.km`
DOES: `state = language` (synchronous, rebuilds every watcher) → persists to `mobile-flutter-pos`'s own `SharedPreferences['app_language']`
OUTPUT: `Future<void>`
CALLER: a language toggle widget in `mobile-flutter-pos`
NEXT: `mobile-flutter-pos`'s `MaterialApp.locale` re-evaluates; every `context.l10n.xyz` call site in `mobile-flutter-pos` re-renders — entirely independent of `frontend-flutter-pos`'s own language state, which lives in a separate running process/app.

## H. State Before and After

BEFORE: `mobile-flutter-pos`'s `appLanguageProvider` state = `AppLanguage.en`
Call: `ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.km)`
AFTER: state = `AppLanguage.km`; `mobile-flutter-pos`'s own `SharedPreferences['app_language'] = 'km'` (a value stored in the mobile app's own local storage — entirely separate from any value `frontend-flutter-pos` might have stored on a desktop/web session).

## I. Classification

```text
Money, resolveBilingual, AppLanguageNotifier, ThemeModeNotifier, L10nX extension
COPY/ADAPT NEARLY EXACTLY

MainColorNotifier/kMainColorOptions, KhmerTextScaler/khmerAwareTextScaler
COPY/ADAPT NEARLY EXACTLY

PosTheme's color/spacing constants, PosTheme's primaryGreen*/applyMainColor mutable-getter mechanism
RECREATE USING SAME LOGIC (values and the getter-over-const pattern both reused; specific widget
constants retuned per mobile screen; semantic colors stay static const, untouched by main color)

app_en.arb / app_km.arb content
RECREATE USING SAME LOGIC (own files, seeded from source, allowed to diverge over time)
```

## J. Build Order Inside the Day

1. Open `[OLD/SOURCE] frontend-flutter-pos/l10n.yaml`, confirm the 6 config lines.
2. Open `[OLD/SOURCE] frontend-flutter-pos/lib/l10n/app_en.arb`/`app_km.arb`, identify the subset of keys relevant to a minimal mobile shell (login, common buttons, POS labels) — don't copy everything.
3. Create `[NEW/MOBILE] mobile-flutter-pos/l10n.yaml` (same shape) and the two seeded `.arb` files.
4. Create `[NEW/MOBILE] mobile-flutter-pos/lib/core/utils/l10n_extensions.dart`.
5. Run `flutter gen-l10n` inside `mobile-flutter-pos` — confirm `mobile-flutter-pos/lib/l10n/generated/app_localizations.dart` is produced.
6. Create `[NEW/MOBILE]` `money.dart`, `bilingual.dart`, `language_provider.dart`, `theme_provider.dart`, `pos_theme.dart` in `mobile-flutter-pos`, each adapted from its `[OLD/SOURCE]` counterpart per section D — for `pos_theme.dart`, reproduce the mutable-getter `primaryGreen`/`primaryGreenDark`/`primaryGreenLight` + `applyMainColor` mechanism, not plain constants.
7. Create `[NEW/MOBILE]` `main_color_provider.dart` (same shape as `language_provider.dart`, key `app_main_color`) and `khmer_text_scaler.dart` (ported near-verbatim).
8. Build a minimal placeholder `MaterialApp` in `mobile-flutter-pos/lib/main.dart` using `PosTheme`, wired to `appLanguageProvider`/`themeModeProvider`, PLUS: call `PosTheme.applyMainColor(ref.watch(mainColorProvider))` right before constructing `MaterialApp` (same spot `[OLD/SOURCE] PosApp.build()` does it), and wrap `child` in `MaterialApp.builder` with `khmerAwareTextScaler` as `[OLD/SOURCE] main.dart` does.
9. Run on an Android emulator and iOS simulator, toggle EN↔KM and light↔dark, confirm both work — this is `mobile-flutter-pos`'s FIRST real running screen. The main-color/Khmer-scaling mechanisms won't have visible UI to drive them yet (that's Day 19's swatch picker and this same day's language toggle respectively) — confirming here only that `applyMainColor`/`khmerAwareTextScaler` compile and wire without breaking the placeholder screen.

## K. "When I Click This, What Happens?"

# Toggle language (inside `mobile-flutter-pos`)
```text
Tap "KM" segment
↓
ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.km)   [mobile-flutter-pos's own provider]
↓
state = AppLanguage.km
↓
mobile-flutter-pos's MaterialApp.locale updates
↓
mobile-flutter-pos's own context.l10n.* resolves via its own AppLocalizationsKm
↓
(async) mobile-flutter-pos's own SharedPreferences.setString('app_language', 'km')
```
Note this has **zero effect** on any running `frontend-flutter-pos` session — two entirely separate apps, separate process, separate local storage.

## L. "Where Does This Value Come From?"

A translated label:
```text
mobile-flutter-pos/lib/l10n/app_en.arb["authLogin"] / app_km.arb["authLogin"]
  (seeded from, but now an independent file from, frontend-flutter-pos's own app_en.arb/app_km.arb)
↓ (flutter gen-l10n, run inside mobile-flutter-pos)
mobile-flutter-pos's own generated AppLocalizationsEn/Km.authLogin
↓
context.l10n.authLogin
```

## M. Navigation Flow

None — toggle triggers a rebuild in place.

## N. Error Flow

Same fail-safe-by-construction behavior as `[OLD/SOURCE]`: `AppLanguageNotifier`'s constructor sets a safe default (`AppLanguage.en`) before the async `_loadPreference()` even runs, so a `SharedPreferences` read failure can't leave the app in an undefined language state.

## O. Test Flow

No dedicated automated test exists for `AppLanguageNotifier` in `[OLD/SOURCE]` either — a pre-existing gap, not something to invent a workaround for. Manual test:
```text
1. Launch mobile-flutter-pos, confirm default English.
2. Toggle Khmer, confirm every visible string changes, no tofu boxes.
3. Restart the app, confirm it remembers Khmer.
```

## What I Should Understand Before Day 4

That `mobile-flutter-pos` now has its own complete, independent localization/theme/money-math foundation — nothing in it references `frontend-flutter-pos` at the Dart level, even though every file's logic was directly studied from there. Day 4 builds the first REAL feature (auth) on top of this foundation.

---

# Day 4 — Auth: Login, Function by Function, Old → New

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/core/services/api_service.dart
frontend-flutter-pos/lib/core/services/auth_service.dart
frontend-flutter-pos/lib/core/providers/auth_provider.dart
frontend-flutter-pos/lib/core/config/app_config.dart          (baseUrl resolution)
frontend-flutter-pos/lib/core/models/auth_models.dart
frontend-flutter-pos/lib/features/auth/screens/login_screen.dart
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/core/services/api_service.dart
mobile-flutter-pos/lib/core/services/auth_service.dart
mobile-flutter-pos/lib/core/providers/auth_provider.dart
mobile-flutter-pos/lib/core/config/app_config.dart
mobile-flutter-pos/lib/core/models/auth_models.dart
mobile-flutter-pos/lib/features/auth/screens/mobile_login_screen.dart
```

## A. Where Do I Start?

**STEP 1 READ:** `[OLD/SOURCE — READ] frontend-flutter-pos/lib/core/services/api_service.dart` — study `ApiService`, its Dio setup, and the auth interceptor.

**STEP 2 READ:** `[OLD/SOURCE — READ] frontend-flutter-pos/lib/core/services/auth_service.dart` — study `AuthService.login(...)`.

**STEP 3 READ:** `[OLD/SOURCE — READ] frontend-flutter-pos/lib/core/providers/auth_provider.dart` — study `AuthNotifier.login(...)`.

**STEP 4 CREATE:** `[NEW/MOBILE — CREATE] mobile-flutter-pos/lib/core/services/api_service.dart`, then `[NEW/MOBILE — CREATE] mobile-flutter-pos/lib/core/services/auth_service.dart`, then `[NEW/MOBILE — CREATE] mobile-flutter-pos/lib/core/providers/auth_provider.dart`, then `[NEW/MOBILE — CREATE] mobile-flutter-pos/lib/features/auth/screens/mobile_login_screen.dart`.

## B. `[OLD/SOURCE]` Function Chain — every hop, real code

**Hop 1 — `[OLD/SOURCE] LoginScreen._login()`** (full body, studied for its logic, not its layout):
```dart
Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;
  try {
    await ref.read(authProvider.notifier).login(_emailController.text.trim(), _passwordController.text.trim());
    if (mounted) Navigator.of(context).pushReplacementNamed('/pos');
  } catch (error) {
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.l10n.authLoginFailed}: $error'))); }
  }
}
```
**Important, non-obvious fact**: this `catch` is effectively dead code for real login failures — hop 2 explains why.

**Hop 2 — `[OLD/SOURCE] AuthNotifier.login()`** (`core/providers/auth_provider.dart`, full body):
```dart
Future<void> login(final String email, final String password, {final String? terminalId}) async {
  state = const AsyncValue.loading();
  try {
    final authResponse = await _authService.login(email, password, terminalId: terminalId);
    state = AsyncValue.data(authResponse.user);
  } catch (error, stackTrace) {
    state = AsyncValue.error(error, stackTrace);   // <-- swallowed, NEVER rethrown
  }
}
```
`AuthNotifier.login` catches its own errors into Riverpod state instead of rethrowing — `LoginScreen._login()`'s `try/catch` almost never actually fires. **This behavior is a fact about the business logic itself, so it must be reproduced identically in `[NEW/MOBILE]`'s `AuthNotifier`** — not "fixed" as part of the mobile port. If you want different error-surfacing UX on mobile, that's a deliberate `[NEW/MOBILE]`-only decision made in `MobileLoginScreen`, not a change to the notifier's contract (see section F).

**Hop 3 — `[OLD/SOURCE] AuthService.login()`** (`core/services/auth_service.dart`, full body):
```dart
Future<AuthResponse> login(final String email, final String password, {final String? terminalId}) async {
  final request = LoginRequest(email: email, password: password, terminalId: terminalId);
  final response = await _apiService.post<Map<String, dynamic>>('/api/auth/login', data: request.toJson());
  final authResponse = AuthResponse.fromJson(response);
  await _saveAuthData(authResponse);
  return authResponse;
}
Future<void> _saveAuthData(final AuthResponse authResponse) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(AppConfig.authTokenKey, authResponse.token);          // key: 'auth_token'
  await prefs.setString(AppConfig.userKey, json.encode(authResponse.user.toJson())); // key: 'user_data'
}
```

**Hop 4 — `[OLD/SOURCE] ApiService.post<T>()`** (`core/services/api_service.dart`), plus the auth interceptor's `onRequest`:
```dart
Future<T> post<T>(final String path, {final Object? data, ...}) async {
  try { final response = await _dio.post(path, data: data, queryParameters: queryParameters);
        return fromJson != null ? fromJson(response.data) : response.data as T; }
  on DioException catch (e) { throw _handleError(e); }
}
// interceptor:
onRequest: (options, handler) async {
  final token = await _getAuthToken();
  if (token != null) options.headers['Authorization'] = 'Bearer $token';
  handler.next(options);
},
```

**Hop 5 — the wire**: `POST {AppConfig.apiBaseUrl}/api/auth/login` with JSON body `{"email": ..., "password": ..., "terminalId": ...}` — **exactly the same endpoint `frontend-flutter-pos` calls**, since both clients hit the same shared `backend-spring-boot`.

## C. Backend/API Chain (shared backend — unchanged, both clients call this)

```text
POST /api/auth/login
↓
AuthController.login(@Valid @RequestBody LoginRequest request, HttpServletRequest http)
    -> authService.login(request, http.getRemoteAddr(), http.getHeader("User-Agent"))
↓
AuthService.login(request, ip, userAgent)   [backend, service/AuthService.java — unchanged, shared]
    userRepository.findByEmail(email) -> password check -> lockout logic -> roles/permissions
↓
JwtUtil.generateToken(email, roles, permissions)   -> HS256, expires in app.jwt.access-token-minutes (720min/12h)
↓
AuthDtos.LoginResponse{ token, user: {id, email, fullName, roles, permissions} }
↓ (identical response shape reaches BOTH clients)
[NEW/MOBILE] AuthResponse.fromJson(response)  — same field names as [OLD/SOURCE]'s model, because
    both are parsing the SAME backend DTO
```
**Status codes**: 200 success; 400 via `ApiException` for bad credentials/locked/inactive account or validation failure. No backend change needed or made for the mobile client — it consumes the identical contract `frontend-flutter-pos` already uses.

## D. `[OLD/SOURCE]` Functions to Study → `[NEW/MOBILE]` Functions to Write

| `[OLD/SOURCE]` file | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `core/services/api_service.dart` | `ApiService` (Dio setup, interceptors, `post<T>`/`get<T>`/etc, `_handleError`) | **COPY/ADAPT NEARLY EXACTLY** for interceptor/error-mapping behavior |
| `core/config/app_config.dart` | `AppConfig.baseUrl` getter | **RECREATE USING SAME LOGIC** — same `kIsWeb`/Android-emulator/iOS-simulator branches, PLUS a new physical-device branch (`--dart-define`-driven, since `mobile-flutter-pos` is mobile-only and physical-device testing is the common case, not an edge case) |
| `core/services/auth_service.dart` | `AuthService.login/logout/getToken/getCurrentUser/_saveAuthData` | **COPY/ADAPT NEARLY EXACTLY** — OR **RECREATE USING SAME LOGIC** if you deliberately adopt `flutter_secure_storage` instead of plain `SharedPreferences` (a legitimate mobile-specific upgrade — decide explicitly, document the decision, keep method signatures identical either way) |
| `core/providers/auth_provider.dart` | `AuthNotifier` (constructor, `_initializeAuth`, `login`, `logout`, `refreshUser`) | **COPY/ADAPT NEARLY EXACTLY** — including the swallow-don't-rethrow behavior in `login()`, which is a business-logic fact, not an accident |
| `core/models/auth_models.dart` | `User`, `AuthResponse`, `LoginRequest` | **COPY/ADAPT NEARLY EXACTLY** — field names must match the shared backend DTO exactly |
| `features/auth/screens/login_screen.dart` | `_login()`'s call sequence (NOT its widget tree) | **MOBILE UI REIMPLEMENT** — write `MobileLoginScreen` with the same call sequence (`authProvider.notifier.login(...)` then navigate), full-screen phone-appropriate form fields |

**Do not hardcode a primary brand color in `MobileLoginScreen`.** `[OLD/SOURCE] frontend-flutter-pos/lib/features/auth/screens/login_screen.dart` used to hardcode `Color(0xFF0f766e)` (old brand teal) at its primary-brand-role spots; that branch converted every one of those spots to `Theme.of(context).colorScheme.primary` instead, so they track the app's live configured main color (Day 3's `PosTheme`/`mainColorProvider` mechanism) automatically. Reproduce that same judgment call in `[NEW/MOBILE]`'s `MobileLoginScreen`, not a hardcoded literal. The 6 converted spots to mirror:
```text
1. Logo container's background color
2. Logo container's drop shadow color (derived from the same color, with opacity)
3. Password field's focused border color
4. "Remember me" checkbox's fill color
5. "Forgot password" link's text color AND its underline decoration color
6. LOGIN button's background color AND its shadow color
   (plus: the shared `_inputField` helper's focused border, reused by other fields such as email)
```
Deliberately LEFT hardcoded in `[OLD/SOURCE]` — judged decorative, not primary-brand — and `[NEW/MOBILE]` should make the same call rather than converting everything indiscriminately: the left-panel branding gradient background, the decorative background circles, and the "Register" link's color. Converting those too is not "more correct" — it's over-theming visual flourishes that were never meant to track the merchant's chosen main color.

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/core/services/api_service.dart
mobile-flutter-pos/lib/core/services/auth_service.dart
mobile-flutter-pos/lib/core/providers/auth_provider.dart
mobile-flutter-pos/lib/core/models/auth_models.dart
mobile-flutter-pos/lib/features/auth/screens/mobile_login_screen.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/auth/screens/mobile_login_screen.dart
class MobileLoginScreen extends ConsumerStatefulWidget {
  const MobileLoginScreen({super.key});
  @override
  ConsumerState<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends ConsumerState<MobileLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    // STEP 1: call mobile-flutter-pos's OWN AuthNotifier — adapted from [OLD/SOURCE], not imported from it.
    await ref.read(authProvider.notifier).login(_emailCtl.text.trim(), _passwordCtl.text.trim());
    // STEP 2: because AuthNotifier.login never rethrows (see section B, hop 2), check state directly.
    final state = ref.read(authProvider);
    if (state.hasError) { /* show mobile-appropriate error UI */ return; }
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');   // Day 5's MobileHomeShell route
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Scaffold(
      body: Form(key: _formKey, child: Column(children: [
        // STEP 3: email/password TextFormFields, same validators as [OLD/SOURCE] LoginScreen
        ElevatedButton(
          onPressed: authState.isLoading ? null : _login,
          // STEP 4: brand color comes from the live theme, never a hardcoded literal — see the
          // note above section E for the full list of spots this applies to (logo, borders,
          // checkbox, link, this button) and which decorative elements are deliberately excluded.
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
          child: authState.isLoading ? const CircularProgressIndicator() : Text(context.l10n.authLogin),
        ),
      ])),
    );
  }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] AuthNotifier.login(String email, String password, {String? terminalId})`
INPUT: `email = "owner@kaknnea.local"`, `password = "Password123!"`
DOES: `state = loading` → `mobile-flutter-pos`'s own `AuthService.login()` → `POST /api/auth/login` (shared backend) → parse `AuthResponse` → save to `mobile-flutter-pos`'s own `SharedPreferences` → `state = data(user)` (or `error(e)`, never rethrown)
OUTPUT: `Future<void>`
CALLER: `[NEW/MOBILE] MobileLoginScreen._login()`
NEXT: caller must check `ref.read(authProvider)` and navigate.

## H. State Before and After

BEFORE: `mobile-flutter-pos`'s `authProvider` state = `AsyncValue.data(null)`; its own `SharedPreferences` has no `auth_token`/`user_data`.
Call: `ref.read(authProvider.notifier).login('owner@kaknnea.local', 'Password123!')`
AFTER (success): state = `AsyncValue.data(User(...))`; `mobile-flutter-pos`'s own `SharedPreferences['auth_token']`/`['user_data']` populated — entirely separate storage from anything `frontend-flutter-pos` may have stored.

## I. Classification

```text
ApiService's interceptor/error-mapping behavior, AuthNotifier, User/AuthResponse/LoginRequest models
COPY/ADAPT NEARLY EXACTLY

AppConfig.baseUrl, AuthService's storage layer (if adopting flutter_secure_storage)
RECREATE USING SAME LOGIC

LoginScreen's widget tree
MOBILE UI REIMPLEMENT -> MobileLoginScreen
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE] frontend-flutter-pos/lib/core/services/api_service.dart` fully.
2. **READ** `[OLD/SOURCE] frontend-flutter-pos/lib/core/services/auth_service.dart` fully.
3. **READ** `[OLD/SOURCE] frontend-flutter-pos/lib/core/providers/auth_provider.dart` fully — note the swallow-don't-rethrow behavior in `login()`.
4. **READ** `[OLD/SOURCE] frontend-flutter-pos/lib/features/auth/screens/login_screen.dart`'s `_login()`.
5. **CREATE** `[NEW/MOBILE] mobile-flutter-pos/lib/core/models/auth_models.dart`.
6. **CREATE** `[NEW/MOBILE] mobile-flutter-pos/lib/core/config/app_config.dart` with `baseUrl` extended for a physical-device path (`--dart-define`), plus the same feature-flag/key constants pattern as `[OLD/SOURCE]`.
7. **CREATE** `[NEW/MOBILE] mobile-flutter-pos/lib/core/services/api_service.dart`.
8. Decide/document: plain `SharedPreferences` vs. `flutter_secure_storage` for `mobile-flutter-pos`'s token storage.
9. **CREATE** `[NEW/MOBILE] mobile-flutter-pos/lib/core/services/auth_service.dart`, **CREATE** `[NEW/MOBILE] mobile-flutter-pos/lib/core/providers/auth_provider.dart`.
10. **CREATE** `[NEW/MOBILE] mobile-flutter-pos/lib/features/auth/screens/mobile_login_screen.dart` using section F's skeleton.
11. Run `mobile-flutter-pos` on an Android emulator against the shared `backend-spring-boot` (`10.0.2.2:8081`), confirm login round-trips.
12. Run on a physical device over LAN, confirm the new `AppConfig.baseUrl` branch works.

## K. "When I Click This, What Happens?"

# Tap "Login" (in `mobile-flutter-pos`)
```text
Tap LOGIN
↓
_formKey.currentState!.validate()
↓
[NEW/MOBILE] AuthNotifier.login(email, password)
↓
state = loading
↓
[NEW/MOBILE] AuthService.login() -> [NEW/MOBILE] ApiService.post -> POST /api/auth/login
↓  (shared backend, unchanged)
AuthController.login -> AuthService.login [backend]
↓
state = AsyncValue.data(user)
↓
Navigator.pushReplacementNamed(mobile-flutter-pos's home route, Day 5)
```

## L. "Where Does This Value Come From?"

The `User` shown after login:
```text
Shared backend AuthDtos.UserResponse{id, email, fullName, roles, permissions}
↓
[NEW/MOBILE] AuthResponse.fromJson(response)['user']
↓
[NEW/MOBILE] User.fromJson(...)
↓
[NEW/MOBILE] AuthNotifier.state = AsyncValue.data(user)
```

## M. Navigation Flow

`[NEW/MOBILE] MobileLoginScreen` uses `Navigator.of(context).pushReplacementNamed(...)`, mirroring `[OLD/SOURCE] LoginScreen`'s `pushReplacementNamed('/pos')` — same reasoning: no "back" to the login screen after authenticating.

## N. Error Flow

Identical shape to `[OLD/SOURCE]`: `AuthService.login`/`ApiService.post` failures are caught inside `AuthNotifier.login` and turned into `AsyncValue.error`, never rethrown — `MobileLoginScreen` must check `ref.read(authProvider).hasError` after the `await`, exactly as documented in section B, hop 2. This is a faithful reproduction of `[OLD/SOURCE]`'s actual behavior, not a bug to fix during the mobile port.

## O. Test Flow

`[OLD/SOURCE]`'s `frontend-flutter-pos/test/auth_provider_test.dart` tests `AuthNotifier` directly — **read it as a reference for what to test**, but write a NEW test at `[NEW/MOBILE] mobile-flutter-pos/test/auth_provider_test.dart` targeting `mobile-flutter-pos`'s own `AuthNotifier` — the old test file stays in `frontend-flutter-pos/test/` and is never modified or executed against the new project.
```bash
cd mobile-flutter-pos && flutter test test/auth_provider_test.dart
```
Manual test:
```text
1. Launch mobile-flutter-pos on Android emulator, reach MobileLoginScreen.
2. Correct credentials -> confirm navigation to mobile home.
3. Kill/relaunch -> confirm still logged in.
4. Wrong password -> confirm mobile-appropriate error UI (not a silent failure).
5. Repeat on a physical device and on iOS.
```

## What I Should Understand Before Day 5

There is no refresh-token endpoint on the shared backend (confirmed: `AuthController` only exposes `/login`, `/request-reset`, `/reset`, `/change-password`), and the JWT is valid 12 hours — this applies identically to both clients, since they share one backend. `mobile-flutter-pos`'s session will simply expire after 12 hours with no silent renewal, exactly like `frontend-flutter-pos`'s does today.

---

# Day 5 — Mobile Navigation Shell: Routes in the New Project

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart      (full destination inventory)
frontend-flutter-pos/lib/main.dart                                   (the routes map these destinations resolve to)
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/main.dart                                     (mobile-flutter-pos's OWN routes map)
mobile-flutter-pos/lib/features/pos/screens/mobile_home_shell.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_more_menu.dart
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart` — the complete map of every destination in the existing app.

## B. `[OLD/SOURCE]` Function Chain

`[OLD/SOURCE] PosDrawer` renders `ListTile`s whose `onTap` calls `Navigator.pushNamed(context, '/$route')`. Full destination list (confirmed against `[OLD/SOURCE] main.dart`'s `routes` map):
```text
Register -> /pos | Held Tickets -> /open-tickets
Inventory Management: /inventory, /purchase-orders, /transfer-orders, /stock-adjustments,
  /inventory-counts, /productions, /suppliers, /inventory-history, /inventory-valuation
Receipts -> /receipts
Reports: /report-sales-summary, /report-sales-by-item, /report-sales-by-category,
  /report-sales-by-employee, /report-sales-by-payment-type, /report-receipts,
  /report-sales-by-modifier, /report-discounts, /report-taxes
Items: /items, /add-item, /categories, /modifiers, /units
Employees: /employeelist, /useraccount, /accessRole, /permission
Customers: /customers, /add-customer
Tables: /tables, /add-table
Shifts: /shifts, /shift-history
Settings -> /settings | Logout -> confirmation -> authProvider.notifier.logout() -> /login
```
**These are destination *names/concepts* to reproduce in `[NEW/MOBILE]`'s own routes map** — not literal cross-project route strings (the new project's routes map is entirely its own; the string `/inventory` in `mobile-flutter-pos` resolves to `mobile-flutter-pos`'s own `InventoryHubScreen`-equivalent widget, never to anything in `frontend-flutter-pos`).

## C. Backend/API Chain

None — navigation itself makes no network call.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | `[NEW/MOBILE]` action |
|---|---|
| `main.dart`'s `routes` map (~40 entries) | **RECREATE USING SAME LOGIC** — `mobile-flutter-pos/lib/main.dart` gets its own `routes` map, same destination *concepts*, own widget classes |
| `features/pos/screens/_pos_drawer.dart` (permanent sidebar widget) | **DO NOT COPY** the widget — **RECREATE USING SAME LOGIC** the destination list, inside `[NEW/MOBILE] MobileHomeShell`/`MobileMoreMenu` |

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/features/pos/screens/mobile_home_shell.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_more_menu.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/pos/screens/mobile_home_shell.dart
class MobileHomeShell extends StatefulWidget {
  const MobileHomeShell({super.key});
  @override
  State<MobileHomeShell> createState() => _MobileHomeShellState();
}
class _MobileHomeShellState extends State<MobileHomeShell> {
  int _index = 0;
  // STEP 1: destination CONCEPTS studied from [OLD/SOURCE]'s _pos_drawer.dart — route strings
  // here point at mobile-flutter-pos's OWN routes map, defined in mobile-flutter-pos/lib/main.dart.
  static const _primary = [('/pos', Icons.point_of_sale), ('/open-tickets', Icons.receipt_long),
      ('/inventory', Icons.inventory_2), ('/reports', Icons.bar_chart)];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i < _primary.length) {
            Navigator.pushNamed(context, _primary[i].$1);   // resolves within mobile-flutter-pos only
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileMoreMenu()));
          }
        },
        destinations: [for (final d in _primary) NavigationDestination(icon: Icon(d.$2), label: ''),
            const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More')],
      ),
    );
  }
}
```

## G. Function Inputs and Outputs

`Navigator.pushNamed(BuildContext context, String routeName)` (Flutter SDK function, called from `[NEW/MOBILE]` code)
INPUT: `context`, `'/inventory'`
DOES: looks up `'/inventory'` in `mobile-flutter-pos/lib/main.dart`'s OWN `routes` map → builds and pushes THAT project's inventory screen (studied from `[OLD/SOURCE]`, written fresh — Day 17)
OUTPUT: `Future<T?>`

## H. State Before and After

Not applicable — navigation doesn't mutate business state.

## I. Classification

```text
main.dart's routes map (the CONCEPT of one route per destination)
RECREATE USING SAME LOGIC

_pos_drawer.dart (the permanent-sidebar WIDGET)
DO NOT COPY -> MOBILE UI REIMPLEMENT as MobileHomeShell/MobileMoreMenu
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE] frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart` — list every destination.
2. **READ** `[OLD/SOURCE] frontend-flutter-pos/lib/main.dart`'s `routes` map — cross-check.
3. **CREATE** `[NEW/MOBILE] mobile-flutter-pos/lib/main.dart`'s own `routes` map, one entry per destination concept (widgets built incrementally as each day's feature lands — stub with placeholders where the real screen doesn't exist yet).
4. **CREATE** `[NEW/MOBILE] mobile_home_shell.dart` using section F's skeleton — pick 4–5 primary destinations (POS, Held Tickets, Inventory, Reports, More).
5. **CREATE** `[NEW/MOBILE] mobile_more_menu.dart` listing the remaining destinations.
6. Wire `mobile-flutter-pos`'s `MobileLoginScreen` (Day 4) to `pushReplacementNamed` into whichever route resolves to `MobileHomeShell`.
7. Test tapping every primary destination and every "More" entry, confirm each resolves (even if to a placeholder screen for not-yet-built features).

## K–O

Same shape as before, entirely within `mobile-flutter-pos` — see prior days' K–O sections for the pattern; content here is navigation-only (no new business logic), covered by section J's manual test.

## What I Should Understand Before Day 6

That "POS" as a bottom-nav destination today points at whatever placeholder `mobile-flutter-pos/lib/main.dart` currently resolves it to — Day 6/7 replace that placeholder with the real `MobilePosScreen`/`MobileProductGrid`/`MobileCartScreen`, built fresh in `mobile-flutter-pos`, studying (never importing) `[OLD/SOURCE]`'s `pos_screen.dart`.

---

# Day 6 — Products: Old Logic, New Screen

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/models/product_models.dart
frontend-flutter-pos/lib/features/pos/providers/product_provider.dart
frontend-flutter-pos/lib/features/pos/services/product_service.dart
frontend-flutter-pos/lib/features/pos/services/demo_product_service.dart
frontend-flutter-pos/lib/features/pos/providers/category_provider.dart
frontend-flutter-pos/lib/features/pos/widgets/product_grid.dart
frontend-flutter-pos/lib/features/pos/widgets/product_card.dart
frontend-flutter-pos/lib/features/pos/widgets/category_tabs.dart
frontend-flutter-pos/lib/features/pos/widgets/product_modifier_sheet.dart
frontend-flutter-pos/lib/features/pos/screens/pos_screen.dart          (search debounce pattern, modifier-sheet wiring)
```
**Explicitly do NOT study/copy** `frontend-flutter-pos/lib/features/pos/models/product.dart` or `services/product_api_service.dart` — confirmed dead code in `[OLD/SOURCE]` itself, unreferenced anywhere.

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/models/product_models.dart
mobile-flutter-pos/lib/features/pos/providers/product_provider.dart
mobile-flutter-pos/lib/features/pos/services/product_service.dart
mobile-flutter-pos/lib/features/pos/services/demo_product_service.dart
mobile-flutter-pos/lib/features/pos/providers/category_provider.dart
mobile-flutter-pos/lib/features/pos/widgets/mobile_product_grid.dart
mobile-flutter-pos/lib/features/pos/widgets/mobile_product_search_bar.dart
mobile-flutter-pos/lib/features/pos/widgets/product_card.dart
mobile-flutter-pos/lib/features/pos/widgets/category_tabs.dart
mobile-flutter-pos/lib/features/pos/widgets/product_modifier_sheet.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_pos_screen.dart
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/providers/product_provider.dart` — read `ProductState` first, then `ProductNotifier`.

## B. `[OLD/SOURCE]` Function Chain

`[OLD/SOURCE] ProductState` — every field:
```dart
class ProductState {
  final List<Product> products; final bool isLoading; final bool isLoadingMore;
  final bool hasMore; final int currentPage; final int totalCount; final String? error;
}
```
Known quirk to reproduce (or deliberately fix) in `[NEW/MOBILE]`: `copyWith`'s `error` field uses `error ?? this.error`, so `copyWith(error: null)` does not actually clear a previous error.

`[OLD/SOURCE] ProductNotifier.loadProducts`/`loadMore`/`searchProducts`/`filterByCategory`/`findByBarcode` — full bodies (unchanged from prior research; see Day 1's table for where each maps):
```dart
static const int _pageSize = 48;
Future<void> loadProducts({String? query, int? categoryId}) async { /* resets page 0, hasMore true, fetches */ }
Future<void> loadMore() async { /* guarded by isLoadingMore/hasMore, appends */ }
Future<void> searchProducts(String query) async => loadProducts(query: query.isEmpty ? null : query);  // NO internal debounce
Future<void> filterByCategory(int? categoryId) async => loadProducts(categoryId: categoryId);
Future<Product?> findByBarcode(String barcode) => _service.findByBarcode(barcode);  // delegates, no state touch
```
Debounce is done by the CALLER (`[OLD/SOURCE] pos_screen.dart`'s `_PosAppBarState`, a `TextEditingController` listener + 300ms `Timer` — a pattern to reproduce in `[NEW/MOBILE]`'s search bar, not a function to import).

`[OLD/SOURCE] ApiProductService.getProducts` — two-endpoint branch (`/api/products/pos-catalog` unfiltered, `/api/products` filtered/paginated) — **same shared backend, both clients call it identically**.

`[OLD/SOURCE] _FallbackProductService`'s `_tryApi<T>` — silently falls back to `DemoProductService`'s 15 hardcoded products on any exception. Decide explicitly in `[NEW/MOBILE]` whether to keep this exact silent behavior or surface a "using demo data" indicator — either is valid, but it's a decision to make, not inherit unconsciously.

## C. Backend/API Chain (shared, unchanged)

```text
GET /api/products/pos-catalog   (initial load)         GET /api/products?q=&categoryId=&page=&size=  (filtered)
↓                                                        ↓
ProductController.posCatalog(storeId)                   ProductController.search(...) -> Page<ProductResponse>
```
Identical for both clients — `[NEW/MOBILE]`'s `ApiProductService` calls the exact same two endpoints `[OLD/SOURCE]`'s does.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `providers/product_provider.dart` | `ProductNotifier` (all methods), `ProductState` | **COPY/ADAPT NEARLY EXACTLY** |
| `services/product_service.dart` | `ApiProductService`, abstract `findByBarcode` default | **COPY/ADAPT NEARLY EXACTLY** — same two endpoints |
| `services/demo_product_service.dart` | `_FallbackProductService`, `DemoProductService` | **COPY/ADAPT NEARLY EXACTLY**, or **RECREATE USING SAME LOGIC** if you change the silent-fallback UX |
| `providers/category_provider.dart` | `categoriesProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| `widgets/product_card.dart` | `ProductCard` | **COPY/ADAPT NEARLY EXACTLY** — already touch-friendly, minimal changes expected |
| `widgets/category_tabs.dart` | `CategoryTabs` | **COPY/ADAPT NEARLY EXACTLY** — already has horizontal/vertical modes |
| `widgets/product_modifier_sheet.dart` | `ProductModifierSheet` | **COPY/ADAPT NEARLY EXACTLY** — already a bottom sheet, already mobile-appropriate |
| `widgets/product_grid.dart` | `ProductGrid` (`_fixedColumns = 5`) | **MOBILE UI REIMPLEMENT** -> `MobileProductGrid` (responsive column count) |
| `screens/pos_screen.dart` | desktop layout + search-debounce `Timer` PATTERN | **MOBILE UI REIMPLEMENT** for layout; **RECREATE USING SAME LOGIC** for the debounce pattern |
| `models/product.dart`, `services/product_api_service.dart` | dead code | **DO NOT COPY** |

**Selected/active states use the configurable main color; status/stock states never do.** `[OLD/SOURCE] widgets/category_tabs.dart` reads `PosTheme.primaryGreen` directly for its selected-tab background/border (`color: isSelected ? PosTheme.primaryGreen : PosTheme.backgroundPage`) — this is the concrete precedent to follow for any "this is the currently active/selected thing" state in `[NEW/MOBILE]`'s `MobileProductGrid`/`CategoryTabs`/`ProductCard`. Because `PosTheme.primaryGreen` is now a mutable getter (Day 3), `CategoryTabs`, `MobileProductGrid`'s selected-category chip, and any similar "active" indicator automatically track whatever main color the merchant configured in Settings (Day 19) — zero widget-level changes needed beyond reading the same getter `[OLD/SOURCE]` already reads. Keep this strictly separate from semantic colors: stock-status badges, error states, warning states, and similar meaning-carrying colors must stay on their own fixed constants (`errorRed`, `warningAmber`, etc.), entirely independent of the main color, exactly as `[OLD/SOURCE]`'s `PosTheme` already separates them. A grep-audit of `[OLD/SOURCE]`'s `lib/features/pos/screens/pos_screen.dart` and `lib/features/pos/widgets/*.dart` for hardcoded hex-color bypasses of this mechanism found none — `[NEW/MOBILE]`'s equivalent widgets should hold to the same standard.

## E. Exact `[NEW/MOBILE]` Files to Create

Listed in "NEW MOBILE FILES TO CREATE/MODIFY" above.

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/pos/widgets/mobile_product_grid.dart
class MobileProductGrid extends ConsumerStatefulWidget {
  const MobileProductGrid({super.key});
  @override
  ConsumerState<MobileProductGrid> createState() => _MobileProductGridState();
}
class _MobileProductGridState extends ConsumerState<MobileProductGrid> {
  final _scrollController = ScrollController();
  @override
  void initState() { super.initState(); _scrollController.addListener(_onScroll); }
  void _onScroll() {
    // STEP 1: same "200px from bottom" pattern studied from [OLD/SOURCE]'s ProductGrid.
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(productsProvider.notifier).loadMore();   // mobile-flutter-pos's OWN productsProvider
    }
  }
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    // STEP 2: responsive column count — the one deliberate change from [OLD/SOURCE]'s fixed 5.
    final columns = (MediaQuery.of(context).size.width / 160).floor().clamp(2, 6);
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns),
      itemCount: state.products.length,
      itemBuilder: (context, i) => ProductCard(product: state.products[i], onTap: () async {
        final result = await showModalBottomSheet<CartItem>(context: context, isScrollControlled: true,
            builder: (_) => ProductModifierSheet(product: state.products[i]));
        if (result != null) ref.read(cartProvider.notifier).addItem(result);   // Day 7
      }),
    );
  }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] ProductNotifier.searchProducts(String query)`
INPUT: `query = "coca"`
DOES: `await loadProducts(query: "coca")` — same as `[OLD/SOURCE]`
OUTPUT: `Future<void>`
CALLER: `mobile-flutter-pos`'s own search bar's debounce `Timer`
NEXT: `MobileProductGrid`'s `ref.watch(productsProvider)` rebuilds.

## H. State Before and After

Identical shape to `[OLD/SOURCE]` — see Day 6's original H section content for the exact before/after; the state lives in `mobile-flutter-pos`'s own `productsProvider`, entirely separate from any `frontend-flutter-pos` session's state.

## I. Classification

```text
ProductNotifier, ProductState, ApiProductService, DemoProductService/_FallbackProductService,
CategoryTabs, ProductCard, ProductModifierSheet
COPY/ADAPT NEARLY EXACTLY

ProductGrid's layout, pos_screen.dart's search-bar layout
MOBILE UI REIMPLEMENT

product.dart, product_api_service.dart
DO NOT COPY
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `product_provider.dart`, `product_service.dart`, `demo_product_service.dart`, `category_provider.dart` fully.
2. **READ** `[OLD/SOURCE]` `product_grid.dart`, `product_card.dart`, `category_tabs.dart`, `product_modifier_sheet.dart`.
3. **READ** `[OLD/SOURCE]` `pos_screen.dart`'s `_PosAppBarState` debounce `Timer` pattern.
4. **CREATE** `[NEW/MOBILE]` `product_models.dart`, `product_provider.dart`, `product_service.dart`, `demo_product_service.dart`, `category_provider.dart` — copy/adapt per section D.
5. **CREATE** `[NEW/MOBILE]` `product_card.dart`, `category_tabs.dart`, `product_modifier_sheet.dart` — copy/adapt.
6. **CREATE** `[NEW/MOBILE]` `mobile_product_grid.dart` using section F's skeleton.
7. **CREATE** `[NEW/MOBILE]` `mobile_product_search_bar.dart` (debounce pattern, own `Timer`).
8. **CREATE/MODIFY** `[NEW/MOBILE]` `mobile_pos_screen.dart`, wiring the grid + search bar + `CategoryTabs`.
9. Wire `mobile_pos_screen.dart` as the real destination for `MobileHomeShell`'s "POS" tab (replacing Day 5's placeholder).
10. Test against the shared backend: load, scroll (loadMore), search, filter by category.

## K–O

Same content/shape as the original Day 6 (function-flow diagrams, error flow, test flow) — every occurrence now understood to be entirely within `mobile-flutter-pos`, studied from but never importing `frontend-flutter-pos`. Existing `[OLD/SOURCE]` tests (`frontend-flutter-pos/test/product_provider_test.dart`) are read as a reference for what to test; write NEW tests at `[NEW/MOBILE] mobile-flutter-pos/test/product_provider_test.dart`.

## What I Should Understand Before Day 7

That `Product.modifierGroups` arrives embedded directly on the product from `/pos-catalog`/`/api/products` (shared backend contract, unchanged) — `[NEW/MOBILE]`'s `ProductModifierSheet` reads it straight off the object already in `mobile-flutter-pos`'s own `ProductState.products`, no extra network call.

---

# Day 7 — Cart: Every Mutator, Old Body → New Body

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/models/cart_models.dart
frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart
frontend-flutter-pos/lib/features/pos/services/cart_service.dart
frontend-flutter-pos/lib/features/pos/widgets/cart_items_list.dart
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/models/cart_models.dart
mobile-flutter-pos/lib/features/pos/providers/cart_provider.dart
mobile-flutter-pos/lib/features/pos/services/cart_service.dart
mobile-flutter-pos/lib/features/pos/widgets/cart_items_list.dart
mobile-flutter-pos/lib/features/pos/widgets/mobile_cart_badge.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_cart_screen.dart
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart` — read `CartState`'s money getters first, then every `CartNotifier` method.

## B. `[OLD/SOURCE]` Function Chain — money math, exact formulas (study these before writing anything)

```dart
int get _subtotalMinor => items.fold<int>(0, (sum, item) => sum + Money.lineTotalMinor(item.unitPrice, item.qty));
int get _itemDiscountsMinor => items.fold<int>(0, (sum, item) => sum + Money.toMinor((item.discountAmount ?? 0) * item.qty));
int get _discountMinor { final raw = discountType == DiscountType.fixed ? Money.toMinor(discount)
    : Money.percentOfMinor(_subtotalMinor, discount); return raw.clamp(0, _subtotalMinor); }
double get total => Money.toMajor(_subtotalMinor - _itemDiscountsMinor);
double get discountAmount => Money.toMajor(_discountMinor);
double get taxAmount => total * taxRate;   // tax on POST-item-discount, PRE-cart-discount subtotal
double get finalTotal {
  final subtotalAfterItemDiscounts = _subtotalMinor - _itemDiscountsMinor;
  final net = (subtotalAfterItemDiscounts - _discountMinor - Money.toMinor(loyalty)).clamp(0, subtotalAfterItemDiscounts);
  return Money.toMajor(net) + taxAmount;
}
```
This exact formula — including the tax-on-`total` (not tax-on-cart-discounted-total) subtlety — is a **business rule**, not an implementation detail. `[NEW/MOBILE]`'s `CartState` must reproduce it exactly; a mobile cart that computes tax differently from the desktop cart for the same inputs is a real, customer-facing bug, not an acceptable platform difference.

Every mutator shares one pattern: mutate `state` → `await persistCart()` (always succeeds or logs) → `await _syncService(...)` (best-effort, swallows all errors). `[OLD/SOURCE]` bodies (full, exact — reproduce identically in `[NEW/MOBILE]`):
```dart
Future<void> addItemFromProduct(Product product) async {
  final existingIdx = state.items.indexWhere((item) => item.product.id == product.id);
  if (existingIdx >= 0) { await incrementItem(state.items[existingIdx].id); }
  else { final newItem = CartItem(id: '${DateTime.now().microsecondsSinceEpoch}_${product.id}',
      product: product, qty: 1, addedAt: DateTime.now().millisecondsSinceEpoch); await addItem(newItem); }
}
Future<void> addItem(final CartItem item) async {
  state = state.copyWith(loading: true);
  try {
    int? waitingNumber = state.waitingNumber;
    waitingNumber ??= await waitingNumberService.issueNumber();
    state = state.copyWith(items: [...state.items, item], waitingNumber: waitingNumber);
    await persistCart();
    await _syncService(() => service.saveCartItems(state.items), 'add');
  } catch (e) { debugPrint('Cart add failed: $e'); }
  finally { state = state.copyWith(loading: false); }
}
// removeItem/incrementItem/decrementItem/setItemQuantity: same persist-then-sync order;
// decrementItem delegates to removeItem when qty<=1; setItemQuantity delegates when qty<=0.
void applyDiscount(final double amount, {DiscountType type = DiscountType.fixed}) {
  state = state.copyWith(discount: amount, discountType: type); persistCart();   // fire-and-forget, NO _syncService
}
void setCustomer(int customerId) { state = state.copyWith(customerId: customerId); persistCart(); }  // non-nullable!
void clearCustomer() { state = state.copyWith(clearCustomer: true); persistCart(); }
Future<void> clear({bool releaseWaitingNumber = true}) async {
  final waitingNumber = state.waitingNumber;
  state = state.copyWith(loading: true);
  if (releaseWaitingNumber && waitingNumber != null) {
    try { await waitingNumberService.releaseNumber(waitingNumber); } catch (e) { debugPrint('...'); }
  }
  state = CartState.initial();
  await persistCart();
  await _syncService(() => service.clearCart(), 'clear');
  state = state.copyWith(loading: false);
}
```

`[OLD/SOURCE] CartService`'s switch point:
```dart
final cartServiceProvider = Provider<CartService>((ref) =>
    AppConfig.useApiCartService ? ApiCartService(ref.watch(apiServiceProvider)) : LocalCartService());
```
`[NEW/MOBILE]`'s own `cartServiceProvider` reproduces this same switch, reading `mobile-flutter-pos`'s own `AppConfig.useApiCartService` flag — a value entirely independent of whatever `frontend-flutter-pos`'s flag is currently set to on a different device/session.

## C. Backend/API Chain (shared, only exercised when `useApiCartService == true`)

```text
[NEW/MOBILE] CartNotifier._syncService -> [NEW/MOBILE] ApiCartService.saveCartItems
    DELETE /api/carts/{oldId} -> POST /api/carts -> POST /api/carts/{newId}/items (per item)
↓
CartController -> CartService.addItemToCart [backend — unchanged, shared]
```
**Confirmed architectural fact, applies to BOTH clients identically**: this backend `Cart` entity is completely disconnected from `Sale` — `CartController.completeCart` only flips `Cart.status`, never creates a `Sale`. The real checkout (Day 11) for both `frontend-flutter-pos` and `mobile-flutter-pos` goes through `SaleController`/`SaleService` independently, building its request from the in-memory `CartState`, never from this backend Cart entity. Treat `ApiCartService` as pure background persistence in `[NEW/MOBILE]`, exactly as it is in `[OLD/SOURCE]`.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `providers/cart_provider.dart` | `CartState` (money getters), `CartNotifier` (every method) | **COPY/ADAPT NEARLY EXACTLY** — this is the highest-stakes "must match exactly" logic in the entire plan |
| `models/cart_models.dart` | `CartItem`, `SelectedModifier`, `HeldOrder` | **COPY/ADAPT NEARLY EXACTLY** |
| `services/cart_service.dart` | `ApiCartService`, `LocalCartService`, `cartServiceProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| `widgets/cart_items_list.dart` | `CartItemsList` (swipe-to-delete) | **COPY/ADAPT NEARLY EXACTLY** — already touch-friendly |
| `widgets/cart_panel.dart` (380px sidebar) | — | **DO NOT COPY** |
| `widgets/cart_panel_footer.dart`, `cart_footer.dart` | — | **DO NOT COPY** — confirmed dead code even in `[OLD/SOURCE]` itself |

**Cart line-item actions are icon buttons, not text links — follow the current `[OLD/SOURCE]` precedent, don't reinvent it.** Inside `[OLD/SOURCE] widgets/cart_items_list.dart`'s private `_CartItemCard`, the old "Remove"/"Modifier" underlined-text `GestureDetector`s were replaced with icon buttons: `Icons.delete_outline` colored `PosTheme.errorRed` for remove, `Icons.tune` colored `PosTheme.primaryGreen` for editing modifiers — each wrapped in `Tooltip(message: ...)` carrying the same localized string that used to be the visible label, so the action stays accessible/discoverable without permanent on-screen text. Reproduce this exact icon/color pairing in `[NEW/MOBILE]`'s `CartItemsList`. **The underlying callbacks are unchanged** — remove still calls `notifier.removeItem(item.id)`, modifier-edit still opens the same `ProductModifierSheet` (Day 6) via the same private `_editModifiers(context)`-style method — this was a pure UI-presentation change in `[OLD/SOURCE]`, and `[NEW/MOBILE]` should port it the same way: new icon widgets wired to the identical `CartNotifier` methods documented in section B, no business-logic changes riding along with it.

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/features/pos/models/cart_models.dart
mobile-flutter-pos/lib/features/pos/providers/cart_provider.dart
mobile-flutter-pos/lib/features/pos/services/cart_service.dart
mobile-flutter-pos/lib/features/pos/widgets/cart_items_list.dart
mobile-flutter-pos/lib/features/pos/widgets/mobile_cart_badge.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_cart_screen.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/pos/screens/mobile_cart_screen.dart
class MobileCartScreen extends ConsumerWidget {
  const MobileCartScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);   // mobile-flutter-pos's OWN cartProvider
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.cartTitle)),
      body: Column(children: [
        // STEP 1: reuse the [NEW/MOBILE] CartItemsList adapted in section D — same widget, new project.
        Expanded(child: CartItemsList(items: cart.items)),
        Text('${context.l10n.total}: ${cart.finalTotal}'),   // NEVER recompute — always read finalTotal
        ElevatedButton(
          onPressed: cart.items.isEmpty ? null : () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => MobilePaymentScreen(total: cart.finalTotal /* ... Day 11 */))),
          child: Text(context.l10n.charge),
        ),
      ]),
    );
  }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] CartNotifier.incrementItem(String id)`
INPUT: a cart-line id (format `'${microsecondsSinceEpoch}_${productId}'`)
DOES: finds the line, increments `qty`, persists, best-effort syncs — identical to `[OLD/SOURCE]`
OUTPUT: `Future<void>`
CALLER: `mobile-flutter-pos`'s own qty-stepper widget
NEXT: `ref.watch(cartProvider)` rebuilds every consumer in `mobile-flutter-pos`.

## H. State Before and After

Same shape as `[OLD/SOURCE]`'s Day 7: BEFORE `mobile-flutter-pos`'s own `CartState.items = [...]`, AFTER incremented — entirely within the new project's own provider tree, independent of any `frontend-flutter-pos` session.

## I. Classification

```text
CartNotifier (every method), CartState, CartItem/SelectedModifier/HeldOrder, CartService/ApiCartService/LocalCartService
COPY/ADAPT NEARLY EXACTLY

CartItemsList
COPY/ADAPT NEARLY EXACTLY

CartPanel (380px sidebar), cart_panel_footer.dart, cart_footer.dart
DO NOT COPY

MobileCartBadge, MobileCartScreen
MOBILE UI REIMPLEMENT
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `cart_models.dart` fully.
2. **READ** `[OLD/SOURCE]` `cart_provider.dart`'s money getters twice — confirm you understand the tax-on-`total` subtlety before writing anything.
3. **READ** `[OLD/SOURCE]` every `CartNotifier` method listed in section D.
4. **READ** `[OLD/SOURCE]` `cart_service.dart`.
5. **CREATE** `[NEW/MOBILE]` `cart_models.dart`, `cart_provider.dart`, `cart_service.dart` — copy/adapt, verifying the money formulas match exactly (write a quick throwaway test comparing outputs against known `[OLD/SOURCE]` values if unsure).
6. **CREATE** `[NEW/MOBILE]` `cart_items_list.dart`, `mobile_cart_badge.dart`, `mobile_cart_screen.dart`.
7. Wire the badge into `mobile_pos_screen.dart`'s AppBar (Day 6).
8. Test: add several items, confirm badge/total match manual arithmetic; force-quit/relaunch, confirm cart persisted via `mobile-flutter-pos`'s own `SharedPreferences`.

## K–O

Same shape as the original Day 7 (function-flow diagrams for add/charge, error flow documenting the swallow-errors-silently `_syncService` behavior, test flow) — now entirely `mobile-flutter-pos`-internal. `[OLD/SOURCE]`'s `frontend-flutter-pos/test/cart_provider_resilience_test.dart` is read as the reference for what to test; write the equivalent at `[NEW/MOBILE] mobile-flutter-pos/test/cart_provider_resilience_test.dart`.

## What I Should Understand Before Day 8

The mutate → `persistCart()` → best-effort `_syncService()` pattern repeats identically in `HeldTicketNotifier` (Day 9) — recognizing it in `[OLD/SOURCE]` once means recognizing it again quickly when adapting Day 9's code.

---

# Day 8 — Barcode Scanner: Camera to Cart, Old → New

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart     (addProductByBarcode)
frontend-flutter-pos/lib/features/pos/providers/product_provider.dart  (findByBarcode)
frontend-flutter-pos/lib/features/pos/screens/phone_screen_scan.dart   (MobileScannerController config)
frontend-flutter-pos/lib/features/pos/services/scanner_relay_role.dart (STUDY ONLY — see classification)
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/screens/mobile_scan_screen.dart
mobile-flutter-pos/ios/Runner/Info.plist                (NSCameraUsageDescription)
mobile-flutter-pos/android/app/src/main/AndroidManifest.xml   (CAMERA permission)
```
Note: `CartNotifier.addProductByBarcode`/`ProductNotifier.findByBarcode` were already created Days 6–7 in `mobile-flutter-pos` — today only ADDS the camera scan screen that calls them; no cart/product files are recreated today.

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart` — find `addProductByBarcode`, the function every scan path converges on.

## B. `[OLD/SOURCE]` Function Chain

`[OLD/SOURCE] CartNotifier.addProductByBarcode` — full body (already adapted into `mobile-flutter-pos` on Day 7 — re-confirm it here before wiring the scanner to it):
```dart
Future<BarcodeAddResult> addProductByBarcode(String barcode) async {
  final normalized = barcode.trim();
  if (normalized.isEmpty) return const BarcodeAddResult(added: false, message: 'Enter or scan a barcode');
  try {
    Product? product;
    final comparable = normalized.toLowerCase();
    for (final candidate in _ref.read(productsProvider).products) {   // fast path: in-memory check first
      if (candidate.barcode.trim().toLowerCase() == comparable) { product = candidate; break; }
    }
    product ??= await _ref.read(productsProvider.notifier).findByBarcode(normalized);   // slow path
    if (product == null) return BarcodeAddResult(added: false, message: 'No product found for barcode $normalized');
    if (!product.active) return BarcodeAddResult(added: false, message: '${product.nameEn} is inactive', product: product);
    if (!product.sellable) return BarcodeAddResult(added: false, message: '${product.nameEn} is not sellable', product: product);
    if (product.outOfStock) return BarcodeAddResult(added: false, message: '${product.nameEn} is out of stock', product: product);
    await addItemFromProduct(product);
    return BarcodeAddResult(added: true, message: '${product.nameEn} added to cart', product: product);
  } catch (error, stackTrace) { return BarcodeAddResult(added: false, message: 'Could not look up barcode $normalized'); }
}
```

`[OLD/SOURCE] PhoneScannerScreen`'s `MobileScannerController` config (worth reusing the exact values):
```dart
_cameraController = MobileScannerController(facing: CameraFacing.back, detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 700, autoZoom: true,
    formats: const [BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.code93, BarcodeFormat.codabar,
        BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.itf, BarcodeFormat.upcA, BarcodeFormat.upcE]);
```
**Important distinction**: `[OLD/SOURCE]`'s `_onDetect` sends the scanned value over `ScannerRelayClient` (a websocket) to a SEPARATE desktop POS terminal — it does NOT call `addProductByBarcode` directly, because `frontend-flutter-pos` was built assuming the device running the POS UI has no camera. In `mobile-flutter-pos`, the phone running the scanner **is** the POS — so `[NEW/MOBILE]`'s scan screen calls `addProductByBarcode` directly, skipping the relay entirely.

## C. Backend/API Chain

Only reached on the slow path (Day 6): `GET /api/products?q={barcode}&page=0&size=50` — shared endpoint, unchanged.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `providers/cart_provider.dart` | `addProductByBarcode`, `BarcodeAddResult` | Already **COPY/ADAPT NEARLY EXACTLY**'d on Day 7 — no new work today |
| `screens/phone_screen_scan.dart` | `MobileScannerController` config values | **COPY/ADAPT NEARLY EXACTLY** the config; **RECREATE USING SAME LOGIC** the detect handler (direct-to-cart, not relay) |
| `services/scanner_relay_role.dart` | `ScannerRelayClient` | **DO NOT COPY** as the primary path — the code is portable, but its REASON to exist (letting a camera-less desktop borrow a phone's camera) mostly disappears once the POS itself is a phone. If a "second staff member's phone scans for a busy till" feature is wanted later, that's an additive, deliberate feature decision — not something to build by default today. |

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/features/pos/screens/mobile_scan_screen.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/pos/screens/mobile_scan_screen.dart
class MobileScanScreen extends ConsumerStatefulWidget {
  const MobileScanScreen({super.key});
  @override
  ConsumerState<MobileScanScreen> createState() => _MobileScanScreenState();
}
class _MobileScanScreenState extends ConsumerState<MobileScanScreen> {
  // STEP 1: same config values studied from [OLD/SOURCE]'s PhoneScannerScreen.
  late final _controller = MobileScannerController(facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal, detectionTimeoutMs: 700);
  String? _lastValue; DateTime? _lastAt;

  Future<void> _onDetect(BarcodeCapture capture) async {
    final value = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    if (_lastValue == value && _lastAt != null &&
        DateTime.now().difference(_lastAt!) < const Duration(milliseconds: 1200)) return;   // de-dupe
    _lastValue = value; _lastAt = DateTime.now();
    // STEP 2: call DIRECTLY — no relay, since this phone IS the POS.
    final result = await ref.read(cartProvider.notifier).addProductByBarcode(value);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: MobileScanner(controller: _controller, onDetect: _onDetect));
}
```

## G. Function Inputs and Outputs

Unchanged from Day 7's `addProductByBarcode` — see that day. New today: `MobileScanScreen._onDetect(BarcodeCapture capture)` — INPUT: a `BarcodeCapture` from `mobile_scanner`; DOES: de-dupes, calls `addProductByBarcode`; OUTPUT: `Future<void>`; CALLER: `MobileScanner` widget's `onDetect`; NEXT: SnackBar shows `result.message`.

## H. State Before and After

Same as Day 7's `addProductByBarcode` before/after — the scan screen is purely a new input source for the same `CartState` mutation already built.

## I. Classification

```text
addProductByBarcode / findByBarcode
COPY/ADAPT NEARLY EXACTLY (already done Day 6/7)

MobileScannerController config values
COPY/ADAPT NEARLY EXACTLY

_onDetect's RELAY-vs-DIRECT dispatch
RECREATE USING SAME LOGIC (direct call, not relay)

ScannerRelayClient / scanner_relay_role.dart as the PRIMARY path
DO NOT COPY
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `phone_screen_scan.dart`'s `MobileScannerController` setup and `_onDetect`.
2. Add `NSCameraUsageDescription` to `[NEW/MOBILE] mobile-flutter-pos/ios/Runner/Info.plist` (confirm `CAMERA` is already present in `mobile-flutter-pos/android/app/src/main/AndroidManifest.xml` from Day 2's scaffolding, or add it).
3. **CREATE** `[NEW/MOBILE] mobile_scan_screen.dart` using section F's skeleton.
4. Wire a scan button on `[NEW/MOBILE] mobile_pos_screen.dart`'s search bar (Day 6) to push `MobileScanScreen`.
5. Test on Android and iOS: scan a real barcode, confirm cart updates; test denied camera permission, confirm graceful messaging.

## K–O

Same shape as the original Day 8 — every diagram/test now entirely `mobile-flutter-pos`-internal.

## What I Should Understand Before Day 9

That permission-request handling here is the first genuinely new *platform-facing* code in `mobile-flutter-pos` (Days 1–7 were pure business-logic adaptation) — the same "request → handle denied gracefully" shape reappears at higher stakes for Bluetooth (Day 16).

---

# Day 9 — Customer / Table / Held & Waiting Tickets

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/providers/customer_provider.dart
frontend-flutter-pos/lib/features/pos/services/customer_service.dart
frontend-flutter-pos/lib/features/pos/providers/table_selection_provider.dart
frontend-flutter-pos/lib/features/pos/widgets/table_selector.dart          (the dual-call gotcha)
frontend-flutter-pos/lib/features/pos/providers/held_ticket_provider.dart
frontend-flutter-pos/lib/features/pos/services/held_ticket_service.dart
frontend-flutter-pos/lib/features/pos/services/waiting_number_service.dart
frontend-flutter-pos/lib/features/pos/providers/waiting_ticket_provider.dart
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/providers/customer_provider.dart
mobile-flutter-pos/lib/features/pos/services/customer_service.dart
mobile-flutter-pos/lib/features/pos/providers/table_selection_provider.dart
mobile-flutter-pos/lib/features/pos/providers/held_ticket_provider.dart
mobile-flutter-pos/lib/features/pos/services/held_ticket_service.dart
mobile-flutter-pos/lib/features/pos/services/waiting_number_service.dart
mobile-flutter-pos/lib/features/pos/providers/waiting_ticket_provider.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_customer_picker_screen.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_table_selector_screen.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_held_tickets_screen.dart
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/widgets/table_selector.dart` — the row `onTap` handler contains the single most important gotcha in this whole day.

## B. `[OLD/SOURCE]` Function Chain — the dual-state gotcha, exact code

```dart
onTap: () {
  if (!isAvailable) { /* show "in use" SnackBar */ return; }
  ref.read(tableSelectionProvider.notifier).select(table);   // 1st
  ref.read(cartProvider.notifier).setTable(table.id);          // 2nd — MUST both happen, in this order
  Navigator.of(context).pop();
},
```
**This exact two-call sequence, in this exact order, must be reproduced in `[NEW/MOBILE]`'s table selector** — calling only one leaves the UI showing a table that isn't actually attached to the sale, or vice versa. This is a business rule (a data-consistency invariant), not incidental desktop-UI code.

`[OLD/SOURCE] HeldTicketNotifier.holdCurrentCart`/`restoreTicket`/`cancelResume`/`cancelCurrentTicket`/`releaseTicketById` — full bodies (see prior research; identical shape to Day 7's mutate→persist→sync pattern, reproduced exactly in `[NEW/MOBILE]`). `releaseTicketById` deliberately swallows all errors — *"the sale already succeeded — a leftover held-ticket row is just clutter, not a lost order"* — reproduce this exact non-fatal handling.

`[OLD/SOURCE] WaitingNumberService` is entirely offline (SharedPreferences, cycles 1–100, no backend counterpart at all) — `[NEW/MOBILE]`'s copy is equally offline, using `mobile-flutter-pos`'s own local storage.

## C. Backend/API Chain (shared)

```text
Customers:    GET/POST/PUT/DELETE /api/customers            -> CustomerController [backend, shared]
Held tickets: GET/POST /api/pos/open-tickets                -> HeldTicketController [backend, shared]
Waiting numbers: NO backend endpoint — fully client-local in BOTH clients
Tables (admin CRUD): GET/POST/PUT/DELETE /api/tables         -> TableController [backend, shared]
Table SELECTION during a sale: no network call at all (TableSelectionNotifier.select is 100% offline)
```

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `providers/customer_provider.dart` | `CustomerNotifier.load/create/update` | **COPY/ADAPT NEARLY EXACTLY** |
| `providers/table_selection_provider.dart` | `TableSelectionNotifier.select` | **COPY/ADAPT NEARLY EXACTLY** |
| `providers/held_ticket_provider.dart` | `HeldTicketNotifier` (all methods) | **COPY/ADAPT NEARLY EXACTLY** |
| `services/waiting_number_service.dart` | `WaitingNumberService` (all methods) | **COPY/ADAPT NEARLY EXACTLY** |
| `widgets/table_selector.dart` | the dual-provider-call `onTap` LOGIC | **COPY/ADAPT NEARLY EXACTLY** the logic, **MOBILE UI REIMPLEMENT** the fixed-320px dialog layout |
| `widgets/held_tickets_dialog.dart`/`waiting_tickets_dialog.dart` | desktop modal layout | **MOBILE UI REIMPLEMENT** as full-screen `mobile_held_tickets_screen.dart` |

## E. Exact `[NEW/MOBILE]` Files to Create

Listed above.

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste (table selector shown, the highest-risk one).
```dart
// mobile-flutter-pos/lib/features/pos/screens/mobile_table_selector_screen.dart
class MobileTableSelectorScreen extends ConsumerWidget {
  const MobileTableSelectorScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tableProvider);
    return Scaffold(body: tables.when(
      data: (page) => ListView(children: [
        for (final table in page.items)
          ListTile(title: Text(table.displayName), onTap: () {
            // STEP 1 and STEP 2 MUST both happen, in this order — copied EXACTLY from [OLD/SOURCE].
            ref.read(tableSelectionProvider.notifier).select(table);
            ref.read(cartProvider.notifier).setTable(table.id);
            Navigator.of(context).pop();
          }),
      ]),
      loading: () => const CircularProgressIndicator(), error: (e, _) => Text('$e'),
    ));
  }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] HeldTicketNotifier.holdCurrentCart(List<CartItem> items, {int? ticketId})`
INPUT: `mobile-flutter-pos`'s own `cart.items`, `ticketId: null` (new hold)
DOES: POSTs a hold-ticket payload, reloads the held-ticket list, clears the working cart, clears table selection — identical to `[OLD/SOURCE]`
OUTPUT: `Future<int?>`
CALLER: a "Hold" button in `mobile_cart_screen.dart`
NEXT: cart badge drops to 0; ticket appears in `mobile_held_tickets_screen.dart`.

## H. State Before and After

Same shape as `[OLD/SOURCE]`'s Day 9 — entirely within `mobile-flutter-pos`'s own provider tree.

## I. Classification

```text
CustomerNotifier, TableSelectionNotifier, HeldTicketNotifier, WaitingNumberService
COPY/ADAPT NEARLY EXACTLY

table_selector.dart's dual-call LOGIC
COPY/ADAPT NEARLY EXACTLY

table_selector.dart's fixed-320px DIALOG, held_tickets_dialog.dart, waiting_tickets_dialog.dart
MOBILE UI REIMPLEMENT
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `table_selection_provider.dart` and `table_selector.dart`, confirm the dual-call order yourself.
2. **READ** `[OLD/SOURCE]` `held_ticket_provider.dart` fully.
3. **READ** `[OLD/SOURCE]` `waiting_number_service.dart` fully.
4. **CREATE** `[NEW/MOBILE]` `customer_provider.dart`, `customer_service.dart`, `table_selection_provider.dart`, `held_ticket_provider.dart`, `held_ticket_service.dart`, `waiting_number_service.dart`, `waiting_ticket_provider.dart` — copy/adapt.
5. **CREATE** `[NEW/MOBILE]` `mobile_customer_picker_screen.dart`.
6. **CREATE** `[NEW/MOBILE]` `mobile_table_selector_screen.dart` using section F's skeleton — test the dual-call explicitly.
7. **CREATE** `[NEW/MOBILE]` `mobile_held_tickets_screen.dart`.
8. Test the full hold → reopen cycle end to end within `mobile-flutter-pos`.

## K–O

Same shape as the original Day 9 — all diagrams/error-flows now entirely `mobile-flutter-pos`-internal.

## What I Should Understand Before Day 10

`WaitingNumberService` and `TableSelectionNotifier` are intentionally, entirely offline by design in `[OLD/SOURCE]` — reproduce that design choice in `[NEW/MOBILE]` rather than "improving" it into an online service; contrast with `CustomerService` (always-online, no local fallback, in both projects).

---

# Day 10 — Shift Management: Open, Close, Precheck, History

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/providers/shift_provider.dart
frontend-flutter-pos/lib/features/pos/services/shift_service.dart
frontend-flutter-pos/lib/features/pos/screens/shift_screen.dart      (confirms display-only, no local compute)
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/providers/shift_provider.dart
mobile-flutter-pos/lib/features/pos/services/shift_service.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_shift_screen.dart
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/providers/shift_provider.dart` — 4 methods, short file, read the whole thing.

## B. `[OLD/SOURCE]` Function Chain

```dart
class ShiftState { final bool isShiftOpen; final Shift? currentShift; }
Future<void> loadCurrentShift() async { /* try getCurrentShift, catch -> isShiftOpen: false */ }
Future<void> openShift({double openingFloat = 0.0}) async {
  final newShift = await service.openShift(openingFloat);   // NO try/catch — propagates
  state = ShiftState(isShiftOpen: true, currentShift: newShift);
}
Future<void> closeShift({double? closingCash}) async {
  if (state.currentShift != null) {
    final closed = await service.closeShift(state.currentShift!.id, closingCash ?? state.currentShift!.openingFloat);
    state = ShiftState(isShiftOpen: false, currentShift: closed);   // isShiftOpen goes false UNCONDITIONALLY
  }
}
Future<Map<String, dynamic>> getClosePrecheck() async { /* GET .../close-precheck */ }
```
**Non-obvious fact to reproduce identically**: `closeShift` sets `isShiftOpen: false` regardless of whether the backend returned `CLOSED` or `PENDING_APPROVAL` — `[NEW/MOBILE]`'s UI must read `state.currentShift?.status`, not just `isShiftOpen`, to distinguish the two, exactly as `[OLD/SOURCE]`'s UI must.

`[OLD/SOURCE] ApiShiftService`'s 4 endpoints (`GET /api/shifts/current`, `POST /api/shifts/open`, `POST /api/shifts/{id}/close`, `GET /api/shifts/{id}/close-precheck`) — same 4 endpoints `[NEW/MOBILE]` calls.

## C. Backend/API Chain (shared, unchanged) — the variance logic

```text
POST /api/shifts/{id}/close {closingCash, forceClose: false}
↓
ShiftController.close -> ShiftService.close(id, request)  [backend, shared, unchanged]
    VARIANCE_THRESHOLD = 10.00 (BigDecimal)
    expected = openingCash + cashSales + cashRefunds + manualCashEvents
    variance = closingCash - expected
    if (|variance| > 10.00) { OWNER/MANAGER -> CLOSED (self-approve) : else -> PENDING_APPROVAL }
    else { CLOSED }
```
This variance/approval logic lives **entirely on the shared backend** — identical for both `frontend-flutter-pos` and `mobile-flutter-pos`, because both clients call the exact same `POST /api/shifts/{id}/close` endpoint. `[NEW/MOBILE]` must never reimplement this threshold client-side; it just calls the endpoint and renders whatever comes back.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `providers/shift_provider.dart` | `ShiftNotifier` (all 4 methods), `ShiftState` | **COPY/ADAPT NEARLY EXACTLY** |
| `services/shift_service.dart` | `ApiShiftService` (4 methods) | **COPY/ADAPT NEARLY EXACTLY** — same 4 shared endpoints |
| `screens/shift_screen.dart` | display-only pattern (never computes variance) | **MOBILE UI REIMPLEMENT** the layout; **COPY/ADAPT NEARLY EXACTLY** the "just display what the backend returned" principle |

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/features/pos/providers/shift_provider.dart
mobile-flutter-pos/lib/features/pos/services/shift_service.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_shift_screen.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/pos/screens/mobile_shift_screen.dart
class MobileShiftScreen extends ConsumerWidget {
  const MobileShiftScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftState = ref.watch(shiftProvider);   // mobile-flutter-pos's OWN shiftProvider
    return Scaffold(body: shiftState.isShiftOpen
        ? _CloseShiftForm(shift: shiftState.currentShift!) : const _OpenShiftForm());
  }
}
class _CloseShiftForm extends ConsumerWidget {
  final Shift shift;
  const _CloseShiftForm({required this.shift});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(onPressed: () async {
      // STEP 1: ALWAYS precheck first — same as [OLD/SOURCE]'s implied flow.
      final precheck = await ref.read(shiftProvider.notifier).getClosePrecheck();
      if (precheck['blockedByOpenTickets'] == true) { /* block, show dialog */ return; }
      final closingCash = await _promptClosingCash(context);
      await ref.read(shiftProvider.notifier).closeShift(closingCash: closingCash);
      // STEP 2: check the REAL status, not just isShiftOpen (see section B's warning).
      final status = ref.read(shiftProvider).currentShift?.status;
      if (status == 'PENDING_APPROVAL') { /* show "awaiting manager approval" — NOT a failure */ }
    }, child: Text(context.l10n.closeShift));
  }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] ShiftNotifier.closeShift({double? closingCash})`
INPUT: `closingCash = 145.50`
DOES: `POST /api/shifts/{id}/close` (shared backend) → backend computes variance → `CLOSED` or `PENDING_APPROVAL`
OUTPUT: `Future<void>` (throws on failure — no internal catch, same as `[OLD/SOURCE]`)
CALLER: `_CloseShiftForm`'s close button
NEXT: `state.currentShift.status` reflects the real backend decision.

## H. State Before and After

Same shape as `[OLD/SOURCE]`'s Day 10 — a large-variance close by a cashier-role account leaves `mobile-flutter-pos`'s own `ShiftState.currentShift.status == 'PENDING_APPROVAL'`, `isShiftOpen == false` either way.

## I. Classification

```text
ShiftNotifier, ShiftState, ApiShiftService
COPY/ADAPT NEARLY EXACTLY

Variance threshold / PENDING_APPROVAL logic
BACKEND-OWNED, shared — never reimplement in either client

shift_screen.dart's layout
MOBILE UI REIMPLEMENT (logic: COPY/ADAPT NEARLY EXACTLY)
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `shift_provider.dart` fully (short file).
2. **READ** `[OLD/SOURCE]` `shift_service.dart`, confirm the 4 endpoints/request bodies.
3. **READ** `[OLD/SOURCE]` `shift_screen.dart`, confirm it only displays `currentShift.variance`, never computes.
4. **CREATE** `[NEW/MOBILE]` `shift_provider.dart`, `shift_service.dart`.
5. **CREATE** `[NEW/MOBILE]` `mobile_shift_screen.dart` using section F, branching on `currentShift?.status`, not just `isShiftOpen`.
6. Test open, close with small variance (<$10, CLOSED), close with large variance as a cashier account (PENDING_APPROVAL) — against the SAME shared backend `frontend-flutter-pos` also uses.

## K–O

Same shape as the original Day 10 — every diagram/test now entirely `mobile-flutter-pos`-internal, hitting the identical shared backend endpoints.

## What I Should Understand Before Day 11

The rule this day reinforces, true for BOTH clients equally: if a business rule has a dollar/legal consequence, the shared backend owns it — the client's job is to call the right endpoint and faithfully render the response, never to recompute or second-guess it. Day 11's idempotent sale submission leans on the exact same principle.

---

# Day 11 — Payment: The Complete Checkout Chain (deep)

This is the most important day in the whole plan. Read all of it before writing anything.

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/screens/payment_screen.dart     (_submitSaleToBackend, in full)
frontend-flutter-pos/lib/features/pos/widgets/cart_totals.dart        (Charge button, saleLines construction)
frontend-flutter-pos/lib/features/pos/services/sale_service.dart
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/services/sale_service.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_payment_screen.dart
```
(`mobile-flutter-pos`'s `mobile_cart_screen.dart`, from Day 7, is MODIFIED today to build `saleLines` and push `MobilePaymentScreen`.)

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/screens/payment_screen.dart` — find `_submitSaleToBackend()`. Read it once for shape, then come back and read section B line by line against the real file.

## B. `[OLD/SOURCE]` Function Chain — every hop, real code

**Hop 0 — how `[OLD/SOURCE] PaymentScreen` gets constructed**, in `[OLD/SOURCE] widgets/cart_totals.dart`'s Charge button:
```dart
final saleLines = cart.items.map((item) => <String, dynamic>{
  'productId': item.product.id, 'quantity': item.qty,
  if (item.note != null) 'note': item.note,
  if (item.discountAmount != null && item.discountAmount! > 0) 'lineDiscount': item.discountAmount! * item.qty,
  if (item.selectedModifiers.isNotEmpty) ...{'modifierSummary': item.modifierSummaryText, 'modifierData': item.modifierDataJson},
}).toList();
Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(
    total: cart.finalTotal, saleLines: saleLines, customerId: cart.customerId, tableId: cart.tableId,
    waitingNumber: waitingNumber, heldTicketId: cart.heldTicketId)));
```
`[NEW/MOBILE]`'s `mobile_cart_screen.dart` Charge button (Day 7's skeleton, completed today) must build the identical `saleLines` shape — this is the exact request payload the shared backend's `SaleCreateRequest.lines` expects.

**Hop 1–4** — `PaymentMethod` enum, `SplitRow`/`_rebalance()` (integer-cents split math), the stable `_clientRef = const Uuid().v4()` idempotency key (generated once, per screen instance — reused across retries), dual-currency cash tender via `_convert()`/`_changeDue` — **all identical business rules to reproduce exactly in `[NEW/MOBILE]`**; see the original Day 11 research for full exact bodies (unchanged, still accurate — reproduced faithfully here as the specification for `[NEW/MOBILE]`'s `MobilePaymentScreen`).

**Hop 5 — `[OLD/SOURCE] _submitSaleToBackend()`, the full method — the specification `[NEW/MOBILE]` must port near-verbatim:**
```dart
Future<void> _submitSaleToBackend() async {
  if (_isSubmitting) return;
  setState(() => _isSubmitting = true);
  try {
    final cartSnapshot = ref.read(cartProvider);
    final saleItems = List<CartItem>.from(cartSnapshot.items);
    final saleService = ref.read(saleServiceProvider);
    final payments = _splits.where((s) => s.status == SplitStatus.authorized)
        .map((s) => paymentRequestEntry(s, _cashReceived)).toList();
    final request = <String, dynamic>{
      'lines': widget.saleLines ?? [], 'clientRef': _clientRef,
      if (widget.customerId != null) 'customerId': widget.customerId,
      if (widget.tableId != null) 'tableId': widget.tableId,
      'orderMode': _getOrderModeFromCart(),
      if (payments.isNotEmpty) 'payments': payments,
      'taxRate': cartSnapshot.taxRate,
      if (cartSnapshot.discountAmount > 0) 'invoiceDiscount': cartSnapshot.discountAmount,
    };
    // 1. CREATE (DRAFT, no money moved, no stock deducted yet)
    final saleResponse = await saleService.createSale(request);
    final saleId = saleResponse.id;
    SaleResponse? payResponse;
    // 2. PAY — only if authorized splits exist; else the sale is created but never actually paid
    if (payments.isNotEmpty) { payResponse = await saleService.paySale(saleId, payments); }
    else { payResponse = saleResponse; }
    if (!mounted) return;
    // 3. release held ticket — fire-and-forget
    if (widget.heldTicketId != null) { unawaited(ref.read(heldTicketProvider.notifier).releaseTicketById(widget.heldTicketId!)); }
    // 4. save waiting ticket — own try/catch, non-fatal on failure
    try {
      await ref.read(waitingNumberServiceProvider).saveWaitingTicket(waitingNumber: widget.waitingNumber,
          items: saleItems, orderMode: cartSnapshot.orderMode, status: WaitingTicketStatus.paid,
          total: widget.total, orderId: saleId);
    } catch (e) { /* non-fatal warning SnackBar */ }
    // 5. clear cart — waiting number kept reserved
    await ref.read(cartProvider.notifier).clear(releaseWaitingNumber: false);
    if (mounted) setState(() { _completedSale = payResponse; _paymentState = PaymentState.completed; _isSubmitting = false; });
    // 6. fetch receipt — NOT awaited, fires in background
    unawaited(_fetchCompletedReceipt(saleId));
  } catch (e) {
    // see section N — SnackBar + Retry action re-invoking THIS SAME function with the SAME _clientRef
  }
}
```
**This 6-step sequence — including step 2's "created but unpaid" branch, step 3/6's fire-and-forget calls, and step 4's non-fatal isolation — is a business-logic specification, not a UI detail.** `[NEW/MOBILE]`'s `MobilePaymentScreen._submitSaleToBackend()` must reproduce every step, in this order, exactly.

## C. Backend/API Chain (shared, unchanged — identical for both clients)

```text
POST /api/pos/sales  {lines, clientRef, customerId?, tableId?, orderMode, payments?, taxRate, invoiceDiscount?}
↓
SaleController.create -> SaleService.create(request)  [backend, shared, unchanged]
    clientRef idempotency check FIRST — findByClientRef returns existing sale if found (retry-safe)
    DRAFT sale created, validateSaleStockAvailable (checks, does NOT deduct)
↓
POST /api/pos/sales/{id}/pay  {payments}
↓
SaleController.pay -> SaleService.pay  [backend]
    STOCK ACTUALLY DEDUCTED HERE (applyStockForSale/applyStockMovement, pessimistic row lock)
```
Because both `frontend-flutter-pos` and `mobile-flutter-pos` call the identical `POST /api/pos/sales` and `POST /api/pos/sales/{id}/pay` endpoints with the identical request shape, **the idempotency guarantee (same `clientRef` → same sale, no duplicate) works identically for both clients** — this was verified server-side once, and applies to any client sending a well-formed request, mobile included.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `services/sale_service.dart` | `createSale`, `paySale`, `getReceipt`, `refundSale` | **COPY/ADAPT NEARLY EXACTLY** |
| `screens/payment_screen.dart` | `PaymentMethod`, `SplitRow`/`_rebalance()`, `_clientRef` pattern, `_submitSaleToBackend()`'s 6-step LOGIC | **COPY/ADAPT NEARLY EXACTLY** the logic |
| `screens/payment_screen.dart` | the 2-column `Row` WIDGET TREE | **MOBILE UI REIMPLEMENT** -> `MobilePaymentScreen`'s vertical layout |
| `widgets/cart_totals.dart` | `saleLines` construction + Charge navigation | **COPY/ADAPT NEARLY EXACTLY** the logic, inside `[NEW/MOBILE]`'s `mobile_cart_screen.dart` |

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/features/pos/services/sale_service.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_payment_screen.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste. Structure only; the real `_submitSaleToBackend` logic (hop 5) must be ported close to verbatim, not reinvented.
```dart
// mobile-flutter-pos/lib/features/pos/screens/mobile_payment_screen.dart
class MobilePaymentScreen extends ConsumerStatefulWidget {
  final double total; final List<Map<String, dynamic>>? saleLines;
  final int? customerId; final int? tableId; final int waitingNumber; final int? heldTicketId;
  const MobilePaymentScreen({super.key, required this.total, this.saleLines, this.customerId,
      this.tableId, required this.waitingNumber, this.heldTicketId});
  @override
  ConsumerState<MobilePaymentScreen> createState() => _MobilePaymentScreenState();
}
class _MobilePaymentScreenState extends ConsumerState<MobilePaymentScreen> {
  final String _clientRef = const Uuid().v4();   // STEP 1: same idempotency pattern as [OLD/SOURCE]
  bool _isSubmitting = false;
  List<SplitRow> _splits = [];

  Future<void> _submitSaleToBackend() async {
    // STEP 2: port [OLD/SOURCE]'s 6-step method essentially verbatim — see section B, hop 5.
    // This is NOT a place to simplify or "clean up."
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Column(children: [
      // STEP 3: vertical layout — order summary -> method chips -> amount entry (large touch
      // keypad) -> split rows stacked (not columned) -> Complete Sale button.
      ElevatedButton(onPressed: _isSubmitting ? null : _submitSaleToBackend, child: Text(context.l10n.completeSale)),
    ]));
  }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] SaleService.createSale(Map<String, dynamic> request)`
INPUT: `{'lines': [...], 'clientRef': 'a1b2c3d4-...', 'tableId': 3, 'orderMode': 'dineIn', 'payments': [...], 'taxRate': 0.10}`
DOES: `POST /api/pos/sales` (shared backend) → idempotency check → `DRAFT` sale created → stock availability checked, not deducted
OUTPUT: `Future<SaleResponse>`
CALLER: `MobilePaymentScreen._submitSaleToBackend`, step 1
NEXT: `paySale(saleId, payments)` if payments non-empty.

## H. State Before and After

BEFORE: `mobile-flutter-pos`'s own `CartState.items = [2 items]`, `finalTotal = 5.00`.
Sequence: `createSale` → `paySale` → `cartProvider.notifier.clear(releaseWaitingNumber: false)`.
AFTER: `mobile-flutter-pos`'s `CartState = CartState.initial()`; shared backend's `Sale`/`StockItem`/`StockMovement` rows updated identically to what a `frontend-flutter-pos` checkout would produce for the same cart contents.

## I. Classification

```text
PaymentMethod, SplitRow/_rebalance, _clientRef pattern, SaleService (all methods), the
6-step _submitSaleToBackend LOGIC, saleLines construction
COPY/ADAPT NEARLY EXACTLY

payment_screen.dart's 2-column Row WIDGET TREE
MOBILE UI REIMPLEMENT
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `payment_screen.dart` fully — constructor, `PaymentMethod`, `SplitRow`/`_rebalance()`, `_clientRef`, dual-currency tender.
2. **READ** `[OLD/SOURCE]` `_submitSaleToBackend()` in full, matching against the 6 numbered steps in section B.
3. **READ** `[OLD/SOURCE]` `sale_service.dart`.
4. **CREATE** `[NEW/MOBILE]` `sale_service.dart` — copy/adapt.
5. **CREATE** `[NEW/MOBILE]` `mobile_payment_screen.dart` with the same constructor shape as `[OLD/SOURCE]`'s `PaymentScreen`.
6. Port `_submitSaleToBackend` near-verbatim — resist "cleaning it up."
7. Build the vertical layout: summary → method chips → amount entry → stacked splits.
8. **MODIFY** `[NEW/MOBILE] mobile_cart_screen.dart`'s Charge button to build `saleLines` and push `MobilePaymentScreen` (completing Day 7's stub).
9. Test a full cash sale, a split payment, and the idempotent-retry guarantee (submit, force a retry with the same `_clientRef`, confirm no duplicate sale) — against the SAME shared backend.

## K–O

Same shape as the original Day 11 (the click-flow diagrams, error-flow SnackBar/Retry pattern, test flow referencing `sale_service_idempotency_test.dart`) — every occurrence now entirely `mobile-flutter-pos`-internal, hitting the identical shared backend contract `frontend-flutter-pos` uses. `[OLD/SOURCE]`'s `frontend-flutter-pos/test/sale_service_idempotency_test.dart`/`payment_screen_test.dart` are read as references for what to test; write equivalents at `[NEW/MOBILE] mobile-flutter-pos/test/`.

## What I Should Understand Before Day 12

`getReceipt(saleId)` is fetched in the background AFTER the UI shows "completed" — identical in both projects, since it's the same `_fetchCompletedReceipt` pattern — meaning `[NEW/MOBILE]`'s receipt preview (Day 12) must handle a brief window where receipt data doesn't exist yet.

---

# Day 12 — Receipt: ReceiptViewModel to Preview, and Receipt History

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/services/printing/receipt_view_model.dart
frontend-flutter-pos/lib/features/pos/widgets/receipt_paper_view.dart
frontend-flutter-pos/lib/features/pos/providers/receipt_provider.dart      (status filters — see addendum)
frontend-flutter-pos/lib/features/pos/screens/receipts_screen.dart         (status filters — see addendum)
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/services/printing/receipt_view_model.dart
mobile-flutter-pos/lib/features/pos/widgets/receipt_paper_view.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_receipt_preview_screen.dart
mobile-flutter-pos/lib/features/pos/providers/receipt_provider.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_receipts_screen.dart
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/services/printing/receipt_view_model.dart` — read `ReceiptViewModel.fromReceiptResponse` fully, the seam between backend JSON and everything printing-related.

## B. `[OLD/SOURCE]` Function Chain

`ReceiptViewModel.fromReceiptResponse` — full body, with its fallbacks (`businessName → r.businessName ?? r.storeName ?? l10n.appName`, `invoiceNumber → r.saleNumber ?? '#${r.saleId}'`, `paymentMethodLabel` only shows the FIRST payment even for a split sale) and `containsKhmer`/`_allText` (checked once per whole document) — **must be reproduced identically in `[NEW/MOBILE]`**, since these fallback rules are business decisions, not incidental code.

`ReceiptContent` (`widgets/receipt_paper_view.dart`) — the ONE shared widget, `kReceiptContentWidth = 300` — reused for on-screen preview, PDF Khmer rasterization (Day 14), and ESC/POS Khmer rasterization (Day 14). `[NEW/MOBILE]`'s copy must remain the single shared widget across all three uses too — never fork it once written. Note for later: this widget's own font sizes are a fixed print/rasterization spec, not app UI typography — Day 14 explains in detail why Day 3's Khmer UI text-scaling work (`khmer_text_scaler.dart`) must never be applied here.

## C. Backend/API Chain (shared)

```text
GET /api/pos/sales/{id}/receipt
↓
SaleController.receipt(id) -> saleService.receipt(id)  [backend, shared, unchanged]
↓
ReceiptDtos.ReceiptResponse{businessName, storeName, saleNumber, saleId, createdAt, lines, subtotal,
    total, paidAmount, changeAmount, currency, footer, payments, ...}
```
Identical response shape reaches both clients — `[NEW/MOBILE]`'s `ReceiptResponse.fromJson` parses the same fields `[OLD/SOURCE]`'s does.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `receipt_view_model.dart` | `ReceiptViewModel.fromReceiptResponse`/`.fromCart`, `containsKhmer` | **COPY/ADAPT NEARLY EXACTLY** |
| `widgets/receipt_paper_view.dart` | `ReceiptContent`, `kReceiptContentWidth` | **COPY/ADAPT NEARLY EXACTLY** |
| `widgets/receipt_preview_screen.dart` | desktop dialog sizing | **MOBILE UI REIMPLEMENT** -> `mobile_receipt_preview_screen.dart` |

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/features/pos/services/printing/receipt_view_model.dart
mobile-flutter-pos/lib/features/pos/widgets/receipt_paper_view.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_receipt_preview_screen.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/pos/screens/mobile_receipt_preview_screen.dart
class MobileReceiptPreviewScreen extends ConsumerWidget {
  final int saleId;
  const MobileReceiptPreviewScreen({super.key, required this.saleId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(icon: const Icon(Icons.print), onPressed: () { /* Day 13/15 */ }),
        IconButton(icon: const Icon(Icons.share), onPressed: () { /* Day 13 */ }),
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.read(saleServiceProvider).getReceipt(saleId),   // mobile-flutter-pos's OWN SaleService
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final receipt = ReceiptResponse.fromJson(snapshot.data!);
          final viewModel = ReceiptViewModel.fromReceiptResponse(
              receipt, ref.read(appLanguageProvider), AppLocalizations.of(context));
          return SingleChildScrollView(child: Center(child: ReceiptContent(receipt: viewModel)));
        },
      ),
    );
  }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] ReceiptViewModel.fromReceiptResponse(ReceiptResponse r, AppLanguage language, AppLocalizations l10n)`
INPUT: the `GET /api/pos/sales/{id}/receipt` response (shared backend)
DOES: maps every field with the same fallbacks as `[OLD/SOURCE]`
OUTPUT: `ReceiptViewModel`
CALLER: `MobileReceiptPreviewScreen`, `PrintService.buildReceiptPdf` (Day 13), ESC/POS builder (Day 15)
NEXT: `ReceiptContent(receipt: viewModel)`.

## H. State Before and After

Not Riverpod-driven — `ReceiptViewModel` is a plain immutable object, identical construction pattern in both projects.

## I. Classification

```text
ReceiptViewModel, ReceiptContent, kReceiptContentWidth
COPY/ADAPT NEARLY EXACTLY

receipt_preview_screen.dart's dialog layout
MOBILE UI REIMPLEMENT
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `receipt_view_model.dart` fully.
2. **READ** `[OLD/SOURCE]` `receipt_paper_view.dart`.
3. **CREATE** `[NEW/MOBILE]` `receipt_view_model.dart`, `receipt_paper_view.dart` — copy/adapt.
4. **CREATE** `[NEW/MOBILE]` `mobile_receipt_preview_screen.dart` using section F.
5. Test with an English and a Khmer receipt against the shared backend.

## K–O

Same shape as the original Day 12 — every diagram now entirely `mobile-flutter-pos`-internal.

---

## Addendum — Receipt History: Status Filters, Refunded Family, and the New `[NEW/MOBILE]` Receipts Screen

The single-receipt `ReceiptViewModel`/`ReceiptContent` architecture above is unchanged by this addendum. This section documents `[OLD/SOURCE]`'s current receipt-history filtering logic (`receipt_provider.dart`/`receipts_screen.dart`) and its `[NEW/MOBILE]` counterpart.

### SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/providers/receipt_provider.dart
frontend-flutter-pos/lib/features/pos/screens/receipts_screen.dart
```

### NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/providers/receipt_provider.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_receipts_screen.dart
```

### Where Do I Start

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/providers/receipt_provider.dart` — read `saleMatchesStatusFilter`, `backendStatusQueryFor`, and `ReceiptState.filteredSales` together. A stale `PENDING` filter chip and dead `status == 'COMPLETED'` checks were already removed from `[OLD/SOURCE]` — never reintroduce either in `[NEW/MOBILE]`. (Unrelated to `PENDING_APPROVAL`, the real shift status from Day 10 — different domain, correct as documented there in both projects.)

### `[OLD/SOURCE]` Function Chain — exact code to reproduce

```dart
// [OLD/SOURCE] frontend-flutter-pos/lib/features/pos/providers/receipt_provider.dart
bool saleMatchesStatusFilter(String saleStatus, String filterStatus) {
  if (filterStatus == 'REFUNDED') { return saleStatus == 'REFUNDED' || saleStatus == 'PARTIALLY_REFUNDED'; }
  return saleStatus == filterStatus;
}
String? backendStatusQueryFor(String? filterStatus) => filterStatus == 'REFUNDED' ? null : filterStatus;
```
**The single most important teaching point here**: the UI's "Refunded" filter does NOT mean `status == 'REFUNDED'` — it means `status == 'REFUNDED' OR status == 'PARTIALLY_REFUNDED'`. The shared backend's `GET /api/pos/sales?status=` accepts only one literal value, so it can't express this 2-status family; `backendStatusQueryFor('REFUNDED')` returns `null` (fetch unfiltered) and `saleMatchesStatusFilter` narrows client-side. `[NEW/MOBILE]` must reproduce both functions with identical behavior — this is a real business rule tied to the shared backend's actual API shape, not a UI nicety.

`ReceiptNotifier.setStatusFilter`/`loadAllSales` are independent — `loadAllSales(status: ...)` does NOT also set `state.statusFilter` (a prior coupling bug, already fixed in `[OLD/SOURCE]`; do not reintroduce it in `[NEW/MOBILE]`).

### Backend/API Chain (shared)

```text
GET /api/pos/sales?status=PAID   (or VOID, or omitted for All/Refunded)
↓
SaleController's list-sales endpoint  [backend, shared, unchanged]
↓
List<SaleResponse>{status: PAID|VOID|REFUNDED|PARTIALLY_REFUNDED|CREDIT|DRAFT|HOLD}
```

### `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `providers/receipt_provider.dart` | `saleMatchesStatusFilter`, `backendStatusQueryFor`, `ReceiptState.filteredSales`, `ReceiptNotifier` (all methods) | **COPY/ADAPT NEARLY EXACTLY** — including the independence of `setStatusFilter`/`loadAllSales` |
| `screens/receipts_screen.dart` | status-action rules (below), status labels/colors/icons | **COPY/ADAPT NEARLY EXACTLY** the rules, **MOBILE UI REIMPLEMENT** the split-pane layout |

### Status Action Rules — Do Not Invent Transitions (reproduce exactly in `[NEW/MOBILE]`)

```text
PAID  -> Print, Save PDF, Email, Refund (when allowed)
VOID  -> Print, Save PDF, Email — NO Pay, NO Refund — VOID is TERMINAL, no VOID -> PAID transition exists
REFUNDED -> Print, Save PDF, Email (no further refund — already fully refunded)
PARTIALLY_REFUNDED -> Print, Save PDF, Email, Refund (further refund IS permitted, same as PAID)
```
`DRAFT`/`HOLD` belong to Open Tickets (Day 9) and checkout (Day 11) — not to the Receipts screen's action menu, in either project.

### Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/pos/screens/mobile_receipts_screen.dart
class MobileReceiptsScreen extends ConsumerWidget {
  const MobileReceiptsScreen({super.key});
  static const _statusFilters = [null, 'PAID', 'VOID', 'REFUNDED'];   // SAME set as [OLD/SOURCE] — no PENDING
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptProvider);   // mobile-flutter-pos's OWN receiptProvider
    return Scaffold(body: Column(children: [
      Row(children: [for (final f in _statusFilters) FilterChip(
        label: Text(f ?? context.l10n.commonAll), selected: state.statusFilter == f,
        onSelected: (_) {
          ref.read(receiptProvider.notifier).setStatusFilter(f);
          ref.read(receiptProvider.notifier).loadAllSales(status: backendStatusQueryFor(f));
        },
      )]),
      Expanded(child: ListView(children: [
        for (final sale in state.filteredSales)   // ALWAYS filteredSales, never state.sales directly
          ListTile(title: Text(sale.invoiceNumber ?? '#${sale.id}'), trailing: Text(sale.status),
              onTap: () => ref.read(receiptProvider.notifier).loadReceipt(sale.id)),
      ])),
    ]));
  }
}
```

### Function Inputs and Outputs

`[NEW/MOBILE] backendStatusQueryFor(String? filterStatus)`
INPUT: `'REFUNDED'`
DOES: pure function, no state, identical to `[OLD/SOURCE]`
OUTPUT: `null` (backend can't express the 2-status family)
CALLER: any `loadAllSales` call site
NEXT: `loadAllSales(status: null)` fetches unfiltered; `saleMatchesStatusFilter` narrows client-side.

### Classification

```text
saleMatchesStatusFilter, backendStatusQueryFor, ReceiptState/ReceiptNotifier (all)
COPY/ADAPT NEARLY EXACTLY

receipts_screen.dart's split-pane layout
MOBILE UI REIMPLEMENT
```

### Test Flow

`[OLD/SOURCE]`'s `frontend-flutter-pos/test/receipt_status_filter_test.dart` and `receipts_screen_filter_test.dart` are read as references for exact scenarios to cover (the REFUNDED-family regression, the no-PENDING-chip regression, the `setStatusFilter`/`loadAllSales`-independence regression) — write equivalents at `[NEW/MOBILE] mobile-flutter-pos/test/receipt_status_filter_test.dart` and `mobile-flutter-pos/test/receipts_screen_filter_test.dart`.

## What I Should Understand Before Day 13

`kReceiptContentWidth = 300` and the fact that `ReceiptContent` is deliberately the SAME widget instance type used for on-screen display, PDF rasterization, and ESC/POS rasterization in `[OLD/SOURCE]` — `[NEW/MOBILE]`'s copy must preserve this single-widget property too, since Day 14's entire Khmer strategy depends on it. Separately: `ReceiptState`/`ReceiptNotifier` (a list of past sales, with filters) is a completely different concern from `ReceiptViewModel` (one sale's printable content) — don't conflate them in either project.

---

# Day 13 — PDF Printing: Print Button to PDF Bytes to OS Dialog

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/services/print_service.dart
frontend-flutter-pos/lib/features/pos/services/printing/printer_pdf_format.dart
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/services/print_service.dart
mobile-flutter-pos/lib/features/pos/services/printing/printer_pdf_format.dart
mobile-flutter-pos/pubspec.yaml    (add pdf, printing packages)
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/services/print_service.dart` — read `printReceipt` first, then `buildReceiptPdf`.

## B. `[OLD/SOURCE]` Function Chain

```dart
Future<bool> printReceipt(BuildContext context, int saleId) async {
  try {
    final receiptJson = await _api.get<Map<String, dynamic>>('/api/pos/sales/$saleId/receipt');
    final viewModel = ReceiptViewModel.fromReceiptResponse(ReceiptResponse.fromJson(receiptJson),
        _ref.read(appLanguageProvider), AppLocalizations.of(context));
    final config = await _ref.read(thermalPrinterServiceProvider).loadConfig();
    if (config.transportType == PrinterTransportType.pdfDriver) {
      final pdfBytes = await buildReceiptPdf(viewModel, config.paperSize, context: context);
      await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'receipt_$saleId');
    } else { await _ref.read(thermalPrinterServiceProvider).printReceipt(context, viewModel, config); }
    return true;
  } catch (e) { return false; }
}
Future<Uint8List> buildReceiptPdf(ReceiptViewModel r, PrinterPaperSize paperSize, {BuildContext? context}) async {
  final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());
  final content = await _pageContent(context, r, paperSize);   // Khmer-vs-Latin branch, Day 14
  doc.addPage(pw.Page(pageFormat: paperSize.pdfPageFormat, build: (_) => content));
  return doc.save();
}
```

## C. Backend/API Chain (shared)

Same `GET /api/pos/sales/{id}/receipt` as Day 12 — `[NEW/MOBILE]`'s `PrintService` fetches independently, exactly as `[OLD/SOURCE]`'s does.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `print_service.dart` | `printReceipt`, `buildReceiptPdf`, `_pageContent` | **COPY/ADAPT NEARLY EXACTLY** — this pipeline is already cross-platform, confirmed zero platform-conditional code |
| `printer_pdf_format.dart` | mm58/mm80 → `PdfPageFormat` mapping | **COPY/ADAPT NEARLY EXACTLY** |
| `package:printing`'s `Printing.layoutPdf`/`sharePdf` | — | **COPY/ADAPT NEARLY EXACTLY** — add the SAME `pdf`/`printing` package versions to `mobile-flutter-pos/pubspec.yaml`; the package itself already handles Android/iOS/web differences internally |

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/features/pos/services/print_service.dart
mobile-flutter-pos/lib/features/pos/services/printing/printer_pdf_format.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste (fills in Day 12's two stubbed `IconButton`s in `MobileReceiptPreviewScreen`).
```dart
IconButton(icon: const Icon(Icons.print), onPressed: () async {
  final success = await ref.read(printServiceProvider).printReceipt(context, saleId);   // mobile-flutter-pos's OWN
  if (!success && context.mounted) { /* SnackBar */ }
}),
IconButton(icon: const Icon(Icons.share), onPressed: () async {
  final bytes = await ref.read(printServiceProvider).buildReceiptPdf(viewModel, config.paperSize, context: context);
  await Printing.sharePdf(bytes: bytes, filename: '${viewModel.invoiceNumber}.pdf');
}),
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] PrintService.buildReceiptPdf(ReceiptViewModel r, PrinterPaperSize paperSize, {BuildContext? context})` — identical signature/behavior to `[OLD/SOURCE]`; see Day 12/14 for `ReceiptViewModel` and the Khmer branch.

## H. State Before and After

Not Riverpod state — pure function producing bytes each call.

## I. Classification

```text
PrintService (all methods), printer_pdf_format.dart, Printing.layoutPdf/sharePdf usage
COPY/ADAPT NEARLY EXACTLY
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `print_service.dart`, `printer_pdf_format.dart` fully.
2. Add `pdf`/`printing` (same versions) to `[NEW/MOBILE] mobile-flutter-pos/pubspec.yaml`.
3. **CREATE** `[NEW/MOBILE]` `print_service.dart`, `printer_pdf_format.dart` — copy/adapt.
4. Wire Day 12's print/share buttons.
5. Test print and share, English and Khmer receipts, on Android and iOS.

## K–O

Same shape as the original Day 13 — this day required ZERO platform-specific logic in `[OLD/SOURCE]`, and requires none in `[NEW/MOBILE]` either; if you find yourself writing a platform `if` today, something's been misunderstood.

## What I Should Understand Before Day 14

Today required no changes beyond copy-adapt — contrast with Day 16, where genuinely new platform permission code is needed. One more thing to hold onto going into Day 14: `buildReceiptPdf`'s font sizes come entirely from `KhmerPdfFont`/`ReceiptContent`'s own `package:pdf` spec — none of it flows through `MaterialApp`/`Theme`/`MediaQuery`, so nothing Day 3 does to app UI typography (`khmer_text_scaler.dart`) can reach this pipeline even indirectly. Day 14 covers exactly why.

---

# Day 14 — Khmer Rendering: The Exact Branch, Old → New

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/services/printing/khmer_pdf_font.dart
frontend-flutter-pos/lib/features/pos/services/printing/receipt_bitmap_renderer.dart
frontend-flutter-pos/lib/features/pos/services/printing/escpos_receipt_builder.dart
frontend-flutter-pos/lib/core/utils/khmer_text.dart
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/services/printing/khmer_pdf_font.dart
mobile-flutter-pos/lib/features/pos/services/printing/receipt_bitmap_renderer.dart
mobile-flutter-pos/lib/features/pos/services/printing/escpos_receipt_builder.dart
mobile-flutter-pos/lib/core/utils/khmer_text.dart
mobile-flutter-pos/assets/fonts/NotoSans-Regular.ttf, NotoSans-Bold.ttf,
    NotoSansKhmer-Regular.ttf, NotoSansKhmer-Bold.ttf     (font asset files, copied)
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/services/printing/escpos_receipt_builder.dart` — find the one `if (receipt.containsKhmer)` branch inside `build()`.

**STOP — before touching anything below, understand this boundary: "Khmer Rendering" in this day's title means print-output glyph handling, and has NOTHING to do with Day 3's UI text-scaling work.** Day 3 covered `khmer_text_scaler.dart` — a `TextScaler` that bumps Khmer UI text size (+2px small text, +3px titles, +0 very-large-display) inside `MaterialApp`'s widget tree, via `MediaQuery`/`MaterialApp.builder`. This day's `ReceiptContent`, `khmer_pdf_font.dart`, `receipt_bitmap_renderer.dart`, and `escpos_receipt_builder.dart` (and Day 13's `receipt_layout_spec.dart`/thermal 58mm/80mm font sizes, and Day 18's `A4ReportPdf` typography) render through an entirely separate `package:pdf` `pw.*` widget system that shares ZERO code paths with `MaterialApp`/`Theme`/`MediaQuery` — this was independently verified by two research passes before the Day 3 feature shipped. **`[NEW/MOBILE]` must NOT apply the Day 3 `khmerAwareTextScaler`/`KhmerTextScaler` bump — or any variant of it — to any font size in this pipeline.** Every font size in `ReceiptContent`, the PDF path, and the ESC/POS path must stay exactly as `[OLD/SOURCE]` defines them, byte-for-byte, regardless of which language is selected in the app's UI or what Khmer UI-scaling work `[NEW/MOBILE]` has done elsewhere. If a future change to this pipeline's font sizes is ever wanted, it must be a deliberate, separate decision made here — never an automatic side effect of Day 3's UI scaler.

## B. `[OLD/SOURCE]` Function Chain — both branches, exact code (reproduce identically)

```dart
// khmer_pdf_font.dart — Khmer is fontFallback ONLY, never primary (the bundled Khmer font
// has zero Latin/digit glyphs — using it as primary breaks all-English documents)
static Future<pw.ThemeData> loadTheme() async {
  _latinRegular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  // ... 3 more, loaded SEQUENTIALLY not Future.wait (documented flaky-test-mock reason)
  return pw.ThemeData.withFont(base: _latinRegular!, bold: _latinBold!, fontFallback: [_khmerRegular!, _khmerBold!]);
}
// receipt_bitmap_renderer.dart — off-screen mount-and-rasterize
Future<img.Image> renderImage(BuildContext context, ReceiptViewModel receipt, PrinterPaperSize paperSize) async {
  const logicalWidth = kReceiptContentWidth;           // = 300, from Day 12
  final pixelRatio = paperSize.dotWidth / logicalWidth; // 384/300 or 576/300
  // OverlayEntry at left: -100000 (off-screen but still lays out/paints), mounts the SAME
  // ReceiptContent widget the preview uses, waits 2x endOfFrame, RenderRepaintBoundary.toImage(pixelRatio:...)
}
// escpos_receipt_builder.dart
if (receipt.containsKhmer) {
  final image = await bitmapRenderer.render(context, receipt, paperSize);   // + Floyd-Steinberg dither
  bytes += generator.imageRaster(image, align: PosAlign.center);
} else { bytes += _buildLatinText(generator, receipt); }   // native ESC/POS text commands
```
`core/utils/khmer_text.dart::containsKhmerText` is the single source of truth for Khmer detection, used by `ReceiptViewModel.containsKhmer` (Day 12).

## C. Backend/API Chain

None new — pure rendering logic on top of `ReceiptViewModel` (Day 12).

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `khmer_pdf_font.dart`, `receipt_bitmap_renderer.dart`, `escpos_receipt_builder.dart`, `khmer_text.dart` | all | **COPY/ADAPT NEARLY EXACTLY** — confirmed zero platform-conditional code anywhere in this pipeline; the ENTIRE Khmer strategy is pure Dart/Flutter |
| `assets/fonts/*.ttf` | font files | copy the actual `.ttf` asset files into `[NEW/MOBILE] mobile-flutter-pos/assets/fonts/`, register in `mobile-flutter-pos/pubspec.yaml`'s `fonts:` block, same family names |

## E. Exact `[NEW/MOBILE]` Files to Create

Listed above.

## F. Exact `[NEW/MOBILE]` Function Skeleton

No new skeleton today — every function is **COPY/ADAPT NEARLY EXACTLY**; write `[NEW/MOBILE]` versions matching `[OLD/SOURCE]`'s bodies line for line.

## G. Function Inputs and Outputs

Unchanged from `[OLD/SOURCE]` — see section B; `[NEW/MOBILE]`'s `ReceiptBitmapRenderer.renderImage` takes the same `(BuildContext, ReceiptViewModel, PrinterPaperSize)` and returns the same `Future<img.Image>`.

## H. State Before and After

Not Riverpod state — pure rendering pipeline, invoked fresh each call, identical in both projects.

## I. Classification

```text
KhmerPdfFont, ReceiptBitmapRenderer, EscPosReceiptBuilder, containsKhmerText
COPY/ADAPT NEARLY EXACTLY (entire pipeline)
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `escpos_receipt_builder.dart`'s branch, `receipt_bitmap_renderer.dart`, `khmer_pdf_font.dart` fully.
2. Copy the 4 `.ttf` font files from `frontend-flutter-pos/assets/fonts/` into `[NEW/MOBILE] mobile-flutter-pos/assets/fonts/`, register them in `mobile-flutter-pos/pubspec.yaml`.
3. **CREATE** `[NEW/MOBILE]` `khmer_pdf_font.dart`, `receipt_bitmap_renderer.dart`, `escpos_receipt_builder.dart`, `khmer_text.dart` — copy/adapt line for line.
4. Generate English, Khmer, and mixed receipt PDFs on Android and iOS, visually inspect for correct subscript/vowel positioning.
5. Confirm PDF generation timing (native zlib on both mobile platforms, same as `[OLD/SOURCE]` observes).

## K–O

Same shape as the original Day 14 — every diagram now entirely within `mobile-flutter-pos`.

## What I Should Understand Before Day 15

The distinction between this day's whole-document rasterization strategy (`ReceiptBitmapRenderer`) and Day 18's per-string strategy (`KhmerTextRasterizer`, for reports) — both real, both correct, solving the same underlying `package:pdf`-can't-shape-Khmer problem for two different document shapes, in BOTH projects identically.

---

# Day 15 — Network Printer: The Full ESC/POS Transport Chain

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/services/printing/thermal_printer_service.dart
frontend-flutter-pos/lib/features/pos/services/printing/network_printer_transport.dart
frontend-flutter-pos/lib/features/pos/services/printing/printer_transport.dart
frontend-flutter-pos/ios/Runner/Info.plist            (READ for reference only — do not modify)
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/services/printing/thermal_printer_service.dart
mobile-flutter-pos/lib/features/pos/services/printing/network_printer_transport.dart
mobile-flutter-pos/lib/features/pos/services/printing/printer_transport.dart
mobile-flutter-pos/ios/Runner/Info.plist                (NSLocalNetworkUsageDescription — NEW key)
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/services/printing/thermal_printer_service.dart` — read `_transportFor()`, the one `switch` that picks a concrete transport class.

## B. `[OLD/SOURCE]` Function Chain

```dart
PrinterTransport _transportFor(PrinterConfig config) {
  switch (config.transportType) {
    case PrinterTransportType.network:
      final host = config.networkHost;
      if (host == null || host.isEmpty) throw StateError('No printer IP address configured');
      return NetworkPrinterTransport(host, port: config.networkPort);
    // bluetooth/usb cases -> Day 16; pdfDriver -> throws, handled by PrintService instead
  }
}
Future<void> printReceipt(BuildContext context, ReceiptViewModel receipt, PrinterConfig config) async {
  final transport = _transportFor(config);
  await transport.connect();      // OUTSIDE the try — a connect failure skips disconnect (nothing to disconnect)
  try {
    final bytes = await builder.build(context, receipt, config.paperSize);
    await transport.write(bytes);
  } finally { await transport.disconnect(); }
}
```
`[OLD/SOURCE] NetworkPrinterTransport` — the ENTIRE file:
```dart
class NetworkPrinterTransport implements PrinterTransport {
  NetworkPrinterTransport(this.host, {this.port = 9100});
  Socket? _socket;
  @override Future<void> connect() async { _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5)); }
  @override Future<void> write(List<int> bytes) async { _socket!.add(bytes); await _socket!.flush(); }
  @override Future<void> disconnect() async { await _socket?.close(); _socket = null; }
}
```
Port `9100` is the universal raw-print port most thermal printers listen on — no driver needed. This code is 100% platform-portable `dart:io` — **reproduce it in `[NEW/MOBILE]` unchanged.**

## C. Backend/API Chain

None — direct device-to-device TCP, bypassing the shared backend entirely (the `ReceiptViewModel` data driving what gets printed still came from the backend in Day 12, but the print mechanism itself is peer-to-peer).

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `printer_transport.dart` | `PrinterTransport` interface | **COPY/ADAPT NEARLY EXACTLY** |
| `thermal_printer_service.dart` | `ThermalPrinterService` (all methods) | **COPY/ADAPT NEARLY EXACTLY** |
| `network_printer_transport.dart` | `NetworkPrinterTransport` (all methods) | **COPY/ADAPT NEARLY EXACTLY** — zero platform changes needed, and this transport actually works BETTER on mobile than on web (web's `Socket` throws `UnsupportedError` at runtime; Android/iOS both support `dart:io Socket` natively) |

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/features/pos/services/printing/printer_transport.dart
mobile-flutter-pos/lib/features/pos/services/printing/thermal_printer_service.dart
mobile-flutter-pos/lib/features/pos/services/printing/network_printer_transport.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

No skeleton needed — every function is **COPY/ADAPT NEARLY EXACTLY**; write `[NEW/MOBILE]` versions matching `[OLD/SOURCE]`'s bodies verbatim (shown in full in section B).

## G. Function Inputs and Outputs

`[NEW/MOBILE] NetworkPrinterTransport.connect()` — identical to `[OLD/SOURCE]`; INPUT: constructor's `host`/`port`; DOES: `Socket.connect(host, port, timeout: 5s)`; OUTPUT: `Future<void>` (throws on failure).

## H. State Before and After

Not Riverpod state — transient `Socket` connection, opened/closed within a single `printReceipt` call, identical pattern in both projects.

## I. Classification

```text
PrinterTransport, ThermalPrinterService, NetworkPrinterTransport
COPY/ADAPT NEARLY EXACTLY — confirmed zero platform-conditional code needed
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `printer_transport.dart`, `thermal_printer_service.dart`, `network_printer_transport.dart` — all short files.
2. Add the NEW iOS permission (confirmed absent from `[OLD/SOURCE]` too, so this is new for BOTH projects, not something to "copy" — add independently to `[NEW/MOBILE] mobile-flutter-pos/ios/Runner/Info.plist`):
   ```xml
   <key>NSLocalNetworkUsageDescription</key>
   <string>Used to connect to your receipt printer on the local network.</string>
   ```
3. **CREATE** `[NEW/MOBILE]` `printer_transport.dart`, `thermal_printer_service.dart`, `network_printer_transport.dart` — copy/adapt verbatim.
4. Test against a real network printer, or simulate with `nc -l 9100` on your dev machine.
5. Test the iOS local-network permission prompt, both Allow and Deny paths.

## K–O

Same shape as the original Day 15 — every diagram now entirely `mobile-flutter-pos`-internal.

## What I Should Understand Before Day 16

Why this transport needed zero Dart changes while Day 16's USB/Bluetooth need real new permission code — entirely about what the OS gates behind a runtime permission prompt.

---

# Day 16 — USB / Bluetooth Printers: Old Code, New Permission Layer

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/services/printing/bluetooth_printer_transport.dart
frontend-flutter-pos/lib/features/pos/services/printing/usb_printer_transport.dart
frontend-flutter-pos/android/app/src/main/AndroidManifest.xml    (READ for reference only — confirm no Bluetooth perms exist there yet either)
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/services/printing/bluetooth_printer_transport.dart
mobile-flutter-pos/lib/features/pos/services/printing/usb_printer_transport.dart
mobile-flutter-pos/lib/features/pos/services/printing/printer_permission.dart    (genuinely new)
mobile-flutter-pos/android/app/src/main/AndroidManifest.xml       (BLUETOOTH_CONNECT/SCAN — NEW)
mobile-flutter-pos/ios/Runner/Info.plist                          (NSBluetoothAlwaysUsageDescription — NEW)
mobile-flutter-pos/pubspec.yaml                                    (add permission_handler)
```

## A. Where Do I Start?

Open `[OLD/SOURCE — READ]` `bluetooth_printer_transport.dart` and `usb_printer_transport.dart` side by side — both implement the same `PrinterTransport` interface from Day 15.

## B. `[OLD/SOURCE]` Function Chain

Both transport classes are already complete and correct in `[OLD/SOURCE]` — `PrintBluetoothThermal.connect(macPrinterAddress:)`/`.writeBytes()`/`.disconnect` (static getter, not a method — no `()`), and `PrinterManager.instance.connect(type: PrinterType.usb, ...)`/`.send()`/`.disconnect()`/`.discovery()`. **This is exactly where "shared logic ends and platform-specific code begins": the class boundary itself** — nothing above `PrinterTransport` needs to know these classes exist.

**Confirmed by direct grep of `[OLD/SOURCE]`**: `permission_handler` (a declared dependency) is imported **nowhere** in `frontend-flutter-pos/lib/`. Neither transport class, nor any settings screen, requests a runtime permission before calling `connect()`. **This means there is no existing pattern in EITHER project to copy for permission-handling — `[NEW/MOBILE]` must design this fresh**, following the transport interface's existing shape.

## C. Backend/API Chain

None — device-to-device, same as Day 15.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `bluetooth_printer_transport.dart`, `usb_printer_transport.dart` | `connect`/`write`/`disconnect`/discovery methods | **PLATFORM IMPLEMENTATION** — the code IS portable and correct, but has never been exercised without permission-handling in front of it in `[OLD/SOURCE]` either |
| — (nothing in `[OLD/SOURCE]` to copy) | permission-request flow | genuinely **NEW** in `[NEW/MOBILE]` — designed fresh, not adapted from anything |

## E. Exact `[NEW/MOBILE]` Files to Create

```text
mobile-flutter-pos/lib/features/pos/services/printing/bluetooth_printer_transport.dart
mobile-flutter-pos/lib/features/pos/services/printing/usb_printer_transport.dart
mobile-flutter-pos/lib/features/pos/services/printing/printer_permission.dart
```

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste. This is genuinely new logic in BOTH projects.
```dart
// mobile-flutter-pos/lib/features/pos/services/printing/printer_permission.dart — NEW FILE,
// no [OLD/SOURCE] equivalent exists.
Future<bool> ensurePrinterPermission(PrinterTransportType type) async {
  if (type == PrinterTransportType.bluetooth) {
    final status = await Permission.bluetoothConnect.request();   // permission_handler package
    return status.isGranted;
  }
  if (type == PrinterTransportType.usb) { return true; /* see AndroidManifest/plugin docs */ }
  return true;
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] BluetoothPrinterTransport.connect()` — identical signature/body to `[OLD/SOURCE]`; the new work is calling `ensurePrinterPermission` BEFORE this, from `ThermalPrinterService.printReceipt`'s call site or Settings' device-picker (Day 19).

## H. State Before and After

Not Riverpod state — transient connection, same as Day 15, with a new permission-check gate in front of it in `[NEW/MOBILE]` only.

## I. Classification

```text
BluetoothPrinterTransport, UsbPrinterTransport (connect/write/disconnect bodies)
PLATFORM IMPLEMENTATION — code portable, needs a new caller

permission_handler request flow
genuinely NEW — does not exist in [OLD/SOURCE] to adapt from
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` both transport files fully.
2. Confirm via `grep -rn "permission_handler" frontend-flutter-pos/lib/` that it's truly unused there too.
3. Add `permission_handler` to `[NEW/MOBILE] mobile-flutter-pos/pubspec.yaml`.
4. Add NEW Android manifest permissions to `[NEW/MOBILE] mobile-flutter-pos/android/app/src/main/AndroidManifest.xml`: `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`.
5. Add NEW iOS key to `[NEW/MOBILE] mobile-flutter-pos/ios/Runner/Info.plist`: `NSBluetoothAlwaysUsageDescription`.
6. **CREATE** `[NEW/MOBILE]` `bluetooth_printer_transport.dart`, `usb_printer_transport.dart` — copy/adapt.
7. **CREATE** `[NEW/MOBILE]` `printer_permission.dart` using section F's skeleton, wire it in front of every `connect()` call path.
8. Test Bluetooth/USB against real hardware on Android; attempt USB on iOS and document the actual result (MFi certification may block it — a genuine open question, not assumed either way).

## K–O

Same shape as the original Day 16 — every diagram now entirely `mobile-flutter-pos`-internal.

## What I Should Understand Before Day 17

You've now seen the full spectrum of printing portability, identical for both projects since both study the same `[OLD/SOURCE]` code: PDF (zero changes), Network (zero Dart changes, mobile easier than web), Bluetooth/USB (code portable, permission-flow genuinely new in both, iOS USB genuinely uncertain).

---

# Day 17 — Inventory: Every Entity, One Pattern, Two Projects

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/inventory/providers/inventory_provider.dart
frontend-flutter-pos/lib/features/inventory/providers/production_provider.dart
frontend-flutter-pos/lib/features/inventory/services/inventory_service.dart
frontend-flutter-pos/lib/features/inventory/services/production_service.dart
frontend-flutter-pos/lib/features/inventory/models/inventory_models.dart
frontend-flutter-pos/lib/features/inventory/models/production_models.dart
frontend-flutter-pos/lib/features/inventory/screens/create_purchase_order.dart
frontend-flutter-pos/lib/features/inventory/screens/purchase_orders_screen.dart
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/inventory/providers/inventory_provider.dart
mobile-flutter-pos/lib/features/inventory/providers/production_provider.dart
mobile-flutter-pos/lib/features/inventory/services/inventory_service.dart
mobile-flutter-pos/lib/features/inventory/services/production_service.dart
mobile-flutter-pos/lib/features/inventory/models/inventory_models.dart
mobile-flutter-pos/lib/features/inventory/models/production_models.dart
mobile-flutter-pos/lib/features/inventory/screens/mobile_purchase_orders_screen.dart
mobile-flutter-pos/lib/features/inventory/screens/mobile_create_purchase_order_screen.dart
mobile-flutter-pos/lib/features/inventory/screens/mobile_stock_adjustments_screen.dart
mobile-flutter-pos/lib/features/inventory/screens/mobile_inventory_hub_screen.dart
# ... one pair (list + form) per remaining entity, same pattern
mobile-flutter-pos/lib/features/pos/widgets/mobile_status_action_sheet.dart
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/inventory/providers/inventory_provider.dart` — find `PurchaseOrdersNotifier`, the richest workflow (real status transitions); master it first, every other entity is a smaller variant.

## B. `[OLD/SOURCE]` Function Chain — Purchase Order, the deepest example

```dart
Future<void> loadOrders() async { /* try/catch -> AsyncValue.data or .error */ }
Future<void> createOrder(PurchaseOrder order) async { await _service.createPurchaseOrder(order); await loadOrders(); }
Future<void> transition(int id, String action) async { await _service.transitionPurchaseOrder(id, action); await loadOrders(); }
```
`ApiInventoryService.transitionPurchaseOrder(id, action)` -> `POST /api/purchase-orders/$id/$action` (literal string interpolation). `purchase_orders_screen.dart::_actionsFor(status)` (a business rule, reproduce exactly):
```dart
List<String> _actionsFor(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT': return ['submit', 'cancel'];
    case 'SUBMITTED': return ['approve', 'send', 'cancel'];
    case 'APPROVED': return ['send', 'cancel'];
    case 'RECEIVED': case 'PARTIALLY_RECEIVED': return ['send', 'close'];
    default: return [];
  }
}
```
**A discrepancy flagged in `[OLD/SOURCE]`'s own research, still true today, applies equally to `[NEW/MOBILE]`**: the Flutter `PurchaseOrder` model defaults `status = 'DRAFT'` locally, but the shared backend's `createPurchaseOrder` was observed setting `status = 'SUBMITTED'` directly on creation. Verify against a running shared backend before building `[NEW/MOBILE]` UI that assumes `DRAFT` is reachable post-creation — do not silently pick one behavior.

## C. Backend/API Chain (shared, unchanged)

```text
POST /api/purchase-orders/{id}/{action}
↓
PurchaseOrderController.transition -> PurchasingWorkflowService.transitionPurchaseOrder(id, action)
  [backend, shared, unchanged — identical for both clients]
```

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]` — every inventory entity

| Entity | `[OLD/SOURCE]` Provider | `[NEW/MOBILE]` action |
|---|---|---|
| Stock lookup (read-only) | uses `productsProvider` | **COPY/ADAPT NEARLY EXACTLY** the read pattern |
| Stock adjustments | `movementsProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| Inventory counts | `inventoryCountProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| Suppliers | `suppliersProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| Purchase orders | `purchaseOrdersProvider` | **COPY/ADAPT NEARLY EXACTLY** (including `_actionsFor`) |
| Transfer orders | `transferOrdersProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| Valuation/History (read-only) | `inventoryValuationProvider`/`movementsProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| Recipes | `recipesProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| Production orders | `productionOrdersProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| All desktop list/form screens | `inventory_hub_screen.dart`, `purchase_orders_screen.dart`, etc. | **MOBILE UI REIMPLEMENT** — logic: **COPY/ADAPT NEARLY EXACTLY** |

## E. Exact `[NEW/MOBILE]` Files to Create

Listed above — reuse `mobile_status_action_sheet.dart` (from Day 16) for every status-transition action across Purchase/Transfer/Production orders.

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste (Purchase Orders shown; every other entity follows the same shape).
```dart
// mobile-flutter-pos/lib/features/inventory/screens/mobile_purchase_orders_screen.dart
class MobilePurchaseOrdersScreen extends ConsumerWidget {
  const MobilePurchaseOrdersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(purchaseOrdersProvider);   // mobile-flutter-pos's OWN provider
    return Scaffold(body: orders.when(
      data: (list) => ListView(children: [for (final order in list) ListTile(
        title: Text(order.referenceNumber ?? '#${order.id}'), subtitle: Text(order.status),
        trailing: PopupMenuButton<String>(
          itemBuilder: (_) => [for (final a in _actionsFor(order.status)) PopupMenuItem(value: a, child: Text(a))],
          onSelected: (action) async {
            if (action == 'cancel') { /* confirm dialog */ }
            await ref.read(purchaseOrdersProvider.notifier).transition(order.id!, action);
          },
        ),
      )]),
      loading: () => const CircularProgressIndicator(), error: (e, _) => Text('$e'),
    ));
  }
  // Copy VERBATIM from [OLD/SOURCE]'s purchase_orders_screen.dart — it IS the business rule.
  List<String> _actionsFor(String status) { /* same switch as section B */ return []; }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] PurchaseOrdersNotifier.transition(int id, String action)` — identical to `[OLD/SOURCE]`; `POST /api/purchase-orders/{id}/{action}` on the shared backend, `await loadOrders()` refreshes the full list.

## H. State Before and After

Same shape as `[OLD/SOURCE]` — `mobile-flutter-pos`'s own `purchaseOrdersProvider` list refetches after every mutation.

## I. Classification

```text
Every *Notifier class (inventory_provider.dart, production_provider.dart)
COPY/ADAPT NEARLY EXACTLY

_actionsFor(status) switch statements
COPY/ADAPT NEARLY EXACTLY — copy verbatim, this encodes real backend-enforced workflow rules

Desktop list/form screen layouts
MOBILE UI REIMPLEMENT
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `inventory_provider.dart` fully (`PurchaseOrdersNotifier` first).
2. **READ** `[OLD/SOURCE]` `inventory_service.dart`, confirm exact endpoint strings.
3. **READ** `[OLD/SOURCE]` `create_purchase_order.dart`, `purchase_orders_screen.dart`.
4. **CREATE** `[NEW/MOBILE]` `inventory_models.dart`, `production_models.dart`, `inventory_provider.dart`, `production_provider.dart`, `inventory_service.dart`, `production_service.dart` — copy/adapt.
5. **CREATE** `[NEW/MOBILE]` `mobile_purchase_orders_screen.dart`, `mobile_create_purchase_order_screen.dart` using section F.
6. Repeat the same list+form pattern for the remaining 8 entities.
7. Before writing "submit from DRAFT" UI, verify against a running shared backend whether new orders actually land in `DRAFT` or `SUBMITTED` (section B's flagged discrepancy) — do not guess in either project.

## K–O

Same shape as the original Day 17 — every diagram now entirely `mobile-flutter-pos`-internal, hitting the identical shared backend contract.

## What I Should Understand Before Day 18

Every inventory workflow entity follows one repeated shape (notifier method → service → shared endpoint → reload list) in BOTH projects — and the one piece of business logic deliberately duplicated client-side in each (`_actionsFor`-style status→actions mappings) is necessary for UX responsiveness, since the shared backend re-validates every transition regardless of what either client's menu offered.

---

# Day 18 — Reports & Invoice PDF: Filter to Full-Dataset PDF

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/reports/services/report_service.dart
frontend-flutter-pos/lib/core/services/printing/a4_report_pdf.dart
frontend-flutter-pos/lib/features/reports/widgets/report_charts.dart
frontend-flutter-pos/lib/features/reports/screens/sales_by_item_screen.dart
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/reports/services/report_service.dart
mobile-flutter-pos/lib/core/services/printing/a4_report_pdf.dart
mobile-flutter-pos/lib/features/reports/widgets/report_charts.dart
mobile-flutter-pos/lib/features/pos/screens/mobile_reports_hub_screen.dart
mobile-flutter-pos/lib/features/reports/screens/mobile_sales_by_item_screen.dart
# ... one per remaining report type, same pattern
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/reports/services/report_service.dart` — find `fetchAllPages<T>`.

## B. `[OLD/SOURCE]` Function Chain

```dart
const reportPrintPageSize = 200;
Future<List<T>> fetchAllPages<T>({required Future<(List<T> rows, PageMeta meta)> Function(int page) fetchPage}) async {
  final all = <T>[]; var page = 0;
  while (true) {
    final (rows, meta) = await fetchPage(page);
    all.addAll(rows);
    if (rows.isEmpty || page + 1 >= meta.totalPages) break;
    page++;
  }
  return all;
}
```
What's shown on screen (paginated, ~20 rows) and what goes in an exported PDF (complete dataset, walked at `size: 200`) are DELIBERATELY different — **this decoupling must be reproduced identically in `[NEW/MOBILE]`**, never skipped "to keep it simple," or a mobile export would silently be incomplete versus the desktop equivalent for the same filter.

## C. Backend/API Chain (shared, unchanged)

```text
GET /api/reports/sales-by-item?from=&to=&page=&size=200
↓
ReportController -> ReportService [backend, shared] -> Page<...>
```
All 14 report endpoints under `/api/reports` are shared, unchanged, identical for both clients.

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `report_service.dart` | `fetchAllPages<T>`, every per-report method | **COPY/ADAPT NEARLY EXACTLY** |
| `core/services/printing/a4_report_pdf.dart` | `A4ReportPdf.build` | **COPY/ADAPT NEARLY EXACTLY** |
| `widgets/report_charts.dart` | `ReportBarChart`/`LineChart`/`PieChart` (`fl_chart`) | **COPY/ADAPT NEARLY EXACTLY** — no platform-specific rendering |
| Desktop report screens | filter bar + wide table layouts | **MOBILE UI REIMPLEMENT** — logic: **COPY/ADAPT NEARLY EXACTLY** the `fetchAllPages` → `A4ReportPdf.build` → `Printing` pattern |

## E. Exact `[NEW/MOBILE]` Files to Create

Listed above.

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/reports/screens/mobile_sales_by_item_screen.dart
Future<void> _exportPdf() async {
  // STEP 1: reuse fetchAllPages EXACTLY — never export just the on-screen page.
  final allRows = await fetchAllPages<SalesByItemRow>(fetchPage: (page) async {
    final pageData = await ref.read(reportServiceProvider).salesByItem(
        from: _filter.fromStr, to: _filter.toStr, page: page, size: reportPrintPageSize);
    return (pageData.content, pageData.meta);
  });
  final company = await ref.read(settingsServiceProvider).getCompanyProfile();   // mobile-flutter-pos's OWN
  final pdfBytes = await A4ReportPdf.build(title: context.l10n.reportsSalesByItem,
      businessName: '${company['businessName'] ?? ''}', columns: [/* ... */], rows: [/* mapped */],
      generatedAt: DateTime.now(), generatedLabel: '', pageLabel: '');
  await Printing.sharePdf(bytes: pdfBytes, filename: 'sales_by_item.pdf');
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] fetchAllPages<SalesByItemRow>({required fetchPage})` — identical to `[OLD/SOURCE]`; loops until an empty page or `page+1 >= meta.totalPages`.

## H. State Before and After

Not Riverpod-driven for the export path — one-shot async operation, identical shape in both projects.

## I. Classification

```text
fetchAllPages, ReportService (every method), A4ReportPdf.build, reportPrintPageSize
COPY/ADAPT NEARLY EXACTLY

report_charts.dart
COPY/ADAPT NEARLY EXACTLY

Desktop report screen layouts
MOBILE UI REIMPLEMENT
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `report_service.dart`, `a4_report_pdf.dart`, `sales_by_item_screen.dart`'s `_printReport()`.
2. **CREATE** `[NEW/MOBILE]` `report_service.dart`, `a4_report_pdf.dart`, `report_charts.dart` — copy/adapt.
3. **CREATE** `[NEW/MOBILE]` `mobile_reports_hub_screen.dart`.
4. **CREATE** 2–3 representative mobile report screens as templates (Sales Summary, Sales by Item, Payment Mix), then the rest.
5. Wire the Day 17 inventory screens' PDF export through the same mechanism.
6. Test: export a report with more rows than one page, confirm the PDF contains ALL matching rows.

## K–O

Same shape as the original Day 18 — every diagram now entirely `mobile-flutter-pos`-internal, against the shared backend's 14 identical report endpoints.

## What I Should Understand Before Day 19

`A4ReportPdf`'s Khmer handling (per-string, `KhmerTextRasterizer`) is architecturally distinct from the receipt pipeline's whole-document `ReceiptBitmapRenderer` (Day 14) — true in both projects, since both study the same `[OLD/SOURCE]` split.

---

# Day 19 — Settings: Company, Tax, Currency, Printer Config

## SOURCE FILES TO STUDY

```text
frontend-flutter-pos/lib/features/pos/services/settings_service.dart
frontend-flutter-pos/lib/core/providers/company_provider.dart
frontend-flutter-pos/lib/core/providers/currency_provider.dart
frontend-flutter-pos/lib/core/providers/main_color_provider.dart             (already ported in Day 3 — see below for its Settings-screen UI)
frontend-flutter-pos/lib/features/pos/screens/settings_modules_screen.dart   (paper-width duplication gotcha; Main Color swatch UI)
frontend-flutter-pos/lib/features/pos/screens/pos_settings_screen.dart
frontend-flutter-pos/lib/features/pos/screens/debug_settings_screen.dart
```

## NEW MOBILE FILES TO CREATE/MODIFY

```text
mobile-flutter-pos/lib/features/pos/services/settings_service.dart
mobile-flutter-pos/lib/core/providers/company_provider.dart
mobile-flutter-pos/lib/core/providers/currency_provider.dart
mobile-flutter-pos/lib/features/settings/screens/mobile_settings_screen.dart   (includes the Main Color swatch section)
mobile-flutter-pos/lib/features/settings/screens/mobile_pos_settings_screen.dart
mobile-flutter-pos/lib/features/settings/screens/mobile_debug_settings_screen.dart
```

## A. Where Do I Start?

`[OLD/SOURCE — READ] frontend-flutter-pos/lib/features/pos/services/settings_service.dart` — flat file, every method follows one shape.

## B. `[OLD/SOURCE]` Function Chain

```dart
Future<Map<String, dynamic>> getCompanyProfile() async => _api.get('/api/settings/company-profile');
Future<Map<String, dynamic>> updateCompanyProfile(Map<String, dynamic> request) async =>
    _api.put('/api/settings/company-profile', data: request);
// getTax/updateTax, getGeneral/updateGeneral follow the same shape
```
```dart
final companyProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async =>
    ref.read(settingsServiceProvider).getCompanyProfile());
String watchCompanyName(WidgetRef ref, {required String fallback}) {
  final company = ref.watch(companyProfileProvider).valueOrNull;   // valueOrNull, not .when() — avoids
  final name = (company?['businessName'] as String?)?.trim();       // flashing fallback during invalidation
  return (name == null || name.isEmpty) ? fallback : name;
}
```
**Confirmed gotcha, reproduce awareness of it in `[NEW/MOBILE]`**: paper width lives in TWO places in `[OLD/SOURCE]` — `pos_settings_screen.dart`'s 58/80mm dropdown persists to the backend via `updatePosLayout` (`receiptPaperWidth` int, currently NOT read anywhere in the printing code path), while `settings_modules_screen.dart`'s `_thermalPrinterSection` persists `PrinterConfig.paperSize` (`PrinterPaperSize` enum) locally via `ThermalPrinterService.saveConfig` — the ONE actually consumed by printing (Days 13–16). `[NEW/MOBILE]` must decide deliberately whether to keep this split or unify it — either way, know which value the print pipeline actually reads.

`[OLD/SOURCE] debug_settings_screen.dart::_save()` — only 2 writes, in-memory-only (process lifetime):
```dart
void _save() { setState(() { AppConfig.useApiCartService = _useApiCart; AppConfig.enableHeldTicketSync = _syncHeldTickets; }); }
```

`[OLD/SOURCE] settings_modules_screen.dart` — Main Color: a new `ListTile` (icon `Icons.palette_outlined`, label from l10n key `settingsMainColor`) sits in the General settings section, immediately after the existing Dark Mode toggle. Its body is a `Wrap` of 6 tappable circular swatches, one per `kMainColorOptions` entry (Day 3):
```dart
ListTile(
  leading: const Icon(Icons.palette_outlined, size: 20),
  title: Text(l10n.settingsMainColor),
  subtitle: Wrap(
    children: kMainColorOptions.map((color) {
      final selected = color.value == currentMainColor.value;
      return Semantics(
        button: true,
        selected: selected,
        label: _mainColorLabel(l10n, color),   // localized color name, e.g. "Green", "Blue"
        child: GestureDetector(
          onTap: () => ref.read(mainColorProvider.notifier).setMainColor(color),
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color,
                border: selected ? Border.all(width: 3, /* highlight */) : null),
            child: selected ? const Icon(Icons.check, color: Colors.white) : null,
          ),
        ),
      );
    }).toList(),
  ),
)
```
Unlike the rest of this settings screen's sections (company profile, tax, etc.), this control has **no separate Save button** — tapping a swatch calls `ref.read(mainColorProvider.notifier).setMainColor(color)` directly and the change is live immediately, exactly like the pre-existing Dark Mode toggle right above it. Each swatch is wrapped in `Semantics(button: true, selected: ..., label: <localized color name>)` for screen-reader accessibility, and the currently-selected swatch shows a white checkmark icon plus a border highlight. `[NEW/MOBILE]` must reproduce this same "no save button, updates instantly" pattern, the same swatch/checkmark/border visual language, and the same `Semantics` accessibility wrapping — this is the Settings-screen half of the mechanism whose provider/persistence/theme-application plumbing was already built in Day 3 (`mainColorProvider`, `MainColorNotifier`, `PosTheme.applyMainColor`). The `SharedPreferences` key to reuse is `app_main_color` — same key Day 3's `MainColorNotifier` already writes to, nothing new to add here beyond the UI.

## C. Backend/API Chain (shared, unchanged)

```text
GET/PUT /api/settings/company-profile   -> SettingsController [backend, shared]
    -> BusinessSettings entity (SAME table/row company-profile and general settings share)
```

## D. `[OLD/SOURCE]` → `[NEW/MOBILE]`

| `[OLD/SOURCE]` | Function | `[NEW/MOBILE]` action |
|---|---|---|
| `settings_service.dart` | every `get`/`update` pair | **COPY/ADAPT NEARLY EXACTLY** |
| `core/providers/company_provider.dart` | `companyProfileProvider`, `watchCompanyName` | **COPY/ADAPT NEARLY EXACTLY** |
| `core/providers/currency_provider.dart` | `currencyCodeProvider` | **COPY/ADAPT NEARLY EXACTLY** |
| `settings_modules_screen.dart` | save/invalidate call sequences | **COPY/ADAPT NEARLY EXACTLY** the logic |
| `settings_modules_screen.dart`'s Main Color `ListTile` | swatch `Wrap`, `Semantics` wrapping, checkmark/border-on-selected, `setMainColor()` call | **COPY/ADAPT NEARLY EXACTLY** — same "no Save button, updates instantly" pattern, same accessibility wrapping, reusing Day 3's `mainColorProvider`/`app_main_color` key |
| `settings_modules_screen.dart`, `pos_settings_screen.dart` | single long scrolling desktop form | **MOBILE UI REIMPLEMENT** — grouped sub-screens |
| `debug_settings_screen.dart` | 2-flag in-memory mechanism | **COPY/ADAPT NEARLY EXACTLY**, or **RECREATE USING SAME LOGIC** if `[NEW/MOBILE]` also exposes `useApiTableService` (missing even in `[OLD/SOURCE]`) and/or persists to SharedPreferences — a deliberate, documented improvement if made |

## E. Exact `[NEW/MOBILE]` Files to Create

Listed above.

## F. Exact `[NEW/MOBILE]` Function Skeleton

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile-flutter-pos/lib/features/settings/screens/mobile_company_profile_screen.dart
Future<void> _save() async {
  if (_businessNameCtl.text.trim().isEmpty) { /* error */ return; }
  try {
    await ref.read(settingsServiceProvider).updateCompanyProfile({'businessName': _businessNameCtl.text.trim(), /* ... */});
    ref.invalidate(companyProfileProvider);   // SAME invalidation — updates mobile-flutter-pos's OWN AppBar name
  } catch (e) { /* error */ }
}
```

## G. Function Inputs and Outputs

`[NEW/MOBILE] SettingsService.updateCompanyProfile(Map request)` — identical to `[OLD/SOURCE]`; `PUT /api/settings/company-profile` (shared backend).

## H. State Before and After

`mobile-flutter-pos`'s own `companyProfileProvider` re-fetches after `ref.invalidate` — every consumer within `mobile-flutter-pos` rebuilds; **no effect on any running `frontend-flutter-pos` session**, since the two apps hold entirely separate provider trees even though both read the same backend row.

## I. Classification

```text
SettingsService, companyProfileProvider/watchCompanyName, currencyCodeProvider, save/invalidate sequences
COPY/ADAPT NEARLY EXACTLY

Main Color ListTile (swatch Wrap, Semantics, checkmark/border, instant setMainColor())
COPY/ADAPT NEARLY EXACTLY

Desktop settings screen layouts
MOBILE UI REIMPLEMENT

debug_settings_screen.dart's mechanism
COPY/ADAPT NEARLY EXACTLY, optionally RECREATE USING SAME LOGIC with documented improvements
```

## J. Build Order Inside the Day

1. **READ** `[OLD/SOURCE]` `settings_service.dart`, `company_provider.dart`.
2. **READ** `[OLD/SOURCE]` `settings_modules_screen.dart`'s save handlers and `_thermalPrinterSection` — note the paper-width duplication.
3. **READ** `[OLD/SOURCE]` `debug_settings_screen.dart`.
4. **CREATE** `[NEW/MOBILE]` `settings_service.dart`, `company_provider.dart`, `currency_provider.dart` — copy/adapt.
5. **CREATE** `[NEW/MOBILE]` `mobile_settings_screen.dart` with section navigation, then each section's sub-screen — include the Main Color `ListTile`/swatch `Wrap` in the General section, right after Dark Mode, wired to Day 3's already-ported `mainColorProvider`.
6. **CREATE** `[NEW/MOBILE]` printer config sub-screen, wiring Day 15/16's permission flows in.
7. **CREATE** `[NEW/MOBILE]` `mobile_debug_settings_screen.dart`.
8. Test: change company name in `mobile-flutter-pos`, confirm its own AppBar updates without restart; confirm a `frontend-flutter-pos` session (if also running) is unaffected until IT independently refetches. Also test: tap a color swatch, confirm the checkmark/border moves to it immediately with no Save button, restart the app, confirm the choice persisted.

## K–O

Same shape as the original Day 19 — every diagram now entirely `mobile-flutter-pos`-internal.

## What I Should Understand Before Day 20

The paper-width duplication is a good final example of this whole plan's core lesson, true in both projects: read the actual code path a feature uses, don't assume a setting labeled correctly is the one that's actually wired up.

---

# Day 20 — Full Application Flow: Two Projects, One Shared Backend

## SOURCE FILES TO STUDY

None new — today retraces everything studied across Days 1–19, confirming `[NEW/MOBILE]`'s independent build against the shared `backend-spring-boot`.

## NEW MOBILE FILES TO CREATE/MODIFY

None new — today is integration/QA, plus final release-config touches inside `mobile-flutter-pos/android/` and `mobile-flutter-pos/ios/` (never `frontend-flutter-pos`'s).

## A. Where Do I Start?

Nowhere new — retrace the entire chain below on real devices, entirely within `mobile-flutter-pos`. If any arrow surprises you, go back to that day's `[OLD/SOURCE]` section B.

## B. The Complete Application Chain — all `[NEW/MOBILE]`, all calling the shared backend

```text
mobile-flutter-pos/lib/main.dart: main()
  -> WidgetsFlutterBinding.ensureInitialized() -> AppConfig.initialize() -> runApp(ProviderScope(child: PosApp()))
↓
PosApp.build -> ref.watch(authProvider) -> home: MobileLoginScreen (no session) or MobileHomeShell (restored)
↓
[Day 4] MobileLoginScreen._login() -> AuthNotifier.login() -> AuthService.login() -> POST /api/auth/login
  (shared backend) -> AuthNotifier.state = data(user) -> Navigator.pushReplacementNamed(mobile home)
↓
[Day 5] MobileHomeShell (bottom nav) -> tap POS -> Navigator.pushNamed('/pos')  (mobile-flutter-pos's own route)
↓
[Day 10] MobileShiftScreen -> ShiftNotifier.openShift() -> POST /api/shifts/open  (shared backend)
↓
[Day 6] MobileProductGrid -> ProductNotifier.loadProducts() -> GET /api/products/pos-catalog  (shared backend)
↓
[Day 8] (optional) MobileScanScreen -> CartNotifier.addProductByBarcode(barcode)
↓
[Day 7] tap product -> CartNotifier.addItem() -> persistCart() -> _syncService()
↓
[Day 9] (optional) MobileTableSelectorScreen, MobileCustomerPickerScreen, Hold via HeldTicketNotifier
↓
[Day 7] MobileCartScreen -> Charge -> Navigator.push(MobilePaymentScreen(total: cart.finalTotal, ...))
↓
[Day 11] MobilePaymentScreen._submitSaleToBackend()
  -> SaleService.createSale() -> POST /api/pos/sales  (shared backend, idempotent via clientRef)
  -> SaleService.paySale() -> POST /api/pos/sales/{id}/pay  (shared backend, stock deducted here)
  -> HeldTicketNotifier.releaseTicketById(), WaitingNumberService.saveWaitingTicket()
  -> CartNotifier.clear(releaseWaitingNumber: false)
↓
[Day 12] MobileReceiptPreviewScreen -> ReceiptViewModel.fromReceiptResponse() -> ReceiptContent renders
↓
[Day 12 addendum] MobileReceiptsScreen -> receiptProvider.filteredSales, status filters, reprint
↓
[Day 13/14/15/16] Print -> PrintService.printReceipt() -> PDF (Printing.layoutPdf) or
  ThermalPrinterService (Network/Bluetooth/USB transports)
↓
[Day 17] (separately) MobilePurchaseOrdersScreen -> createOrder/transition()  (shared backend)
↓
[Day 18] (separately) MobileReportsHub -> fetchAllPages() -> A4ReportPdf.build() -> Printing
↓
[Day 19] (any time) MobileSettingsScreen -> SettingsService.update*() -> ref.invalidate()
↓
[Day 10] MobileShiftScreen -> getClosePrecheck() -> closeShift() -> POST /api/shifts/{id}/close (shared backend)
```
**Every arrow crossing "shared backend" hits the identical `backend-spring-boot` `frontend-flutter-pos` also uses** — this is the architectural guarantee the whole plan was built around: two independent Flutter codebases, one backend, one API contract.

## C. A Realistic Cashier Scenario, Entirely Within `mobile-flutter-pos`

```text
1. Cashier opens mobile-flutter-pos -> AuthNotifier._initializeAuth() restores a valid session.
2. Taps Shift -> ShiftNotifier.openShift(openingFloat: 100.00) -> POST /api/shifts/open.
3. Taps POS -> ProductNotifier.loadProducts() -> GET /api/products/pos-catalog -> grid populates.
4. Scans a barcode -> MobileScanScreen -> CartNotifier.addProductByBarcode('885...') -> added.
5. Long-presses another product -> ProductModifierSheet -> CartNotifier.addItem(withModifiers).
6. Selects a table -> tableSelectionProvider.select() + cartProvider.setTable() (both calls).
7. Taps cart badge -> MobileCartScreen -> Charge -> Navigator.push(MobilePaymentScreen).
8. Selects Cash, taps Complete Sale -> createSale() -> paySale() -> stock deducted -> cart clears.
9. Views Receipts history -> filters "Refunded" -> saleMatchesStatusFilter narrows correctly.
   Switches to "Paid", finds this morning's sale, taps it -> confirms Print/Save PDF/Email/Refund
   show (no Pay, since PAID not VOID) -> taps reprint -> PrintService.printReceipt() -> SAME
   ReceiptViewModel/PrintService path as any fresh print, not a second pipeline.
10. At end of day: getClosePrecheck() -> closeShift(closingCash: 245.00) -> variance within $10 ->
    status CLOSED.
```
Every function name above is a `mobile-flutter-pos` file, studied from but never importing `frontend-flutter-pos`.

## D. Test Flow — Full Regression

```bash
cd mobile-flutter-pos
flutter test
flutter test integration_test
```
`mobile-flutter-pos/test/` and `mobile-flutter-pos/integration_test/` are entirely this project's own test suites — never mixed into `frontend-flutter-pos/test/`. Existing `[OLD/SOURCE]` tests (`frontend-flutter-pos/test/*.dart`) are read as references for scenarios worth covering; the actual test files written for `mobile-flutter-pos` live exclusively under `mobile-flutter-pos/test/`.

### Main Color / Khmer Scaling / Cart Icons — End-to-End Regression Checklist

Run this checklist against `mobile-flutter-pos` on a real device, in order, without restarting the app until step 6 tells you to:

- [ ] 1. Change main color in Settings (Day 19's swatch `Wrap`).
- [ ] 2. Settings screen itself updates immediately — the checkmark/border selection marker moves to the tapped swatch, no restart needed.
- [ ] 3. POS screen updates immediately — the selected category tab (or other primary UI, e.g. selected buttons/chips) reflects the new color (Day 6).
- [ ] 4. Log out.
- [ ] 5. Login screen uses the same configured color — not a hardcoded old brand color (Day 4).
- [ ] 6. Restart the app.
- [ ] 7. The chosen color persists across restart — `SharedPreferences['app_main_color']` read back correctly (Day 3/19).
- [ ] 8. Switch language to Khmer.
- [ ] 9. Khmer text is visibly larger/more readable than before, while English text on the same screens is unchanged (Day 3's `khmer_text_scaler.dart`).
- [ ] 10. Cart item rows show icon-only remove/modifier controls — no "Remove"/"Modifier" text — with working tooltips and unchanged underlying behavior (`removeItem`, `ProductModifierSheet`) (Day 7).
- [ ] 11. Receipt/thermal print output typography is completely unchanged by any of the above — font sizes in printed receipts and A4 reports match pre-existing behavior exactly, unaffected by the Khmer UI scaling or main-color work (Day 12/13/14/18).

## E. Definition of Done — Release Readiness Checklist

- [ ] Full scenario (section C) completes on a real Android phone and a real iPhone, in English and Khmer.
- [ ] All 4 printer transports tested on both platforms; iOS USB result documented either way.
- [ ] Camera/Bluetooth/local-network permission-denied paths tested — graceful, no crash.
- [ ] Offline/idempotent-retry behavior tested (Day 7, Day 11).
- [ ] Receipts history: All/Paid/Void/Refunded filters verified, VOID shows no Pay/Refund, PARTIALLY_REFUNDED still offers Refund, reprint uses the same `PrintService` path as a fresh print.
- [ ] `mobile-flutter-pos/android/app/build.gradle.kts`'s `applicationId` and release signing are real (not a debug-keystore placeholder).
- [ ] `mobile-flutter-pos/ios/Runner.xcodeproj`'s bundle ID and provisioning are real.
- [ ] 12-hour JWT expiry tested mid-shift.
- [ ] `mobile-flutter-pos` builds and runs with ZERO references to `frontend-flutter-pos` anywhere in its source or `pubspec.yaml`.
- [ ] Release checklist drafted: store listings, privacy-policy language for camera/Bluetooth/local-network permissions.

## Final Repository Structure

```text
workspace/
│
├── backend-spring-boot/              # shared, unchanged, single backend
│
├── frontend-flutter-pos/             # existing web/desktop POS — READ-ONLY reference throughout this plan
│   └── (unchanged by this entire plan — no android/ios config, no mobile/ folder, nothing)
│
└── mobile-flutter-pos/               # NEW — this plan's actual deliverable
    ├── android/
    ├── ios/
    ├── lib/
    ├── test/
    └── integration_test/
```
Both Flutter clients call `backend-spring-boot` independently. Neither Flutter project imports the other.

## What I Should Understand at the End of This Plan

The thesis this plan tested: a POS app's business logic is portable almost by construction when kept out of the UI layer — but portability here means *studying and re-implementing in a new, independent project*, not *sharing files or folders with the old one*. Every single "COPY/ADAPT NEARLY EXACTLY" verdict across 20 days meant "write a new file in `mobile-flutter-pos` whose logic matches `frontend-flutter-pos`'s," never "reference the old file directly." If at any point during this build `frontend-flutter-pos` needed to change to make `mobile-flutter-pos` work, that's a signal worth stopping on and reporting separately — the two projects' independence is a design goal, not an accident to work around.

---

## From UI to Database — 5 Deep Examples (both projects call the identical shared backend)

### 1. Login

```text
[NEW/MOBILE] mobile-flutter-pos/lib/features/auth/screens/mobile_login_screen.dart — MobileLoginScreen._login()
  ↓
[NEW/MOBILE] mobile-flutter-pos/lib/core/providers/auth_provider.dart — AuthNotifier.login()
  (adapted from [OLD/SOURCE] frontend-flutter-pos/lib/core/providers/auth_provider.dart)
  ↓
[NEW/MOBILE] mobile-flutter-pos/lib/core/services/auth_service.dart — AuthService.login()
  ↓
[NEW/MOBILE] mobile-flutter-pos/lib/core/services/api_service.dart — ApiService.post('/api/auth/login', ...)
  ↓  HTTP POST — SHARED BACKEND, identical endpoint frontend-flutter-pos also calls
AuthController.login(...)  [backend-spring-boot, unchanged]
  ↓
AuthService.login(request, ip, userAgent)  [backend]
  ↓
UserRepository.findByEmail(email)  [backend]
  ↓
User entity (table "users")  [backend]
  ↓ (password verified, roles/permissions collected)
JwtUtil.generateToken(email, roles, permissions)  [backend] — HS256, 720min expiry
  ↓
AuthDtos.LoginResponse{token, user}  [backend DTO — IDENTICAL shape reaches both clients]
  ↓  HTTP response
[NEW/MOBILE] AuthResponse.fromJson(response)
  ↓
[NEW/MOBILE] AuthService._saveAuthData() — mobile-flutter-pos's OWN SharedPreferences
  ↓
[NEW/MOBILE] AuthNotifier.state = AsyncValue.data(user)
  ↓
[NEW/MOBILE] MobileHomeShell appears (Day 5)
```

### 2. Add Product to Cart

```text
[NEW/MOBILE] ProductCard.onTap (from MobileProductGrid)
  ↓
[NEW/MOBILE] CartNotifier.addItemFromProduct(product)  (adapted from [OLD/SOURCE] cart_provider.dart)
  ↓
[NEW/MOBILE] CartNotifier.addItem(item)
  ↓
[NEW/MOBILE] WaitingNumberService.issueNumber() — fully offline, no backend call, mobile-flutter-pos's own local storage
  ↓
[NEW/MOBILE] state = state.copyWith(items: [...state.items, item])
  ↓
[NEW/MOBILE] CartNotifier.persistCart() — mobile-flutter-pos's OWN SharedPreferences['cart_state_v2']
  ↓
[NEW/MOBILE] CartNotifier._syncService(() => service.saveCartItems(items)) — best-effort, errors swallowed
  ↓ (only if mobile-flutter-pos's own AppConfig.useApiCartService == true)
[NEW/MOBILE] ApiCartService.saveCartItems()
  ↓  HTTP DELETE + POST — SHARED BACKEND
CartController.createCart / addItemToCart  [backend-spring-boot, unchanged]
  ↓
CartService.addItemToCart()  [backend]
  ↓
Cart/CartItem entities (tables "carts"/"cart_items")  [backend]
  — CONFIRMED: this backend Cart is disconnected from Sale, for BOTH clients — background
    persistence only, never part of the checkout path.
  ↓ (back in mobile-flutter-pos, regardless of remote sync outcome)
[NEW/MOBILE] MobileCartBadge, MobileCartScreen rebuild (ref.watch(cartProvider))
```

### 3. Complete Sale

```text
[NEW/MOBILE] MobilePaymentScreen (Complete Sale button)
  ↓
[NEW/MOBILE] _submitSaleToBackend()  (ported near-verbatim from [OLD/SOURCE] payment_screen.dart)
  ↓
build request map: {lines, clientRef, customerId?, tableId?, orderMode, payments?, taxRate, invoiceDiscount?}
  ↓
[NEW/MOBILE] SaleService.createSale(request)
  ↓  HTTP POST /api/pos/sales — SHARED BACKEND
SaleController.create(@Valid SaleCreateRequest)  [backend-spring-boot, unchanged]
  ↓
SaleService.create(request)  [backend, @Transactional]
  ↓
SaleRepository.findByClientRef(clientRef)  — IDEMPOTENCY CHECK, returns existing sale if found
  (works identically regardless of WHICH client — frontend or mobile — sent the clientRef)
  ↓ (new sale)
Sale.status = "DRAFT", SaleRepository.save(sale)  [backend]
  ↓
SaleDtos.SaleResponse{id, status: "DRAFT", grandTotal, ...}
  ↓ (back in mobile-flutter-pos — IF payments were authorized)
[NEW/MOBILE] SaleService.paySale(saleId, payments)  ↓  HTTP POST /api/pos/sales/{id}/pay
SaleController.pay → SaleService.pay()  [backend]
  ↓
applyStockForSale() → applyStockMovement() per line — PESSIMISTIC LOCK, stock ACTUALLY deducted here
  ↓
Sale/SaleLine/StockItem/StockMovement entities updated  [backend]
  ↓ (back in mobile-flutter-pos)
[NEW/MOBILE] CartNotifier.clear(releaseWaitingNumber: false), WaitingNumberService.saveWaitingTicket()
  ↓
[NEW/MOBILE] MobilePaymentScreen rebuilds to "completed"; MobileCartBadge drops to 0.
```

### 4. Open/Close Shift

```text
[NEW/MOBILE] MobileShiftScreen (Open button)
  ↓
[NEW/MOBILE] ShiftNotifier.openShift(openingFloat: 100.00)
  ↓
[NEW/MOBILE] ApiShiftService.openShift(100.00)
  ↓  HTTP POST /api/shifts/open — SHARED BACKEND
ShiftController.open  →  ShiftService.open()  [backend-spring-boot, unchanged]
  ↓
Shift entity created (status="OPEN"), CashEventService.recordInternal(...)  [backend]
  ↓
[NEW/MOBILE] ShiftNotifier.state = ShiftState(isShiftOpen: true, currentShift: shift)

--- later ---

[NEW/MOBILE] MobileShiftScreen (Close, closingCash: 245.00)
  ↓
[NEW/MOBILE] ShiftNotifier.closeShift(closingCash: 245.00)
  ↓  HTTP POST /api/shifts/{id}/close — SHARED BACKEND, identical for both clients
ShiftService.close()  [backend]
  ↓
expected = openingCash + cashSales + cashRefunds + manualCashEvents
variance = closingCash - expected
if (|variance| > 10.00) { OWNER/MANAGER → CLOSED : else → PENDING_APPROVAL } else { CLOSED }
  ↓
[NEW/MOBILE] ShiftNotifier.state = ShiftState(isShiftOpen: false, currentShift: <response>)
  — mobile-flutter-pos's UI must read currentShift.status, not just isShiftOpen, exactly
    as frontend-flutter-pos's must.
```

### 5. Create Purchase Order

```text
[NEW/MOBILE] MobileCreatePurchaseOrderScreen (Save button)
  ↓
[NEW/MOBILE] purchaseOrdersProvider.notifier.createOrder(PurchaseOrder(supplierId, storeId, lines, ...))
  ↓
[NEW/MOBILE] ApiInventoryService.createPurchaseOrder(order)
  ↓  HTTP POST /api/purchase-orders — SHARED BACKEND
PurchaseOrderController.create(@Valid PurchaseOrderRequest)  [backend-spring-boot, unchanged]
  ↓
PurchasingWorkflowService.createPurchaseOrder(request)  [backend]
  ↓
SupplierRepository.findById(supplierId), ProductRepository.findById(productId) per line  [backend]
  ↓
PurchaseOrder.status = "SUBMITTED" (confirmed set directly here — see Day 17's flagged discrepancy
  against the Flutter model's local 'DRAFT' default, applies identically to both clients)
PurchaseOrderRepository.save(order)  [backend]
  ↓
PurchasingWorkflowDtos.PurchaseOrderResponse{id, referenceNumber, status, supplierName, lines: [...]}
  ↓ (back in mobile-flutter-pos)
[NEW/MOBILE] purchaseOrdersProvider.notifier.loadOrders() — full list refetched
  ↓
[NEW/MOBILE] Navigator.of(context).pop(true) — form closes, list screen reloads
```

---

## Mobile POS Function Map — All `[NEW/MOBILE]` (mobile-flutter-pos), Adapted From `[OLD/SOURCE]` (frontend-flutter-pos)

Grouped by module. Every function below is a NEW file in `mobile-flutter-pos`, whose logic was studied from the named `[OLD/SOURCE]` counterpart — never a shared or imported file.

### Authentication

```text
FUNCTION: AuthNotifier.login(String email, String password, {String? terminalId})
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/core/providers/auth_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/core/providers/auth_provider.dart
CALLED BY: MobileLoginScreen._login()
CALLS: AuthService.login()  [mobile-flutter-pos's own]
INPUT: email, password
OUTPUT: Future<void> (result observed via state)
CHANGES STATE: authProvider — loading -> data(user) or error(e) [never rethrows]
NEXT STEP: caller checks ref.read(authProvider) and navigates

FUNCTION: AuthNotifier.logout()
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/core/providers/auth_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/core/providers/auth_provider.dart
CALLED BY: logout button; ApiService.onUnauthorized callback (auto-logout on shared-backend 401)
CALLS: AuthService.logout()
CHANGES STATE: authProvider = data(null); mobile-flutter-pos's own SharedPreferences cleared
NEXT STEP: MobileHomeShell rebuilds home: to MobileLoginScreen
```

### Products

```text
FUNCTION: ProductNotifier.loadProducts({String? query, int? categoryId})
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/providers/product_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/providers/product_provider.dart
CALLED BY: MobilePosScreen init, MobileProductGrid, searchProducts, filterByCategory
CALLS: ProductService.getProducts  [mobile-flutter-pos's own]
CHANGES STATE: productsProvider.products, currentPage=0, hasMore
NEXT STEP: MobileProductGrid rebuilds

FUNCTION: ProductNotifier.findByBarcode(String barcode)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/providers/product_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/providers/product_provider.dart
CALLED BY: CartNotifier.addProductByBarcode (slow path only)
CHANGES STATE: none (does not touch ProductState)
NEXT STEP: caller (CartNotifier) decides add/reject
```

### Cart

```text
FUNCTION: CartNotifier.addItemFromProduct(Product product)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/providers/cart_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart
CALLED BY: ProductCard quick-add tap
CHANGES STATE: cartProvider.items
NEXT STEP: MobileCartBadge/MobileCartScreen rebuild

FUNCTION: CartNotifier.addProductByBarcode(String barcode)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/providers/cart_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart
CALLED BY: MobileScanScreen._onDetect (direct call — no relay, unlike [OLD/SOURCE]'s PhoneScannerScreen)
OUTPUT: Future<BarcodeAddResult>
CHANGES STATE: cartProvider.items (if found+valid)
NEXT STEP: caller shows result.message

FUNCTION: CartNotifier.clear({bool releaseWaitingNumber = true})
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/providers/cart_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart
CALLED BY: post-checkout (Day 11), Hold action (Day 9), manual Clear button
CHANGES STATE: cartProvider = CartState.initial()
NEXT STEP: all cart-watching widgets rebuild to empty
```

### Sale

```text
FUNCTION: SaleService.createSale(Map<String,dynamic> request)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/services/sale_service.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/services/sale_service.dart
CALLED BY: MobilePaymentScreen._submitSaleToBackend, step 1
CALLS: ApiService.post -> POST /api/pos/sales  (SHARED BACKEND)
OUTPUT: Future<SaleResponse>
CHANGES STATE: shared backend Sale row (DRAFT); no mobile-flutter-pos local state change directly
NEXT STEP: paySale (if payments present)

FUNCTION: SaleService.paySale(int saleId, List<Map> payments)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/services/sale_service.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/services/sale_service.dart
CALLED BY: _submitSaleToBackend, step 2
CALLS: ApiService.post -> POST /api/pos/sales/{id}/pay  (SHARED BACKEND)
CHANGES STATE: shared backend Sale row (paid), StockItem quantities, StockMovement rows
NEXT STEP: heldTicket release, waiting ticket save, cart clear
```

### Printing

```text
FUNCTION: PrintService.printReceipt(BuildContext context, int saleId)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/services/print_service.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/services/print_service.dart
CALLED BY: any print button
CALLS: ApiService.get (receipt fetch, SHARED BACKEND), ReceiptViewModel.fromReceiptResponse,
    ThermalPrinterService.loadConfig, buildReceiptPdf + Printing.layoutPdf OR ThermalPrinterService.printReceipt
OUTPUT: Future<bool>
CHANGES STATE: none (side effect: OS print dialog or physical print)
NEXT STEP: caller shows success/failure feedback

FUNCTION: ThermalPrinterService.printReceipt(BuildContext, ReceiptViewModel, PrinterConfig)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/services/printing/thermal_printer_service.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/services/printing/thermal_printer_service.dart
CALLED BY: PrintService.printReceipt (non-pdfDriver path)
CALLS: _transportFor (Network/Usb/Bluetooth), EscPosReceiptBuilder.build, transport.connect/write/disconnect
CHANGES STATE: none (side effect: physical print)
NEXT STEP: caller's try/catch handles failure
```

### Receipts

```text
FUNCTION: ReceiptNotifier.setStatusFilter(String? status)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/providers/receipt_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/providers/receipt_provider.dart
CALLED BY: filter chip tap (MobileReceiptsScreen)
INPUT: String? status — null (All), 'PAID', 'VOID', 'REFUNDED' — the raw UI filter value
CHANGES STATE: receiptProvider.statusFilter (does NOT touch state.sales — independent of loadAllSales)
NEXT STEP: state.filteredSales re-derives; watchers rebuild

FUNCTION: ReceiptNotifier.loadAllSales({String? status})
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/providers/receipt_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/providers/receipt_provider.dart
CALLED BY: Shift/All toggle, pull-to-refresh, filter-chip handler (alongside setStatusFilter)
CALLS: SaleService.listSales(status: status) -> GET /api/pos/sales?status=  (SHARED BACKEND)
INPUT: the RESOLVED backend query value (caller must pass backendStatusQueryFor(uiFilter))
CHANGES STATE: receiptProvider.sales/.loading/.error (does NOT touch state.statusFilter)
NEXT STEP: state.filteredSales re-derives from new sales + UNCHANGED statusFilter

FUNCTION: saleMatchesStatusFilter(String saleStatus, String filterStatus)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/providers/receipt_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/providers/receipt_provider.dart
CALLED BY: ReceiptState.filteredSales (internally)
OUTPUT: bool — true if filterStatus=='REFUNDED' and saleStatus is REFUNDED OR PARTIALLY_REFUNDED,
    else exact string match
CHANGES STATE: none (pure)
NEXT STEP: ReceiptState.filteredSales includes/excludes the sale accordingly

FUNCTION: backendStatusQueryFor(String? filterStatus)
[NEW/MOBILE] FILE: mobile-flutter-pos/lib/features/pos/providers/receipt_provider.dart
[OLD/SOURCE] STUDIED FROM: frontend-flutter-pos/lib/features/pos/providers/receipt_provider.dart
CALLED BY: every call site of loadAllSales
OUTPUT: String? — same value for PAID/VOID/null; ALWAYS null for REFUNDED (shared backend can't
    express the 2-status family in one query param)
CHANGES STATE: none (pure)
NEXT STEP: passed as loadAllSales's status argument
```

---

## Where Should I Write Code? (recap — see the table near the top of this document for the full version)

New screen/widget/provider/service/model → `mobile-flutter-pos/lib/features/.../` (never `frontend-flutter-pos/lib/`). New translated string → `mobile-flutter-pos`'s own `.arb` files + `flutter gen-l10n` run inside `mobile-flutter-pos`. New printer transport → `mobile-flutter-pos/lib/features/pos/services/printing/`. New Android/iOS permission → `mobile-flutter-pos/android/`/`mobile-flutter-pos/ios/` exclusively — never `frontend-flutter-pos/android/`/`frontend-flutter-pos/ios/`.

## Do Not Put Code Here (recap)

No file anywhere under `frontend-flutter-pos/lib/.../mobile/` — that entire project is read-only reference. No cross-project imports (`import '../../frontend-flutter-pos/...'`). No money/tax math in widgets. No direct `Dio`/`ApiService` calls from widgets. No copying `frontend-flutter-pos/lib/pos/` (legacy, doubly irrelevant). No hand-editing `mobile-flutter-pos`'s generated localization files. No forking `ReceiptContent`/`ReceiptViewModel` within `mobile-flutter-pos` once written. No platform `if` branches outside the printer transport classes and `AppConfig.baseUrl`. No copying confirmed-dead `[OLD/SOURCE]` files (`product.dart`, `product_api_service.dart`, `cart_panel_footer.dart`, `cart_footer.dart`, `status_bar.dart`). No silently fixing an `[OLD/SOURCE]` bug as part of the mobile build — stop, report separately.

---

## What I Will Have After Day 20

Two independent Flutter codebases sharing one backend:
```text
backend-spring-boot/          (unchanged, shared)
frontend-flutter-pos/         (unchanged by this plan — existing web/desktop POS, read-only reference)
mobile-flutter-pos/           (NEW — this plan's deliverable)
    Android -> APK/AAB
    iOS     -> Xcode archive / App Store build
```
`mobile-flutter-pos` has its own `CartNotifier`/`SaleService`/`ShiftNotifier` business logic (adapted, matching `frontend-flutter-pos`'s rules exactly), its own inventory/production workflow, its own `ReceiptViewModel` and printing architecture, its own English/Khmer localization files, its own Android/iOS platform configuration — all studied from `frontend-flutter-pos`, none of it imported from or dependent on it. Both apps call the identical shared `backend-spring-boot` API contract.

## What Still Requires Real Hardware Testing

USB thermal printer on iOS (MFi-gated, unverified — the single biggest open risk, identical uncertainty in both projects since neither has tested it); Bluetooth pairing/mid-print-disconnect behavior; network printer over real Wi-Fi including iOS's local-network permission prompt; camera barcode scan reliability under real conditions; the 12-hour JWT expiry's mid-shift UX; cross-device screen-size coverage.
