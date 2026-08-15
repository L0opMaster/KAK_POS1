# Day 1 — Architecture Mapping: Read-Only Study of `frontend-flutter-pos`

Status: **Day 1 deliverable — study/mapping only.** Per the 20-day plan (`frontend-flutter-pos/docs/MOBILE_ANDROID_IOS_20_DAY_BUILD_PLAN.md`), Day 1 writes **zero application code**. `frontend_flutter_mobile` at this point is exactly what `flutter create` produced — this file is Day 1's actual output: the architecture map that every later day's `[NEW/MOBILE]` work is built from.

Note on naming: the 20-day plan uses the placeholder project name `mobile-flutter-pos`. The real project, already created, is **`frontend_flutter_mobile`** (confirmed by inspecting this directory: standard `flutter create` output — `android/`, `ios/`, `lib/main.dart` only, default `pubspec.yaml`). This document uses the real name throughout. The plan doc's placeholder name can be swapped for the real one on request — not done automatically here since it wasn't asked for this turn.

---

## SOURCE FILES TO STUDY (all read-only, all in `frontend-flutter-pos/`)

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
frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart   (full module inventory)
frontend-flutter-pos/lib/features/pos/providers/   (all files — skim now, deep-dive per day later)
frontend-flutter-pos/lib/features/pos/services/    (all files, including services/printing/)
frontend-flutter-pos/lib/features/inventory/       (models/providers/services/screens)
frontend-flutter-pos/lib/features/reports/         (models/services/screens/widgets)
frontend-flutter-pos/lib/l10n/app_en.arb, app_km.arb
```
**Explicitly excluded**: `frontend-flutter-pos/lib/pos/` — a legacy, retired duplicate module even within `frontend-flutter-pos` itself. Never study or copy from it.

## NEW MOBILE FILES TO CREATE/MODIFY

None today. `frontend_flutter_mobile/lib/main.dart` still holds the Flutter default counter-app placeholder — that's correct and expected; it gets replaced starting Day 4/5.

---

## A. Where Do I Start?

Open `[OLD/SOURCE — READ] frontend-flutter-pos/lib/main.dart`. Read `PosApp.build(BuildContext context, WidgetRef ref)` — this one function decides both the initial screen and how every screen reaches the network. `frontend_flutter_mobile/lib/main.dart` will do the equivalent job for the new project once it's written (Day 4/5).

## B. `[OLD/SOURCE]` Function Chain — `main()` and `PosApp.build`

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
    routes: <String, WidgetBuilder>{ /* ~40 routes */ },
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
[NEW/MOBILE] frontend_flutter_mobile — MobileLoginScreen._login()
  -> AuthNotifier.login(email, password)          (adapted from [OLD/SOURCE] AuthNotifier)
  -> AuthService.login()                           (adapted from [OLD/SOURCE] AuthService)
  -> ApiService.post('/api/auth/login', ...)       (adapted from [OLD/SOURCE] ApiService)
  -> POST /api/auth/login  (SAME backend endpoint frontend-flutter-pos already calls)
  -> AuthController.login(...) -> AuthService.login(...) [backend, unchanged, shared]
  -> UserRepository.findByEmail -> password check -> JwtUtil.generateToken
  -> AuthDtos.LoginResponse{token, user}
  -> AuthResponse.fromJson(response)
  -> AuthService._saveAuthData()
  -> AuthNotifier.state = AsyncValue.data(user)
  -> MobileHomeShell appears (Day 5)
```

**PRODUCT** (full detail Day 6):
```text
[NEW/MOBILE] MobilePosScreen.initState -> ProductNotifier.loadProducts()
  -> ProductService.getProducts(...)
  -> ApiService.get('/api/products/pos-catalog')
  -> GET /api/products/pos-catalog  (SAME endpoint)
  -> ProductController.posCatalog(storeId) [backend, unchanged, shared]
  -> List<Product>
  -> ProductState.products
  -> MobileProductGrid rebuilds
```

**SALE** (full detail Day 11):
```text
[NEW/MOBILE] product tap -> CartNotifier.addItemFromProduct/addItem
  -> Charge -> MobilePaymentScreen -> MobilePaymentScreen._submitSaleToBackend()
  -> SaleService.createSale(request) -> POST /api/pos/sales
  -> SaleController.create -> SaleService.create [backend, unchanged, shared]
  -> (if payments present) SaleService.paySale(saleId, payments) -> POST /api/pos/sales/{id}/pay
  -> SaleResponse
  -> SaleService.getReceipt(saleId) -> GET /api/pos/sales/{id}/receipt -> ReceiptResponse map
  -> ReceiptViewModel.fromReceiptResponse(...)
  -> ReceiptContent (preview / PDF / ESC-POS all read this one model)
```
Every chain is identical in *shape* on both sides — same layering, same backend endpoints, same request/response contracts. Only the concrete Dart files differ (one project's files, not the other's), and only the UI at the front of each chain differs deliberately (Day 5 onward).

## D. Old File → Purpose → New Mobile Destination

The actual deliverable of this day.

| `[OLD/SOURCE]` (frontend-flutter-pos/lib/...) | Purpose | `[NEW/MOBILE]` destination (frontend_flutter_mobile/lib/...) |
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
| `l10n/app_en.arb`, `app_km.arb` | source translation strings | `l10n/app_en.arb`, `app_km.arb` — **own copies**, seeded not shared (Day 3) |

Everything under `frontend-flutter-pos/lib/pos/` (legacy) has no `[NEW/MOBILE]` destination — never studied, never adapted.

## E. Exact `[NEW/MOBILE]` Files to Create

None today.

## F–H

Not applicable — read-only day, no code, no state.

## I. Classification (headline calls — detailed per day as each feature is built)

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
DO NOT COPY
```

## J. Build Order Inside the Day

1. Open `[OLD/SOURCE] frontend-flutter-pos/lib/main.dart`. Read `main()` and `PosApp.build` top to bottom.
2. Open `[OLD/SOURCE] frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart` — the full module inventory.
3. Open `[OLD/SOURCE]` `core/providers/auth_provider.dart`, `core/services/auth_service.dart`, `core/services/api_service.dart` — read `login()`/`post()` fully.
4. Open `[OLD/SOURCE]` `features/pos/providers/product_provider.dart`, `services/product_service.dart` — read `loadProducts()`/`getProducts()`.
5. Open `[OLD/SOURCE]` `features/pos/screens/payment_screen.dart` — skim `_submitSaleToBackend()`'s shape (Day 11 goes deep).
6. Cross-check section D's table against the actual repo — verify, don't just trust this document.
7. Run the EXISTING web app (`cd frontend-flutter-pos && flutter run -d chrome`) against the real backend and do one full login → browse → checkout, watching the `ApiService` debug logging interceptor's console output.

## Definition of Done

You can reproduce the three chains in section C from memory with correct `[OLD/SOURCE]`/`[NEW/MOBILE]` labels, and you can name every file in section D's table without looking.

## What I Should Understand Before Day 2

`frontend_flutter_mobile` already exists (confirmed: default `flutter create` scaffolding — `android/`, `ios/`, `lib/main.dart` counter-app placeholder, default `pubspec.yaml`), so Day 2's `flutter create` step is effectively already satisfied — Day 2 now just means: confirm/adjust the application ID, bundle ID, and display name, rather than running `flutter create` from scratch. Every file in section D's right-hand column is something to write into `frontend_flutter_mobile/lib/...` on the day that feature comes up, not something already sitting there.
