# Mobile (Android/iOS) 20-Day Build Plan — Function-Level Edition

Status: **planning/teaching document only**. No production code was changed to produce this. Every function body, class, endpoint, and backend trace below was read directly from the current source on 2026-08-12 — `frontend-flutter-pos/lib/` and `backend-spring-boot/src/main/java/`. Where the source contradicted the project's own Markdown docs (`DEVELOPER.md`, `ARCHITECTURE.md`), the source wins and the discrepancy is called out.

This is a rewrite of the earlier, higher-level version of this document. That version told you *what* to build ("reuse `ProductNotifier`", "wire search"). This version tells you *exactly which function to open, what it does line by line, what it calls next, and what to write next to it* — the level of detail you'd get pair-programming with someone who already knows this codebase.

---

## How to Read This Document

Every day (1–20) has the same section structure. Not every section applies with equal weight to every day — a platform-config day (Day 2) has no "state before/after," a pure-UI day has a short backend chain — where a section is thin for a given day, it says so plainly instead of padding.

- **A. Where Do I Start?** — the one file/class/function to open first, and why.
- **B. Existing Web Function Chain** — the real call chain, function → function, as it exists today, with actual code.
- **C. Backend/API Chain** — when the flow touches the network, the Controller → Service → Repository → Entity → DTO chain on the Spring Boot side.
- **D. Exact Existing Functions to Reuse** — a table: file, class, function, input, output, mobile use.
- **E. Exact New Mobile Files to Create** — exact paths, fitting this project's actual folder layout.
- **F. Exact Function I Need to Write** — an educational skeleton (not production code) for the new mobile file.
- **G. Function Inputs and Outputs** — for the day's key business function(s).
- **H. State Before and After** — Riverpod state, concretely, before/after the key mutation.
- **I. What Should Be Shared vs Mobile-Only?** — 🟢 keep exactly / 🟡 call from new mobile UI / 🟠 small adaptation / 🔵 new mobile UI / 🔴 do not copy.
- **J. Build Order Inside the Day** — numbered, specific steps.
- **K. "When I Click This, What Happens?"** — the exact chain for the day's main user action(s).
- **L. "Where Does This Value Come From?"** — traces a displayed value back to its source.
- **M. Navigation Flow** — exact `Navigator` mechanism used (`push`, `pushNamed`, `pushReplacementNamed`, etc.).
- **N. Error Flow** — what actually happens today when the API call fails — not a hypothetical.
- **O. Test Flow** — exact existing test file + manual test steps.

### Project structure this document assumes

```text
lib/
  main.dart                          # entry point, routes map, home: auth gate
  core/
    config/                          # AppConfig, PosTheme, currency_utils
    models/                          # auth_models.dart (User, AuthResponse, LoginRequest)
    providers/                       # auth, company, connectivity, currency, language, theme
    services/                        # api_service.dart, auth_service.dart
    services/printing/               # a4_report_pdf.dart, khmer_text_rasterizer.dart
    utils/                           # money.dart, khmer_text.dart, bilingual.dart, l10n_extensions.dart, ...
  features/
    auth/screens/                    # login_screen.dart
    pos/
      models/                        # cart_models.dart, product_models.dart, shift_model.dart, ...
      providers/                     # cart_provider.dart, product_provider.dart, shift_provider.dart, ...
      services/                      # cart_service.dart, sale_service.dart, settings_service.dart,
                                      # print_service.dart, ...
      services/printing/             # thermal_printer_service.dart, escpos_receipt_builder.dart,
                                      # receipt_bitmap_renderer.dart, printer_profile.dart,
                                      # network/usb/bluetooth_printer_transport.dart, ...
      screens/                       # pos_screen.dart, payment_screen.dart, settings_modules_screen.dart, ...
      widgets/                       # product_grid.dart, cart_items_list.dart, table_selector.dart, ...
    inventory/                       # models/, providers/, services/, screens/
    reports/                         # models/, services/, screens/, widgets/
  l10n/                               # app_en.arb, app_km.arb (source strings)
  l10n/generated/                    # AppLocalizations (generated — never hand-edit)
lib/pos/                             # LEGACY — retired duplicate, do not open, do not copy
```

**Where new mobile code goes**, decided once here so every day below is consistent: this project has no existing `mobile/` subfolder convention, so this plan introduces one, mirroring the existing `features/pos/{screens,widgets}` split:

```text
lib/features/pos/mobile/
├── screens/
│   ├── mobile_login_screen.dart
│   ├── mobile_home_shell.dart
│   ├── mobile_pos_screen.dart
│   ├── mobile_cart_screen.dart
│   ├── mobile_payment_screen.dart
│   ├── mobile_receipt_preview_screen.dart
│   ├── mobile_scan_screen.dart
│   ├── mobile_customer_picker_screen.dart
│   ├── mobile_table_selector_screen.dart
│   ├── mobile_held_tickets_screen.dart
│   ├── mobile_shift_screen.dart
│   ├── mobile_settings_screen.dart
│   └── mobile_reports_hub_screen.dart
└── widgets/
    ├── mobile_product_grid.dart
    ├── mobile_cart_badge.dart
    ├── mobile_product_search_bar.dart
    └── mobile_status_action_sheet.dart   # reused for PO/transfer-order status actions
```
Inventory screens follow the same idea under `lib/features/inventory/mobile/screens/`. No new provider/service/model files are needed anywhere in this plan — that is the entire point of the architecture: every provider, service, and model listed in section D of each day is opened and called, never duplicated.

---

## Where Should I Write Code? (quick reference, keep this open)

| I need... | Write it under... | Example from this codebase |
|---|---|---|
| A new **screen** | `lib/features/pos/mobile/screens/` (or `lib/features/inventory/mobile/screens/`) | `mobile_cart_screen.dart` |
| A reusable **widget** (not a full screen) | `lib/features/pos/mobile/widgets/` | `mobile_product_grid.dart` |
| New **business state** | `lib/features/pos/providers/` — but check Day 1–19 first, almost certainly it already exists | `cart_provider.dart` (do not create a second one) |
| A new **API operation** | `lib/features/pos/services/` — again, check first; nearly every operation this plan needs already exists | `sale_service.dart` |
| New **JSON data shape** | `lib/features/pos/models/` | `cart_models.dart` |
| A new **translated string** | Add the key to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_km.arb`, then run `flutter gen-l10n` | see Day 3 |
| A **printer transport** | `lib/features/pos/services/printing/` implementing `PrinterTransport` | `network_printer_transport.dart` |
| An **Android permission** | `android/app/src/main/AndroidManifest.xml` | Day 8, 15, 16 |
| An **iOS permission** | `ios/Runner/Info.plist` (`NSCameraUsageDescription` etc.) | Day 8, 15, 16 |

## Do Not Put Code Here

- **Do not** put money/discount/tax math inside a widget's `build()` method — it already lives in `CartState`'s getters (`total`, `discountAmount`, `taxAmount`, `finalTotal` in `cart_provider.dart`). If you find yourself writing `item.price * item.qty` inside a widget, stop — read Day 7's `CartItem.lineTotal` getter instead.
- **Do not** call `Dio`/`ApiService` directly from a widget. Every existing screen goes through a service (`SaleService`, `ProductService`, ...); a widget calling `ref.read(apiServiceProvider).get(...)` directly is a pattern this codebase does not use anywhere — don't introduce it.
- **Do not** copy anything from `lib/pos/` (legacy, 3 files, explicitly retired per `DEVELOPER.md` §3 — "LEGACY module ... do not add code here").
- **Do not** hand-edit `lib/l10n/generated/app_localizations*.dart` — it's generated by `flutter gen-l10n` from the two `.arb` files; edits are silently overwritten.
- **Do not** create a second `ReceiptViewModel`-like class "for mobile" — `ReceiptContent` (in `receipt_paper_view.dart`) is deliberately the *one* widget shared by the on-screen preview, the PDF Khmer rasterizer, and the ESC/POS Khmer rasterizer. A second implementation would silently reintroduce a preview/print drift bug this codebase already fixed once (see Day 14).
- **Do not** write Android/iOS `if` branches inside provider or service code. The only files in this entire codebase with platform-conditional logic are the three printer transport classes and `AppConfig.baseUrl`. Keep it that way — new platform differences belong in a new transport class or a new file under `services/printing/`, not scattered through business logic.
- **Do not** copy `lib/features/pos/models/product.dart` or `services/product_api_service.dart` — confirmed dead code (unreferenced anywhere), a stale skeleton, not the real `Product` model (`product_models.dart` is real).
- **Do not** copy `lib/features/pos/widgets/cart_panel_footer.dart`, `cart_footer.dart`, or `status_bar.dart` — confirmed dead code, not instantiated anywhere in the active app.

---

## Architecture Classification (condensed — see each day for the function-level version)

| Component | Classification |
|---|---|
| `ApiService`, `AuthService`, `AuthNotifier` | 🟢 KEEP EXACTLY |
| `CartNotifier`, `CartState`, `Money` | 🟢 KEEP EXACTLY |
| `ProductNotifier`, `ProductService` (+ demo fallback) | 🟢 KEEP EXACTLY |
| `SaleService`, `PaymentMethod`, `SplitRow` | 🟢 KEEP EXACTLY |
| `ReceiptViewModel`, `ReceiptContent`, printing builders | 🟢 KEEP EXACTLY |
| `PrinterTransport` interface | 🟢 KEEP EXACTLY (interface) |
| `NetworkPrinterTransport` | 🟡 CALL AS-IS + 🟠 new iOS permission wrapper |
| `UsbPrinterTransport`, `BluetoothPrinterTransport` | 🟡 CALL AS-IS + 🟠 new permission_handler wrapper (currently unused anywhere) |
| `pos_screen.dart` 380px sidebar, `payment_screen.dart` 2-column layout, `product_grid.dart` fixed-5-column | 🔵 NEW MOBILE UI (logic under them is 🟢) |
| `lib/pos/` (legacy) | 🔴 DO NOT COPY |
| `product.dart`, `product_api_service.dart`, `cart_panel_footer.dart`, `cart_footer.dart`, `status_bar.dart` | 🔴 DO NOT COPY (dead code) |

---

# Day 1 — Architecture: Three Complete Function Chains

## A. Where Do I Start?

Open `lib/main.dart`. Read `PosApp.build(BuildContext context, WidgetRef ref)`. This one function decides both the initial screen and how every screen from here on gets to the network — everything else in this document hangs off of it.

## B. Existing Web Function Chain — `main()` and `PosApp.build`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  await SharedPreferences.getInstance();
  unawaited(_prewarmPrinting());
  runApp(const ProviderScope(child: PosApp()));
}
```
Order matters: Flutter bindings → `AppConfig.initialize()` (currently a no-op, reserved for future env/config loading) → pre-warm the `SharedPreferences` singleton (so the auth check on the very next line is instant, no first-read latency) → fire-and-forget printing font pre-load (`unawaited`, never blocks startup) → `runApp` wrapped in `ProviderScope` (this is what makes every `ref.watch`/`ref.read` in the app work at all).

```dart
Widget build(final BuildContext context, final WidgetRef ref) {
  final authState = ref.watch(authProvider);
  ApiService.onUnauthorized = () => ref.read(authProvider.notifier).logout();
  return MaterialApp(
    theme: PosTheme.lightTheme,
    darkTheme: PosTheme.darkTheme,
    themeMode: ref.watch(themeModeProvider).value,
    locale: ref.watch(appLanguageProvider).toLocale(),
    supportedLocales: const [Locale('en'), Locale('km')],
    localizationsDelegates: const [
      AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
    ],
    routes: <String, WidgetBuilder>{ /* ~40 routes, see Day 5 */ },
    home: authState.maybeWhen(
      data: (final User? user) => user != null ? const PosScreen() : const LoginScreen(),
      orElse: () => const LoginScreen(),
    ),
  );
}
```
`authState` is `AsyncValue<User?>` from `authProvider`. Watching it means `PosApp` rebuilds on every auth state change. `ApiService.onUnauthorized` is re-assigned on *every* build (harmless — same closure) so a `401` anywhere in the app always routes back to `authProvider.notifier.logout()`. `home:` is `AsyncValue.maybeWhen`: only the `data` case checks `user != null`; `loading` and `error` both fall through to `LoginScreen()` via `orElse`.

## C. Backend/API Chain — none yet

Day 1 is read-only; nothing here calls the network. The three chains below are the ones you'll build against on Days 4, 6, and 11.

**LOGIN** (full detail in Day 4):
```text
LoginScreen._login()
  -> ref.read(authProvider.notifier).login(email, password)
  -> AuthNotifier.login()                 [state = AsyncValue.loading(), then .data(user) or .error]
  -> AuthService.login()                  [builds LoginRequest, calls ApiService.post]
  -> ApiService.post<Map>('/api/auth/login', data: request.toJson())
  -> POST /api/auth/login
  -> AuthController.login(...) -> AuthService.login(...) [backend]
  -> UserRepository.findByEmail -> password check -> JwtUtil.generateToken
  -> AuthDtos.LoginResponse{token, user}
  -> AuthResponse.fromJson(response)      [Flutter]
  -> AuthService._saveAuthData()          [writes SharedPreferences 'auth_token'/'user_data']
  -> AuthNotifier.state = AsyncValue.data(authResponse.user)
  -> PosApp rebuilds (ref.watch(authProvider))
  -> LoginScreen explicitly navigates: Navigator.of(context).pushReplacementNamed('/pos')
```

**PRODUCT** (full detail in Day 6):
```text
PosScreen.initState() -> ref.read(productsProvider.notifier).loadProducts()
  -> ProductNotifier.loadProducts({query, categoryId})
  -> ProductService.getProducts(...)           [ApiProductService, with DemoProductService fallback]
  -> ApiService.get('/api/products/pos-catalog')  [or /api/products with query params]
  -> GET /api/products/pos-catalog
  -> ProductController.posCatalog(storeId) [backend]
  -> List<Product> (Product.fromJson per item)
  -> ProductState.products
  -> ProductGrid rebuilds (ref.watch(productsProvider))
```

**SALE** (full detail in Day 11):
```text
Product tap -> CartNotifier.addItemFromProduct/addItem
  -> Charge button -> PaymentScreen -> PaymentScreen._submitSaleToBackend()
  -> SaleService.createSale(request) -> POST /api/pos/sales -> SaleController.create -> SaleService.create [backend]
  -> (if payments present) SaleService.paySale(saleId, payments) -> POST /api/pos/sales/{id}/pay
  -> SaleResponse
  -> SaleService.getReceipt(saleId) -> GET /api/pos/sales/{id}/receipt -> ReceiptResponse map
  -> ReceiptViewModel.fromReceiptResponse(...)
  -> ReceiptContent (preview / PDF / ESC-POS all read this one model)
```

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `main.dart` | `PosApp` | `build` | `(BuildContext, WidgetRef)` | `Widget` | Keep the `home:`/auth-gate logic; only the `routes` map and what widget "POS" points to changes (Day 5) |
| `core/providers/auth_provider.dart` | `AuthNotifier` | `login` | `(String email, String password, {String? terminalId})` | `Future<void>` | Called unchanged from `MobileLoginScreen` (Day 4) |
| `features/pos/providers/product_provider.dart` | `ProductNotifier` | `loadProducts` | `({String? query, int? categoryId})` | `Future<void>` | Called unchanged from `MobilePosScreen`/`MobileProductGrid` (Day 6) |

## E. Exact New Mobile Files to Create

None today — Day 1 is inspection only.

## F. Exact Function I Need to Write

None today.

## G. Function Inputs and Outputs

Not applicable today — see Days 4, 6, 11 for the three chains above traced at this level.

## H. State Before and After

Not applicable today.

## I. What Should Be Shared vs Mobile-Only?

```text
PosApp.build's home:/auth-gate logic
🟢 KEEP EXACTLY

PosApp.build's routes: map
🟠 SMALL ADAPTATION (Day 5 — same targets, "POS" route's widget changes)
```

## J. Build Order Inside the Day

1. Open `lib/main.dart`. Read `main()` top to bottom.
2. Read `PosApp.build`. Find the `routes` map — don't memorize it, just note it exists and is a flat `Map<String, WidgetBuilder>`.
3. Open `core/providers/auth_provider.dart`. Read `AuthNotifier`'s constructor and `login()`.
4. Open `core/services/auth_service.dart`. Read `login()`.
5. Open `core/services/api_service.dart`. Read `post<T>()` and the auth interceptor.
6. Open `features/pos/providers/product_provider.dart`. Read `loadProducts()`.
7. Open `features/pos/services/product_service.dart`. Read `ApiProductService.getProducts()`.
8. Open `features/pos/screens/payment_screen.dart`. Skim (don't fully digest yet — Day 11 goes deep) `_submitSaleToBackend()` just to see its shape.
9. Draw (on paper or in a scratch file, not committed) the three chains from section B, filling in real function names from what you just read.
10. Run the existing web app (`flutter run -d chrome`) against the real backend and do one full login → browse products → checkout, watching `debugPrint` output from `ApiService`'s debug logging interceptor — you'll see the real request sequence appear in the console, confirming what you just traced on paper.

## K. "When I Click This, What Happens?"

# Login button
```text
Tap "LOGIN"
↓
LoginScreen._login()
↓
form validates
↓
AuthNotifier.login(email, password)
↓
AuthService.login() -> POST /api/auth/login
↓
AuthNotifier.state = AsyncValue.data(user)
↓
LoginScreen: Navigator.pushReplacementNamed('/pos')
```

## L. "Where Does This Value Come From?"

Not applicable today — this section becomes concrete once real screens exist (Day 4 onward).

## M. Navigation Flow

Confirmed today: this app uses **named routes** (`Navigator.pushReplacementNamed`, `Navigator.pushNamed`) almost everywhere, plus a few `MaterialPageRoute` pushes for screens that need constructor parameters not expressible as a route string (e.g. `PaymentScreen`, which needs `total`/`saleLines`/etc — see Day 11). No `go_router`, no `onGenerateRoute`.

## N. Error Flow

Not applicable today.

## O. Test Flow

No test to run today — this is a reading day. If you want to sanity-check your understanding, run:
```bash
flutter analyze
```
and confirm it's clean on the unmodified codebase (matches `DEVELOPER.md`'s stated requirement, and gives you a known-good baseline before you touch anything).

## What I Should Understand Before Day 2

That `main.dart` → `PosApp` → `routes` map is the entire routing surface of this app (no nested navigators, no shell routes) — Day 5's mobile navigation shell wraps *around* this, it doesn't replace it.

---

# Day 2 — Platform Setup: Exact Files, Exact Settings

## A. Where Do I Start?

Open `android/app/build.gradle.kts`. This is a Kotlin DSL Gradle file, not Dart — it configures how the Android build packages your unchanged `lib/` tree into an APK/AAB.

## B. Existing Web Function Chain

Not applicable — no Dart function chain today. This day is entirely configuration file edits.

## C. Backend/API Chain

None.

## D–H

Not applicable (no Dart functions today).

## Exact Config Changes

**FILE:** `android/app/build.gradle.kts`
```kotlin
android {
    namespace = "com.example.frontend_flutter_pos"
    defaultConfig {
        applicationId = "com.example.frontend_flutter_pos"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")  // TODO comment already in the file
        }
    }
}
```
**SETTING:** `namespace` / `applicationId`
**CURRENT:** `com.example.frontend_flutter_pos` (Flutter's default placeholder — untouched since `flutter create`)
**TARGET:** a real reverse-domain ID, e.g. `com.kaknnea.pos`
**WHY:** the placeholder works for local `flutter run` but must be a real, unique ID before any Play Store upload; changing it later (after installs exist) is painful, so decide it now.

**SETTING:** `buildTypes.release.signingConfig`
**CURRENT:** signs with the **debug** keystore (`signingConfigs.getByName("debug")`) — confirmed directly in this file.
**TARGET:** a real release keystore (full signing setup is Day 20's job — today, just know this line exists and why `flutter build apk --release` today produces an unsigned-for-store output).
**WHY:** Play Store rejects debug-signed uploads.

**FILE:** `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
<application android:usesCleartextTraffic="true" ...>
```
**KEY/PERMISSION:** `INTERNET`, `CAMERA` already present — no change needed today (Day 8 needs `CAMERA`, already here; Day 16 adds Bluetooth permissions, not here yet).
**`usesCleartextTraffic="true"`**: already set — needed because the dev backend is plain `http://`, not `https://`. Leave this as-is for development; revisit for a production backend that's HTTPS-only (out of scope for this plan).
**`android:required="true"` on the camera `<uses-feature>`**: this hides your app from the Play Store on any device without a camera. Decide deliberately: if you want the app installable on camera-less tablets too, change to `android:required="false"` — this is a product decision, not a technical default to accept blindly.

**FILE:** `ios/Runner.xcodeproj/project.pbxproj`
```text
PRODUCT_BUNDLE_IDENTIFIER = com.example.frontendFlutterPos;   (×3: Debug/Release/Profile)
IPHONEOS_DEPLOYMENT_TARGET = 13.0;                              (×3)
```
**SETTING:** `PRODUCT_BUNDLE_IDENTIFIER`
**CURRENT:** `com.example.frontendFlutterPos` (placeholder, appears 3 times — Debug, Release, Profile build configs — must be changed in all 3, plus once more for the `.RunnerTests` target)
**TARGET:** match your Android choice in reverse-domain style, e.g. `com.kaknnea.pos`
**WHY:** same reasoning as Android — App Store Connect requires a real, registered bundle ID.

**FILE:** `ios/Runner/Info.plist`
**CURRENT:** no `NSCameraUsageDescription`, `NSBluetoothAlwaysUsageDescription`, or `NSLocalNetworkUsageDescription` keys exist yet (confirmed by reading the file — it has only the default Flutter template keys). **Do not add these today** — add each on the day that introduces the feature needing it (Day 8, Day 16, Day 15 respectively), so each permission's purpose string is written while you have the feature fresh in mind.

## I. What Should Be Shared vs Mobile-Only?

```text
Entire lib/ tree
🟢 KEEP EXACTLY — today only touches android/ and ios/ folders

android/app/build.gradle.kts applicationId, ios PRODUCT_BUNDLE_IDENTIFIER
🟠 SMALL ADAPTATION — change once, from placeholder to real ID
```

## J. Build Order Inside the Day

1. Open `android/app/build.gradle.kts`. Change `namespace` and `applicationId` together (they must match) to your chosen real ID.
2. Open `ios/Runner.xcodeproj/project.pbxproj` in Xcode (easier than hand-editing raw pbxproj text) — Runner target → Signing & Capabilities → change Bundle Identifier for all three configs.
3. Update `android:label` in `AndroidManifest.xml` and `CFBundleDisplayName` in `Info.plist` to the real app display name.
4. `flutter run -d android` — fix any build errors (check each printing/scanner plugin's own `pubspec.yaml`/README for its stated `minSdk` floor if the build fails on that).
5. `flutter run -d ios` — fix any build errors.
6. Confirm both reach `LoginScreen` with correct fonts (`NotoSans`/`NotoSansKhmer` from `pubspec.yaml`'s `fonts:` block — no Android/iOS-specific font config needed, Flutter handles this identically on both).

## K–O

Not applicable in the usual sense today — "test" is simply: does `flutter run -d android` / `-d ios` succeed and show `LoginScreen`.

## Definition of Done

`flutter run -d android` and `flutter run -d ios` both reach `LoginScreen` with the real (not placeholder) application ID / bundle ID, correct fonts, correct app name.

## What I Should Understand Before Day 3

That `android/` and `ios/` are pure packaging metadata — nothing in them can call a Dart function, and nothing in `lib/` needs to know these files exist. This separation is why Day 3 onward can go right back to being 100% Dart work.

---

# Day 3 — Localization: The Exact Key → Widget Chain

## A. Where Do I Start?

Open `l10n.yaml` at the repo root (not under `lib/`). It's four lines and tells you everything about how translation works in this project before you open a single `.dart` file.

## B. Existing Web Function Chain — key to widget

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/generated
nullable-getter: false
```

`lib/l10n/app_en.arb` (source strings, English):
```json
"authLogin": "Login",
"formEmail": "Email",
"authPassword": "Password",
"authLoginFailed": "Login failed"
```

`lib/l10n/app_km.arb` (source strings, Khmer):
```json
"authLogin": "ចូលប្រើប្រាស់",
"formEmail": "អ៊ីមែល",
"authPassword": "ពាក្យសម្ងាត់",
"authLoginFailed": "ការចូលប្រើប្រាស់បរាជ័យ"
```

Running `flutter gen-l10n` (or just `flutter run`/`flutter build`, which triggers it automatically because `pubspec.yaml` has `flutter: generate: true`) reads both `.arb` files and writes `lib/l10n/generated/app_localizations.dart`:
```dart
abstract class AppLocalizations {
  /// In en, this message translates to: **'Login'**
  String get authLogin;
}
```
and the concrete per-language override, `lib/l10n/generated/app_localizations_en.dart`:
```dart
class AppLocalizationsEn extends AppLocalizations {
  @override
  String get authLogin => 'Login';
}
```
(and the matching `_km.dart` file returns the Khmer string). `AppLocalizations.of(context)` (wired up via the `localizationsDelegates` list in `main.dart`, Day 1) picks the right concrete subclass based on `MaterialApp.locale`, which is `ref.watch(appLanguageProvider).toLocale()`.

Real usage site (`category_management_screen.dart`):
```dart
Text(context.l10n.navCategories)
```
where `context.l10n` is defined in full in `lib/core/utils/l10n_extensions.dart` (the entire file, 8 lines):
```dart
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

**Where does the app know which language to use?** `lib/core/providers/language_provider.dart`:
```dart
class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.en) { _loadPreference(); }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language');
    state = (saved == AppLanguage.km.name) ? AppLanguage.km : AppLanguage.en;
  }

  Future<void> setLanguage(final AppLanguage language) async {
    state = language;                                    // synchronous — triggers rebuild immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', language.name); // persistence happens after, non-blocking
  }
}
```
`state = language` is what makes every `ref.watch(appLanguageProvider)` consumer (including `main.dart`'s `MaterialApp.locale`) rebuild — the `await prefs.setString(...)` line that follows is fire-and-forget from the UI's perspective; the rebuild already happened.

## C. Backend/API Chain

None — localization is entirely client-side/static, no network call.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `core/providers/language_provider.dart` | `AppLanguageNotifier` | `setLanguage` | `AppLanguage` | `Future<void>` | Call unchanged from a mobile language toggle |
| `core/utils/l10n_extensions.dart` | `L10nX` (extension) | `l10n` (getter) | — | `AppLocalizations` | Use `context.l10n.xyz` in every new mobile widget exactly as existing screens do |
| `core/providers/theme_provider.dart` | `ThemeModeNotifier` | `toggle`/`setLight`/`setDark` | — | `void` | Reuse for a mobile dark-mode toggle |

## E. Exact New Mobile Files to Create

None — no new provider/service needed. If you add a language-toggle widget, it's small enough to live inline in `mobile_settings_screen.dart` (Day 19) rather than as its own file — this matches how `settings_modules_screen.dart` does it today (an inline `SegmentedButton`, not a separate widget file).

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// Inside mobile_settings_screen.dart, or wherever your mobile shell puts a language toggle:
class MobileLanguageToggle extends ConsumerWidget {
  const MobileLanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);
    return SegmentedButton<AppLanguage>(
      segments: const [
        ButtonSegment(value: AppLanguage.en, label: Text('EN')),
        ButtonSegment(value: AppLanguage.km, label: Text('KM')),
      ],
      selected: {current},
      onSelectionChanged: (selected) {
        ref.read(appLanguageProvider.notifier).setLanguage(selected.first);
        // STEP: nothing else needed — MaterialApp.locale watches this provider already.
      },
    );
  }
}
```

## G. Function Inputs and Outputs

`setLanguage(AppLanguage language)`
INPUT: `AppLanguage.km`
DOES: sets `state` synchronously (triggers every watcher's rebuild) → then persists to `SharedPreferences['app_language']`
OUTPUT: `Future<void>`
CALLER: any widget's `onPressed`/`onSelectionChanged`
NEXT: `MaterialApp.locale` re-evaluates → `AppLocalizations.of(context)` returns the Khmer subclass → every `context.l10n.xyz` call site re-renders with Khmer strings, with zero manual widget-level work.

## H. State Before and After

BEFORE:
```text
appLanguageProvider state = AppLanguage.en
```
Call: `ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.km)`
AFTER:
```text
appLanguageProvider state = AppLanguage.km
SharedPreferences['app_language'] = 'km'
```
Then: `ref.watch(appLanguageProvider)` anywhere in the widget tree (including `main.dart`) causes a rebuild; `MaterialApp.locale` changes; all `context.l10n.*` getters now resolve to `AppLocalizationsKm`.

## I. What Should Be Shared vs Mobile-Only?

```text
AppLanguageNotifier / appLanguageProvider
🟢 KEEP EXACTLY

ThemeModeNotifier / themeModeProvider
🟢 KEEP EXACTLY

app_en.arb / app_km.arb / generated AppLocalizations
🟢 KEEP EXACTLY

A visible language-toggle widget
🔵 NEW MOBILE UI (small — can be inline, not a new file)
```

## J. Build Order Inside the Day

1. Open `l10n.yaml`, confirm you understand the 4 config lines.
2. Open `lib/l10n/app_en.arb`, search for 3–4 keys you recognize (e.g. `authLogin`, `commonSave`).
3. Open `lib/l10n/app_km.arb`, find the same 3–4 keys, confirm they exist.
4. Open `lib/l10n/generated/app_localizations.dart`, search for one of those keys, see the abstract getter.
5. Open `lib/core/utils/l10n_extensions.dart`, read all 8 lines.
6. Open `lib/core/providers/language_provider.dart`, read `AppLanguageNotifier` fully.
7. Build a minimal placeholder `MaterialApp` shell (or reuse the real one once Day 5 exists) with one `Text(context.l10n.someKey)` and a language toggle.
8. Run it, switch EN↔KM, confirm the text changes and Khmer renders in `NotoSansKhmer` without tofu boxes.
9. Switch `themeModeProvider` light↔dark, confirm `PosTheme.darkTheme` colors apply.

## K. "When I Click This, What Happens?"

# Toggle language
```text
Tap "KM" segment
↓
ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.km)
↓
state = AppLanguage.km  (synchronous)
↓
every ref.watch(appLanguageProvider) widget rebuilds
↓
MaterialApp.locale = AppLanguage.km.toLocale()
↓
context.l10n.* now resolves via AppLocalizationsKm
↓
(async, non-blocking) SharedPreferences.setString('app_language', 'km')
```

## L. "Where Does This Value Come From?"

A translated label, e.g. "Login" / "ចូលប្រើប្រាស់":
```text
lib/l10n/app_en.arb["authLogin"] / app_km.arb["authLogin"]
↓ (flutter gen-l10n)
AppLocalizationsEn.authLogin / AppLocalizationsKm.authLogin (generated getters)
↓
AppLocalizations.of(context)  (delegate resolves by MaterialApp.locale)
↓
context.l10n.authLogin
↓
Text(context.l10n.authLogin)
```

## M. Navigation Flow

None — language toggle doesn't navigate anywhere, it just triggers a rebuild in place.

## N. Error Flow

If `SharedPreferences.getInstance()` fails during `_loadPreference()` (extremely rare — only on a corrupted platform storage), the `AppLanguageNotifier` constructor's `super(AppLanguage.en)` already set a safe default before the async `_loadPreference()` even runs, so the app never ends up in a broken/undefined language state — worth understanding as a "fails safe by construction" pattern, not defensive code you need to add yourself.

## O. Test Flow

No dedicated automated test found for `AppLanguageNotifier` in the existing suite — this is a real, pre-existing gap (not mobile-specific). Manual test:
```text
1. Launch app, confirm default is English.
2. Toggle to Khmer.
3. Confirm every visible string changes, no tofu boxes.
4. Restart the app (cold start).
5. Confirm it remembers Khmer (SharedPreferences persistence worked).
```

## What I Should Understand Before Day 4

That adding a new UI string anywhere in this app is a 3-step ritual: add the key to `app_en.arb`, add the same key to `app_km.arb`, run `flutter gen-l10n` (or just `flutter run`), then use `context.l10n.yourNewKey`. You'll do this repeatedly from Day 4 onward for every new mobile screen — never hard-code a UI string.

---

# Day 4 — Login: The Complete Function-by-Function Chain

## A. Where Do I Start?

Open `lib/features/auth/screens/login_screen.dart`. Find `_login()`. This is the one function that starts the entire chain — read it first, then follow it outward.

## B. Existing Web Function Chain — every hop, real code

**Hop 1 — `LoginScreen._login()`** (full body):
```dart
Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;
  try {
    await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
    if (mounted) Navigator.of(context).pushReplacementNamed('/pos');
  } catch (error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.authLoginFailed}: $error')),
      );
    }
  }
}
```
**Important, non-obvious fact**: this `catch` block is effectively dead code for real login failures. Keep reading — hop 2 explains why.

**Hop 2 — `AuthNotifier.login()`** (`core/providers/auth_provider.dart`, full body):
```dart
Future<void> login(final String email, final String password, {final String? terminalId}) async {
  state = const AsyncValue.loading();
  try {
    final authResponse = await _authService.login(email, password, terminalId: terminalId);
    state = AsyncValue.data(authResponse.user);
  } catch (error, stackTrace) {
    state = AsyncValue.error(error, stackTrace);   // <-- swallowed here, NEVER rethrown
  }
}
```
This is why hop 1's `catch` rarely fires: `AuthNotifier.login` catches its own errors and puts them into Riverpod state (`AsyncValue.error`) instead of rethrowing. `LoginScreen._login()`'s `try/catch` around this call only catches something that throws *synchronously outside* `login()`'s own try block — which essentially never happens in practice. **The real failure UX comes from somewhere that watches `authProvider`'s error state** — if you build a mobile login screen, decide explicitly whether to also `ref.watch(authProvider)` for the error case, rather than relying on this `catch` the way the code visually suggests you can.

**Hop 3 — `AuthService.login()`** (`core/services/auth_service.dart`, full body):
```dart
Future<AuthResponse> login(final String email, final String password, {final String? terminalId}) async {
  final request = LoginRequest(email: email, password: password, terminalId: terminalId);
  final response = await _apiService.post<Map<String, dynamic>>(
    '/api/auth/login',
    data: request.toJson(),
  );
  final authResponse = AuthResponse.fromJson(response);
  await _saveAuthData(authResponse);
  return authResponse;
}

Future<void> _saveAuthData(final AuthResponse authResponse) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(AppConfig.authTokenKey, authResponse.token);         // key: 'auth_token'
  await prefs.setString(AppConfig.userKey, json.encode(authResponse.user.toJson())); // key: 'user_data'
}
```

**Hop 4 — `ApiService.post<T>()`** (`core/services/api_service.dart`):
```dart
Future<T> post<T>(final String path, {final Object? data, ...}) async {
  try {
    final response = await _dio.post(path, data: data, queryParameters: queryParameters);
    return fromJson != null ? fromJson(response.data) : response.data as T;
  } on DioException catch (e) {
    throw _handleError(e);
  }
}
```
Before this request is sent, the auth interceptor's `onRequest` runs (attaches a stale `Authorization` header if one exists — harmless for login, backend ignores it):
```dart
onRequest: (options, handler) async {
  final token = await _getAuthToken();
  if (token != null) options.headers['Authorization'] = 'Bearer $token';
  handler.next(options);
},
```

**Hop 5 — the wire**: `POST {AppConfig.apiBaseUrl}/api/auth/login` with JSON body `{"email": ..., "password": ..., "terminalId": ...}`.

## C. Backend/API Chain

```text
POST /api/auth/login
↓
AuthController.login(@Valid @RequestBody LoginRequest request, HttpServletRequest http)
    -> authService.login(request, http.getRemoteAddr(), http.getHeader("User-Agent"))
↓
AuthService.login(request, ip, userAgent)                    [backend, service/AuthService.java]
    userRepository.findByEmail(email)                        -> Optional<User>
    check: lockoutUntil, active, passwordEncoder.matches(password, user.getPasswordHash())
    on failure: increment failedLoginAttempts, lock 15 min after 5 fails, throw ApiException("Invalid credentials")
    on success: reset counters, update lastLoginAt/lastLoginTerminal, upsert Device row
    roles/permissions computed (OWNER/ADMIN/SYSTEM_ADMIN implicitly get ALL permissions)
↓
JwtUtil.generateToken(subject, roles, permissions)
    Jwts.builder().setIssuer(issuer).setSubject(email).setExpiration(now + accessTokenMinutes)
        .addClaims({roles, permissions}).signWith(key, HS256).compact()
↓
UserRepository (JpaRepository<User,Long>)
    Optional<User> findByEmail(String email);
↓
User entity (domain/User.java, table "users")
    email, passwordHash, fullName, active, failedLoginAttempts, lockoutUntil, roles: Set<Role>
↓
AuthDtos.LoginResponse{ token: String, user: UserResponse{id, email, fullName, roles, permissions} }
↓ (back over HTTP as JSON)
AuthResponse.fromJson(response)   [Flutter — field names token/user/id/email/fullName/roles/permissions
                                    line up exactly with the backend DTO, confirmed no mismatches]
```
**Status codes**: 200 on success (no `@ResponseStatus` — plain body return). 400 via `ApiException` for bad credentials, locked account, inactive account, or `@Valid` failures (empty email/password). 401 is never returned by this endpoint itself — 401 only ever comes from *later* requests when the JWT expires or is missing, handled by `ApiService`'s `onError` interceptor (see Day 1 chain).

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `core/providers/auth_provider.dart` | `AuthNotifier` | `login` | `(String, String, {String? terminalId})` | `Future<void>` | Call unchanged from `MobileLoginScreen._login()` |
| `core/providers/auth_provider.dart` | `AuthNotifier` | `logout` | — | `Future<void>` | Call unchanged from a mobile logout button |
| `core/services/auth_service.dart` | `AuthService` | `getCurrentUser` | — | `Future<User?>` | Reuse if you need the cached user outside auth state |
| `core/models/auth_models.dart` | `User`, `AuthResponse`, `LoginRequest` | — | — | — | Reuse unchanged; do not create mobile-specific auth models |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_login_screen.dart
```
PURPOSE: phone-sized login form, full-screen, larger touch targets than the desktop `LoginScreen`.
CLASS: `MobileLoginScreen extends ConsumerStatefulWidget`
USES PROVIDER: `authProvider` (via `ref.read(authProvider.notifier).login(...)`, and optionally `ref.watch(authProvider)` for the error/loading UI — see hop 2's warning above)
CALLS FUNCTION: `AuthNotifier.login(email, password)`
RETURNS/NAVIGATES TO: on success, whatever your mobile shell's post-login destination is (Day 5's `MobileHomeShell`, via `Navigator.pushReplacementNamed`)

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
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
    // STEP 1: call the EXISTING notifier — do not reimplement auth logic here.
    await ref.read(authProvider.notifier).login(_emailCtl.text.trim(), _passwordCtl.text.trim());
    // STEP 2: because AuthNotifier.login never rethrows (see section B, hop 2),
    // check the resulting state directly instead of relying on a try/catch:
    final state = ref.read(authProvider);
    if (state.hasError) {
      // show mobile-appropriate error UI
      return;
    }
    if (mounted) Navigator.of(context).pushReplacementNamed('/mobile-home'); // Day 5 route
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(children: [
          // STEP 3: email/password TextFormFields, same validators as LoginScreen
          // STEP 4: submit button, disabled while authState.isLoading
          ElevatedButton(
            onPressed: authState.isLoading ? null : _login,
            child: authState.isLoading
                ? const CircularProgressIndicator()
                : Text(context.l10n.authLogin),
          ),
        ]),
      ),
    );
  }
}
```

## G. Function Inputs and Outputs

`AuthNotifier.login(String email, String password, {String? terminalId})`
INPUT:
```text
email = "owner@kaknnea.local"
password = "Password123!"
terminalId = null
```
DOES:
```text
state = loading
-> AuthService.login(email, password)
-> POST /api/auth/login
-> parse AuthResponse
-> save token + user to SharedPreferences
-> state = data(user)  [or state = error(e) — never rethrown]
```
OUTPUT: `Future<void>` (the *result* is observed via `ref.watch(authProvider)`, not via a return value)
CALLER: `MobileLoginScreen._login()`
NEXT: caller must check `ref.read(authProvider)` for success/error, then navigate.

## H. State Before and After

BEFORE:
```text
authProvider state = AsyncValue.data(null)
SharedPreferences: no 'auth_token', no 'user_data'
```
Call: `ref.read(authProvider.notifier).login('owner@kaknnea.local', 'Password123!')`
AFTER (success path):
```text
authProvider state = AsyncValue.data(User(id: 1, email: 'owner@kaknnea.local', roles: [...]))
SharedPreferences['auth_token'] = '<jwt>'
SharedPreferences['user_data'] = '{"id":1,"email":...}'
```
AFTER (failure path):
```text
authProvider state = AsyncValue.error(ApiException('Invalid credentials'), stackTrace)
SharedPreferences: unchanged (never written on failure)
```
Then: `PosApp`/`MobileHomeShell`'s `ref.watch(authProvider)` rebuilds either way.

## I. What Should Be Shared vs Mobile-Only?

```text
AuthNotifier.login / AuthService.login / ApiService.post
🟢 KEEP EXACTLY

User / AuthResponse / LoginRequest models
🟢 KEEP EXACTLY

LoginScreen (desktop widget)
🔴 DO NOT COPY — build MobileLoginScreen fresh, same logic calls

MobileLoginScreen
🔵 NEW MOBILE UI
```

## J. Build Order Inside the Day

1. Open `core/providers/auth_provider.dart`. Read `AuthNotifier` fully (constructor, `_initializeAuth`, `login`, `logout`, `refreshUser`).
2. Open `core/services/auth_service.dart`. Read `login`, `_saveAuthData`, `getToken`, `getCurrentUser`.
3. Open `core/services/api_service.dart`. Read `post<T>` and the auth interceptor's `onRequest`/`onError`.
4. Open `features/auth/screens/login_screen.dart`. Read `_login()` and understand the dead-catch subtlety from section B.
5. Decide (document your decision): plain `SharedPreferences` (matches existing code exactly) vs. `flutter_secure_storage` (better for mobile Keychain/Keystore, but a new dependency and a new code path inside `AuthService`).
6. If adopting secure storage: change only `_saveAuthData`, `getToken`, `logout`'s internals in `AuthService` — keep every method signature identical so nothing above it (namely `AuthNotifier`) needs to change.
7. Extend `AppConfig.baseUrl` (or convert to `--dart-define`) for physical-device LAN access — see `core/config/app_config.dart`'s existing `kIsWeb`/`defaultTargetPlatform` branches, add a fallback for physical devices.
8. Create `lib/features/pos/mobile/screens/mobile_login_screen.dart` using the skeleton in section F.
9. Wire it as the `LoginScreen()` replacement wherever your mobile `home:`/routing points (coordinate with Day 5).
10. Run on an Android emulator: confirm login round-trips against `10.0.2.2:8081` (unchanged `AppConfig` logic).
11. Run on a physical device on the same Wi-Fi as your dev machine, using your new LAN-IP config; confirm login succeeds.

## K. "When I Click This, What Happens?"

# Tap "Login"
```text
Tap LOGIN
↓
_formKey.currentState!.validate()
↓ (if valid)
ref.read(authProvider.notifier).login(email, password)
↓
state = AsyncValue.loading()  -> button disables, shows spinner
↓
AuthService.login() -> POST /api/auth/login
↓ (success)
state = AsyncValue.data(user)
↓
caller checks ref.read(authProvider), sees no error
↓
Navigator.pushReplacementNamed(mobile home route)
```

# Tap "Login" with wrong password
```text
Tap LOGIN
↓
AuthNotifier.login() -> AuthService.login() -> POST /api/auth/login
↓
Backend: passwordEncoder.matches fails -> ApiException("Invalid credentials") -> HTTP 400
↓
ApiService.post's DioException catch -> _handleError(e) -> throw ApiException
↓
AuthNotifier's catch block: state = AsyncValue.error(e, stackTrace)   [NOT rethrown]
↓
button's authState.isLoading becomes false again (state is no longer .loading)
↓
YOUR mobile screen must explicitly check ref.read(authProvider).hasError to show a message —
this does NOT happen automatically, and LoginScreen's own SnackBar catch block does NOT fire here.
```

## L. "Where Does This Value Come From?"

The `User` object shown after login (e.g. in a profile menu):
```text
Backend AuthDtos.UserResponse{id, email, fullName, roles, permissions}
↓
AuthResponse.fromJson(response)['user']
↓
User.fromJson(...)  (core/models/auth_models.dart)
↓
AuthNotifier.state = AsyncValue.data(user)
↓
ref.watch(currentUserProvider)  (a convenience Provider<User?> reading authProvider)
↓
displayed in UI
```

## M. Navigation Flow

`LoginScreen` uses `Navigator.of(context).pushReplacementNamed('/pos')` — `pushReplacement`, not `push`, so the user can't navigate "back" to the login screen after authenticating. Your `MobileLoginScreen` should do the same (`pushReplacementNamed` to your mobile home route), for the same reason.

## N. Error Flow

```text
API succeeds
→ AuthNotifier.state = AsyncValue.data(user)
→ UI reads ref.watch(authProvider), sees .data, proceeds

API fails (bad credentials, network error, timeout)
→ ApiService._handleError(DioException) maps it to an ApiException with a message
→ AuthNotifier's own catch swallows it into AsyncValue.error(error, stackTrace) — does NOT rethrow
→ LoginScreen's try/catch around the login() call does NOT catch this (see section B hop 2)
→ the ONLY correct way to detect failure is checking authProvider's state after the await completes
→ existing LoginScreen's SnackBar is effectively unreachable for real backend failures — a known,
   pre-existing subtlety in this codebase, not a mobile-specific bug to "fix" silently; just be aware
   of it when you write MobileLoginScreen's own error handling (see section F's skeleton, step 2)
```

## O. Test Flow

Existing test: `test/auth_provider_test.dart` (tests `AuthNotifier` directly, not the UI — should pass unmodified since you haven't touched `AuthNotifier`).
```bash
flutter test test/auth_provider_test.dart
```
Manual test:
```text
1. Launch app on Android emulator, land on MobileLoginScreen.
2. Enter correct credentials, tap Login.
3. Confirm navigation to mobile home.
4. Kill and relaunch app — confirm still logged in (token persisted, AuthNotifier._initializeAuth restores session).
5. Enter wrong password, tap Login.
6. Confirm your mobile error UI shows (not a silent failure).
7. Repeat steps 1-6 on a physical device over LAN IP.
```

## What I Should Understand Before Day 5

That there is no refresh-token endpoint on the backend (`AuthController` only exposes `/login`, `/request-reset`, `/reset`, `/change-password` — confirmed by grep) and the JWT is valid for `app.jwt.access-token-minutes: 720` (12 hours). Your mobile session will simply expire after 12 hours with no silent renewal — `ApiService`'s `onError` interceptor will catch the resulting 401 and call `onUnauthorized` (wired to `logout()`), which is the *existing* behavior you're inheriting, not something to build.

---

# Day 5 — Mobile Navigation Shell: Exact Routes, Exact Changes

## A. Where Do I Start?

Open `lib/features/pos/screens/_pos_drawer.dart`. This one file is the complete map of every destination in the app today — read it before writing a single line of mobile navigation code.

## B. Existing Web Function Chain

`_pos_drawer.dart`'s `PosDrawer` (a `ConsumerWidget`) renders `ListTile`s whose `onTap` calls `Navigator.pushNamed(context, '/$route')` for a route string. The full destination list, copied from the drawer's own menu items (confirmed against `main.dart`'s `routes` map from Day 1):

```text
Register            -> /pos
Held Tickets        -> /open-tickets
Inventory Management (expandable):
  Stock Lookup        -> /inventory
  Purchase Orders     -> /purchase-orders
  Transfer Orders     -> /transfer-orders
  Stock Adjustments   -> /stock-adjustments
  Inventory Counts    -> /inventory-counts
  Productions         -> /productions
  Suppliers           -> /suppliers
  Inventory History   -> /inventory-history
  Inventory Valuation -> /inventory-valuation
Receipts             -> /receipts
Reports (expandable):
  Sales Summary         -> /report-sales-summary
  Sales by Item          -> /report-sales-by-item
  Sales by Category      -> /report-sales-by-category
  Sales by Employee       -> /report-sales-by-employee
  Sales by Payment Type   -> /report-sales-by-payment-type
  Receipts                -> /report-receipts
  Sales by Modifier        -> /report-sales-by-modifier
  Discounts                -> /report-discounts
  Taxes                    -> /report-taxes
Items (expandable):
  Item List   -> /items
  Add Item    -> /add-item
  Categories  -> /categories
  Modifiers   -> /modifiers
  Units       -> /units
Employees (expandable):
  Employees List -> /employeelist
  User Account   -> /useraccount
  Role           -> /accessRole
  Permission     -> /permission
Customers (expandable):
  Customer List -> /customers
  Add Customer  -> /add-customer
Tables (expandable):
  Table List -> /tables
  Add Table  -> /add-table
Shifts (expandable):
  Manage Shift  -> /shifts
  Shift History -> /shift-history
Settings -> /settings
Logout -> confirmation dialog -> authProvider.notifier.logout() -> /login
```
Every one of these route strings has a matching entry in `main.dart`'s `routes` map (Day 1) — **the destinations are the routing surface; the drawer is just one way to reach them.**

## C. Backend/API Chain

None — navigation itself makes no network call.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `main.dart` | `PosApp` | `routes` map | — | `Map<String,WidgetBuilder>` | Keep every entry; only what widget "POS"/home resolves to changes |
| `core/providers/auth_provider.dart` | `AuthNotifier` | `logout` | — | `Future<void>` | Reuse unchanged for a mobile logout action |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_home_shell.dart
```
PURPOSE: bottom-navigation shell wrapping the same route targets the drawer used.
CLASS: `MobileHomeShell extends ConsumerStatefulWidget` (needs `StatefulWidget` because bottom-nav needs a "current index")
USES PROVIDER: none directly for navigation itself (may watch `authProvider` if you want a logout action inline)
CALLS FUNCTION: `Navigator.pushNamed(context, routeString)` — same mechanism the drawer already uses
RETURNS/NAVIGATES TO: any of the ~40 routes from section B

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
class MobileHomeShell extends StatefulWidget {
  const MobileHomeShell({super.key});
  @override
  State<MobileHomeShell> createState() => _MobileHomeShellState();
}

class _MobileHomeShellState extends State<MobileHomeShell> {
  int _index = 0;

  // STEP 1: same route strings the drawer already uses — do not invent new ones.
  static const _primaryDestinations = [
    ('/pos', Icons.point_of_sale),
    ('/open-tickets', Icons.receipt_long),
    ('/inventory', Icons.inventory_2),
    ('/reports', Icons.bar_chart),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // STEP 2: body swaps based on _index, OR each tab pushes via Navigator — pick one pattern and
      // stay consistent; pushing (like the drawer does today) is simpler to reason about for Day 1.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i < _primaryDestinations.length) {
            Navigator.pushNamed(context, _primaryDestinations[i].$1);
          } else {
            // "More" tab -> full-screen menu listing every other drawer destination
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileMoreMenu()));
          }
        },
        destinations: [
          for (final d in _primaryDestinations) NavigationDestination(icon: Icon(d.$2), label: ''),
          const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
```

## G. Function Inputs and Outputs

`Navigator.pushNamed(BuildContext context, String routeName)`
INPUT: `context`, `'/inventory'`
DOES: looks up `'/inventory'` in `main.dart`'s `routes` map → finds `(context) => const InventoryHubScreen()` → builds and pushes it
OUTPUT: `Future<T?>` (result if the pushed screen pops with a value — usually unused for simple navigation)
CALLER: any `onTap`/`onDestinationSelected` handler
NEXT: `InventoryHubScreen` (existing, unchanged) builds — see Day 17 for what it does.

## H. State Before and After

Not applicable — navigation doesn't mutate Riverpod state by itself (individual destination screens manage their own state once built, as covered in later days).

## I. What Should Be Shared vs Mobile-Only?

```text
main.dart's routes: map (all ~40 entries)
🟢 KEEP EXACTLY

PosDrawer widget itself
🔴 DO NOT COPY — permanent-sidebar pattern, wrong for phone width

MobileHomeShell / MobileMoreMenu
🔵 NEW MOBILE UI
```

## J. Build Order Inside the Day

1. Open `_pos_drawer.dart`. List every route string it references (cross-check against section B above).
2. Open `main.dart`'s `routes` map. Confirm every drawer route string has a matching entry (it does — do this as a verification exercise, not blind trust).
3. Create `lib/features/pos/mobile/screens/mobile_home_shell.dart` using the skeleton in section F.
4. Pick 4–5 highest-frequency destinations for the bottom nav (recommend: POS, Held Tickets, Inventory, Reports, More).
5. Create `MobileMoreMenu` (a simple `ListView` of `ListTile`s, one per remaining route, reusing the exact same route strings).
6. Wire `MobileHomeShell` as the mobile equivalent of `PosApp`'s `home:` (Day 4's `MobileLoginScreen` should `pushReplacementNamed` to whatever route resolves to `MobileHomeShell`).
7. Test tapping every one of the 4–5 primary destinations, confirm it reaches the existing (still-desktop-styled, that's fine for now) screen.
8. Test the Android hardware back button and iOS swipe-back gesture don't fight the bottom nav's own tab-switch state.

## K. "When I Click This, What Happens?"

# Tap "Inventory" in bottom nav
```text
Tap Inventory icon
↓
onDestinationSelected(2)
↓
setState(() => _index = 2)
↓
Navigator.pushNamed(context, '/inventory')
↓
main.dart's routes['/inventory'] resolves to InventoryHubScreen
↓
InventoryHubScreen builds (existing screen, unchanged — Day 17 covers what's inside it)
```

## L. "Where Does This Value Come From?"

Not applicable this day — no data values displayed by the shell itself.

## M. Navigation Flow

```text
FROM: MobileHomeShell
ACTION: tap a bottom-nav destination
TO: whatever screen main.dart's routes map resolves that route string to
MECHANISM: Navigator.pushNamed (same mechanism _pos_drawer.dart already uses — not pushReplacementNamed,
           so the user CAN navigate back to the shell)
```

## N. Error Flow

If a route string is mistyped (e.g. `'/inventroy'`), `Navigator.pushNamed` throws at runtime with a clear "could not find route" Flutter error — there's no silent failure mode here, which is why section J step 2 (cross-checking every string against `main.dart`) matters.

## O. Test Flow

No existing automated test targets the drawer's navigation directly. Write a new widget test for `MobileHomeShell`:
```text
1. Pump MobileHomeShell wrapped in a MaterialApp with the real routes map.
2. Tap each bottom-nav destination.
3. Assert the expected screen type appears (e.g. find.byType(InventoryHubScreen)).
```
Manual test: tap every primary destination and every "More" menu item once, confirm no crashes, confirm back navigation returns to the shell.

## What I Should Understand Before Day 6

That "POS" as a bottom-nav destination today still points at the existing desktop `PosScreen` — that's fine and expected. Day 6 and 7 are what actually replace the *inside* of that destination with mobile-appropriate screens; Day 5 only replaced the *chrome around* getting there.

---

# Day 6 — Products: Load, Search, Filter, Load More, Select

## A. Where Do I Start?

Open `lib/features/pos/providers/product_provider.dart`. Read `ProductState` first (the shape of what you'll display), then `ProductNotifier` (the functions that populate it).

## B. Existing Web Function Chain

**`ProductState`** (every field):
```dart
class ProductState {
  final List<Product> products;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final int totalCount;
  final String? error;
}
```
**Known quirk, worth understanding before you rely on it**: `copyWith`'s `error` field uses `error ?? this.error` — so calling `copyWith(error: null)` does **not** clear a previous error (it falls back to the old value). `loadProducts` calls `copyWith(isLoading: true, error: null, ...)` at its start expecting to clear stale errors, but this line does not actually do that due to the quirk above. Not a mobile-specific bug — just something to know before you build UI that displays `state.error`.

**LOAD** — `ProductNotifier.loadProducts({String? query, int? categoryId})`:
```dart
static const int _pageSize = 48; // 4 cols × 12 rows per load

Future<void> loadProducts({String? query, int? categoryId}) async {
  _currentQuery = query;
  _currentCategoryId = categoryId;
  state = state.copyWith(isLoading: true, error: null, currentPage: 0, hasMore: true);
  try {
    final list = await _service.getProducts(query: query, categoryId: categoryId, page: 0, size: _pageSize);
    state = state.copyWith(products: List.of(list), isLoading: false,
        hasMore: list.length >= _pageSize, currentPage: 0, totalCount: list.length);
  } catch (e, st) {
    state = state.copyWith(isLoading: false, error: e.toString());
  }
}
```

**LOAD MORE** — `loadMore()`:
```dart
Future<void> loadMore() async {
  if (state.isLoadingMore || !state.hasMore) return;
  state = state.copyWith(isLoadingMore: true);
  final nextPage = state.currentPage + 1;
  try {
    final list = await _service.getProducts(query: _currentQuery, categoryId: _currentCategoryId, page: nextPage, size: _pageSize);
    final updatedProducts = [...state.products, ...list];
    state = state.copyWith(products: updatedProducts, isLoadingMore: false,
        hasMore: list.length >= _pageSize, currentPage: nextPage, totalCount: updatedProducts.length);
  } catch (e) {
    state = state.copyWith(isLoadingMore: false);   // note: no error shown for loadMore failures
  }
}
```

**SEARCH** — `searchProducts(String query)`:
```dart
Future<void> searchProducts(String query) async {
  await loadProducts(query: query.isEmpty ? null : query);
}
```
This has **no internal debounce** — it's a thin delegate to `loadProducts`. Debouncing is done entirely by the caller (see below).

**CATEGORY FILTER** — `filterByCategory(int? categoryId)`:
```dart
Future<void> filterByCategory(int? categoryId) async {
  await loadProducts(categoryId: categoryId);
}
```

**SELECT PRODUCT (barcode)** — `findByBarcode`:
```dart
Future<Product?> findByBarcode(String barcode) {
  return _service.findByBarcode(barcode);   // delegates straight to the service, does NOT touch state
}
```
(Full barcode flow is Day 8 — this is just the notifier-level piece.)

**Where the debounce actually lives** — `pos_screen.dart`'s `_PosAppBarState` (NOT a `TextField.onChanged` — a `TextEditingController` listener + `Timer`):
```dart
final TextEditingController _searchCtl = TextEditingController();
Timer? _searchDebounce;

@override
void initState() {
  super.initState();
  _searchCtl.addListener(_onSearchChanged);
}

void _onSearchChanged() {
  _searchDebounce?.cancel();
  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
    ref.read(productsProvider.notifier).searchProducts(_searchCtl.text.trim());
  });
}
```

**`ProductService.getProducts`** (`ApiProductService`, the actual HTTP call):
```dart
Future<List<Product>> getProducts({String? query, int? categoryId, int page = 0, int size = 100}) async {
  if (query == null && categoryId == null) {
    final resp = await _api.get<List<dynamic>>('/api/products/pos-catalog');   // flat, unpaginated
    return resp.cast<Map<String, dynamic>>().map((e) => Product.fromJson(e)).toList();
  }
  final params = <String, dynamic>{};
  if (query != null && query.isNotEmpty) params['q'] = query;
  if (categoryId != null) params['categoryId'] = categoryId;
  params['page'] = page;
  params['size'] = size;
  final resp = await _api.get<Map<String, dynamic>>('/api/products', queryParameters: params);
  return (resp['content'] as List).map((e) => Product.fromJson(e)).toList();
}
```
Two different endpoints depending on whether a query/filter is active — the initial POS grid load (no query, no category) hits the flat `/pos-catalog` endpoint; search/filter hits the paginated `/api/products`.

**Demo fallback** — every `ProductService` call actually goes through `_FallbackProductService` (`demo_product_service.dart`), which wraps every method in a generic try/catch:
```dart
Future<T> _tryApi<T>(Future<T> Function() apiCall, Future<T> Function() demoCall) async {
  try {
    return await apiCall();
  } catch (e) {
    return await demoCall();
  }
}
```
So a broken backend never surfaces as a visible error in the product grid — it silently shows 15 hardcoded demo products instead. `findByBarcode` is **not** separately overridden by the fallback wrapper, so it inherits the abstract `ProductService`'s default implementation (below), which itself calls `getProducts` — meaning barcode lookup also benefits from the same silent fallback.

**`ProductService.findByBarcode`** (abstract default, reused by any subclass that doesn't override it):
```dart
Future<Product?> findByBarcode(String barcode) async {
  final normalized = barcode.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  final matches = await getProducts(query: normalized, page: 0, size: 50);
  for (final product in matches) {
    if (product.barcode.trim().toLowerCase() == normalized) return product;
  }
  return null;
}
```

## C. Backend/API Chain

```text
GET /api/products/pos-catalog?storeId=   (initial load, no filters)
↓
ProductController.posCatalog(@RequestParam(required=false) Long storeId)
    -> productService.posCatalog(storeId)
↓
List<ProductDtos.ProductResponse>

---

GET /api/products?q=&categoryId=&page=&size=   (search/filter)
↓
ProductController.search(q, categoryId, active, sellable, stockTracked, purchasable, storeId, productType, page, size)
    -> productService.search(...) -> Page<ProductDtos.ProductResponse>
↓
(Flutter unwraps resp['content'] — matches the Spring Page JSON shape: {content: [...], totalElements, ...})
```
Note: the backend's `search` endpoint accepts several filters (`active`, `sellable`, `stockTracked`, `purchasable`, `storeId`, `productType`) that the Flutter client never sends — available for future use, not currently exercised.

Categories: `GET /api/categories` → `CategoryController.list()` → `List<CategoryDtos.CategoryResponse>`.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `providers/product_provider.dart` | `ProductNotifier` | `loadProducts` | `({String? query, int? categoryId})` | `Future<void>` | Initial grid load |
| `providers/product_provider.dart` | `ProductNotifier` | `loadMore` | — | `Future<void>` | Infinite scroll |
| `providers/product_provider.dart` | `ProductNotifier` | `searchProducts` | `String` | `Future<void>` | Search bar (with your own debounce Timer, mirroring `_PosAppBarState`) |
| `providers/product_provider.dart` | `ProductNotifier` | `filterByCategory` | `int?` | `Future<void>` | Category tab tap |
| `providers/category_provider.dart` | — | `categoriesProvider` | — | `AsyncValue<List<Category>>` | Category tabs data source |
| `widgets/category_tabs.dart` | `CategoryTabs` | — | — | — | Reuse as-is (has horizontal/vertical modes already) |
| `widgets/product_card.dart` | `ProductCard` | — | — | — | Reuse as-is (sizing follows grid column count) |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/widgets/mobile_product_grid.dart
lib/features/pos/mobile/widgets/mobile_product_search_bar.dart
```
PURPOSE (`mobile_product_grid.dart`): responsive `GridView` replacing `product_grid.dart`'s hard-coded `_fixedColumns = 5`.
CLASS: `MobileProductGrid extends ConsumerWidget`
USES PROVIDER: `productsProvider`
CALLS FUNCTION: `ProductNotifier.loadMore()` on scroll-near-bottom
RETURNS/NAVIGATES TO: on tap, opens `ProductModifierSheet` exactly like `pos_screen.dart` does (Day 7 wires the result into cart)

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
class MobileProductGrid extends ConsumerStatefulWidget {
  const MobileProductGrid({super.key});
  @override
  ConsumerState<MobileProductGrid> createState() => _MobileProductGridState();
}

class _MobileProductGridState extends ConsumerState<MobileProductGrid> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // STEP 1: same "200px from bottom" pattern product_grid.dart already uses.
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(productsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    // STEP 2: responsive column count — the one real change from the desktop grid.
    final columns = (MediaQuery.of(context).size.width / 160).floor().clamp(2, 6);
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns),
      itemCount: state.products.length,
      itemBuilder: (context, i) {
        final product = state.products[i];
        return ProductCard(
          product: product,
          onTap: () async {
            // STEP 3: same modifier-sheet flow pos_screen.dart uses — see Day 7.
            final result = await showModalBottomSheet<CartItem>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ProductModifierSheet(product: product),
            );
            if (result != null) ref.read(cartProvider.notifier).addItem(result);
          },
        );
      },
    );
  }
}
```

## G. Function Inputs and Outputs

`ProductNotifier.searchProducts(String query)`
INPUT: `query = "coca"`
DOES: `await loadProducts(query: "coca")` — resets `currentPage` to 0, `hasMore` to true, fetches page 0 with the query.
OUTPUT: `Future<void>` (result observed via `state.products`)
CALLER: your mobile search bar's debounce `Timer` callback (300ms, mirroring `_PosAppBarState`)
NEXT: `ref.watch(productsProvider)` in `MobileProductGrid` rebuilds with the filtered list.

## H. State Before and After

BEFORE:
```text
ProductState
  products = [48 items, page 0]
  currentPage = 0
  hasMore = true
```
Call: `ref.read(productsProvider.notifier).searchProducts('coca')`
AFTER:
```text
ProductState
  products = [3 items matching "coca", page 0]
  currentPage = 0
  hasMore = false   (3 < pageSize of 48)
```
Then: `MobileProductGrid`'s `ref.watch(productsProvider)` rebuilds, shows 3 items.

## I. What Should Be Shared vs Mobile-Only?

```text
ProductNotifier (all methods) / ProductState / ProductService / DemoProductService fallback
🟢 KEEP EXACTLY

CategoryTabs / ProductCard / ProductModifierSheet
🟢 KEEP EXACTLY

ProductGrid (desktop, _fixedColumns = 5)
🔴 DO NOT COPY

MobileProductGrid / MobileProductSearchBar
🔵 NEW MOBILE UI

lib/features/pos/models/product.dart, services/product_api_service.dart
🔴 DO NOT COPY (confirmed dead code)
```

## J. Build Order Inside the Day

1. Open `providers/product_provider.dart`. Read `ProductState`, note the `copyWith` error-clearing quirk.
2. Read `ProductNotifier.loadProducts`, `loadMore`, `searchProducts`, `filterByCategory`, `findByBarcode` — all 5, in that order.
3. Open `services/product_service.dart`. Read the abstract `findByBarcode` default and `ApiProductService.getProducts`'s two-endpoint branch.
4. Open `services/demo_product_service.dart`. Read `_tryApi` and understand the silent-fallback implication.
5. Open `pos_screen.dart`'s `_PosAppBarState`. Read the `Timer`-based debounce — this is the pattern to copy into your mobile search bar (the *pattern*, not the widget).
6. Create `mobile_product_grid.dart` using the skeleton in section F.
7. Create `mobile_product_search_bar.dart` (a `TextField` + the same 300ms `Timer` debounce pattern, calling `searchProducts`).
8. Wire `CategoryTabs` (reused as-is) above the grid, in horizontal mode, calling `filterByCategory`.
9. Decide and document: keep or change the silent demo-fallback behavior for mobile (e.g., show a "using demo data" banner if `_tryApi` fell through — this requires a small, deliberate change if you want it, not a given).
10. Test: load, scroll to trigger `loadMore`, search, filter by category — confirm all four against the real backend.

## K. "When I Click This, What Happens?"

# Type in search bar
```text
Type "c", "co", "cok", "coke" (each keystroke)
↓
TextEditingController listener fires each time
↓
_searchDebounce?.cancel()  (cancels the previous pending timer)
↓
new Timer(300ms, ...) scheduled
↓ (300ms after the LAST keystroke, i.e. "coke")
ref.read(productsProvider.notifier).searchProducts('coke')
↓
ProductNotifier.loadProducts(query: 'coke')
↓
GET /api/products?q=coke&page=0&size=48
↓
ProductState.products updates
↓
MobileProductGrid rebuilds
```

# Scroll to bottom of grid
```text
User scrolls down
↓
ScrollController listener fires continuously
↓
pixels >= maxScrollExtent - 200 ?
↓ (yes)
ref.read(productsProvider.notifier).loadMore()
↓
guarded by isLoadingMore/hasMore checks (no duplicate fetch if already loading)
↓
GET /api/products?page=1&size=48 (or /pos-catalog if no filter active — page/size ignored there)
↓
ProductState.products = [...old, ...new]
↓
grid appends new items, scroll position preserved
```

## L. "Where Does This Value Come From?"

Product name shown on a card:
```text
Backend Product.nameEn / nameKm
↓
Product.fromJson(json)  (features/pos/models/product_models.dart)
↓
resolveBilingual(en: product.nameEn, km: product.nameKm, language: appLanguage)  (core/utils/bilingual.dart)
↓
ProductCard displays the resolved name
```

## M. Navigation Flow

Tapping a product does not navigate to a new screen — it opens `ProductModifierSheet` via `showModalBottomSheet<CartItem>` (a modal overlay, not a route push). The sheet returns a `CartItem` via `Navigator.of(context).pop(cartItem)` when confirmed, or `null` if dismissed.

## N. Error Flow

```text
API succeeds
→ ProductState.products updates, isLoading = false

API fails (network error, 500, etc.)
→ caught in ProductNotifier.loadProducts's try/catch
→ state.error = e.toString()   (but see section B's copyWith quirk — a STALE error may persist
  across a subsequent successful load if you're not careful reading state.error)
→ HOWEVER: _FallbackProductService intercepts the exception BEFORE it reaches ProductNotifier at all,
  and silently returns demo data instead — so in practice, ProductNotifier's error path rarely
  triggers for product loads specifically; you'll see 15 demo products with no visible error, which
  can be confusing during mobile development if your backend is actually down. Check DemoProductService's
  data (a fixed set of 15 sample products) if you ever see suspiciously identical products across devices.
```

## O. Test Flow

Existing tests: `test/product_provider_test.dart`, `test/product_grid_test.dart`, `test/product_grid_ui_test.dart`.
```bash
flutter test test/product_provider_test.dart
```
(The grid tests target the desktop `ProductGrid` widget specifically — write new equivalents for `MobileProductGrid`, same provider, different widget under test.)

Manual test:
```text
1. Open MobileProductGrid on Android with backend running — confirm real products load.
2. Kill the backend, restart the screen — confirm demo products silently appear (no error banner).
3. Restart backend, search for a known product name — confirm correct filtered results.
4. Scroll to bottom — confirm more items load (if the catalog has >48 products) without duplicate requests.
5. Tap a category tab — confirm grid filters.
```

## What I Should Understand Before Day 7

That `Product.modifierGroups` arrives embedded directly on the product from `/pos-catalog`/`/api/products` (not a separate fetch) — `ProductModifierSheet` reads `product.modifierGroups` straight off the object you already have in `ProductState.products`, no extra network call needed when the tap-to-add-with-modifiers flow opens.

---

# Day 7 — Cart: Every Mutator, Exact Bodies

## A. Where Do I Start?

Open `lib/features/pos/providers/cart_provider.dart`. Read `CartState`'s money getters first (`total`, `discountAmount`, `taxAmount`, `finalTotal`) — these are the single most important 15 lines in the whole cart system. Then read `CartNotifier`.

## B. Existing Web Function Chain — money math, exact formulas

```dart
int get _subtotalMinor => items.fold<int>(0,
    (sum, item) => sum + Money.lineTotalMinor(item.unitPrice, item.qty));

int get _itemDiscountsMinor => items.fold<int>(0,
    (sum, item) => sum + Money.toMinor((item.discountAmount ?? 0) * item.qty));

int get _discountMinor {
  final raw = discountType == DiscountType.fixed
      ? Money.toMinor(discount)
      : Money.percentOfMinor(_subtotalMinor, discount);
  return raw.clamp(0, _subtotalMinor);
}

double get total => Money.toMajor(_subtotalMinor - _itemDiscountsMinor);
double get discountAmount => Money.toMajor(_discountMinor);
double get taxAmount => total * taxRate;    // <-- tax computed on `total`, i.e. POST item-discount,
                                             //     PRE cart-discount. Non-obvious — read twice.

double get finalTotal {
  final subtotalAfterItemDiscounts = _subtotalMinor - _itemDiscountsMinor;
  final net = (subtotalAfterItemDiscounts - _discountMinor - Money.toMinor(loyalty))
      .clamp(0, subtotalAfterItemDiscounts);
  return Money.toMajor(net) + taxAmount;
}
```
Everything is computed in **integer minor units first** (cents, via `core/utils/money.dart::Money`) then converted back to `double` — this avoids float rounding drift on totals. **Never** reimplement this math in a mobile widget; always read `CartState.finalTotal` etc.

**Every mutator shares one pattern**: mutate `state` → `await persistCart()` (local SharedPreferences snapshot, always succeeds or silently logs) → `await _syncService(...)` (best-effort remote sync, **swallows all errors, never rethrows**). This order is deliberate: a network blip can never make a just-added item "disappear."

`addItemFromProduct(Product product)`:
```dart
Future<void> addItemFromProduct(Product product) async {
  final existingIdx = state.items.indexWhere((item) => item.product.id == product.id);
  if (existingIdx >= 0) {
    await incrementItem(state.items[existingIdx].id);
  } else {
    final newItem = CartItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_${product.id}',
      product: product, qty: 1, addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await addItem(newItem);
  }
}
```

`addItem(CartItem item)`:
```dart
Future<void> addItem(final CartItem item) async {
  state = state.copyWith(loading: true);
  try {
    int? waitingNumber = state.waitingNumber;
    waitingNumber ??= await waitingNumberService.issueNumber();
    state = state.copyWith(items: [...state.items, item], waitingNumber: waitingNumber);
    await persistCart();
    await _syncService(() => service.saveCartItems(state.items), 'add');
  } catch (e) {
    debugPrint('Cart add failed: $e');
  } finally {
    state = state.copyWith(loading: false);
  }
}
```

`removeItem`, `incrementItem`, `decrementItem`, `setItemQuantity` all follow the identical persist→sync order:
```dart
Future<void> decrementItem(final String id) async {
  ...
  if (item.qty <= 1) {
    await removeItem(id);          // <-- delegates to removeItem, which itself persists+syncs
  } else {
    list[idx] = item.copyWith(qty: item.qty - 1);
    state = state.copyWith(items: list);
    await persistCart();
    await _syncService(() => service.saveCartItems(state.items), 'decrement');
  }
}

Future<void> setItemQuantity(final String id, final int qty) async {
  ...
  if (qty <= 0) { await removeItem(id); return; }   // <-- same delegation
  ...
}
```

`applyDiscount`/`clearDiscount` — **synchronous, `persistCart()` NOT awaited, NO `_syncService` call at all** (discounts are never synced to the backend cart, only saved locally):
```dart
void applyDiscount(final double amount, {DiscountType type = DiscountType.fixed}) {
  state = state.copyWith(discount: amount, discountType: type);
  persistCart();   // fire-and-forget
}
```

`setItemDiscount(String id, double amount)` — clamps to the product's price, persist+sync:
```dart
Future<void> setItemDiscount(String id, double amount) async {
  ...
  final adjusted = amount.clamp(0.0, item.product.price);
  ...
  await persistCart();
  await _syncService(() => service.saveCartItems(state.items), 'item discount');
}
```

`setCustomer`/`clearCustomer`/`setTable`/`clearTable` — synchronous, `persistCart()` not awaited, **no `_syncService`** (never synced to backend cart at all):
```dart
void setCustomer(int customerId) { state = state.copyWith(customerId: customerId); persistCart(); }
void clearCustomer() { state = state.copyWith(clearCustomer: true); persistCart(); }
void setTable(int tableId) { state = state.copyWith(tableId: tableId); persistCart(); }
void clearTable() { state = state.copyWith(clearTable: true); persistCart(); }
```
Note the real signature is `setCustomer(int customerId)` — **non-nullable**; clearing goes through the separate `clearCustomer()` method, not `setCustomer(null)`.

`clear({bool releaseWaitingNumber = true})` — releases the waiting number first (best-effort), resets state, persists, then syncs `clearCart()`:
```dart
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

`persistCart()` and `_syncService()` (the two shared helpers):
```dart
Future<void> persistCart() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartPrefsKey, json.encode(state.toJson()));
  } catch (e) { debugPrint('Cart persist skipped: $e'); }
}

Future<void> _syncService(Future<void> Function() action, String label) async {
  try { await action(); } catch (e) { debugPrint('Cart $label (remote) failed: $e'); }
}
```

`CartService` — the switch point (`cart_service.dart`):
```dart
final cartServiceProvider = Provider<CartService>((ref) {
  if (AppConfig.useApiCartService) {
    return ApiCartService(ref.watch(apiServiceProvider));
  }
  return LocalCartService();
});
```
`ApiCartService.saveCartItems` deletes and recreates the **entire** remote cart on every save (no partial update) — DELETE old cart, POST new cart, POST each item individually. `LocalCartService.saveCartItems` is a plain SharedPreferences write, no network at all.

## C. Backend/API Chain

Only relevant when `AppConfig.useApiCartService == true` (default `true` per `AppConfig`, but see Day 19's finding that this only affects `ApiCartService`, a persistence adapter — **the real checkout in Day 11 never reads from this backend cart at all**; it builds its sale request directly from the live `CartState.items` in memory):
```text
CartNotifier._syncService(() => service.saveCartItems(items), ...)
↓
ApiCartService.saveCartItems(items)
    DELETE /api/carts/{oldId}
    POST /api/carts                    -> CartController.createCart -> 201 Created
    POST /api/carts/{newId}/items      -> CartController.addItemToCart -> 201 Created (per item)
↓
CartController -> CartService.addItemToCart(cartId, productId, quantity) [backend]
    validateQuantity (0 < qty <= 10000, else IllegalArgumentException -> UNCAUGHT -> HTTP 500,
                       not the usual ApiException->400 pattern used elsewhere in this backend)
    ProductRepository.findById -> Cart/CartItem entities -> cart.calculateTotal() -> save
```
**Important architectural fact, confirmed by direct backend inspection**: this backend `Cart` is a real, persistent entity — but it is **completely disconnected from `Sale`**. `CartController`'s `completeCart` only flips `Cart.status` to `COMPLETED`; it never creates a `Sale`, never touches `StockItemRepository`. The actual checkout (Day 11) always goes through `SaleController`/`SaleService` independently, building its request from the in-memory `CartState`, not from this backend Cart. Treat `ApiCartService` as pure background persistence (so a cashier's cart survives a crash/reinstall), not as part of the checkout path.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `providers/cart_provider.dart` | `CartNotifier` | `addItemFromProduct` | `Product` | `Future<void>` | Quick-add from product grid |
| `providers/cart_provider.dart` | `CartNotifier` | `addItem` | `CartItem` | `Future<void>` | Add with modifiers (from `ProductModifierSheet` result) |
| `providers/cart_provider.dart` | `CartNotifier` | `incrementItem` / `decrementItem` | `String id` | `Future<void>` | Qty +/− steppers |
| `providers/cart_provider.dart` | `CartNotifier` | `setItemQuantity` | `(String, int)` | `Future<void>` | Direct qty entry |
| `providers/cart_provider.dart` | `CartNotifier` | `removeItem` | `String id` | `Future<void>` | Swipe-to-delete |
| `providers/cart_provider.dart` | `CartNotifier` | `applyDiscount` / `clearDiscount` | `(double, {DiscountType})` | `void` | Cart-level discount |
| `providers/cart_provider.dart` | `CartNotifier` | `setItemDiscount` | `(String, double)` | `Future<void>` | Per-item discount |
| `providers/cart_provider.dart` | `CartNotifier` | `setCustomer` / `clearCustomer` | `int` / — | `void` | Customer attach (Day 9) |
| `providers/cart_provider.dart` | `CartNotifier` | `setTable` / `clearTable` | `int` / — | `void` | Table attach (Day 9) |
| `providers/cart_provider.dart` | `CartNotifier` | `clear` | `({bool releaseWaitingNumber})` | `Future<void>` | Post-checkout / cancel |
| `widgets/cart_items_list.dart` | `CartItemsList` | — | — | — | Reuse as-is (already has swipe-to-delete) |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_cart_screen.dart
lib/features/pos/mobile/widgets/mobile_cart_badge.dart
```
PURPOSE (`mobile_cart_badge.dart`): small persistent badge (item count + running total) on the product screen, tapping through to the cart screen.
PURPOSE (`mobile_cart_screen.dart`): full-screen cart (per the required pattern: `Products screen → Cart button → Cart screen`), replacing the desktop's permanent 380px sidebar.
CLASS: both `ConsumerWidget`
USES PROVIDER: `cartProvider`
CALLS FUNCTION: every `CartNotifier` method in section D
RETURNS/NAVIGATES TO: `MobilePaymentScreen` (Day 11) on Charge

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
// mobile_cart_badge.dart — sits on MobileProductGrid's AppBar
class MobileCartBadge extends ConsumerWidget {
  const MobileCartBadge({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);   // STEP 1: watch, don't read — badge must live-update
    return Badge(
      label: Text('${cart.items.length}'),
      child: IconButton(
        icon: const Icon(Icons.shopping_cart),
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const MobileCartScreen()),
        ),
      ),
    );
  }
}

// mobile_cart_screen.dart
class MobileCartScreen extends ConsumerWidget {
  const MobileCartScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.cartTitle)),
      body: Column(children: [
        // STEP 2: reuse the EXISTING widget — swipe-to-delete already built in.
        Expanded(child: CartItemsList(items: cart.items)),
        // STEP 3: totals footer — read cart.finalTotal etc., never recompute.
        Text('${context.l10n.total}: ${cart.finalTotal}'),
        ElevatedButton(
          onPressed: cart.items.isEmpty ? null : () {
            // STEP 4: same navigation pattern as cart_totals.dart's Charge button (see Day 11).
            Navigator.push(context, MaterialPageRoute(builder: (_) => MobilePaymentScreen(
              total: cart.finalTotal,
              // ...saleLines, customerId, tableId, waitingNumber, heldTicketId — Day 11 builds this.
            )));
          },
          child: Text(context.l10n.charge),
        ),
      ]),
    );
  }
}
```

## G. Function Inputs and Outputs

`CartNotifier.incrementItem(String id)`
INPUT: `id = "1723489213456_42"` (a cart-line id, NOT a product id — format is `'${microsecondsSinceEpoch}_${productId}'`)
DOES: finds the line by `id`, increments `qty` by 1, persists, best-effort syncs
OUTPUT: `Future<void>`
CALLER: qty-stepper `+` button in `MobileCartScreen`
NEXT: `ref.watch(cartProvider)` rebuilds everywhere the cart is displayed (badge, cart screen, cart footer)

## H. State Before and After

BEFORE:
```text
CartState
  items = [CartItem(id: '..._42', product: Coke, qty: 1)]
  finalTotal = 2.50
```
Call: `ref.read(cartProvider.notifier).incrementItem('..._42')`
AFTER:
```text
CartState
  items = [CartItem(id: '..._42', product: Coke, qty: 2)]
  finalTotal = 5.00
SharedPreferences['cart_state_v2'] updated (persistCart)
(best-effort) remote cart synced if AppConfig.useApiCartService
```
Then: `MobileCartBadge` and `MobileCartScreen` both rebuild (both `ref.watch(cartProvider)`).

## I. What Should Be Shared vs Mobile-Only?

```text
CartNotifier (every method) / CartState / Money
🟢 KEEP EXACTLY

CartService / ApiCartService / LocalCartService / cartServiceProvider
🟢 KEEP EXACTLY

CartItemsList (swipe-to-delete widget)
🟢 KEEP EXACTLY

CartPanel (desktop, fixed 380px sidebar)
🔴 DO NOT COPY

cart_panel_footer.dart, cart_footer.dart
🔴 DO NOT COPY (confirmed dead code, unreferenced anywhere)

MobileCartBadge / MobileCartScreen
🔵 NEW MOBILE UI
```

## J. Build Order Inside the Day

1. Open `models/cart_models.dart`. Read `CartItem` fully (fields + `unitPrice`/`lineTotal`/`modifierSummaryText` getters).
2. Open `providers/cart_provider.dart`. Read `CartState`'s money getters twice — make sure you understand the tax-on-`total` (not tax-on-discounted-total) subtlety.
3. Read every `CartNotifier` method listed in section D, in order.
4. Open `services/cart_service.dart`. Read both `saveCartItems` implementations and the `cartServiceProvider` switch.
5. Create `mobile_cart_badge.dart` using the skeleton in section F. Add it to `MobileProductGrid`'s AppBar (Day 6).
6. Create `mobile_cart_screen.dart`, reusing `CartItemsList` for the item list.
7. Wire `incrementItem`/`decrementItem`/`removeItem` to the reused widget's existing callbacks.
8. Wire a discount-entry UI to `applyDiscount`/`clearDiscount`.
9. Wire the Charge button's navigation (full parameters completed in Day 11).
10. Test: add several items from the grid, confirm badge count updates live; open cart, adjust quantities, apply a discount, confirm `finalTotal` matches manual arithmetic; force-quit and relaunch the app, confirm the cart persisted (via `persistCart`/`restoreCart`).

## K. "When I Click This, What Happens?"

# Tap "Add" on a product card (quick add, no modifiers)
```text
Tap ProductCard
↓
ref.read(cartProvider.notifier).addItemFromProduct(product)
↓
existing line for this product? -> incrementItem(existing.id) : addItem(newItem)
↓
CartState.items updates
↓
persistCart()  (SharedPreferences write)
↓
_syncService(saveCartItems)  (best-effort, errors swallowed)
↓
MobileCartBadge rebuilds (ref.watch(cartProvider)), count increments
```

# Long-press a product card (with modifiers)
```text
Long-press ProductCard
↓
showModalBottomSheet<CartItem>(builder: (_) => ProductModifierSheet(product: product))
↓
user selects modifiers, taps Confirm
↓
Navigator.of(context).pop(cartItem)   [inside ProductModifierSheet]
↓
result = await showModalBottomSheet(...)   [back in the caller]
↓
if (result != null) ref.read(cartProvider.notifier).addItem(result)
↓
same persist+sync sequence as above
```

# Tap "Charge"
```text
Tap Charge (disabled if cart.items.isEmpty)
↓
Navigator.push(MaterialPageRoute(builder: (_) => MobilePaymentScreen(total: cart.finalTotal, ...)))
↓
MobilePaymentScreen reads the SAME cartProvider (Day 11)
```

## L. "Where Does This Value Come From?"

Cart total shown on the badge/footer:
```text
CartItem data (product.price, qty, selectedModifiers)
↓
CartState._subtotalMinor / _itemDiscountsMinor / _discountMinor  (Money, integer-safe math)
↓
CartState.finalTotal getter
↓
ref.watch(cartProvider).finalTotal
↓
Text('$finalTotal') in MobileCartBadge / MobileCartScreen
```

## M. Navigation Flow

`MobileCartBadge` → `MobileCartScreen`: `Navigator.push` (not replace — user can go back to the product grid, cart state persists regardless since it lives in `cartProvider`, not screen state). `MobileCartScreen` → `MobilePaymentScreen`: also `Navigator.push` (matches the desktop's `cart_totals.dart` Charge button, which uses `Navigator.of(context).push(MaterialPageRoute(...))`, not a named route — `PaymentScreen` needs constructor parameters a route string can't carry).

## N. Error Flow

```text
persistCart() fails (SharedPreferences write error — rare)
→ caught inside persistCart's own try/catch, debugPrint only, state already updated in memory
→ UI is NOT blocked or shown an error — the in-memory CartState is the source of truth for the
  current session regardless of persistence success

_syncService(saveCartItems) fails (network error, backend down)
→ caught inside _syncService's own try/catch, debugPrint only
→ UI is NOT shown an error — by design, so a network blip never blocks adding items to a cart
→ IMPLICATION FOR MOBILE: on a flaky mobile connection, the backend cart (if AppConfig.useApiCartService
  is on) can silently drift out of sync with the local cart for a while. This is acceptable BECAUSE
  Day 11's checkout never reads from the backend cart anyway (see section C) — the local CartState
  is what actually gets submitted at checkout time.
```

## O. Test Flow

Existing test: `test/cart_provider_resilience_test.dart` (specifically tests that `CartNotifier` stays responsive when storage/service calls fail — exactly the error-swallowing behavior described above).
```bash
flutter test test/cart_provider_resilience_test.dart
```
Also relevant: `test/local_cart_service_test.dart`, `test/api_cart_service_test.dart`.

Manual test:
```text
1. Add 3 different products (mix of quick-add and modifier-sheet add).
2. Confirm badge shows 3, confirm totals match manual math.
3. Increment/decrement quantities, confirm totals update live.
4. Apply a $1 cart discount, confirm finalTotal reflects it minus tax-on-pre-discount-total quirk.
5. Force-quit the app, relaunch, confirm cart state restored.
6. Turn off Wi-Fi, add another item — confirm it still adds successfully (local persist always works).
```

## What I Should Understand Before Day 8

The mutate → `persistCart()` → best-effort `_syncService()` pattern you just saw repeated across every `CartNotifier` method — you'll see the *identical* shape again in `HeldTicketNotifier` (Day 9). Recognizing the pattern means Day 9 goes faster.

---

# Day 8 — Barcode Scanner: Camera to Cart, Exact Chain

## A. Where Do I Start?

Open `lib/features/pos/providers/cart_provider.dart`, find `addProductByBarcode`. This is the *destination* every scan path converges on — read it before the scanning UI, so you know exactly what a working scanner integration needs to call.

## B. Existing Web Function Chain

`CartNotifier.addProductByBarcode(String barcode)` — full body:
```dart
class BarcodeAddResult {
  const BarcodeAddResult({required this.added, required this.message, this.product});
  final bool added;
  final String message;
  final Product? product;
}

Future<BarcodeAddResult> addProductByBarcode(String barcode) async {
  final normalized = barcode.trim();
  if (normalized.isEmpty) {
    return const BarcodeAddResult(added: false, message: 'Enter or scan a barcode');
  }
  try {
    Product? product;
    final comparable = normalized.toLowerCase();
    // fast path: check the ALREADY-LOADED in-memory product list first, no network round-trip
    for (final candidate in _ref.read(productsProvider).products) {
      if (candidate.barcode.trim().toLowerCase() == comparable) { product = candidate; break; }
    }
    // slow path: only if not found in memory, hit the network via the products NOTIFIER (not
    // the service directly)
    product ??= await _ref.read(productsProvider.notifier).findByBarcode(normalized);

    if (product == null) {
      return BarcodeAddResult(added: false, message: 'No product found for barcode $normalized');
    }
    if (!product.active) return BarcodeAddResult(added: false, message: '${product.nameEn} is inactive', product: product);
    if (!product.sellable) return BarcodeAddResult(added: false, message: '${product.nameEn} is not sellable', product: product);
    if (product.outOfStock) return BarcodeAddResult(added: false, message: '${product.nameEn} is out of stock', product: product);

    await addItemFromProduct(product);   // <-- same function from Day 7
    return BarcodeAddResult(added: true, message: '${product.nameEn} added to cart', product: product);
  } catch (error, stackTrace) {
    debugPrint('Barcode lookup failed: $error');
    return BarcodeAddResult(added: false, message: 'Could not look up barcode $normalized');
  }
}
```
Note the fast path: it checks `productsProvider`'s already-loaded list before ever calling the network — meaning if your mobile scan flow runs while the product grid has already loaded, most scans resolve instantly with zero latency.

**Existing camera scan screen** — `phone_screen_scan.dart`'s `PhoneScannerScreen` (already phone-native, built on `package:mobile_scanner`):
```dart
_cameraController = MobileScannerController(
  facing: CameraFacing.back,
  detectionSpeed: DetectionSpeed.normal,
  detectionTimeoutMs: 700,
  autoZoom: true,
  formats: const [BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.code93,
      BarcodeFormat.codabar, BarcodeFormat.ean13, BarcodeFormat.ean8,
      BarcodeFormat.itf, BarcodeFormat.upcA, BarcodeFormat.upcE],
);
```
Its `_onDetect` handler — **important**: this screen was built as a *companion-device* scanner (a second phone relaying barcodes over a websocket to the main POS terminal), NOT a direct add-to-cart flow:
```dart
void _onDetect(BarcodeCapture capture) {
  if (_connectionState != ScannerRelayConnectionState.connected) return;
  String? value;
  for (final barcode in capture.barcodes) {
    final candidate = barcode.rawValue?.trim() ?? '';
    if (candidate.isNotEmpty) { value = candidate; break; }
  }
  if (value == null) return;
  // de-dupe repeats within 1200ms (camera fires detection repeatedly while pointed at a barcode)
  if (_lastDetectedValue == value && _lastDetectedAt != null &&
      DateTime.now().difference(_lastDetectedAt!) < const Duration(milliseconds: 1200)) return;
  _lastDetectedValue = value;
  _lastDetectedAt = DateTime.now();
  _relay.sendBarcode(value);          // <-- sends over ScannerRelayClient (websocket), NOT addProductByBarcode
  HapticFeedback.mediumImpact();
}
```
For a mobile app where the phone doing the scanning **is** the POS, you don't need the relay — you want the direct path: `MobileScannerController.onDetect` → `addProductByBarcode` directly. Build a new, simpler screen (or a thin variant of this one) that skips `ScannerRelayClient` entirely.

## C. Backend/API Chain

Only reached on the slow path (product not already in the in-memory list):
```text
ProductNotifier.findByBarcode(barcode)
↓
ProductService.findByBarcode(barcode)   [abstract default impl, reused by ApiProductService]
    normalizes barcode, calls getProducts(query: barcode, page: 0, size: 50), exact-match filter
↓
GET /api/products?q={barcode}&page=0&size=50
↓
ProductController.search(...) -> Page<ProductResponse>
```
No dedicated backend barcode-lookup endpoint exists — barcode search reuses the general product search endpoint with the barcode as the `q` parameter, then filters client-side for an exact match.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `providers/cart_provider.dart` | `CartNotifier` | `addProductByBarcode` | `String` | `Future<BarcodeAddResult>` | Called by your new mobile scan screen after every detection |
| `providers/product_provider.dart` | `ProductNotifier` | `findByBarcode` | `String` | `Future<Product?>` | Called internally by `addProductByBarcode` — you never call this directly |
| — | `MobileScannerController` (package `mobile_scanner`) | `onDetect` callback | `BarcodeCapture` | — | Reuse the config from `phone_screen_scan.dart`, skip the relay logic |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_scan_screen.dart
```
PURPOSE: camera scan screen wired directly to cart (not through a relay).
CLASS: `MobileScanScreen extends ConsumerStatefulWidget`
USES PROVIDER: `cartProvider` (via `addProductByBarcode`)
CALLS FUNCTION: `CartNotifier.addProductByBarcode(barcode)`
RETURNS/NAVIGATES TO: pops back to the product grid/cart after a successful add (or stays open for continuous scanning — a UX decision to make explicitly)

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
class MobileScanScreen extends ConsumerStatefulWidget {
  const MobileScanScreen({super.key});
  @override
  ConsumerState<MobileScanScreen> createState() => _MobileScanScreenState();
}

class _MobileScanScreenState extends ConsumerState<MobileScanScreen> {
  // STEP 1: reuse the SAME MobileScannerController config as phone_screen_scan.dart.
  late final _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 700,
  );
  String? _lastValue;
  DateTime? _lastAt;

  Future<void> _onDetect(BarcodeCapture capture) async {
    final value = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    // STEP 2: same 1200ms de-dupe pattern as the existing screen.
    if (_lastValue == value && _lastAt != null &&
        DateTime.now().difference(_lastAt!) < const Duration(milliseconds: 1200)) return;
    _lastValue = value; _lastAt = DateTime.now();

    // STEP 3: call the EXISTING cart function directly — no relay needed.
    final result = await ref.read(cartProvider.notifier).addProductByBarcode(value);

    // STEP 4: show result.message (added or not-found) via a mobile-appropriate snackbar.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
```

## G. Function Inputs and Outputs

`CartNotifier.addProductByBarcode(String barcode)`
INPUT:
```text
barcode = "8851234567890"
```
DOES:
```text
check in-memory productsProvider.products for exact barcode match (fast path)
-> not found: ProductNotifier.findByBarcode(barcode) -> GET /api/products?q=... (slow path)
-> found: validate active/sellable/outOfStock
-> addItemFromProduct(product)
```
OUTPUT: `Future<BarcodeAddResult>` (`{added: bool, message: String, product: Product?}`)
CALLER: `MobileScanScreen._onDetect`
NEXT: show `result.message`; if `result.added`, the cart badge (Day 7) already updated via `addItemFromProduct`'s state change.

## H. State Before and After

BEFORE:
```text
CartState.items = []
```
Call: `addProductByBarcode("8851234567890")` (resolves to "Coca-Cola 330ml")
AFTER (found + sellable):
```text
CartState.items = [CartItem(product: Coca-Cola 330ml, qty: 1)]
result = BarcodeAddResult(added: true, message: "Coca-Cola 330ml added to cart", product: ...)
```
AFTER (not found):
```text
CartState.items = []   (unchanged)
result = BarcodeAddResult(added: false, message: "No product found for barcode 8851234567890")
```

## I. What Should Be Shared vs Mobile-Only?

```text
CartNotifier.addProductByBarcode
🟢 KEEP EXACTLY

ProductNotifier.findByBarcode / ProductService.findByBarcode
🟢 KEEP EXACTLY

MobileScannerController config (facing/detectionSpeed/formats)
🟡 CALL FROM NEW MOBILE UI — same config values, new screen

PhoneScannerScreen (relay-based)
🔴 DO NOT COPY as your primary scan path — it solves a different problem (borrowing a second
   phone's camera for a desktop POS). Keep the file, reconsider the FEATURE (not the code) for
   a "second staff member scans for a busy till" scenario, additive not primary.

ScannerRelayClient / scanner_relay_role.dart
🟡 CALL FROM NEW MOBILE UI only if you decide to keep the multi-device relay feature — otherwise skip
```

## J. Build Order Inside the Day

1. Open `providers/cart_provider.dart`, read `addProductByBarcode` and `BarcodeAddResult` fully.
2. Open `providers/product_provider.dart`, re-confirm `findByBarcode`'s delegation to the service.
3. Open `screens/phone_screen_scan.dart`, read the `MobileScannerController` setup and `_onDetect` — understand it's relay-oriented, not what you'll copy verbatim.
4. Add `NSCameraUsageDescription` to `ios/Runner/Info.plist` (confirmed absent today — the app will crash on iOS without it):
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Camera access is used to scan product barcodes.</string>
   ```
5. Create `mobile_scan_screen.dart` using the skeleton in section F.
6. Wire a scan button/icon on `MobileProductGrid`'s search bar (Day 6) to push `MobileScanScreen`.
7. Test on Android: scan a real barcode, confirm the item is added and the cart badge updates.
8. Test on iOS: confirm the camera permission prompt appears with your purpose string, grant it, confirm scanning works.
9. Test the denied-permission path on both platforms: deny camera access, confirm the app shows a clear message rather than crashing or silently doing nothing.
10. Decide (document your decision) whether to keep the cross-device relay feature for mobile at all.

## K. "When I Click This, What Happens?"

# Point camera at a barcode
```text
Camera detects a barcode
↓
MobileScanner's onDetect fires (possibly repeatedly while the barcode is in frame)
↓
_onDetect: de-dupe check (skip if same value within 1200ms)
↓
ref.read(cartProvider.notifier).addProductByBarcode(value)
↓
fast path: check productsProvider.products in memory
↓ (not found in memory)
slow path: ProductNotifier.findByBarcode -> GET /api/products?q=...
↓
product found, active, sellable, in stock
↓
addItemFromProduct(product)  [same Day 7 function]
↓
CartState updates -> cart badge rebuilds
↓
SnackBar shows "X added to cart"
```

## L. "Where Does This Value Come From?"

The "not found" message:
```text
addProductByBarcode's own literal string construction
↓
BarcodeAddResult(added: false, message: 'No product found for barcode $normalized')
↓
displayed directly in a SnackBar — not localized today (a hard-coded English string in the
existing addProductByBarcode function) — if you want this localized for Khmer-speaking cashiers,
that's a small, deliberate change to make in cart_provider.dart itself (shared with desktop, not
mobile-only), not something to route around in mobile UI.
```

## M. Navigation Flow

`MobileProductGrid` → `MobileScanScreen`: `Navigator.push` (a full-screen camera view). After a successful add, decide explicitly: `Navigator.pop(context)` back to the grid (single-scan-then-return) or stay open (continuous scanning for a customer buying many items) — both are legitimate UX choices; the existing `PhoneScannerScreen` stays open (continuous), which is a reasonable default to match.

## N. Error Flow

```text
Product found and valid
→ addItemFromProduct succeeds -> BarcodeAddResult(added: true, ...)

Product not found
→ BarcodeAddResult(added: false, message: 'No product found for barcode ...')

Product found but inactive/not sellable/out of stock
→ BarcodeAddResult(added: false, message: '<name> is inactive/not sellable/out of stock', product: product)
  (note: product IS included in the result even on this failure — useful if you want to show
   the product name/image in your not-added message rather than just the barcode)

Network error during the slow-path lookup
→ caught by addProductByBarcode's own try/catch
→ BarcodeAddResult(added: false, message: 'Could not look up barcode $normalized')

Camera permission denied (Android or iOS)
→ mobile_scanner's controller throws/reports an error state — NOT handled anywhere in the
  existing codebase (no prior mobile camera usage to model this on) — you must build this
  handling yourself: catch the permission-denied state and show a clear "enable camera access
  in Settings" message rather than a blank/frozen camera view.
```

## O. Test Flow

Existing test: `test/scan_barcode_test.dart` — if it targets `addProductByBarcode`/`ProductService.findByBarcode` at the provider level (not a UI test), it should be directly reusable, unmodified.
```bash
flutter test test/scan_barcode_test.dart
```
Manual test matrix:
```text
1. Scan a known product's barcode -> confirm added to cart.
2. Scan an unknown/garbage barcode -> confirm clear "not found" message.
3. Scan a barcode for an out-of-stock product -> confirm clear "out of stock" message, not silently ignored.
4. Deny camera permission -> confirm app shows guidance, does not crash.
5. Repeat all 4 on both Android and iOS.
```

## What I Should Understand Before Day 9

That permission-request handling (step 9 above) is the first genuinely new *platform-facing* code you've written in this entire plan — Days 1–7 were pure reuse of existing Dart. The same "request → handle denied gracefully → don't crash" shape reappears for Bluetooth in Day 16, at higher stakes (a denied Bluetooth permission there blocks printing an entire receipt, not just one scan).

---

# Day 9 — Customer / Table / Held & Waiting Tickets

## A. Where Do I Start?

Open `lib/features/pos/widgets/table_selector.dart` and find its row `onTap` handler. It's short, but it contains the single most important gotcha in this whole day: two providers must be updated together, in a specific order, or table state silently disagrees with itself.

## B. Existing Web Function Chain

**Table selection — the dual-state gotcha, exact code**:
```dart
onTap: () {
  if (!isAvailable) { /* show "in use" SnackBar */ return; }
  ref.read(tableSelectionProvider.notifier).select(table);   // 1st: UI-facing "current table" state
  ref.read(cartProvider.notifier).setTable(table.id);          // 2nd: attaches table to the actual cart/sale
  Navigator.of(context).pop();
},
```
`TableSelectionNotifier.select` (persists only the table *name* string, offline-only):
```dart
Future<void> select(RestaurantTable? table) async {
  state = table;
  final prefs = await SharedPreferences.getInstance();
  if (table == null) { await prefs.remove(AppConfig.selectedTableKey); }
  else { await prefs.setString(AppConfig.selectedTableKey, table.tableNumber); }
}
```
**Your `MobileTableSelector` must call both `select(table)` and `setTable(table.id)`, in this order, every time** — calling only one leaves the UI showing a table that isn't actually attached to the sale (or vice versa). The "No Table" action mirrors this: `tableSelectionProvider.notifier.select(null)` then `cartProvider.notifier.clearTable()`.

**Customer selection** — `CustomerNotifier` (`customer_provider.dart`):
```dart
Future<void> load({String query = ''}) async {
  state = state.copyWith(loading: true, query: query, clearError: true);
  try {
    final customers = await _service.listCustomers(query: query);
    state = state.copyWith(loading: false, customers: customers, clearError: true);
  } catch (e) {
    state = state.copyWith(loading: false, error: e.toString());
  }
}
```
`create`/`update` have **no try/catch** — unlike `load`, errors propagate straight to the caller UI:
```dart
Future<void> create(CreateCustomerRequest request) async {
  await _service.createCustomer(request);
  await load(query: state.query);   // reload list on success
}
```
Attaching a selected customer to the cart is a single call: `ref.read(cartProvider.notifier).setCustomer(customer.id)` (Day 7's function — no dual-state gotcha here, unlike tables).

**Held tickets** — `HeldTicketNotifier` (`held_ticket_provider.dart`):
```dart
Future<void> loadHeldTickets() async {
  ...
  final tickets = raw.map((e) => HeldOrder.fromJson(e)).where((t) => t.status.toLowerCase() != 'in_progress').toList();
  state = state.copyWith(loading: false, tickets: tickets);
}

Future<int?> holdCurrentCart(List<CartItem> items, {int? ticketId}) async {
  try {
    final data = { if (ticketId != null) 'id': ticketId.toString(), 'status': 'open',
        'cart': items.map((e) => e.toJson()).toList(), 'createdAt': DateTime.now().toIso8601String() };
    final table = ref.read(tableSelectionProvider);
    if (table != null) data['tableName'] = table.tableNumber;
    final created = await service.holdTicket(ticketData: data);
    await loadHeldTickets();
    await ref.read(cartProvider.notifier).clear();          // <-- clears the WORKING cart, ticket now holds it
    ref.read(tableSelectionProvider.notifier).select(null);
    return created?['id'] == null ? null : int.tryParse(created!['id'].toString());
  } catch (e) { state = state.copyWith(error: e.toString()); return null; }
}

Future<void> restoreTicket(HeldOrder ticket) async {
  ...
  final waitingNumber = await ref.read(waitingNumberServiceProvider).getNumberForOrder(ticket.id);
  await ref.read(cartProvider.notifier).restoreItems(
      items: ticket.cartItems!, waitingNumber: waitingNumber, heldTicketId: ticket.id, tableId: ticket.table?.id);
  ref.read(tableSelectionProvider.notifier).select(ticket.table);
  ...  // marks ticket in_progress on backend, non-fatal if that fails
}
```
`releaseTicketById` (called after a successful sale in Day 11) deliberately swallows all errors — the comment in the actual code explains why: *"the sale already succeeded — a leftover held-ticket row is just clutter, not a lost order."*

**Waiting numbers** — `WaitingNumberService` is entirely **offline**, no backend counterpart at all:
```dart
Future<int> issueNumber() async {
  ...
  for (int offset = 0; offset < maxNumber; offset++) {
    final candidate = ((nextNumber - minNumber + offset) % maxNumber) + minNumber;
    if (activeNumbers.contains(candidate)) continue;
    // ... claim `candidate`, persist, return it
  }
  throw StateError('No waiting number is currently available.');
}
```
Cycles 1–100 via SharedPreferences; if all 100 are in use it throws — a real, reachable error path a busy mobile POS could hit on a high-volume day.

## C. Backend/API Chain

```text
Customers:  GET/POST/PUT/DELETE /api/customers -> CustomerController
Held tickets: GET/POST /api/pos/open-tickets (dual-mapped also as /api/pos/held-tickets) -> HeldTicketController
Waiting numbers: NO backend endpoint at all — fully client-local (SharedPreferences)
Tables: GET/POST/PUT/DELETE /api/tables -> TableController (admin CRUD); table SELECTION
  during a sale never calls the network at all — TableSelectionNotifier.select is 100% offline.
```

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `providers/customer_provider.dart` | `CustomerNotifier` | `load` | `({String query})` | `Future<void>` | Customer picker search |
| `providers/customer_provider.dart` | `CustomerNotifier` | `create` | `CreateCustomerRequest` | `Future<void>` (no catch — caller must handle) | Quick-add customer |
| `providers/table_selection_provider.dart` | `TableSelectionNotifier` | `select` | `RestaurantTable?` | `Future<void>` | Table picker — **always pair with `setTable`/`clearTable`** |
| `providers/cart_provider.dart` | `CartNotifier` | `setCustomer` / `setTable` | `int` | `void` | Attach to sale |
| `providers/held_ticket_provider.dart` | `HeldTicketNotifier` | `loadHeldTickets` / `holdCurrentCart` / `restoreTicket` / `releaseTicketById` | see above | — | Hold/reopen flow |
| `services/waiting_number_service.dart` | `WaitingNumberService` | `issueNumber` / `getNumberForOrder` / `saveWaitingTicket` | see above | — | Ticket numbering |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_customer_picker_screen.dart
lib/features/pos/mobile/screens/mobile_table_selector_screen.dart
lib/features/pos/mobile/screens/mobile_held_tickets_screen.dart
```
Each: full-screen list replacing a desktop dialog. `MobileTableSelectorScreen` is the one that must replicate the dual-provider-call exactly.

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste (table selector shown, the highest-risk one).
```dart
class MobileTableSelectorScreen extends ConsumerWidget {
  const MobileTableSelectorScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tableProvider);   // AsyncValue<TablePage>
    return Scaffold(
      body: tables.when(
        data: (page) => ListView(children: [
          for (final table in page.items)
            ListTile(
              title: Text(table.displayName),
              onTap: () {
                // STEP 1 and STEP 2 MUST both happen, in this order — see section B.
                ref.read(tableSelectionProvider.notifier).select(table);
                ref.read(cartProvider.notifier).setTable(table.id);
                Navigator.of(context).pop();
              },
            ),
          ListTile(
            title: Text(context.l10n.noTable),
            onTap: () {
              ref.read(tableSelectionProvider.notifier).select(null);
              ref.read(cartProvider.notifier).clearTable();
              Navigator.of(context).pop();
            },
          ),
        ]),
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}
```

## G. Function Inputs and Outputs

`HeldTicketNotifier.holdCurrentCart(List<CartItem> items, {int? ticketId})`
INPUT: `items = cart.items` (the current cart's line items), `ticketId = null` (new hold, not updating an existing one)
DOES: builds a hold-ticket JSON payload including the current table name (if any), POSTs it, reloads the held-ticket list, **clears the working cart**, clears table selection
OUTPUT: `Future<int?>` (the new ticket's id, or `null` on failure)
CALLER: a "Hold" button in `MobileCartScreen`
NEXT: cart badge (Day 7) drops to 0 items since the cart was just cleared; the held ticket now appears in `MobileHeldTicketsScreen`.

## H. State Before and After

BEFORE:
```text
CartState.items = [2 items]
tableSelectionProvider = Table("T3")
```
Call: `holdCurrentCart(cart.items)`
AFTER:
```text
CartState.items = []            (cleared by holdCurrentCart internally)
tableSelectionProvider = null   (cleared)
heldTicketProvider.tickets = [..., new ticket with those 2 items, tableName: "T3"]
```

## I. What Should Be Shared vs Mobile-Only?

```text
CustomerNotifier / TableSelectionNotifier / HeldTicketNotifier / WaitingNumberService
🟢 KEEP EXACTLY

table_selector.dart (desktop dialog)
🔴 DO NOT COPY layout — 🟢 KEEP EXACTLY the dual-call logic inside its onTap

MobileCustomerPickerScreen / MobileTableSelectorScreen / MobileHeldTicketsScreen
🔵 NEW MOBILE UI
```

## J. Build Order Inside the Day

1. Open `providers/table_selection_provider.dart` and `widgets/table_selector.dart`, confirm the dual-call order for yourself by reading the actual `onTap`.
2. Open `providers/held_ticket_provider.dart`, read `loadHeldTickets`, `holdCurrentCart`, `restoreTicket`, `cancelResume`, `cancelCurrentTicket`, `releaseTicketById`.
3. Open `services/waiting_number_service.dart`, read `issueNumber` and understand the "all 100 numbers in use" failure case.
4. Build `MobileCustomerPickerScreen` (simplest — no dual-state gotcha).
5. Build `MobileTableSelectorScreen` using the skeleton in section F — test the dual-call explicitly (select a table, confirm `cartProvider.tableId` is set, not just `tableSelectionProvider`).
6. Build `MobileHeldTicketsScreen` (list + restore/cancel actions).
7. Test the full hold → reopen cycle: add items, hold, confirm cart clears, reopen the ticket, confirm items and table restore correctly and the *original* waiting number comes back (via `getNumberForOrder`), not a new one.

## K. "When I Click This, What Happens?"

# Select a table
```text
Tap a table row
↓
tableSelectionProvider.notifier.select(table)   [UI state, persists table NAME only]
↓
cartProvider.notifier.setTable(table.id)         [attaches table ID to the actual cart/sale]
↓
Navigator.pop()
↓
both MobileCartScreen (reads cartProvider.tableId) and any table-name display
(reads tableSelectionProvider) now agree
```

# Hold the current cart
```text
Tap "Hold"
↓
HeldTicketNotifier.holdCurrentCart(cart.items)
↓
POST /api/pos/open-tickets (or LocalHeldTicketService if AppConfig.enableHeldTicketSync is off)
↓
loadHeldTickets() refreshes the list
↓
cartProvider.notifier.clear()   -> cart badge drops to 0
↓
tableSelectionProvider.notifier.select(null)
```

## L. "Where Does This Value Come From?"

The waiting number shown after reopening a held ticket:
```text
WaitingNumberService's local 'waiting_number_order_map' SharedPreferences entry, keyed by orderId
↓
getNumberForOrder(ticket.id)
↓
HeldTicketNotifier.restoreTicket -> CartNotifier.restoreItems(waitingNumber: ...)
↓
CartState.waitingNumber
↓
displayed on receipt/UI — SAME number the customer was originally given, not a freshly issued one
```

## M. Navigation Flow

All three new screens: `Navigator.push` from wherever they're triggered (cart screen for customer/table, a held-tickets icon for tickets), `Navigator.pop()` on selection/dismissal — none use named routes, matching how `table_selector.dart` is opened today (as a dialog, not a route).

## N. Error Flow

```text
CustomerNotifier.load fails
→ caught internally, state.error set -> your picker screen must check state.error and show it

CustomerNotifier.create fails
→ NOT caught internally -> propagates to your screen's own try/catch -> you must handle this,
  there's no existing pattern to silently fall back on here (unlike ProductService's demo fallback)

HeldTicketNotifier.holdCurrentCart fails
→ caught internally, state.error set, function returns null -> your Hold button handler must
  check for a null return and show an error, rather than assuming success and clearing the cart
  (holdCurrentCart itself only clears the cart on the success path, so this is already safe —
  just make sure your UI reflects the failure to the cashier)

WaitingNumberService.issueNumber throws StateError (all 100 numbers in use)
→ NOT caught anywhere upstream in CartNotifier.addItem — this exception will propagate up through
  addItem's own catch (which just debugPrints and doesn't rethrow, per Day 7) — meaning today, if
  this happens, the item silently fails to add with only a debug console log, no user-facing error.
  Worth deciding whether to improve this for mobile (a real, reachable edge case on a busy day) —
  a genuine, documented gap, not a hypothetical.
```

## O. Test Flow

Existing tests: `test/held_ticket_provider_test.dart`, `held_ticket_provider_resilience_test.dart`, `held_ticket_provider_table_test.dart`, `table_provider_test.dart`, `table_selection_provider_test.dart` — all provider-level, reusable unmodified.
```bash
flutter test test/held_ticket_provider_test.dart test/table_selection_provider_test.dart
```
Manual test:
```text
1. Select a table, confirm both providers agree (check via debug print or a temporary display).
2. Add 2 items, hold the cart.
3. Confirm cart clears, table clears.
4. Reopen the held ticket.
5. Confirm items AND table AND waiting number all restore correctly.
```

## What I Should Understand Before Day 10

That `WaitingNumberService` and `TableSelectionNotifier` are both intentionally, entirely offline by design (not gaps to "fix") — they model physical, in-hand realities (a paper ticket number, a table sign) that don't need real-time backend sync. Contrast this with `CustomerService` (Day 9, always-online, no local fallback) — recognizing *why* each piece chose its online/offline model will help you make good decisions in Day 17's inventory work, where similar choices repeat.

---

# Day 10 — Shift Management: Open, Close, Precheck, History

## A. Where Do I Start?

Open `lib/features/pos/providers/shift_provider.dart`. It's short (4 methods) — read the whole file before opening anything else today.

## B. Existing Web Function Chain

```dart
class ShiftState { final bool isShiftOpen; final Shift? currentShift; }

Future<void> loadCurrentShift() async {
  try {
    final current = await service.getCurrentShift();
    state = ShiftState(isShiftOpen: current != null && current.status.toUpperCase() == 'OPEN', currentShift: current);
  } catch (_) {
    state = ShiftState(isShiftOpen: false, currentShift: null);
  }
}

Future<void> openShift({double openingFloat = 0.0}) async {
  final newShift = await service.openShift(openingFloat);   // NO try/catch — propagates to caller
  state = ShiftState(isShiftOpen: true, currentShift: newShift);
}

Future<void> closeShift({double? closingCash}) async {
  if (state.currentShift != null) {
    final closed = await service.closeShift(state.currentShift!.id, closingCash ?? state.currentShift!.openingFloat);
    state = ShiftState(isShiftOpen: false, currentShift: closed);   // <-- sets false UNCONDITIONALLY
  }
}

Future<Map<String, dynamic>> getClosePrecheck() async {
  final current = state.currentShift;
  if (current == null) return const {};
  return service.getClosePrecheck(current.id);
}
```
**Non-obvious fact**: `closeShift` sets `isShiftOpen: false` regardless of whether the backend actually returned `status: 'CLOSED'` or `status: 'PENDING_APPROVAL'` (see section C — a large variance can leave the shift pending, not truly closed). The *boolean flag* goes false either way, but `state.currentShift.status` (the real backend value) is preserved in the returned `closed` object — **read `state.currentShift?.status` for the true state, don't trust `isShiftOpen` alone if you need to distinguish "closed" from "pending approval."**

`ApiShiftService` (exact endpoints):
```dart
Future<Shift?> getCurrentShift() async => Shift.fromJson(await api.get('/api/shifts/current'));
Future<Shift> openShift(double openingCash) async =>
    Shift.fromJson(await api.post('/api/shifts/open', data: {'openingCash': openingCash}));
Future<Shift> closeShift(int shiftId, double closingCash) async =>
    Shift.fromJson(await api.post('/api/shifts/$shiftId/close', data: {'closingCash': closingCash, 'forceClose': false}));
Future<Map<String, dynamic>> getClosePrecheck(int shiftId) async =>
    api.get('/api/shifts/$shiftId/close-precheck');
```

## C. Backend/API Chain — the variance logic, exact code

```text
POST /api/shifts/open   {openingCash}
↓
ShiftController.open (@PreAuthorize PERM_SHIFT_MANAGE or PERM_POS_SALE)
↓
ShiftService.open(request) [backend]
    shiftRepository.findFirstByOpenedByIdAndStoreIdAndStatusOrderByOpenedAtDesc(actor, store, "OPEN")
      .ifPresent(existing -> throw ApiException("An open shift already exists..."))
    Shift saved -> status="OPEN" -> cashEventService.recordInternal(saved, "OPEN_SHIFT", openingCash, ...)

---

POST /api/shifts/{id}/close   {closingCash, forceClose: false}
↓
ShiftController.close (@PreAuthorize PERM_SHIFT_MANAGE — stricter than /open)
↓
ShiftService.close(id, request) [backend]
    private static final BigDecimal VARIANCE_THRESHOLD = new BigDecimal("10.00");
    cashSales = CashEventRepository.sumByShiftIdAndTypes(shiftId, ["SALE_CASH"])
    cashRefunds = sumByShiftIdAndTypes(shiftId, ["REFUND_CASH"])
    manualCashEvents = sumByShiftIdAndTypes(shiftId, ["CASH_IN","CASH_OUT","PAID_IN","PAID_OUT"])
    expected = openingCash + cashSales + cashRefunds + manualCashEvents
    variance = (closingCash - expected).setScale(2, HALF_UP)
    shift.setClosingCash/setExpectedCash/setVariance(...)
    if (variance.abs().compareTo(VARIANCE_THRESHOLD) > 0) {
        if (RoleUtil.hasRole("OWNER") || RoleUtil.hasRole("MANAGER")) {
            shift.setStatus("CLOSED"); shift.setClosedAt(now());   // self-approve
        } else {
            shift.setStatus("PENDING_APPROVAL");                   // cashier must wait
        }
    } else {
        shift.setStatus("CLOSED"); shift.setClosedAt(now());        // variance <= $10.00, auto-close
    }
```
`expectedCash` is computed from **`CashEvent` records**, not directly from `Sale.grandTotal` — this matters if you ever want to display a live "expected cash so far" figure mid-shift on mobile: you'd need to sum the same event types, not just sales totals.

`POST /api/shifts/{id}/approve-variance` is the separate endpoint that later flips a `PENDING_APPROVAL` shift to `CLOSED` — requires a Manager/Owner role, verified server-side.

`Shift` entity fields: `openedBy, closedBy, approvedBy, store, approvalNote, openedAt, closedAt, openingCash, closingCash, expectedCash, variance, status` (`OPEN`/`CLOSED`/`PENDING_APPROVAL`, a plain `String` column).

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `providers/shift_provider.dart` | `ShiftNotifier` | `loadCurrentShift` | — | `Future<void>` | Screen init |
| `providers/shift_provider.dart` | `ShiftNotifier` | `openShift` | `({double openingFloat})` | `Future<void>` (no catch) | Open form submit |
| `providers/shift_provider.dart` | `ShiftNotifier` | `closeShift` | `({double? closingCash})` | `Future<void>` (no catch) | Close form submit |
| `providers/shift_provider.dart` | `ShiftNotifier` | `getClosePrecheck` | — | `Future<Map>` | Pre-close confirmation |
| `providers/shift_provider.dart` | `ShiftHistoryNotifier` | — | — | — | History screen |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_shift_screen.dart
```
No new history screen file needed if you keep the existing `shift_history_screen.dart` reachable via the "More" menu (Day 5) — its layout is a simple list, likely already reasonable at phone width; verify before deciding to rebuild it.

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
class MobileShiftScreen extends ConsumerWidget {
  const MobileShiftScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftState = ref.watch(shiftProvider);
    return Scaffold(
      body: shiftState.isShiftOpen
          ? _CloseShiftForm(shift: shiftState.currentShift!)
          : _OpenShiftForm(),
    );
  }
}

class _CloseShiftForm extends ConsumerWidget {
  final Shift shift;
  const _CloseShiftForm({required this.shift});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        // STEP 1: ALWAYS precheck before closing — mirrors what the existing shift close flow implies.
        final precheck = await ref.read(shiftProvider.notifier).getClosePrecheck();
        if (precheck['blockedByOpenTickets'] == true) {
          // show a mobile confirmation/blocker dialog
          return;
        }
        // STEP 2: collect closing cash from the cashier, then close.
        final closingCash = await _promptClosingCash(context);
        await ref.read(shiftProvider.notifier).closeShift(closingCash: closingCash);
        // STEP 3: check the REAL status, not just isShiftOpen (see section B's warning).
        final status = ref.read(shiftProvider).currentShift?.status;
        if (status == 'PENDING_APPROVAL') {
          // show "awaiting manager approval" UI — this is NOT the same as a failure
        }
      },
      child: Text(context.l10n.closeShift),
    );
  }
}
```

## G. Function Inputs and Outputs

`ShiftNotifier.closeShift({double? closingCash})`
INPUT: `closingCash = 145.50` (cashier's physically-counted drawer total)
DOES: `POST /api/shifts/{id}/close` with `{closingCash, forceClose: false}` → backend computes variance, sets status to `CLOSED` or `PENDING_APPROVAL` per the threshold logic in section C
OUTPUT: `Future<void>` (throws on network/validation failure — no internal catch)
CALLER: `_CloseShiftForm`'s close button
NEXT: `state.currentShift.status` reflects the real backend decision; `state.isShiftOpen` is always `false` after this call regardless.

## H. State Before and After

BEFORE:
```text
ShiftState{ isShiftOpen: true, currentShift: Shift(status: 'OPEN', openingCash: 100.00) }
```
Call: `closeShift(closingCash: 145.50)` where expected was `132.00` (variance = $13.50, over $10 threshold, cashier role)
AFTER:
```text
ShiftState{ isShiftOpen: false, currentShift: Shift(status: 'PENDING_APPROVAL', variance: 13.50) }
```
Then: your mobile UI must check `currentShift.status`, not just `isShiftOpen`, to correctly show "awaiting manager approval" rather than "closed."

## I. What Should Be Shared vs Mobile-Only?

```text
ShiftNotifier / ShiftState / ApiShiftService
🟢 KEEP EXACTLY

Variance threshold / PENDING_APPROVAL logic
🟢 BACKEND-OWNED — never reimplement client-side, on mobile or web

shift_screen.dart layout
🔴 DO NOT COPY layout — 🟢 KEEP EXACTLY its pattern of just displaying whatever the backend returns

MobileShiftScreen
🔵 NEW MOBILE UI
```

## J. Build Order Inside the Day

1. Open `providers/shift_provider.dart`, read all 4 methods (it's short).
2. Open `services/shift_service.dart`, confirm the 4 endpoints and their exact request bodies.
3. Open `screens/shift_screen.dart`, find where it displays `currentShift.variance` — confirm for yourself it never computes anything, only displays.
4. Build `MobileShiftScreen` using the skeleton in F, being careful to branch UI on `currentShift?.status` (the real 3-way state) not just the boolean `isShiftOpen`.
5. Build the close-precheck confirmation step explicitly — don't skip it even though it's easy to.
6. Test opening a shift, then closing it with a small variance (<$10) — confirm `CLOSED`.
7. Test closing with a large variance (>$10) as a cashier-role user — confirm `PENDING_APPROVAL`, confirm your UI shows this distinctly from a normal close.
8. If you have Manager/Owner test credentials, confirm the same large-variance close self-approves to `CLOSED` for that role.

## K. "When I Click This, What Happens?"

# Close shift with variance over $10, as a cashier
```text
Enter closing cash, tap Close
↓
ShiftNotifier.closeShift(closingCash: 145.50)
↓
POST /api/shifts/{id}/close {closingCash: 145.50, forceClose: false}
↓
Backend: expected computed from CashEvent sums, variance = 13.50, abs > 10.00
↓
role check: not OWNER/MANAGER -> status = "PENDING_APPROVAL"
↓
ShiftResponse{status: "PENDING_APPROVAL", variance: 13.50, ...}
↓
ShiftNotifier.state = ShiftState(isShiftOpen: false, currentShift: <the above>)
↓
YOUR mobile UI must check currentShift.status == 'PENDING_APPROVAL' and show that specifically —
if you only check isShiftOpen, you'll incorrectly show "shift closed" to a cashier who actually
needs to find a manager.
```

## L. "Where Does This Value Come From?"

The variance figure shown to the cashier:
```text
Backend: CashEventRepository.sumByShiftIdAndTypes over SALE_CASH/REFUND_CASH/manual events
↓
ShiftService.close computes expected, variance = closingCash - expected
↓
ShiftDtos.ShiftResponse.variance
↓
Shift.fromJson(response)  [Flutter]
↓
ShiftState.currentShift.variance
↓
displayed in MobileShiftScreen — this number is ALWAYS backend-computed, never derived
client-side from anything in ShiftState or CartState.
```

## M. Navigation Flow

`MobileShiftScreen` is likely reached from the bottom-nav "More" menu (Day 5) or a status indicator always visible on the POS screen. No special navigation pattern — standard `Navigator.push`.

## N. Error Flow

```text
openShift/closeShift succeed
→ state updates as shown above

openShift fails (e.g. "An open shift already exists for this cashier and store")
→ ApiException propagates UNCAUGHT out of ShiftNotifier.openShift (no internal try/catch) —
  YOUR mobile screen's button handler MUST wrap this call in its own try/catch, there is no
  existing safety net here to lean on.

closeShift fails similarly uncaught (e.g. precheck-blocking in-progress tickets, if you skip
calling getClosePrecheck first and the backend itself also validates and rejects)
→ same requirement: your UI must catch and display this.
```

## O. Test Flow

Existing tests: `test/shift_provider_test.dart`, `test/shift_history_provider_test.dart` — provider-level, reusable unmodified.
```bash
flutter test test/shift_provider_test.dart
```
Manual test:
```text
1. Open a shift with a $100 opening float.
2. Process a sale or two (or use cash-event test data) to establish an expected cash figure.
3. Close with a closing cash within $10 of expected -> confirm status CLOSED.
4. Open another shift, close with closing cash more than $10 off, as a cashier account -> confirm
   status PENDING_APPROVAL, confirm mobile UI reflects this distinctly.
```

## What I Should Understand Before Day 11

The general rule this day reinforced: **if a business rule has a dollar or legal consequence (variance, tax, discounts, stock levels), the backend already owns it — the mobile client's job is to call the right endpoint and faithfully render whatever comes back, never to recompute or second-guess it.** Day 11 (payment totals, idempotent submission) and Day 17 (purchase order approvals) both lean on this same principle.

---

# Day 11 — Payment: The Complete Checkout Chain (deep)

This is the most important day in the whole plan. Read all of it before writing anything.

## A. Where Do I Start?

Open `lib/features/pos/screens/payment_screen.dart`. Find `_submitSaleToBackend()`. Read it top to bottom once for shape, then come back and read section B below line by line against the real file.

## B. Existing Web Function Chain — every hop, real code

**Hop 0 — how `PaymentScreen` gets constructed**, in `widgets/cart_totals.dart`'s Charge button:
```dart
final int waitingNumber = await notifier.ensureWaitingNumber();
final saleLines = cart.items.map((item) => <String, dynamic>{
  'productId': item.product.id,
  'quantity': item.qty,
  if (item.note != null) 'note': item.note,
  if (item.discountAmount != null && item.discountAmount! > 0)
    'lineDiscount': item.discountAmount! * item.qty,
  if (item.selectedModifiers.isNotEmpty) ...{
    'modifierSummary': item.modifierSummaryText,
    'modifierData': item.modifierDataJson,
  },
}).toList();
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => PaymentScreen(
    total: cart.finalTotal, saleLines: saleLines,
    customerId: cart.customerId, tableId: cart.tableId,
    waitingNumber: waitingNumber, heldTicketId: cart.heldTicketId,
  ),
));
```
`saleLines` is built **here**, from live `CartItem`s, into plain `Map<String, dynamic>` — this is the shape the backend's `SaleCreateRequest.lines` expects, and it's built once, before the payment screen even opens. `PaymentScreen`'s constructor:
```dart
class PaymentScreen extends ConsumerStatefulWidget {
  final double total;
  final List<Map<String, dynamic>>? saleLines;
  final int? customerId;
  final int? tableId;
  final int waitingNumber;      // required, not nullable
  final int? heldTicketId;
}
```

**Hop 1 — `PaymentMethod` enum**:
```dart
enum PaymentMethod { cash, card, aba, khqr, bankTransfer, wing, acleda, check, other }
```
String codes (via an extension): `CASH, CARD, ABA, KHQR, BANK_TRANSFER, WING, ACLEDA, CHECK, OTHER`.

**Hop 2 — split payments, `SplitRow` + `_rebalance()`**:
```dart
class SplitRow { int id; PaymentMethod method; double amount; SplitStatus status; }

void _rebalance() {
  if (_splits.isEmpty) return;
  final total = widget.total;
  final count = _splits.length;
  final floorCents = (total * 100 / count).floor();
  final remainder = (total * 100).round() - floorCents * count;
  for (int i = 0; i < count; i++) {
    final cents = (i < count - 1) ? floorCents : floorCents + remainder;   // last row absorbs remainder
    _splits[i].amount = cents / 100.0;
  }
  _broadcastSplitUpdate();
}
```
Splits are integer-cents math, same discipline as `CartState`'s `Money`-based totals — never let a split row's `.amount` be computed via naive float division.

**Hop 3 — the idempotency key**, a field initializer (constructed once, at widget creation, stable for the screen's lifetime — NOT regenerated per retry):
```dart
final String _clientRef = const Uuid().v4();
```
This is deliberate: if `_submitSaleToBackend()` fails on a network timeout and the cashier taps "Retry" (hop 8), the SAME `_clientRef` is sent again. The backend's `SaleService.create` (section C) checks for an existing sale with that `clientRef` first and returns it instead of creating a duplicate — this is real, verified server-side logic, not just a client-side assumption.

**Hop 4 — dual-currency cash tender**:
```dart
ref.read(tenderCurrenciesProvider.future).then((rates) {
  if (mounted && rates.isNotEmpty) setState(() => _rates = rates);
}).catchError((_) {});

double _convert(double amount, String fromCode, String toCode) {
  final fromRate = _rates[fromCode]?.ratePerUsd ?? 1;
  final toRate = _rates[toCode]?.ratePerUsd ?? 1;
  return amount / fromRate * toRate;
}

double get _changeDue {
  final received = _cashReceived;
  if (received == null) return 0;
  final diff = received - widget.total;
  return diff > 0 ? diff : 0;
}
```

**Hop 5 — `_submitSaleToBackend()`, the full method** (read every line — this is the centerpiece of the whole plan):
```dart
Future<void> _submitSaleToBackend() async {
  if (_isSubmitting) return;
  setState(() => _isSubmitting = true);
  try {
    final cartSnapshot = ref.read(cartProvider);
    final saleItems = List<CartItem>.from(cartSnapshot.items);
    final saleOrderMode = cartSnapshot.orderMode;
    final saleService = ref.read(saleServiceProvider);

    final payments = _splits
        .where((s) => s.status == SplitStatus.authorized)
        .map((s) => paymentRequestEntry(s, _cashReceived))
        .toList();

    final request = <String, dynamic>{
      'lines': widget.saleLines ?? [],
      'clientRef': _clientRef,
      if (widget.customerId != null) 'customerId': widget.customerId,
      if (widget.tableId != null) 'tableId': widget.tableId,
      'orderMode': _getOrderModeFromCart(),
      if (payments.isNotEmpty) 'payments': payments,
      'taxRate': cartSnapshot.taxRate,
      if (cartSnapshot.discountAmount > 0) 'invoiceDiscount': cartSnapshot.discountAmount,
    };

    // 1. CREATE the sale (DRAFT status, no money moved, no stock deducted yet)
    final saleResponse = await saleService.createSale(request);
    final saleId = saleResponse.id;
    _savedSaleItems = saleItems;

    SaleResponse? payResponse;
    // 2. PAY the sale — only if there are actually authorized splits
    if (payments.isNotEmpty) {
      payResponse = await saleService.paySale(saleId, payments);
    } else {
      payResponse = saleResponse;   // sale created but never actually paid!
    }
    if (!mounted) return;

    // 3. release the held ticket, if this checkout came from one — fire-and-forget
    if (widget.heldTicketId != null) {
      unawaited(ref.read(heldTicketProvider.notifier).releaseTicketById(widget.heldTicketId!));
    }

    // 4. save the paid waiting ticket — wrapped in its OWN try/catch, a failure here does NOT
    //    roll back the already-successful sale
    try {
      await ref.read(waitingNumberServiceProvider).saveWaitingTicket(
          waitingNumber: widget.waitingNumber, items: saleItems, orderMode: saleOrderMode,
          status: WaitingTicketStatus.paid, total: widget.total, orderId: saleId);
      ref.invalidate(waitingTicketsProvider);
    } catch (e) {
      // shows a non-fatal warning SnackBar, does NOT fail the whole checkout
    }

    // 5. clear the cart — waiting number kept reserved (released later when collected)
    await ref.read(cartProvider.notifier).clear(releaseWaitingNumber: false);

    if (mounted) {
      setState(() { _completedSale = payResponse; _paymentState = PaymentState.completed; _isSubmitting = false; });
    }

    ref.read(customerDisplayProvider.notifier).broadcastPaymentCompleted(
        receiptNumber: payResponse.invoiceNumber ?? 'Sale #$saleId', total: payResponse.grandTotal,
        amountPaid: payResponse.paidAmount, change: _changeDue, currencySymbol: currencySymbol(_currency));

    // 6. fetch the receipt — NOT awaited, fires in the background, UI already shows "completed"
    unawaited(_fetchCompletedReceipt(saleId));
    if (mounted) unawaited(_autoPrintIfEnabled(context, saleId));
  } catch (e) {
    // see section N for the full error path
  }
}
```
**Read this list of numbered steps until it's automatic.** Note especially: step 2's `else` branch — a sale with zero authorized splits is **created but never actually paid** (still `payResponse = saleResponse`, whose `status` will not be a paid status) — worth deciding deliberately whether your mobile UI should even allow reaching "submit" with no authorized payment method at all, or block it earlier in the flow. Note step 6: the receipt fetch is fire-and-forget — the UI transitions to "completed" *before* the receipt data exists; Day 12's receipt preview must handle the "not yet fetched" case.

**Hop 6 — `SaleService`, the 4 relevant methods, full bodies**:
```dart
Future<SaleResponse> createSale(Map<String, dynamic> request) async {
  final data = await _api.post('/api/pos/sales', data: request) as Map<String, dynamic>;
  return SaleResponse.fromJson(data);
}
Future<SaleResponse> paySale(int saleId, List<Map<String, dynamic>> payments) async {
  final data = await _api.post('/api/pos/sales/$saleId/pay', data: {'payments': payments}) as Map<String, dynamic>;
  return SaleResponse.fromJson(data);
}
Future<Map<String, dynamic>> getReceipt(int saleId) async =>
    await _api.get('/api/pos/sales/$saleId/receipt') as Map<String, dynamic>;
Future<SaleResponse> refundSale(int saleId, {required double amount, required String method, ...}) async { ... }
```
`SaleResponse` fields: `id, invoiceNumber, status, grandTotal, paidAmount, customerName, cashierName, createdAt, currency, payments: List<PaymentSummary>`.

**Hop 7 — no automatic navigation to a receipt screen.** After success, `PaymentScreen` just rebuilds itself into a "completed" view (`_paymentState = PaymentState.completed`). Navigation to `ReceiptPreviewScreen` (Day 12) only happens later, when the cashier explicitly taps "Print Receipt" — `Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(...)))`.

**Hop 8 — the retry button**, wired directly to the same function (section N has the full error-path code).

## C. Backend/API Chain

```text
POST /api/pos/sales   {lines, clientRef, customerId?, tableId?, orderMode, payments?, taxRate, invoiceDiscount?}
↓
SaleController.create (@PreAuthorize PERM_POS_SALE)
    -> saleService.create(request)
↓
SaleService.create(request) [backend, @Transactional]
    // IDEMPOTENCY — checked FIRST, before anything else:
    if (request.clientRef present) {
        existing = saleRepository.findByClientRef(request.clientRef)
        if (existing present) return toResponse(existing);   // <-- retry-safe, confirmed real
    }
    sale = new Sale(); sale.status = "DRAFT"; sale.clientRef = request.clientRef;
    lines = request.lines.map(line -> { product = productRepository.findById(line.productId)
        .orElseThrow(-> ApiException("Product not found")); ... });
    sale.lines.addAll(lines);
    validateSaleStockAvailable(sale);   // CHECKS but does NOT deduct stock yet
    currentShift = shiftRepository.findFirstByOpenedByIdAndStatusOrderByOpenedAtDesc(actor, "OPEN")
    sale.shift = currentShift;
    saved = saleRepository.save(sale);
    return toResponse(saved);

---

POST /api/pos/sales/{id}/pay   {payments: [...]}
↓
SaleController.pay (@PreAuthorize PERM_POS_SALE)
    -> saleService.pay(id, request)
↓
SaleService.pay(...) [backend]
    ...
    if (!sale.isStockApplied()) {
        applyStockForSale(sale);          // <-- STOCK IS ACTUALLY DEDUCTED HERE, NOT ON CREATE
        sale.setStockApplied(true);
    }
```
`applyStockMovement` (the actual deduction, called per line from `applyStockForSale`):
```java
StockItem item = stockItemRepository.findByProductIdAndStoreIdForUpdate(productId, storeId)  // PESSIMISTIC LOCK
        .orElseThrow(() -> new ApiException(insufficientStockMessage(...)));
BigDecimal newQty = item.getQuantity().subtract(quantity);
if (newQty.compareTo(BigDecimal.ZERO) < 0) throw new ApiException(insufficientStockMessage(...));
item.setQuantity(newQty); stockItemRepository.save(item);
StockMovement movement = new StockMovement();
movement.setMovementType("SALE"); movement.setQuantity(quantity.negate());
stockMovementRepository.save(movement);   // audit trail row
```
Bundled products deduct each component's underlying product instead; `trackInventory=false` products are skipped entirely.

```text
GET /api/pos/sales/{id}/receipt
↓
SaleController.receipt -> saleService.receipt(id) -> ReceiptDtos.ReceiptResponse
```

**Entities touched**: `Sale` (`sales` table: status, saleNumber, terminalId, clientRef, subtotal, discountAmount, taxRate, taxAmount, grandTotal, totalAmount, paidAmount, changeAmount, customer, createdBy, shift), `SaleLine` (`sale_lines`: sale, product, quantity, unitPrice, lineDiscount, lineTotal, stockDeductedQuantity, modifierData), `StockItem` (`stock_items`, unique on store+product, has an optimistic-lock `version` column in addition to the pessimistic row lock used during deduction).

**Status codes**: 200 on success for both `create` and `pay` (plain body return, no `@ResponseStatus`). `ApiException` → 400 for: product not found, insufficient stock, sale in wrong status for `pay`. `@PreAuthorize` failure → 403.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `services/sale_service.dart` | `SaleService` | `createSale` | `Map<String,dynamic>` | `Future<SaleResponse>` | Call unchanged |
| `services/sale_service.dart` | `SaleService` | `paySale` | `(int, List<Map>)` | `Future<SaleResponse>` | Call unchanged |
| `services/sale_service.dart` | `SaleService` | `getReceipt` | `int saleId` | `Future<Map>` | Feeds Day 12 |
| `providers/held_ticket_provider.dart` | `HeldTicketNotifier` | `releaseTicketById` | `int` | `Future<void>` (swallows errors) | Step 3 of checkout |
| `services/waiting_number_service.dart` | `WaitingNumberService` | `saveWaitingTicket` | see Day 9 | `Future<WaitingTicket>` | Step 4 of checkout |
| `providers/cart_provider.dart` | `CartNotifier` | `clear` | `({bool releaseWaitingNumber})` | `Future<void>` | Step 5 of checkout |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_payment_screen.dart
```
PURPOSE: vertical checkout flow replacing `payment_screen.dart`'s 2-column `Row` (`flex:5` cart list | `VerticalDivider` | `flex:5` payment panel — the single most desktop-specific screen in the app). Every piece of DATA underneath it (section D) is already mobile-ready — this file changes LAYOUT ONLY, the logic in `_submitSaleToBackend` should be reused essentially verbatim.

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste. Shows structure only; the real `_submitSaleToBackend` logic (hop 5 above) should be ported close to verbatim, not reinvented.
```dart
class MobilePaymentScreen extends ConsumerStatefulWidget {
  final double total;
  final List<Map<String, dynamic>>? saleLines;
  final int? customerId;
  final int? tableId;
  final int waitingNumber;
  final int? heldTicketId;
  const MobilePaymentScreen({super.key, required this.total, this.saleLines,
      this.customerId, this.tableId, required this.waitingNumber, this.heldTicketId});
  @override
  ConsumerState<MobilePaymentScreen> createState() => _MobilePaymentScreenState();
}

class _MobilePaymentScreenState extends ConsumerState<MobilePaymentScreen> {
  final String _clientRef = const Uuid().v4();   // STEP 1: same idempotency pattern, unchanged
  bool _isSubmitting = false;
  List<SplitRow> _splits = [];

  Future<void> _submitSaleToBackend() async {
    // STEP 2: port hop 5's method essentially verbatim — this is NOT a place to simplify.
    // The 6 numbered steps in section B, hop 5 are the specification.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // STEP 3: vertical layout — order summary (collapsible) -> method chips -> amount entry
      // (large touch-friendly keypad) -> split rows (stacked, not columned) -> Charge button.
      body: Column(children: [
        // ...
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitSaleToBackend,
          child: Text(context.l10n.completeSale),
        ),
      ]),
    );
  }
}
```

## G. Function Inputs and Outputs

`SaleService.createSale(Map<String, dynamic> request)`
INPUT:
```text
request = {
  'lines': [{'productId': 42, 'quantity': 2}],
  'clientRef': 'a1b2c3d4-...',
  'tableId': 3,
  'orderMode': 'dineIn',
  'payments': [{'method': 'CASH', 'amount': 5.00}],
  'taxRate': 0.10,
}
```
DOES: `POST /api/pos/sales` → backend checks `clientRef` for an existing sale first (idempotent), else creates a `DRAFT` sale, validates stock availability (does not deduct), attaches the current open shift.
OUTPUT: `Future<SaleResponse>` — `{id, invoiceNumber, status: 'DRAFT', grandTotal, ...}`
CALLER: `_submitSaleToBackend`, step 1
NEXT: if `payments` non-empty, `paySale(saleId, payments)` is called next — this is what actually moves money and deducts stock.

## H. State Before and After

BEFORE:
```text
CartState.items = [2 items], finalTotal = 5.00
```
Call sequence: `createSale(...)` → `paySale(saleId, [{method:'CASH', amount:5.00}])` → `cartProvider.notifier.clear(releaseWaitingNumber: false)`
AFTER:
```text
CartState = CartState.initial()   (empty, waiting number preserved)
Backend: Sale{status: some paid status}, StockItem quantities decremented, StockMovement rows created
Widget state: _paymentState = PaymentState.completed, _completedSale = payResponse
```

## I. What Should Be Shared vs Mobile-Only?

```text
PaymentMethod enum / SplitRow / _rebalance()
🟢 KEEP EXACTLY

_clientRef generation pattern (const Uuid().v4(), stable per screen instance)
🟢 KEEP EXACTLY

SaleService (all methods)
🟢 KEEP EXACTLY

_submitSaleToBackend()'s 6-step sequence
🟢 KEEP EXACTLY (port the logic, not the layout)

payment_screen.dart's 2-column Row layout
🔴 DO NOT COPY

MobilePaymentScreen
🔵 NEW MOBILE UI
```

## J. Build Order Inside the Day

1. Open `payment_screen.dart`. Read the constructor, `PaymentMethod`, `SplitRow`/`_rebalance()`.
2. Find `_clientRef`'s declaration — confirm for yourself it's a field initializer, not regenerated inside `_submitSaleToBackend`.
3. Read `_submitSaleToBackend()` in full, matching it against the 6 numbered steps in section B, hop 5. Do not skip any step, including the fire-and-forget ones (3 and 6) and the non-fatal try/catch (step 4).
4. Open `services/sale_service.dart`, read `createSale`, `paySale`, `getReceipt`.
5. Create `mobile_payment_screen.dart` with the constructor matching `PaymentScreen`'s exactly.
6. Port `_submitSaleToBackend` near-verbatim — resist the urge to "clean it up," since its exact sequencing (release ticket before saving waiting ticket, clear cart before fetching receipt, etc.) reflects real product decisions already made.
7. Build the vertical layout: order summary → method selector (chips, not a dropdown) → amount entry (decide: OS numeric keyboard vs. a custom on-screen keypad — both platforms support either equally, this is UX not a platform constraint) → split rows stacked vertically.
8. Port dual-currency cash tender and quick-cash presets.
9. Wire the Charge/Complete button, disabled while `_isSubmitting`.
10. Test a full cash sale end to end.
11. Test a split payment (2+ methods).
12. Test the idempotency guarantee directly: trigger a submit, then (in a debug build) force it to retry with the same `_clientRef` — confirm no duplicate sale is created (check via the backend or `listSales`).

## K. "When I Click This, What Happens?"

# Tap "Complete Sale" (single cash payment, full amount tendered)
```text
Tap Complete Sale
↓
_submitSaleToBackend()
↓
build request map (lines, clientRef, taxRate, ...)
↓
SaleService.createSale(request) -> POST /api/pos/sales -> Sale{status: DRAFT} created
↓
payments = [{method: CASH, amount: 5.00}]  (non-empty)
↓
SaleService.paySale(saleId, payments) -> POST /api/pos/sales/{id}/pay
↓
backend: stock deducted here (applyStockForSale), sale marked paid
↓
heldTicketId null -> skip release
↓
WaitingNumberService.saveWaitingTicket(status: paid, orderId: saleId)
↓
cartProvider.notifier.clear(releaseWaitingNumber: false)
↓
setState: _paymentState = completed
↓
(background, not awaited) getReceipt(saleId) -> feeds Day 12's preview when it resolves
↓
(background, not awaited) auto-print if enabled -> feeds Day 13/15
```

# Tap "Complete Sale" with a partially-filled split (not all rows authorized)
```text
Tap Complete Sale
↓
payments = _splits.where(status == authorized) -> may be a SUBSET of _splits
↓
if payments is empty entirely: sale is CREATED but payResponse = saleResponse (status DRAFT, unpaid!)
↓
YOUR mobile UI should decide explicitly whether to allow reaching this button at all with zero
authorized splits, or block earlier — the existing code does not prevent it at the function level.
```

## L. "Where Does This Value Come From?"

The grand total charged:
```text
CartItem data (product prices, qty, modifier deltas)
↓
CartState.finalTotal  (Money-based integer-safe calc, Day 7)
↓
passed as PaymentScreen.total constructor param (from cart_totals.dart's Charge button)
↓
used for split _rebalance() and displayed throughout PaymentScreen
↓
NOT recomputed anywhere in PaymentScreen — it trusts the value the cart already computed
```
The change amount:
```text
_cashReceived (raw tendered amount, converted via _convert() if a different tender currency was used)
↓
_changeDue getter: max(0, received - widget.total)
↓
displayed to cashier AND broadcast to customerDisplayProvider for a secondary screen
```

## M. Navigation Flow

`MobileCartScreen` → `MobilePaymentScreen`: `Navigator.push(MaterialPageRoute(...))` — NOT a named route, because `PaymentScreen` needs constructor parameters (`total`, `saleLines`, etc.) a route string can't carry. After success: **no automatic navigation** — the screen rebuilds in place to a "completed" view; only an explicit "Print Receipt" tap triggers `Navigator.push` to `ReceiptPreviewScreen` (Day 12).

## N. Error Flow

```text
createSale succeeds, paySale succeeds
→ full success path as shown in K

createSale throws (network error, product not found, insufficient stock)
→ caught by _submitSaleToBackend's outer try/catch
→ debugPrint('Sale submission failed: $e')
→ ScaffoldMessenger SnackBar shown, RED background, message via context.l10n.paymentScreenSaleFailed('$e')
→ SnackBarAction labeled Retry, onPressed: _submitSaleToBackend directly (re-invokes the SAME function,
  with the SAME _clientRef — this is exactly why the stable clientRef matters: a retry after a
  transient network failure is safe, will not double-charge/double-create)
→ setState: _paymentState = PaymentState.failed, _isSubmitting = false
→ UI shows a "Try Again" button (not just the SnackBar) via the failed-state view

paySale throws AFTER createSale already succeeded
→ same catch block, same SnackBar/Retry flow — but note: a retry here calls createSale AGAIN with
  the same clientRef, which the backend correctly returns the EXISTING (already-created, unpaid)
  sale for, rather than erroring — then attempts paySale again. This works correctly precisely
  because of the idempotency check in section C.

waitingNumberService.saveWaitingTicket throws (step 4)
→ caught in its OWN inner try/catch, does NOT trigger the outer failure path — the sale is
  already successful at this point, only a non-fatal warning SnackBar is shown
```

## O. Test Flow

Existing tests: `test/payment_page_test.dart`, `test/payment_screen_test.dart`, `test/payment_request_entry_test.dart`, `test/sale_service_idempotency_test.dart` (the last one specifically tests the retry-safety behavior described above — read it for the exact scenario it covers before writing your own mobile equivalent).
```bash
flutter test test/sale_service_idempotency_test.dart test/payment_screen_test.dart
```
Manual test:
```text
1. Full cash sale, exact change -> confirm sale completes, stock decrements (check via Inventory Day 17).
2. Full cash sale, over-tender -> confirm correct change calculated and displayed.
3. Split payment (cash + card) -> confirm both authorized splits submitted, sale total matches.
4. Turn off Wi-Fi mid-submit (or use a network throttle) -> confirm failure UI + Retry button appear.
5. Turn Wi-Fi back on, tap Retry -> confirm exactly ONE sale was created (check backend/receipt list),
   not two.
6. Attempt Charge with zero authorized splits (if your UI allows reaching this) -> confirm you
   understand and have decided what should happen (block earlier, or allow an unpaid DRAFT sale).
```

## What I Should Understand Before Day 12

That `getReceipt(saleId)` is fetched in the background, AFTER the UI already shows "completed" — meaning Day 12's receipt preview screen must handle a brief window where the receipt data doesn't exist yet, and must never block the payment-completed UI on that fetch finishing.

---

# Day 12 — Receipt: ReceiptViewModel to Preview

## A. Where Do I Start?

Open `lib/features/pos/services/printing/receipt_view_model.dart`. Read `ReceiptViewModel.fromReceiptResponse` fully — this factory is the seam between "a JSON map from the backend" and "everything printing-related reads this one object."

## B. Existing Web Function Chain

`ReceiptViewModel.fromReceiptResponse` — full body:
```dart
factory ReceiptViewModel.fromReceiptResponse(ReceiptResponse r, AppLanguage language, AppLocalizations l10n) {
  final createdAtLocal = parseBackendTimestamp(r.createdAt);   // UTC string -> local DateTime, ONE place
  return ReceiptViewModel(
    language: language,
    businessName: r.businessName ?? r.storeName ?? l10n.appName,      // 3-level fallback
    invoiceNumber: r.saleNumber ?? '#${r.saleId}',                     // fallback if no saleNumber
    date: createdAtLocal != null ? formatReceiptDate(createdAtLocal) : (r.createdAt ?? ''),
    time: createdAtLocal != null ? formatReceiptTime(createdAtLocal) : '',
    lines: r.lines.map((line) => ReceiptLineViewModel(
        name: line.localizedName(language),    // bilingual resolve happens HERE, per line
        qty: line.qty, unitPrice: line.unitPrice, lineTotal: line.lineTotal,
        modifierAmount: line.modifierAmount, modifierSummary: line.modifierSummary)).toList(),
    subtotal: r.subtotal, discountAmount: r.discountAmount, taxAmount: r.taxAmount,
    total: r.total, paidAmount: r.paidAmount, changeAmount: r.changeAmount,
    currencyCode: r.currency, qrImageData: r.qrImageData, logoUrl: r.logoUrl,
    footer: (r.footer != null && r.footer!.isNotEmpty) ? r.footer! : l10n.receiptThankYou,
    paymentMethodLabel: r.payments.isNotEmpty ? r.payments.first.method : null,   // ONLY the first payment
    labels: ReceiptLabels.fromL10n(l10n),
  );
}
```
Three things worth noticing: (1) `businessName` falls back `r.businessName → r.storeName → l10n.appName`; (2) `invoiceNumber` falls back to `'#${r.saleId}'` if `saleNumber` is null — meaning a receipt for a not-yet-numbered sale still displays something sensible; (3) `paymentMethodLabel` only ever shows the *first* payment method, even for a split-payment sale — a real limitation to know about if you're building a mobile receipt for split payments (Day 11).

`containsKhmer` and `_allText` (the trigger for Day 14's whole rendering strategy):
```dart
bool get containsKhmer => language.isKhmer || containsKhmerText(_allText);
String get _allText => [businessName, customerName, cashierName, footer, ...lines.map((l) => l.name)]
    .whereType<String>().join();
```
True if the UI language itself is Khmer, OR if any of those specific fields contains Khmer script even under an English UI — checked **once per whole document**, not per line.

`ReceiptContent` (`widgets/receipt_paper_view.dart`) — the ONE shared widget:
```dart
const double kReceiptContentWidth = 300;

class ReceiptContent extends StatelessWidget {
  final ReceiptViewModel receipt;
  @override
  Widget build(BuildContext context) {
    final labels = receipt.labels;
    return Column(children: [
      Center(child: _Text(receipt.businessName, 22, bold: true)),
      _info(labels.invoiceNumber, receipt.invoiceNumber),
      ...List.generate(receipt.lines.length, (i) => _buildRow(receipt.lines[i], receipt)),
      _total(labels.total, receipt.fmt(receipt.total), bold: true, large: true),
    ]);
  }
}
```
This is a plain `StatelessWidget` — no Riverpod. `kReceiptContentWidth = 300` is the fixed logical width both the on-screen preview AND (critically, Day 14) the off-screen Khmer rasterizer mount this exact widget at.

## C. Backend/API Chain

```text
GET /api/pos/sales/{id}/receipt
↓
SaleController.receipt(@PathVariable Long id) -> saleService.receipt(id)
↓
ReceiptDtos.ReceiptResponse{businessName, storeName, saleNumber, saleId, createdAt, cashierName,
    customerName, tableNumber, lines: [...], subtotal, discountAmount, taxAmount, total,
    paidAmount, changeAmount, currency, qrImageData, logoUrl, footer, payments: [...]}
```
This is called from `PrintService.printReceipt` directly via `_api.get<Map>('/api/pos/sales/$saleId/receipt')` — **not** through `SaleService.getReceipt` in the printing path (both exist and hit the same endpoint; `SaleService.getReceipt` is what Day 11's `_fetchCompletedReceipt` uses for the post-checkout preview, `PrintService` calls the same URL independently for the actual print action).

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `services/printing/receipt_view_model.dart` | `ReceiptViewModel` | `fromReceiptResponse` | `(ReceiptResponse, AppLanguage, AppLocalizations)` | `ReceiptViewModel` | Call unchanged after checkout |
| `widgets/receipt_paper_view.dart` | `ReceiptContent` | (widget) | `ReceiptViewModel` | `Widget` | Reuse exactly — do not fork |
| `services/sale_service.dart` | `SaleService` | `getReceipt` | `int saleId` | `Future<Map>` | Fetch after checkout |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_receipt_preview_screen.dart
```
PURPOSE: full-screen, scrollable wrapper around the SAME `ReceiptContent` widget — not a new receipt renderer.
CLASS: `MobileReceiptPreviewScreen extends ConsumerWidget`

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
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
        // STEP 1: reuse the EXISTING service call — no new fetch logic.
        future: ref.read(saleServiceProvider).getReceipt(saleId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final receipt = ReceiptResponse.fromJson(snapshot.data!);
          final language = ref.read(appLanguageProvider);
          final l10n = AppLocalizations.of(context);
          // STEP 2: same factory, same widget, as the desktop preview.
          final viewModel = ReceiptViewModel.fromReceiptResponse(receipt, language, l10n);
          return SingleChildScrollView(child: Center(child: ReceiptContent(receipt: viewModel)));
        },
      ),
    );
  }
}
```

## G. Function Inputs and Outputs

`ReceiptViewModel.fromReceiptResponse(ReceiptResponse r, AppLanguage language, AppLocalizations l10n)`
INPUT: the raw `GET /api/pos/sales/{id}/receipt` response, parsed into `ReceiptResponse`
DOES: maps every field with the fallbacks shown in section B, resolves each line's bilingual name, computes `containsKhmer`
OUTPUT: `ReceiptViewModel` (immutable, pure data)
CALLER: any screen needing a receipt — preview, PDF builder, ESC/POS builder (Days 13–15 all start here)
NEXT: `ReceiptContent(receipt: viewModel)` for on-screen display, or `PrintService.buildReceiptPdf` for PDF.

## H. State Before and After

Not Riverpod-state-driven — `ReceiptViewModel` is a plain immutable object constructed fresh each time from a fetched map, not stored in a provider. "Before" is `snapshot.hasData == false` (loading), "after" is a fully-populated `ReceiptContent` tree.

## I. What Should Be Shared vs Mobile-Only?

```text
ReceiptViewModel.fromReceiptResponse / .fromCart
🟢 KEEP EXACTLY

ReceiptContent / receipt_layout_spec.dart / ReceiptLabels
🟢 KEEP EXACTLY

kReceiptContentWidth
🟢 KEEP EXACTLY — Day 14 depends on this constant staying 300

receipt_preview_screen.dart (desktop dialog sizing)
🔴 DO NOT COPY layout — 🟢 KEEP EXACTLY its ReceiptContent usage

MobileReceiptPreviewScreen
🔵 NEW MOBILE UI
```

## J. Build Order Inside the Day

1. Open `receipt_view_model.dart`, read `fromReceiptResponse` and `fromCart` fully, and `containsKhmer`/`_allText`.
2. Open `receipt_paper_view.dart`, read `kReceiptContentWidth` and `ReceiptContent.build()`.
3. Create `mobile_receipt_preview_screen.dart` using the skeleton in F.
4. Wire it to appear automatically after Day 11's checkout completes (or via an explicit "View Receipt" button — the desktop app requires an explicit tap, matching Day 11's finding that there's no automatic navigation).
5. Test with an English-only receipt.
6. Test with a Khmer receipt — confirm it visually matches the desktop preview (same layout, same 58/80mm-appropriate proportions) even though Day 14 hasn't built the print path yet — the ON-SCREEN preview uses native Flutter text rendering regardless of `containsKhmer`, so Khmer should already render correctly on-screen today.

## K. "When I Click This, What Happens?"

# View receipt after checkout
```text
Tap "View Receipt" (or auto-navigate, per your Day 11 decision)
↓
Navigator.push(MobileReceiptPreviewScreen(saleId: saleId))
↓
SaleService.getReceipt(saleId) -> GET /api/pos/sales/{id}/receipt
↓
ReceiptResponse.fromJson(map)
↓
ReceiptViewModel.fromReceiptResponse(receipt, language, l10n)
↓
ReceiptContent(receipt: viewModel) renders
```

## L. "Where Does This Value Come From?"

Receipt total shown in the preview:
```text
Backend: finalized Sale.grandTotal (already computed and stored server-side at checkout)
↓
ReceiptDtos.ReceiptResponse.total
↓
ReceiptViewModel.total  (a direct passthrough — NOT recomputed from cart data)
↓
ReceiptContent's _total row
```
Contrast with Day 7's cart total (computed client-side via `Money`) — the RECEIPT total is always the backend's authoritative post-sale figure, never recalculated client-side.

## M. Navigation Flow

`Navigator.push(MaterialPageRoute(builder: (_) => MobileReceiptPreviewScreen(saleId: saleId)))` — a normal push, not a replace (user can go back to the payment-completed screen).

## N. Error Flow

```text
getReceipt succeeds
→ ReceiptContent renders normally

getReceipt fails (network error, or called too soon before the sale is fully committed)
→ your FutureBuilder's snapshot.hasError branch must handle this — the existing desktop
  receipt_preview_screen.dart has its own handling to model this on; there's no shared
  "receipt fetch failed" widget to reuse verbatim, build a simple retry affordance.
```

## O. Test Flow

Existing tests: `test/receipt_financial_fields_test.dart`, `test/receipt_labels_test.dart`, `test/receipt_website_test.dart`, `test/receipt_timestamp_test.dart` — all target `ReceiptViewModel`/model-level correctness, reusable unmodified.
```bash
flutter test test/receipt_financial_fields_test.dart test/receipt_timestamp_test.dart
```
Manual test: complete one English sale and one sale with Khmer product names, view both receipts, visually compare against the desktop app's preview for the same data.

---

## Addendum (production sync, added after this plan was first written) — Mobile Receipts History: Status Filters and the Refunded Family

The single-receipt `ReceiptViewModel`/`ReceiptContent` architecture taught in sections A–O above is **unchanged**. This addendum documents a separate, real production change to the **Receipts history screen** (browsing past sales, filtering by status, reprinting) — `lib/features/pos/providers/receipt_provider.dart` and `lib/features/pos/screens/receipts_screen.dart` — which this plan had not previously covered. Everything below was read directly from the current source, not carried over from an earlier draft.

### Where Do I Start

Open `lib/features/pos/providers/receipt_provider.dart`. Read `saleMatchesStatusFilter`, `backendStatusQueryFor`, and `ReceiptState.filteredSales` together — these three pieces are the entire status-filtering system. A stale `'PENDING'` filter chip and dead `sale.status == 'COMPLETED'` checks were removed as part of this change: neither `PENDING` nor `COMPLETED` is ever a real `Sale.status` value the backend produces, so don't reintroduce either as a filter or a status check anywhere in mobile code. (This is unrelated to `PENDING_APPROVAL`, the real backend *shift* status from Day 10 — different domain entirely, still correct as documented there.)

### The Real Filters, Exact Code

```dart
// lib/features/pos/providers/receipt_provider.dart

/// The "Refunded" filter/chip represents a family of two real backend
/// statuses — REFUNDED and PARTIALLY_REFUNDED both mean "some refund has
/// happened on this sale" — not a single literal `Sale.status` value.
bool saleMatchesStatusFilter(String saleStatus, String filterStatus) {
  if (filterStatus == 'REFUNDED') {
    return saleStatus == 'REFUNDED' || saleStatus == 'PARTIALLY_REFUNDED';
  }
  return saleStatus == filterStatus;
}

/// The backend's `GET /api/pos/sales?status=` query param only accepts one
/// literal status, so it can't express the REFUNDED filter's two-status
/// family — in that case the fetch is left unfiltered (`null`) and
/// saleMatchesStatusFilter does the narrowing client-side instead.
String? backendStatusQueryFor(String? filterStatus) =>
    filterStatus == 'REFUNDED' ? null : filterStatus;
```
**The single most important teaching point in this addendum**: tapping the "Refunded" chip does **not** mean `status == 'REFUNDED'`. It means `status == 'REFUNDED' OR status == 'PARTIALLY_REFUNDED'`. The backend's list endpoint accepts only one literal status value per request — it has no way to ask for "REFUNDED or PARTIALLY_REFUNDED" in a single query — so `backendStatusQueryFor('REFUNDED')` deliberately returns `null` (fetch unfiltered) and `saleMatchesStatusFilter` does the real narrowing entirely client-side, inside `ReceiptState.filteredSales`. `PAID` and `VOID` have no such family — the backend can express them directly, so `backendStatusQueryFor` passes them through unchanged and the server narrows them.

`ReceiptState.filteredSales` — the getter every screen must read (never `state.sales` directly, which is only the raw fetched list):
```dart
List<SaleResponse> get filteredSales {
  Iterable<SaleResponse> result = sales;
  final status = statusFilter?.trim();
  if (status != null && status.isNotEmpty) {
    result = result.where((sale) => saleMatchesStatusFilter(sale.status, status));
  }
  final query = searchQuery?.trim().toLowerCase();
  if (query != null && query.isNotEmpty) {
    result = result.where((sale) =>
        (sale.invoiceNumber?.toLowerCase() ?? '').contains(query) ||
        (sale.customerName?.toLowerCase() ?? '').contains(query) ||
        sale.id.toString().contains(query));
  }
  return result.toList();
}
```

`ReceiptNotifier` — current signatures:
```dart
Future<void> loadActiveShiftSales()                 // no status param — always the current shift's sales
Future<void> loadAllSales({String? status})          // status is the RESOLVED backend query value —
                                                       // caller must pass backendStatusQueryFor(uiFilter),
                                                       // never the raw UI filter string
void setSearchQuery(String query)
void setStatusFilter(String? status)                 // owns the UI-selected chip
Future<void> loadReceipt(int saleId)
```
**Important, easy to get backwards**: `setStatusFilter` and `loadAllSales` are independent now. `loadAllSales(status: ...)` does **not** also set `state.statusFilter` as a side effect — that coupling used to exist and was a real bug (toggling "All Sales" off and back on would silently re-fetch and clear whichever filter chip was selected). Today, `setStatusFilter` is the *only* function that changes `state.statusFilter`; a caller wanting both server-side narrowing and a synced chip UI must call both, exactly as `receipts_screen.dart`'s own filter-chip handler does.

### Backend/API Chain

```text
GET /api/pos/sales?status=PAID   (or VOID, or omitted for All/Refunded)
↓
SaleController's list-sales endpoint — the same one SaleService.listSales() already calls
↓
List<SaleResponse>  (real `status` values: PAID, VOID, REFUNDED, PARTIALLY_REFUNDED, CREDIT, DRAFT, HOLD)
```
No backend change was needed for this fix — the endpoint already accepted a single `status` param; the fix was entirely in how the Flutter client decides what to send it and how it filters what comes back.

### Mobile Function Flow — Loading and Displaying

```text
MobileReceiptsScreen (build)
  ↓
ref.watch(receiptProvider)
  ↓
ReceiptState
  ↓
state.filteredSales
  ↓ (saleMatchesStatusFilter is ALREADY applied inside filteredSales — the widget just reads the result)
mobile receipt list rebuilds
```

### Mobile Function Flow — Changing the Filter

```text
User taps a filter chip (e.g. "Refunded")
  ↓
ref.read(receiptProvider.notifier).setStatusFilter('REFUNDED')
  ↓
state.statusFilter = 'REFUNDED'   (chip selection updates immediately — filteredSales re-derives
  from the ALREADY-loaded state.sales, no network call required for this step alone)
  ↓
(for a fresh fetch too — e.g. pull-to-refresh, or the Shift/All toggle — mirror
 receipts_screen.dart's own pattern and call both:)
backendStatusQueryFor('REFUNDED')  -> null   (backend can't express the 2-status family)
  ↓
ref.read(receiptProvider.notifier).loadAllSales(status: null)
  ↓
SaleService.listSales(status: null)  -> GET /api/pos/sales   (unfiltered — every sale returned)
  ↓
state.sales = <every sale>
  ↓
state.filteredSales re-derives -> saleMatchesStatusFilter narrows to REFUNDED + PARTIALLY_REFUNDED
  ↓
UI rebuilds with exactly the 2-status family, even though the fetch itself was unfiltered
```

### Exact New Mobile File to Create

```text
lib/features/pos/mobile/screens/mobile_receipts_screen.dart
```
PURPOSE: full-screen receipt history, replacing `receipts_screen.dart`'s split list/detail-pane layout (built for wide screens) with a list → tap → full-screen detail flow.
CLASS: `MobileReceiptsScreen extends ConsumerStatefulWidget`
USES PROVIDER: `receiptProvider`
CALLS FUNCTION: `setStatusFilter`, `loadAllSales`/`loadActiveShiftSales`, `loadReceipt`, `PrintService.printReceipt` (reprint)

EDUCATIONAL SKELETON — not production copy/paste:
```dart
class MobileReceiptsScreen extends ConsumerWidget {
  const MobileReceiptsScreen({super.key});
  // STEP 1: SAME filter set as the desktop screen — do not add back a PENDING chip or invent new ones.
  static const _statusFilters = [null, 'PAID', 'VOID', 'REFUNDED'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptProvider);
    return Scaffold(
      body: Column(children: [
        Row(children: [
          for (final f in _statusFilters)
            FilterChip(
              label: Text(f ?? context.l10n.commonAll),
              selected: state.statusFilter == f,
              // STEP 2: call setStatusFilter for the chip; call loadAllSales with the
              // RESOLVED backend query if you also want a fresh fetch on this tap.
              onSelected: (_) {
                ref.read(receiptProvider.notifier).setStatusFilter(f);
                ref.read(receiptProvider.notifier).loadAllSales(status: backendStatusQueryFor(f));
              },
            ),
        ]),
        Expanded(
          child: ListView(children: [
            // STEP 3: ALWAYS read filteredSales, never state.sales directly.
            for (final sale in state.filteredSales)
              ListTile(
                title: Text(sale.invoiceNumber ?? '#${sale.id}'),
                trailing: Text(sale.status),   // map through _statusBadgeLabel-equivalent for display
                onTap: () => ref.read(receiptProvider.notifier).loadReceipt(sale.id),
              ),
          ]),
        ),
      ]),
    );
  }
}
```

### Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `providers/receipt_provider.dart` | — | `saleMatchesStatusFilter` | `(String saleStatus, String filterStatus)` | `bool` | Call unchanged — never reimplement the REFUNDED-family check |
| `providers/receipt_provider.dart` | — | `backendStatusQueryFor` | `String? filterStatus` | `String?` | Call before every `loadAllSales` — never send the raw UI filter straight to the backend |
| `providers/receipt_provider.dart` | `ReceiptNotifier` | `setStatusFilter` | `String? status` | `void` | Filter chip tap |
| `providers/receipt_provider.dart` | `ReceiptNotifier` | `loadAllSales` | `{String? status}` | `Future<void>` | Pass `backendStatusQueryFor(uiFilter)`, not the raw filter |
| `providers/receipt_provider.dart` | `ReceiptNotifier` | `loadActiveShiftSales` | — | `Future<void>` | Default "current shift" view |
| `providers/receipt_provider.dart` | `ReceiptNotifier` | `loadReceipt` | `int saleId` | `Future<void>` | Row tap → detail |
| `services/print_service.dart` | `PrintService` | `printReceipt` | `(BuildContext, int saleId)` | `Future<bool>` | Reprint — the SAME function Day 13 wires up, no second pipeline |

### Status Action Rules — Do Not Invent Transitions

Confirmed directly from `receipts_screen.dart`'s own action-building code, not inferred:

```text
PAID
  -> Print
  -> Save PDF
  -> Email
  -> Refund (SaleService.refundSale, Day 11 — shown for PAID and PARTIALLY_REFUNDED)

VOID
  -> Print
  -> Save PDF
  -> Email
  -> NO Pay action exists anywhere in this codebase for a VOID sale
  -> NO Refund action (the Refund button's condition is literally
     `receipt.status == 'PAID' || receipt.status == 'PARTIALLY_REFUNDED'` — VOID is excluded)
  -> VOID is TERMINAL — there is no VOID -> PAID transition anywhere in the app or backend;
     do not document or build one.

REFUNDED
  -> Print
  -> Save PDF
  -> Email
  -> no further Refund action shown (already fully refunded)

PARTIALLY_REFUNDED
  -> Print
  -> Save PDF
  -> Email
  -> Refund (further refund IS permitted — same button PAID gets, per the condition above)
```
`DRAFT` and `HOLD` statuses can appear in the raw sale list but represent unpaid/held tickets — their payment/resume flow belongs to Open Tickets (Day 9) and the normal checkout/payment flow (Day 11), **not** to the Receipts screen's action menu; do not add a "Pay" button here for them.

### Error Flow

```text
loadAllSales/loadActiveShiftSales succeed -> state.sales updates, filteredSales re-derives

loadAllSales/loadActiveShiftSales fail (network error)
→ caught internally, state.error set, state.selectedReceipt cleared -> your mobile screen
  must display state.error, matching receipts_screen.dart's own error banner

setStatusFilter never fails — synchronous, local-only state, no error path
```

### Test Flow

Existing tests, both directly reusable, unmodified:
```bash
flutter test test/receipt_status_filter_test.dart
flutter test test/receipts_screen_filter_test.dart
```
`receipt_status_filter_test.dart` covers `saleMatchesStatusFilter`, `backendStatusQueryFor`, and `ReceiptState.filteredSales` at the pure-function/model level — including a regression test proving a stale `'PENDING'` filter value now matches nothing (documenting why the chip was removed rather than replaced with another fake status) and a regression test proving `loadAllSales` no longer silently clears `state.statusFilter`. `receipts_screen_filter_test.dart` covers the same behavior end-to-end through the real widget tree.

Manual test:
```text
1. All filter -> confirm every applicable receipt-history row shows, no filtering applied.
2. Paid filter -> confirm ONLY PAID rows show.
3. Void filter -> confirm ONLY VOID rows show; confirm there is no PENDING chip anywhere.
4. Refunded filter -> confirm BOTH REFUNDED and PARTIALLY_REFUNDED rows show together.
5. Confirm VOID rows show no Pay action and no Refund action.
6. Confirm PARTIALLY_REFUNDED rows still show a Refund action (further refund permitted).
7. Tap a filter chip -> confirm the list rebuilds immediately.
8. Toggle Shift/All Sales off and back on with "Refunded" selected -> confirm the chip
   selection survives (the exact regression the loadAllSales/statusFilter decoupling fixes).
9. Reprint a receipt from history -> confirm it goes through the same PrintService.printReceipt
   path as Day 13/15, not a separate mobile-only print implementation.
```

## What I Should Understand Before Day 13

`kReceiptContentWidth = 300` and the fact that `ReceiptContent` is deliberately the SAME widget instance type used for on-screen display, PDF rasterization, and ESC/POS rasterization — Day 14's entire Khmer strategy depends on this widget never forking into a "mobile version." Separately, from the addendum above: the Receipts history screen's status filtering is a completely different concern from the single-receipt preview architecture — don't conflate `ReceiptState`/`ReceiptNotifier` (a list of past sales, with filters) with `ReceiptViewModel` (one sale's printable content) — they're both real, both named similarly, and easy to confuse.

---

# Day 13 — PDF Printing: Print Button to PDF Bytes to OS Dialog

## A. Where Do I Start?

Open `lib/features/pos/services/print_service.dart`. Read `printReceipt` first (the entry point), then `buildReceiptPdf`.

## B. Existing Web Function Chain

`PrintService.printReceipt` — full body:
```dart
Future<bool> printReceipt(BuildContext context, int saleId) async {
  try {
    final receiptJson = await _api.get<Map<String, dynamic>>('/api/pos/sales/$saleId/receipt');
    final receipt = ReceiptResponse.fromJson(receiptJson);
    final language = _ref.read(appLanguageProvider);
    final l10n = AppLocalizations.of(context);
    final viewModel = ReceiptViewModel.fromReceiptResponse(receipt, language, l10n);

    final config = await _ref.read(thermalPrinterServiceProvider).loadConfig();
    if (config.transportType == PrinterTransportType.pdfDriver) {
      final pdfBytes = await buildReceiptPdf(viewModel, config.paperSize, context: context);
      await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'receipt_$saleId');
    } else {
      await _ref.read(thermalPrinterServiceProvider).printReceipt(context, viewModel, config);   // Day 15
    }
    return true;
  } catch (e) { return false; }
}
```
`printReceipt` is the ONE function that decides PDF-vs-direct-thermal, by reading the saved `PrinterConfig.transportType` (Day 19 builds the settings UI for this).

`buildReceiptPdf` — full body:
```dart
Future<Uint8List> buildReceiptPdf(ReceiptViewModel r, PrinterPaperSize paperSize, {BuildContext? context}) async {
  final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());   // Day 14
  final content = await _pageContent(context, r, paperSize);        // branches Khmer vs Latin, Day 14
  doc.addPage(pw.Page(pageFormat: paperSize.pdfPageFormat, build: (_) => content));
  return doc.save();
}
```

## C. Backend/API Chain

Same `GET /api/pos/sales/{id}/receipt` as Day 12 — `PrintService` fetches it independently rather than reusing a value passed in, so a print action always gets fresh data even if the on-screen preview is stale.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `services/print_service.dart` | `PrintService` | `printReceipt` | `(BuildContext, int saleId)` | `Future<bool>` | Call unchanged from mobile print button |
| `services/print_service.dart` | `PrintService` | `buildReceiptPdf` | `(ReceiptViewModel, PrinterPaperSize, {BuildContext?})` | `Future<Uint8List>` | Call unchanged if you want the bytes directly (e.g. for a custom share action) |
| — | `Printing` (package `printing`) | `layoutPdf` / `sharePdf` | `Uint8List` bytes | OS print/share dialog | Already cross-platform — zero mobile-specific code needed |

## E. Exact New Mobile Files to Create

None — this day only WIRES existing functions to two buttons on `mobile_receipt_preview_screen.dart` (Day 12).

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste (fills in Day 12's two stubbed `IconButton`s).
```dart
// inside MobileReceiptPreviewScreen, replacing the Day 12 stubs:
IconButton(
  icon: const Icon(Icons.print),
  onPressed: () async {
    // STEP 1: reuse the EXISTING function — it already handles the pdfDriver-vs-thermal branch.
    final success = await ref.read(printServiceProvider).printReceipt(context, saleId);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.printerPrintFailed)));
    }
  },
),
IconButton(
  icon: const Icon(Icons.share),
  onPressed: () async {
    // STEP 2: mobile favors Share (native share sheet) at least as much as Print.
    final receiptJson = await ref.read(saleServiceProvider).getReceipt(saleId);
    final viewModel = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse.fromJson(receiptJson), ref.read(appLanguageProvider), AppLocalizations.of(context));
    final config = await ref.read(thermalPrinterServiceProvider).loadConfig();
    final bytes = await ref.read(printServiceProvider).buildReceiptPdf(viewModel, config.paperSize, context: context);
    await Printing.sharePdf(bytes: bytes, filename: '${viewModel.invoiceNumber}.pdf');
  },
),
```

## G. Function Inputs and Outputs

`PrintService.buildReceiptPdf(ReceiptViewModel r, PrinterPaperSize paperSize, {BuildContext? context})`
INPUT: a `ReceiptViewModel` (Day 12), `PrinterPaperSize.mm80` (or `mm58`), the widget's `BuildContext` (needed for the Khmer rasterization path, Day 14 — `context` is optional and its absence forces the Latin-only rendering path even for a Khmer receipt, so always pass it when available)
DOES: builds a `pw.Document`, picks Khmer-image or native-text content, saves to bytes
OUTPUT: `Future<Uint8List>` — raw PDF bytes
CALLER: your print/share button handlers
NEXT: `Printing.layoutPdf` (opens OS print dialog) or `Printing.sharePdf` (opens OS share sheet) — both take these exact bytes.

## H. State Before and After

Not Riverpod state — a pure function producing bytes each call, no caching.

## I. What Should Be Shared vs Mobile-Only?

```text
PrintService.printReceipt / buildReceiptPdf / printer_pdf_format.dart
🟢 KEEP EXACTLY — zero changes needed for mobile, confirmed cross-platform already

Printing.layoutPdf / Printing.sharePdf
🟢 KEEP EXACTLY — the `printing` package itself handles Android/iOS/web differences internally
```

## J. Build Order Inside the Day

1. Open `print_service.dart`, read `printReceipt` and `buildReceiptPdf` fully.
2. Open `printer_pdf_format.dart` (short file), confirm the mm58/mm80 → `PdfPageFormat` mapping.
3. Find one real `Printing.layoutPdf` call site (`receipt_preview_screen.dart`) and one real `Printing.sharePdf` call site (`receipts_screen.dart`'s `_savePdf`) — read both, they're a handful of lines each.
4. Wire the print button in `mobile_receipt_preview_screen.dart` to `PrintService.printReceipt`.
5. Wire the share button to `buildReceiptPdf` + `Printing.sharePdf`.
6. Test "Print" on Android — confirm the Android Print Framework dialog opens with a correctly 58mm/80mm-formatted PDF.
7. Test "Print" on iOS — confirm AirPrint's dialog opens.
8. Test "Share" on both — confirm the native share sheet opens and a saved PDF opens correctly from Files (iOS) / a file manager (Android).

## K. "When I Click This, What Happens?"

# Tap the print icon
```text
Tap print icon
↓
PrintService.printReceipt(context, saleId)
↓
GET /api/pos/sales/{id}/receipt (fresh fetch)
↓
ReceiptViewModel.fromReceiptResponse(...)
↓
ThermalPrinterService.loadConfig() -> PrinterConfig
↓
config.transportType == pdfDriver ?
↓ (yes, the mobile default until Day 15/19 changes it)
buildReceiptPdf(viewModel, config.paperSize, context: context)
↓
Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'receipt_$saleId')
↓
OS print dialog opens (Android Print Framework / AirPrint)
```

## L. "Where Does This Value Come From?"

The paper size used for the PDF (58mm vs 80mm):
```text
ThermalPrinterService.loadConfig()  -> reads SharedPreferences 'thermal_printer_config'
↓
PrinterConfig.paperSize  (PrinterPaperSize enum, saved via Day 19's settings screen)
↓
paperSize.pdfPageFormat  (printer_pdf_format.dart extension)
↓
pw.Page(pageFormat: ...)
```

## M. Navigation Flow

No navigation — both actions open OS-native dialogs (print sheet / share sheet), not new app screens.

## N. Error Flow

```text
printReceipt returns true
→ (nothing further — the OS dialog itself handles the actual print/cancel interaction)

printReceipt returns false (any exception during fetch/build)
→ your mobile button handler must check the boolean return and show feedback — printReceipt
  itself swallows the exception internally and just returns false, it does not rethrow or log
  anything visible to the user by default.
```

## O. Test Flow

Existing tests: `test/receipt_pdf_page_format_test.dart`, `test/print_service_batch_test.dart` — target format/logic directly, reusable unmodified.
```bash
flutter test test/receipt_pdf_page_format_test.dart
```
Manual test: print and share both an English and a Khmer receipt on a real Android device and a real iPhone; open the shared PDF from each platform's file app and visually confirm it matches the on-screen preview.

## What I Should Understand Before Day 14

That today required ZERO changes to any printing code — `PrintService`, `Printing.layoutPdf`/`sharePdf`, and `printer_pdf_format.dart` already work identically on Android/iOS/web. If you found yourself writing a platform `if` anywhere today, stop — that's a sign you've misunderstood something, not a sign mobile needs special handling here.

---

# Day 14 — Khmer Rendering: The Exact Branch, Function by Function

## A. Where Do I Start?

Open `lib/features/pos/services/printing/escpos_receipt_builder.dart` and find the one `if (receipt.containsKhmer)` branch inside `build()`. This single conditional is the fork point for the entire Khmer strategy — trace both directions from here.

## B. Existing Web Function Chain — both branches, exact code

**English path** (no Khmer detected): `PrintService._pageContent` calls `_receiptPageContent` (native `pw.Text` layout, not shown in full here — it's a straightforward widget tree using `paperSize.receiptTypography`/`ReceiptSpacing` constants). For ESC/POS, `EscPosReceiptBuilder._buildLatinText` calls `generator.text`/`generator.row`/`generator.hr` directly — no rasterization involved at all.

**Khmer path** — this is the one to understand deeply.

`PrintService._pageContent` branches:
```dart
Future<pw.Widget> _pageContent(BuildContext? context, ReceiptViewModel r, PrinterPaperSize paperSize) async {
  if (r.containsKhmer && context != null && context.mounted) {
    return _khmerImagePageContent(context, r, paperSize);
  }
  return _receiptPageContent(r, paperSize);
}
```
**Note the `context != null` guard**: if you call `buildReceiptPdf` without a `BuildContext` (e.g. from a background isolate or a context-less code path), a Khmer receipt SILENTLY falls back to the native-text path — which will render Khmer incorrectly (missing shaping). Always pass a live `context` when building a receipt PDF that might contain Khmer.

`_khmerImagePageContent`:
```dart
Future<pw.Widget> _khmerImagePageContent(BuildContext context, ReceiptViewModel r, PrinterPaperSize paperSize) async {
  final decoded = await bitmapRenderer.renderImage(context, r, paperSize);
  final targetWidth = paperSize.pdfPageFormat.availableWidth;
  final targetHeight = targetWidth * decoded.height / decoded.width;
  return pw.Image(pw.ImageImage(decoded), width: targetWidth, height: targetHeight, fit: pw.BoxFit.fill);
}
```
`pw.ImageImage(decoded)` embeds the raw decoded pixel image directly — deliberately skipping a PNG re-encode round trip that an earlier version of this code did (a documented ~2.3s optimization).

`ReceiptBitmapRenderer.renderImage` — the actual off-screen mount-and-rasterize, full mechanism:
```dart
Future<img.Image> renderImage(BuildContext context, ReceiptViewModel receipt, PrinterPaperSize paperSize) async {
  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context, rootOverlay: true);
  const logicalWidth = kReceiptContentWidth;                    // = 300, from Day 12
  final pixelRatio = paperSize.dotWidth / logicalWidth;         // 384/300 or 576/300

  late OverlayEntry entry;
  entry = OverlayEntry(builder: (context) => Positioned(
    left: -100000, top: 0,                                       // off-screen, NOT Offstage — still lays out/paints
    child: Directionality(textDirection: TextDirection.ltr,
      child: Material(color: Colors.white,
        child: RepaintBoundary(key: boundaryKey,
          child: Container(width: logicalWidth, color: Colors.white,
            child: ReceiptContent(receipt: receipt)))))));       // <-- the SAME widget as the on-screen preview

  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;   // 1st: mount + layout
    await WidgetsBinding.instance.endOfFrame;   // 2nd: confirm full repaint
    final renderObject = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final uiImage = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    return img.Image.fromBytes(width: uiImage.width, height: uiImage.height,
        bytes: byteData!.buffer, numChannels: 4, order: img.ChannelOrder.rgba);
  } finally { entry.remove(); }
}
```
Mechanics worth internalizing: it mounts at `left: -100000` (still lays out/paints, just off the visible viewport — `Offstage` would skip painting entirely, which is why this technique is used instead), at the EXACT SAME `kReceiptContentWidth = 300` the on-screen preview uses, then scales up to the printer's real dot resolution purely via `pixelRatio` in `toImage()` — never by resizing the widget itself. This is *why* Day 12's warning about never changing `kReceiptContentWidth` matters: changing it would change both the preview AND the print output's relative proportions simultaneously (which is actually fine if changed consistently) but would desync them if only one reference is updated.

`.render()` (used for ESC/POS, not PDF) adds dithering on top of `renderImage()`:
```dart
Future<img.Image> render(BuildContext context, ReceiptViewModel receipt, PrinterPaperSize paperSize) async {
  final decoded = await renderImage(context, receipt, paperSize);
  return img.ditherImage(decoded, kernel: img.DitherKernel.floydSteinberg);
}
```
PDF embeds the un-dithered grayscale image (printers/screens can show shades of gray); ESC/POS dithers because thermal printers are strict 1-bit black/white.

`KhmerPdfFont.loadTheme()` — loaded once, cached, sequential (not `Future.wait`, due to a documented flaky-test-mock issue under concurrency):
```dart
static Future<pw.ThemeData> loadTheme() async {
  _latinRegular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  _latinBold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
  _khmerRegular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansKhmer-Regular.ttf'));
  _khmerBold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansKhmer-Bold.ttf'));
  return pw.ThemeData.withFont(base: _latinRegular!, bold: _latinBold!,
      fontFallback: [_khmerRegular!, _khmerBold!]);   // Khmer is FALLBACK ONLY, never primary
}
```
The bundled `NotoSansKhmer` font is a Khmer-only glyph subset (no Latin/digit glyphs) — using it as `base` would break every all-English document, which is exactly why it's `fontFallback` only.

`EscPosReceiptBuilder.build` — the complete branch, both paths visible together:
```dart
Future<List<int>> build(BuildContext context, ReceiptViewModel receipt, PrinterPaperSize paperSize) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(paperSize.escPosPaperSize, profile);
  var bytes = <int>[];
  bytes += generator.reset();
  if (receipt.containsKhmer) {
    final image = await bitmapRenderer.render(context, receipt, paperSize);        // dithered
    bytes += generator.imageRaster(image, align: PosAlign.center);
  } else {
    bytes += _buildLatinText(generator, receipt);                                  // native ESC/POS text
  }
  bytes += generator.feed(2);
  bytes += generator.cut();
  return bytes;
}
```

## C. Backend/API Chain

None new — this day is entirely rendering logic on top of the `ReceiptViewModel` already fetched in Day 12/13.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `services/printing/khmer_pdf_font.dart` | `KhmerPdfFont` | `loadTheme` | — | `Future<pw.ThemeData>` | Call unchanged, cached automatically |
| `services/printing/receipt_bitmap_renderer.dart` | `ReceiptBitmapRenderer` | `renderImage` / `render` | `(BuildContext, ReceiptViewModel, PrinterPaperSize)` | `Future<img.Image>` | Call unchanged |
| `core/utils/khmer_text.dart` | — | `containsKhmerText` | `String` | `bool` | Already used by `ReceiptViewModel.containsKhmer` — no direct mobile call needed |

## E. Exact New Mobile Files to Create

None — this day is verification only.

## F. Exact Function I Need to Write

None — no new code today; the entire point is that this pipeline needs zero mobile-specific changes.

## G. Function Inputs and Outputs

`ReceiptBitmapRenderer.renderImage(BuildContext context, ReceiptViewModel receipt, PrinterPaperSize paperSize)`
INPUT: a live `context` (must be mounted), the receipt view model, `PrinterPaperSize.mm80`
DOES: mounts `ReceiptContent` off-screen at `kReceiptContentWidth`, waits 2 frames, rasterizes via `RenderRepaintBoundary.toImage(pixelRatio: dotWidth/300)`
OUTPUT: `Future<img.Image>` (raw pixel image, 576×N pixels for 80mm paper)
CALLER: `PrintService._khmerImagePageContent` (PDF path) and `EscPosReceiptBuilder.build` (ESC/POS path, via `.render()` which adds dithering)
NEXT: PDF path embeds directly as `pw.ImageImage`; ESC/POS path passes to `generator.imageRaster()`.

## H. State Before and After

Not Riverpod state — a pure rendering pipeline invoked fresh each print/PDF-build call, nothing cached across calls (unlike `KhmerTextRasterizer`, Day 18, which does cache).

## I. What Should Be Shared vs Mobile-Only?

```text
KhmerPdfFont.loadTheme / ReceiptBitmapRenderer / EscPosReceiptBuilder / containsKhmerText
🟢 KEEP EXACTLY — verified zero platform-conditional code anywhere in this pipeline
```

## J. Build Order Inside the Day

1. Open `escpos_receipt_builder.dart`, find and read the `if (receipt.containsKhmer)` branch.
2. Open `print_service.dart`'s `_pageContent`, note the `context != null && context.mounted` guard.
3. Open `receipt_bitmap_renderer.dart`, read `renderImage` fully, understand the off-screen `OverlayEntry` + two-`endOfFrame` mechanism.
4. Open `khmer_pdf_font.dart`, read `loadTheme`, understand why Khmer is fallback-only.
5. Generate an English, a Khmer, and a mixed EN+KM receipt PDF on an Android emulator — visually inspect for correct subscript/vowel positioning (the exact defect class this whole rasterization strategy exists to avoid).
6. Repeat on iOS.
7. Time PDF generation for the Khmer receipt on mobile vs. a web baseline — confirm it's faster (native zlib during `doc.save()` vs. web's pure-Dart deflate, per the project's own printing docs) — if it's not faster, investigate before assuming mobile "just works" here.

## K. "When I Click This, What Happens?"

# Build a PDF for a receipt containing Khmer product names
```text
buildReceiptPdf(viewModel, paperSize, context: context)
↓
receipt.containsKhmer -> true (Khmer detected in a product name)
↓
_khmerImagePageContent(context, r, paperSize)
↓
ReceiptBitmapRenderer.renderImage: mount ReceiptContent off-screen at width 300
↓
2× endOfFrame, then RenderRepaintBoundary.toImage(pixelRatio: 576/300)  [for 80mm paper]
↓
img.Image (576px wide, correct Khmer shaping via Flutter's own Skia text engine)
↓
pw.Image(pw.ImageImage(decoded)) embedded into the PDF page
```

## L. "Where Does This Value Come From?"

The decision to rasterize at all:
```text
ReceiptViewModel._allText  (concatenates businessName, customerName, cashierName, footer, all line names)
↓
containsKhmerText(_allText)  (regex match against Khmer Unicode block)
↓
ReceiptViewModel.containsKhmer  (boolean, computed ONCE per receipt, not per line)
↓
read by BOTH PrintService._pageContent (PDF) AND EscPosReceiptBuilder.build (thermal) —
  same boolean, same decision, two different rendering targets
```

## M. Navigation Flow

None — pure rendering, no navigation.

## N. Error Flow

```text
context becomes unmounted mid-render (user navigated away while a print/PDF build was in flight)
→ renderImage's `finally { entry.remove(); }` still cleans up the OverlayEntry safely
→ but boundaryKey.currentContext could be null if unmounted before toImage() completes —
  the actual code throws a ReceiptRenderException("Unable to render Khmer receipt: bitmap
  boundary failed to mount.") in this case, which PrintService.printReceipt's outer try/catch
  turns into a `return false` (Day 13's error flow) — worth testing explicitly on mobile since
  a user backgrounding the app mid-print is a very reachable scenario on a phone (much more so
  than on a desktop web tab).
```

## O. Test Flow

Existing tests: `test/a4_report_pdf_khmer_test.dart`, `test/khmer_receipt_dispatch_test.dart`, `test/khmer_text_rasterizer_test.dart`, `test/pdf_font_test.dart`, `test/receipt_bitmap_renderer_test.dart` — all reusable unmodified, none are platform-conditional.
```bash
flutter test test/receipt_bitmap_renderer_test.dart test/khmer_receipt_dispatch_test.dart
```
Manual test: generate English/Khmer/mixed receipts on both platforms; additionally, explicitly test backgrounding the app (Android: press Home; iOS: swipe up) mid-PDF-build for a Khmer receipt, confirm the `ReceiptRenderException` path is handled gracefully rather than crashing.

## What I Should Understand Before Day 15

The distinction between this day's receipt strategy (whole-document rasterization, `ReceiptBitmapRenderer`) and Day 18's report strategy (per-string rasterization, `KhmerTextRasterizer`, with its own cache) — they solve the same underlying problem (`package:pdf` can't shape Khmer correctly) with two deliberately different techniques suited to two different document shapes (a fixed-width receipt vs. a multi-column table). Conflating them is a common mistake — don't reach for `KhmerTextRasterizer` when you mean `ReceiptBitmapRenderer` or vice versa.

---

# Day 15 — Network Printer: The Full ESC/POS Transport Chain

## A. Where Do I Start?

Open `lib/features/pos/services/printing/thermal_printer_service.dart`. Read `_transportFor()` — one `switch` statement that is the ONLY place in the codebase that picks a concrete transport class.

## B. Existing Web Function Chain

`_transportFor` — full body:
```dart
PrinterTransport _transportFor(PrinterConfig config) {
  switch (config.transportType) {
    case PrinterTransportType.bluetooth:
      final address = config.bluetoothAddress;
      if (address == null || address.isEmpty) throw StateError('No Bluetooth printer selected');
      return BluetoothPrinterTransport(address);
    case PrinterTransportType.usb:
      return UsbPrinterTransport(vendorId: config.usbVendorId?.toString(), productId: config.usbProductId?.toString());
    case PrinterTransportType.network:
      final host = config.networkHost;
      if (host == null || host.isEmpty) throw StateError('No printer IP address configured');
      return NetworkPrinterTransport(host, port: config.networkPort);
    case PrinterTransportType.pdfDriver:
      throw StateError('pdfDriver is handled by PrintService, not ThermalPrinterService');
  }
}
```

`printReceipt` — connect → build → write, disconnect always in `finally` (note: `connect()` itself is OUTSIDE the try block, so a connect failure propagates without attempting disconnect):
```dart
Future<void> printReceipt(BuildContext context, ReceiptViewModel receipt, PrinterConfig config) async {
  final transport = _transportFor(config);
  await transport.connect();
  try {
    final bytes = await builder.build(context, receipt, config.paperSize);   // Day 14's EscPosReceiptBuilder
    await transport.write(bytes);
  } finally {
    await transport.disconnect();
  }
}
```

`printReceipts` (batch — used for "Print All" style actions, Day 18/19) shares ONE connect/disconnect across N receipts, since per-receipt reconnect (especially Bluetooth) is too slow:
```dart
Future<void> printReceipts(BuildContext context, List<ReceiptViewModel> receipts, PrinterConfig config,
    {void Function(int done, int total)? onProgress}) async {
  final transport = _transportFor(config);
  await transport.connect();
  try {
    for (var i = 0; i < receipts.length; i++) {
      final bytes = await builder.build(context, receipts[i], config.paperSize);
      await transport.write(bytes);
      onProgress?.call(i + 1, receipts.length);
    }
  } finally { await transport.disconnect(); }
}
```

`NetworkPrinterTransport` — the ENTIRE file (11 lines of interface + this):
```dart
class NetworkPrinterTransport implements PrinterTransport {
  NetworkPrinterTransport(this.host, {this.port = 9100});
  final String host;
  final int port;
  Socket? _socket;

  @override bool get isConnected => _socket != null;

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (_socket == null) throw StateError('Network printer is not connected');
    _socket!.add(bytes);
    await _socket!.flush();
  }

  @override
  Future<void> disconnect() async { await _socket?.close(); _socket = null; }
}
```
`port` defaults to `9100` — the universal raw-print port most thermal/receipt printers with an Ethernet/Wi-Fi interface listen on, no driver needed. `write` does `add` (buffer) then `await flush()` (force the OS send buffer out immediately, don't wait for Dart's internal buffering).

## C. Backend/API Chain

None — this is a direct device-to-device TCP connection, entirely bypassing the Spring Boot backend. The `ReceiptViewModel` data driving what gets printed still came from the backend (Day 12), but the printing mechanism itself is peer-to-peer over the local network.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `services/printing/thermal_printer_service.dart` | `ThermalPrinterService` | `printReceipt` | `(BuildContext, ReceiptViewModel, PrinterConfig)` | `Future<void>` | Call unchanged from mobile print button when `transportType == network` |
| `services/printing/network_printer_transport.dart` | `NetworkPrinterTransport` | `connect`/`write`/`disconnect` | see above | — | Zero changes needed — code is already fully portable |
| `services/printing/printer_transport.dart` | `PrinterTransport` (interface) | — | — | — | Reference this interface for Day 16's implementations too |

## E. Exact New Mobile Files to Create

None — the transport code needs zero mobile-specific changes. What's new is one Info.plist entry (below) and wiring the mobile Settings screen's network host/port fields (Day 19) to `ThermalPrinterService.saveConfig`.

## F. Exact Function I Need to Write

Nothing new in Dart today — see section J for the one config file change.

## G. Function Inputs and Outputs

`NetworkPrinterTransport.connect()`
INPUT: none (uses constructor's `host`/`port`, e.g. `NetworkPrinterTransport('192.168.1.50', port: 9100)`)
DOES: `Socket.connect(host, port, timeout: 5s)` — a raw TCP connection
OUTPUT: `Future<void>` (throws `SocketException` on timeout/refused/unreachable)
CALLER: `ThermalPrinterService.printReceipt`, outside its try block
NEXT: on success, `builder.build(...)` runs, then `transport.write(bytes)`.

## H. State Before and After

Not Riverpod state — `PrinterConfig` (Day 19) is read fresh from SharedPreferences each print call via `loadConfig()`, and the `Socket` connection itself is entirely transient, opened and closed within a single `printReceipt` call.

## I. What Should Be Shared vs Mobile-Only?

```text
ThermalPrinterService (all methods) / NetworkPrinterTransport / PrinterTransport interface
🟢 KEEP EXACTLY — confirmed zero platform-conditional code, and this transport actually works
   BETTER on mobile than on Web (Web's Socket throws UnsupportedError at runtime — browsers
   forbid raw TCP; Android/iOS both support dart:io Socket natively)
```

## J. Build Order Inside the Day

1. Open `printer_transport.dart` (interface), `thermal_printer_service.dart` (`_transportFor`, `printReceipt`, `printReceipts`), and `network_printer_transport.dart` (whole file) — read all three, they're short.
2. Add the new iOS permission — **confirmed absent from `Info.plist` today**:
   ```xml
   <key>NSLocalNetworkUsageDescription</key>
   <string>Used to connect to your receipt printer on the local network.</string>
   ```
   (iOS 14+ requires this even for a direct `Socket.connect` to a manually-entered IP — the local-network privacy prompt triggers on first connection attempt regardless of whether you use mDNS/Bonjour discovery.)
3. No Android manifest change needed — `INTERNET` (already present) is sufficient for LAN sockets.
4. Wait for Day 19's Settings screen to exist, OR temporarily hard-code a `PrinterConfig(transportType: network, networkHost: '192.168.1.x')` for testing today.
5. Test against a real network thermal printer if you have one, OR simulate one on your dev machine: `nc -l 9100` (netcat listening on port 9100) — run a print, confirm the raw ESC/POS bytes arrive in your terminal.
6. Test the iOS local-network permission prompt appears on first print attempt; test denying it, confirm `connect()`'s resulting exception is caught gracefully by `PrintService`/your UI, not left as a crash.

## K. "When I Click This, What Happens?"

# Print to a configured network printer
```text
Tap print icon (config.transportType == network)
↓
PrintService.printReceipt -> config.transportType != pdfDriver
↓
ThermalPrinterService.printReceipt(context, viewModel, config)
↓
_transportFor(config) -> NetworkPrinterTransport(config.networkHost, port: config.networkPort)
↓
transport.connect() -> Socket.connect(host, port, timeout: 5s)
   [iOS: local-network permission prompt fires here on first attempt]
↓
EscPosReceiptBuilder.build(context, receipt, paperSize) -> bytes (Day 14's Khmer/Latin branch)
↓
transport.write(bytes) -> socket.add(bytes); await socket.flush()
↓
transport.disconnect() -> socket.close()
```

## L. "Where Does This Value Come From?"

The printer's IP address used:
```text
Day 19's mobile Settings screen -> user types an IP into a TextField
↓
ThermalPrinterService.saveConfig(PrinterConfig(networkHost: '192.168.1.50', ...))
↓
SharedPreferences['thermal_printer_config']  (JSON-encoded)
↓
ThermalPrinterService.loadConfig()  (read fresh on every print attempt, not cached in memory)
↓
NetworkPrinterTransport(config.networkHost, port: config.networkPort)
```

## M. Navigation Flow

None — printing doesn't navigate.

## N. Error Flow

```text
connect() succeeds, write() succeeds
→ receipt prints, disconnect() cleans up in finally

connect() throws (wrong IP, printer off, wrong network, iOS permission denied)
→ propagates OUT of ThermalPrinterService.printReceipt (connect is outside the try block,
  so disconnect() is never attempted — there's nothing to disconnect from anyway)
→ propagates to PrintService.printReceipt's outer try/catch -> returns false
→ your mobile UI must show this as a failure (Day 13's error-flow pattern) — there is no
  automatic retry or fallback to PDF printing built into this chain; if you want "try network,
  fall back to PDF on failure" as a mobile UX improvement, that's new logic to add deliberately,
  not existing behavior to assume.

write() throws AFTER a successful connect() (printer disconnected mid-print, cable pulled, etc.)
→ same outer catch -> false -> transport.disconnect() still runs (write's exception happens
  inside the try block, so the finally still fires)
```

## O. Test Flow

No existing automated test covers real network hardware (correctly — not unit-testable). `test/escpos_receipt_adjustments_test.dart` and `test/printer_pdf_format_test.dart` test adjacent formatting logic and are reusable unmodified.

Manual test:
```text
1. Configure a network printer (or nc -l 9100 simulator) in mobile Settings.
2. Print a receipt -> confirm bytes arrive correctly (real cut+feed on real hardware, or
   correct raw ESC/POS bytes in the netcat terminal for the simulator).
3. On iOS specifically: confirm the local-network permission prompt appears, test both
   Allow and Deny paths.
4. Simulate a wrong IP -> confirm a clear failure message, no crash, no hang beyond the 5s timeout.
```

## What I Should Understand Before Day 16

Why this specific transport needed literally zero Dart code changes for mobile, while Day 16's USB/Bluetooth transports need real new permission-handling code — the difference is entirely about what the OS gates behind a runtime permission prompt (Bluetooth, USB) versus what it doesn't (a raw outbound TCP socket, gated only by the lighter-weight local-network privacy prompt on iOS).

---

# Day 16 — USB / Bluetooth Printers: Where Shared Logic Ends

## A. Where Do I Start?

Open `lib/features/pos/services/printing/bluetooth_printer_transport.dart` and `usb_printer_transport.dart` side by side. Both implement the same `PrinterTransport` interface from Day 15 — read them together to see exactly how thin and interchangeable they are, which is the whole point of the interface.

## B. Existing Web Function Chain

`BluetoothPrinterTransport` — full bodies:
```dart
class BluetoothPrinterTransport implements PrinterTransport {
  BluetoothPrinterTransport(this.macAddress);
  final String macAddress;
  bool _connected = false;

  @override bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    if (!_connected) throw StateError('Could not connect to Bluetooth printer $macAddress');
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (!_connected) throw StateError('Bluetooth printer is not connected');
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) throw StateError('Failed to write to Bluetooth printer');
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    await PrintBluetoothThermal.disconnect;   // NOTE: static GETTER, not a method call — no ()
    _connected = false;
  }

  static Future<List<BluetoothInfo>> pairedDevices() => PrintBluetoothThermal.pairedBluetooths;  // also a getter
}
```

`UsbPrinterTransport` — full bodies (wraps `flutter_pos_printer_platform_image_3`'s `PrinterManager.instance`):
```dart
class UsbPrinterTransport implements PrinterTransport {
  UsbPrinterTransport({this.vendorId, this.productId, this.name});
  final String? vendorId; final String? productId; final String? name;
  bool _connected = false;

  @override bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = await PrinterManager.instance.connect(
        type: PrinterType.usb, model: UsbPrinterInput(name: name, vendorId: vendorId, productId: productId));
    if (!_connected) throw StateError('Could not connect to USB printer');
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (!_connected) throw StateError('USB printer is not connected');
    final ok = await PrinterManager.instance.send(type: PrinterType.usb, bytes: bytes);
    if (!ok) throw StateError('Failed to write to USB printer');
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    await PrinterManager.instance.disconnect(type: PrinterType.usb);
    _connected = false;
  }

  static Stream<PrinterDevice> discover() => PrinterManager.instance.discovery(type: PrinterType.usb);
}
```
Both classes are 100% written and correct already — **this is exactly where "shared logic ends and platform-specific code begins": the class boundary itself.** Nothing above `PrinterTransport` (interface), `ThermalPrinterService`, `EscPosReceiptBuilder`, or `ReceiptViewModel` needs to know these two classes exist, let alone which platform they're running on.

**What's genuinely missing, confirmed by direct grep** — `permission_handler` (declared in `pubspec.yaml: ^11.2.0`, fully resolved in `pubspec.lock`) is imported **nowhere** in the entire `lib/` tree. Neither transport class, nor `settings_modules_screen.dart`, nor `print_test_screen.dart` requests any runtime permission before calling `connect()`. Today, on a real device with Bluetooth/USB permission not yet granted, `connect()` simply returns `false` from the plugin (or throws), and the existing `StateError`s above fire — with no distinguishing message for "permission denied" vs. "printer not found." **You are building this permission flow from scratch — there is no existing pattern in this codebase to copy, only to design fresh, following the interface's existing shape.**

## C. Backend/API Chain

None — same as Day 15, entirely device-to-device, no backend involvement in the print transport itself.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `services/printing/bluetooth_printer_transport.dart` | `BluetoothPrinterTransport` | `connect`/`write`/`disconnect`/`pairedDevices` | see above | — | Reuse unchanged; wrap `connect()` calls with a NEW permission-request step |
| `services/printing/usb_printer_transport.dart` | `UsbPrinterTransport` | `connect`/`write`/`disconnect`/`discover` | see above | — | Same |
| `services/printing/thermal_printer_service.dart` | `ThermalPrinterService` | `printReceipt` | — | — | Unchanged — it just calls whatever `_transportFor` returns |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/widgets/mobile_status_action_sheet.dart   # reusable — also used in Day 17
```
No new printing files needed — the permission-request logic belongs as a small guard function called from wherever `connect()` is currently called (inside `ThermalPrinterService.printReceipt`, or a new thin wrapper around it) and from Settings' device-picker UI (Day 19).

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste. This is genuinely new logic — no existing file to base it on beyond the `PrinterTransport` interface shape.
```dart
// A NEW small helper — where it lives is your call; a natural home is right beside
// thermal_printer_service.dart since it gates the same connect() calls.
Future<bool> ensurePrinterPermission(PrinterTransportType type) async {
  if (type == PrinterTransportType.bluetooth) {
    // STEP 1: Android 12+ needs BLUETOOTH_CONNECT/BLUETOOTH_SCAN; older Android needs
    // BLUETOOTH/BLUETOOTH_ADMIN + location. permission_handler abstracts this per-OS-version
    // difference for you — call it once, don't branch on OS version yourself.
    final status = await Permission.bluetoothConnect.request();
    return status.isGranted;
  }
  if (type == PrinterTransportType.usb) {
    // STEP 2: USB host-mode permission is typically requested by the OS automatically when
    // a USB accessory is attached (Android), via an intent-filter in AndroidManifest.xml —
    // verify against flutter_pos_printer_platform_image_3's own docs for the exact manifest
    // entries it expects, rather than guessing.
    return true; // placeholder — depends on plugin-specific manifest wiring
  }
  return true; // network/pdfDriver need no runtime permission request here (network's iOS
               // local-network prompt is triggered by the OS automatically on first connect,
               // per Day 15 — nothing to request ahead of time)
}

// Then, wherever printing is triggered (e.g. wrapping the existing call):
Future<bool> printReceiptWithPermissionCheck(BuildContext context, ReceiptViewModel r, PrinterConfig config) async {
  if (!await ensurePrinterPermission(config.transportType)) {
    // show "permission required" UI — do NOT attempt connect() at all if this returns false
    return false;
  }
  await ref.read(thermalPrinterServiceProvider).printReceipt(context, r, config);
  return true;
}
```

## G. Function Inputs and Outputs

`BluetoothPrinterTransport.connect()`
INPUT: none (uses constructor's `macAddress`, obtained from `pairedDevices()` in Settings, Day 19)
DOES: `PrintBluetoothThermal.connect(macPrinterAddress: macAddress)` — attempts a classic Bluetooth serial connection to an already-paired device
OUTPUT: `Future<void>` (throws `StateError` on failure — including permission-denied failures, currently indistinguishable from "device not found")
CALLER: `ThermalPrinterService.printReceipt`, via `_transportFor`
NEXT: on success, same build+write+disconnect sequence as Day 15.

## H. State Before and After

Not Riverpod state — same as Day 15, transient connection state per print call.

## I. What Should Be Shared vs Mobile-Only?

```text
BluetoothPrinterTransport / UsbPrinterTransport (connect/write/disconnect bodies)
🟡 CALL FROM NEW MOBILE UI — the CODE is portable, but it has never been exercised without
   permission-handling in front of it; treat as "needs a new caller," not "needs new code"

permission_handler request flow
🔵 NEW MOBILE UI / NEW CODE — genuinely does not exist anywhere in this codebase today
```

## J. Build Order Inside the Day

1. Read both transport classes fully (section B) — confirm for yourself they're already complete and correct.
2. Confirm via `grep -rn "permission_handler" lib/` that it's truly unused today (an exercise worth doing yourself, not just trusting this document).
3. Add Android manifest permissions (new — not present in `AndroidManifest.xml` today):
   ```xml
   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
   <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
   ```
4. Add the iOS Info.plist key (new — confirmed absent today):
   ```xml
   <key>NSBluetoothAlwaysUsageDescription</key>
   <string>Bluetooth access is used to connect to your receipt printer.</string>
   ```
5. Write `ensurePrinterPermission` (section F) and wire it in front of every `connect()` call path — both the actual print action and Settings' "scan for paired devices" action (Day 19).
6. Check `flutter_pos_printer_platform_image_3`'s own documentation/README for any additional Android manifest entries it expects for USB host-mode (e.g. an intent-filter for `USB_DEVICE_ATTACHED`) — do not guess this, the plugin's own docs are authoritative.
7. Test Bluetooth: pair a real thermal printer at the OS level first, then test your app's connect/print/disconnect cycle, including a deliberate mid-print disconnect (turn the printer off mid-job) to confirm the `finally` block still runs cleanly.
8. Test USB on Android with a real printer.
9. Attempt USB on iOS — **document the actual result** (works / plugin error / MFi-related rejection) rather than assuming either outcome; this is a real open question this plan cannot answer without your specific hardware.

## K. "When I Click This, What Happens?"

# Select Bluetooth as printer transport in Settings, then print
```text
Settings: user selects "Bluetooth" transport type
↓
ensurePrinterPermission(bluetooth) -> Permission.bluetoothConnect.request()
↓ (granted)
BluetoothPrinterTransport.pairedDevices() -> list of already-OS-paired devices shown
↓
user picks one -> macAddress saved into PrinterConfig via ThermalPrinterService.saveConfig (Day 19)
↓
later, print action:
ThermalPrinterService.printReceipt -> _transportFor -> BluetoothPrinterTransport(macAddress)
↓
connect() -> PrintBluetoothThermal.connect(macPrinterAddress: macAddress)
↓
build (Day 14's Khmer/Latin branch) -> write -> disconnect
```

## L. "Where Does This Value Come From?"

The list of selectable Bluetooth printers in Settings:
```text
OS-level Bluetooth pairing (done OUTSIDE this app, in phone Settings)
↓
BluetoothPrinterTransport.pairedDevices() -> PrintBluetoothThermal.pairedBluetooths (static getter)
↓
List<BluetoothInfo> shown in a picker (Day 19)
↓
selected device's macAddress saved into PrinterConfig.bluetoothAddress
```

## M. Navigation Flow

None new — printing itself doesn't navigate; the device-picker UI (Day 19) is a dialog/sheet within Settings.

## N. Error Flow

```text
Permission granted, device paired, printer on and in range
→ connect/write/disconnect succeed as shown in K

Permission denied
→ ensurePrinterPermission returns false BEFORE connect() is ever attempted (section F's skeleton) —
  this is new behavior YOU must build; today, without this guard, a denied-permission connect()
  attempt just fails with the same generic StateError as "printer not found," giving the cashier
  no useful information about WHY it failed or what to do next.

Printer connects but disconnects mid-write (out of range, powered off)
→ write() throws StateError -> caught by ThermalPrinterService.printReceipt's try/catch structure
  (write is inside the try, so disconnect() in finally still attempts cleanup, though the
  transport may already be in a bad state — test this scenario explicitly, don't assume)

USB on iOS
→ UNKNOWN until you test against real hardware — the plugin registers an iOS implementation,
  but Apple's MFi accessory certification program may block non-certified USB thermal printers
  regardless of app-level code correctness. This is a genuine, unresolved risk for this plan,
  not a solved problem — plan your hardware purchasing/testing time accordingly.
```

## O. Test Flow

No existing automated test covers real Bluetooth/USB hardware (correctly not unit-testable).

Manual hardware test matrix:
```text
1. Pair a Bluetooth thermal printer at the OS level (both Android and iOS).
2. In-app: request permission, confirm prompt text matches your Info.plist/manifest strings.
3. Deny permission -> confirm graceful message, no crash, no attempted connect().
4. Grant permission -> select device -> print -> confirm real cut+feed on hardware.
5. Print again, power off the printer mid-print -> confirm error handling, no app hang/crash.
6. USB on Android: connect a real printer, confirm connect/print/disconnect cycle.
7. USB on iOS: attempt the same, document the actual result with your specific hardware.
```

## What I Should Understand Before Day 17

That you've now seen the full spectrum of this app's printing portability: PDF (Day 13, zero changes, works everywhere), Network (Day 15, zero Dart changes, actually easier on mobile than web), and Bluetooth/USB (Day 16, code complete but permission-flow genuinely new, iOS USB genuinely uncertain). This spectrum — not a blanket "printing works on mobile" or "printing needs a rewrite" — is the accurate picture to carry into any conversations about release readiness (Day 20).

---

# Day 17 — Inventory: Every Entity, One Pattern Repeated

## A. Where Do I Start?

Open `lib/features/inventory/providers/inventory_provider.dart` and find `PurchaseOrdersNotifier`. Purchase Orders is the richest workflow (has real status transitions) — master this one first, then every other inventory entity in this file is a smaller variation of the same shape.

## B. Existing Web Function Chain — Purchase Order, the deepest example

`PurchaseOrdersNotifier` — full bodies:
```dart
Future<void> loadOrders() async {
  try { state = const AsyncValue.loading(); state = AsyncValue.data(await _service.getPurchaseOrders()); }
  catch (e, st) { state = AsyncValue.error(e, st); }
}
Future<void> createOrder(PurchaseOrder order) async { await _service.createPurchaseOrder(order); await loadOrders(); }
Future<void> updateOrder(PurchaseOrder order) async { await _service.updatePurchaseOrder(order); await loadOrders(); }
Future<void> transition(int id, String action) async { await _service.transitionPurchaseOrder(id, action); await loadOrders(); }
```
No optimistic updates anywhere — every mutation reloads the entire list from the server afterward.

`ApiInventoryService`'s purchase-order methods, exact endpoints:
```dart
Future<List<PurchaseOrder>> getPurchaseOrders() => _api.get<List>('/api/purchase-orders').then(...);
Future<PurchaseOrder> createPurchaseOrder(PurchaseOrder order) =>
    _api.post<Map>('/api/purchase-orders', data: order.toJson()).then(PurchaseOrder.fromJson);
Future<PurchaseOrder> updatePurchaseOrder(PurchaseOrder order) =>
    _api.put<Map>('/api/purchase-orders/${order.id}', data: order.toJson()).then(PurchaseOrder.fromJson);
Future<PurchaseOrder> transitionPurchaseOrder(int id, String action) =>
    _api.post<Map>('/api/purchase-orders/$id/$action').then(PurchaseOrder.fromJson);   // literal string interpolation
```

Form save handler, `create_purchase_order.dart::_save()` — validates then delegates:
```dart
Future<void> _save() async {
  if (_supplierId == null) { /* show error */ return; }
  final validLines = <PurchaseOrderLine>[];
  for (final line in _lines) {
    final qty = double.tryParse(line.qtyCtl.text.trim());
    if (line.product == null || qty == null || qty <= 0) continue;   // silently skips invalid rows
    validLines.add(PurchaseOrderLine(productId: line.product!.id, quantity: qty, unitCost: double.tryParse(line.costCtl.text.trim()) ?? 0));
  }
  if (validLines.isEmpty) { /* show error */ return; }
  await ref.read(purchaseOrdersProvider.notifier).createOrder(PurchaseOrder(
      supplierId: _supplierId!, storeId: _storeId, orderDeadline: _orderDeadline, expectedArrival: _expectedArrival,
      taxRate: double.tryParse(_taxRateCtl.text.trim()) ?? 0, notes: ..., lines: validLines));
  Navigator.of(context).pop(true);
}
```

Status-based action menu, `purchase_orders_screen.dart::_actionsFor(status)`:
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
And the handler:
```dart
Future<void> _runAction(PurchaseOrder order, String action) async {
  if (action == 'cancel') { final confirmed = await showDialog<bool>(...); if (confirmed != true) return; }
  await ref.read(purchaseOrdersProvider.notifier).transition(order.id!, action);
  // success SnackBar
}
```

**A discrepancy worth flagging rather than silently resolving**: the Flutter `PurchaseOrder` model defaults `status = 'DRAFT'` locally, and `_actionsFor`'s own doc comment describes `DRAFT --submit--> SUBMITTED` as a reachable transition. However, direct inspection of the backend's `PurchasingWorkflowService.createPurchaseOrder` shows it setting `order.setStatus("SUBMITTED")` immediately on creation — not `DRAFT`. **Verify this against the current backend before assuming a newly created order sits in `DRAFT` awaiting a manual "submit" action** — it's possible the create flow always skips straight to `SUBMITTED` today, making the `DRAFT`/`submit` UI path either dead code or reachable only through some other entry point not covered by this research. Don't silently build mobile UI assuming one behavior without checking.

## C. Backend/API Chain

```text
POST /api/purchase-orders   {supplierId, storeId?, orderDeadline?, expectedArrival?, taxRate, notes?, lines: [...]}
↓
PurchaseOrderController.create (@PreAuthorize PERM_PURCHASE_MANAGE or OWNER/MANAGER/ADMIN role)
    -> purchasingWorkflowService.createPurchaseOrder(request)
↓
PurchasingWorkflowService.createPurchaseOrder [backend]
    applyPurchaseOrder(order, request):
        supplier = supplierRepository.findById(request.supplierId).orElseThrow(-> ApiException("Supplier not found"))
        for each line: product = productRepository.findById(line.productId).orElseThrow(...)
            if (!product.purchasable || !product.trackInventory) throw ApiException("... not allowed for purchasing")
    order.status = "SUBMITTED"; order.orderedAt = now()
    saved = purchaseOrderRepository.save(order); assignPoReference(saved)
    purchaseActivityService.log("PO", saved.id, "CREATE", ...)
↓
PurchasingWorkflowDtos.PurchaseOrderResponse{id, referenceNumber, supplierId, supplierName, status, ...}

---

POST /api/purchase-orders/{id}/{action}
↓
PurchaseOrderController.transition(@PathVariable Long id, @PathVariable String action)
    -> purchasingWorkflowService.transitionPurchaseOrder(id, action)
↓
switch (action) {
    case "submit" -> ...  case "approve" -> ...  case "cancel" -> ...  case "close" -> ...  case "send" -> ...
    default -> throw new ApiException("Unsupported purchase order action")
}
```
**Entities**: `PurchaseOrder` (`purchase_orders`: supplier, store, status [plain `String`, NOT a Java enum], taxRate, subtotal, taxAmount, totalAmount, notes, orderedAt, approvedAt, orderDeadline, expectedArrival, sentAt, referenceNumber, lines), `PurchaseOrderLine` (`purchase_order_lines`: purchaseOrder, product, orderedQuantity, receivedQuantity, unitCost, lineTotal).

## D. Exact Existing Functions to Reuse — every inventory entity

| Entity | Provider | Key mutation methods | Service | Endpoint pattern |
|---|---|---|---|---|
| Stock lookup (read-only) | *(uses `productsProvider`, not inventory's own)* | — | — | `/api/products/pos-catalog` |
| Stock adjustments | `movementsProvider` (`MovementsNotifier`) | `createAdjustment(request)` — **no try/catch, propagates to caller** | `ApiInventoryService` | `POST /api/inventory/adjust`, `GET /api/inventory/movements` |
| Inventory counts | `inventoryCountProvider` (`InventoryCountNotifier`) | `startCount()`, `recordEntry({snapshotId, countedQuantity, notes?})`, `post()` — **all 3 caught into `AsyncValue.error`** | `ApiInventoryService` | `POST /api/inventory/snapshots`, `POST /api/inventory/counts/entry`, `POST /api/inventory/counts/post` |
| Suppliers | `suppliersProvider` (`SuppliersNotifier`) | `createSupplier`, `updateSupplier`, `deleteSupplier` | `ApiInventoryService` | `GET/POST /api/suppliers`, `PUT/DELETE /api/suppliers/{id}` |
| Purchase orders | `purchaseOrdersProvider` (`PurchaseOrdersNotifier`) | `createOrder`, `updateOrder`, `transition(id, action)` | `ApiInventoryService` | `GET/POST /api/purchase-orders`, `PUT /{id}`, `POST /{id}/{action}` |
| Transfer orders | `transferOrdersProvider` (`TransferOrdersNotifier`) | `createOrder`, `completeOrder(id)`, `cancelOrder(id)` | `ApiInventoryService` | `GET/POST /api/inventory/transfers`, `POST /{id}/complete`, `POST /{id}/cancel` |
| Valuation (read-only) | `inventoryValuationProvider` | `loadReport()` | `ApiInventoryService` | `GET /api/inventory/valuation` |
| History (read-only) | `movementsProvider` | `load({productId?, storeId?})` | `ApiInventoryService` | `GET /api/inventory/movements` |
| Recipes | `recipesProvider` (`RecipesNotifier`) | `create`, `update`, `deactivate(id)` | `ApiProductionService` | `GET/POST /api/production/recipes`, `PUT/{id}` |
| Production orders | `productionOrdersProvider` (`ProductionOrdersNotifier`) | `checkAvailability(...)` — **pure passthrough, no state mutation at all**, `create`, `start(id)`, `complete(id, {producedQuantity, wasteQuantity, notes})`, `cancel(id, {reason})` | `ApiProductionService` | `POST /api/production/orders/check-availability`, `.../{id}/start`, `.../{id}/complete`, `.../{id}/cancel` |

## E. Exact New Mobile Files to Create

```text
lib/features/inventory/mobile/screens/mobile_purchase_orders_screen.dart
lib/features/inventory/mobile/screens/mobile_create_purchase_order_screen.dart
lib/features/inventory/mobile/screens/mobile_stock_adjustments_screen.dart
lib/features/inventory/mobile/screens/mobile_inventory_hub_screen.dart
# ... one pair (list + form) per entity in section D, following the SAME pattern each time
```
Reuse `lib/features/pos/mobile/widgets/mobile_status_action_sheet.dart` (introduced in Day 16) for every status-transition action across Purchase Orders, Transfer Orders, and Production Orders — don't rebuild this pattern 3 separate times.

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste (Purchase Orders shown; every other workflow entity follows the identical shape).
```dart
class MobilePurchaseOrdersScreen extends ConsumerWidget {
  const MobilePurchaseOrdersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(purchaseOrdersProvider);   // AsyncValue<List<PurchaseOrder>>
    return Scaffold(
      body: orders.when(
        data: (list) => ListView(children: [
          for (final order in list)
            ListTile(
              title: Text(order.referenceNumber ?? '#${order.id}'),
              subtitle: Text(order.status),
              // STEP 1: SAME status-driven action list as the desktop screen — do not invent new actions.
              trailing: PopupMenuButton<String>(
                itemBuilder: (_) => [for (final a in _actionsFor(order.status)) PopupMenuItem(value: a, child: Text(a))],
                onSelected: (action) async {
                  if (action == 'cancel') {
                    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(...));
                    if (confirmed != true) return;
                  }
                  // STEP 2: call the EXISTING notifier method — no new backend call to write.
                  await ref.read(purchaseOrdersProvider.notifier).transition(order.id!, action);
                },
              ),
            ),
        ]),
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text('$e'),
      ),
    );
  }
  // STEP 3: copy this switch VERBATIM from purchase_orders_screen.dart — it IS the business rule.
  List<String> _actionsFor(String status) { /* same switch as section B */ return []; }
}
```

## G. Function Inputs and Outputs

`PurchaseOrdersNotifier.transition(int id, String action)`
INPUT: `id = 42`, `action = 'submit'`
DOES: `POST /api/purchase-orders/42/submit` → backend validates the transition is legal for the order's current status, updates it → `await loadOrders()` refreshes the entire list
OUTPUT: `Future<void>` (throws on invalid transition or network error — no internal catch)
CALLER: your status-action menu's `onSelected`
NEXT: `ref.watch(purchaseOrdersProvider)` rebuilds with the updated order in the refreshed list.

## H. State Before and After

BEFORE:
```text
purchaseOrdersProvider = AsyncValue.data([PurchaseOrder(id: 42, status: 'SUBMITTED')])
```
Call: `transition(42, 'approve')`
AFTER:
```text
purchaseOrdersProvider = AsyncValue.data([PurchaseOrder(id: 42, status: 'APPROVED')])
```
(The entire list was refetched, not patched in place — if the list is large, every row rebuilds, not just the changed one.)

## I. What Should Be Shared vs Mobile-Only?

```text
Every *Notifier class in inventory_provider.dart / production_provider.dart
🟢 KEEP EXACTLY

_actionsFor(status) switch statement (the business rule for what actions are valid per status)
🟢 KEEP EXACTLY — copy verbatim, this encodes real workflow rules, do not simplify or guess at it

Desktop list/form screens (inventory_hub_screen.dart, purchase_orders_screen.dart, etc.)
🔴 DO NOT COPY layout — 🟢 KEEP EXACTLY their provider/service call patterns

Mobile*Screen files
🔵 NEW MOBILE UI
```

## J. Build Order Inside the Day

1. Open `inventory_provider.dart`, read `PurchaseOrdersNotifier` fully (section B).
2. Open `inventory_service.dart`, confirm the exact endpoint strings, especially the `/{id}/{action}` interpolation.
3. Open `create_purchase_order.dart`, read `_save()`.
4. Open `purchase_orders_screen.dart`, read `_actionsFor` and `_runAction`.
5. Build `MobilePurchaseOrdersScreen` and `MobileCreatePurchaseOrderScreen` using the section F skeleton.
6. Repeat the same list+form pattern for Suppliers (simplest — no status workflow) and Transfer Orders (same `transition`-style pattern as Purchase Orders, different action set).
7. Build Inventory Counts' mobile screen — the most stateful (start → per-item entry → post), model it closely on `inventory_counts_screen.dart`'s own sequencing.
8. Build Recipes + Production Orders, introducing the `checkAvailability` UI once, reusing its shape for order creation.
9. Build the 3 read-only screens (Stock Lookup, History, Valuation) last — simplest, no mutation logic at all.
10. Before writing any "submit from DRAFT" UI for Purchase Orders specifically, verify against a running backend instance whether newly created orders actually land in `DRAFT` or `SUBMITTED` (the discrepancy flagged in section B) — do not guess.

## K. "When I Click This, What Happens?"

# Tap "Submit" on a draft purchase order
```text
Tap Submit (from the status-action menu)
↓
purchaseOrdersProvider.notifier.transition(order.id!, 'submit')
↓
POST /api/purchase-orders/{id}/submit
↓
Backend: PurchasingWorkflowService.transitionPurchaseOrder -> case "submit" -> ...
    (validates the CURRENT status allows this transition, else throws ApiException)
↓
updated PurchaseOrder returned
↓
loadOrders() refetches the full list
↓
ref.watch(purchaseOrdersProvider) rebuilds, the order's row now shows status SUBMITTED
```

## L. "Where Does This Value Come From?"

The set of actions shown in a purchase order's action menu:
```text
order.status  (the CURRENT backend-authoritative status string, e.g. "SUBMITTED")
↓
_actionsFor(status)  (a pure client-side switch — encodes the SAME rules the backend enforces,
    duplicated for UI purposes; if backend rules change, this switch must be updated to match,
    or the UI will offer actions the backend then rejects)
↓
PopupMenuButton's itemBuilder
```

## M. Navigation Flow

List screen → create/edit form: `Navigator.push`, form pops with `true`/`false` on save/cancel (matching `create_purchase_order.dart`'s `Navigator.of(context).pop(true)`), list screen reloads on a `true` pop result.

## N. Error Flow

```text
transition succeeds -> list refreshes with new status

transition fails (invalid transition for current status, e.g. trying to 'approve' a CANCELLED order)
→ ApiException propagates UNCAUGHT out of PurchaseOrdersNotifier.transition (no internal catch)
→ your action menu's onSelected handler MUST wrap this in try/catch — there is no existing
  safety net, matching the same pattern you already learned for Shift (Day 10)

createAdjustment fails (Stock Adjustments)
→ also UNCAUGHT, propagates to caller — same requirement

startCount/recordEntry/post fail (Inventory Counts)
→ DIFFERENT pattern — these ARE caught internally into AsyncValue.error, so your UI should
  check the provider's error state rather than wrapping these three specific calls in try/catch
```

## O. Test Flow

No inventory-specific automated tests were found in the existing suite — a genuine, pre-existing gap, not mobile-specific. Consider adding provider-level tests as you build (they benefit the desktop app too, since providers are shared).

Manual test: run one full lifecycle per workflow entity — create a purchase order, submit it, approve it (if you have manager credentials), send it; create a transfer order, complete it; start an inventory count, enter counts for 2+ products, post it; check availability and create a production order, start it, complete it.

## What I Should Understand Before Day 18

That every inventory workflow entity you just built follows one repeated shape (notifier method → service → endpoint → reload list), and that the ONE piece of real business logic duplicated on the client (`_actionsFor`-style status→actions mappings) is a deliberate, necessary duplication for UX responsiveness — not a shortcut, since the backend re-validates every transition regardless of what the client's menu offered.

---

# Day 18 — Reports & Invoice PDF: Filter to Full-Dataset PDF

## A. Where Do I Start?

Open `lib/features/reports/services/report_service.dart`, find `fetchAllPages<T>`. This one generic function is the key idea for the whole day: what's shown on screen (paginated) and what goes in an exported PDF (complete) are deliberately different, and this function is the bridge.

## B. Existing Web Function Chain

`fetchAllPages<T>` — full body:
```dart
const reportPrintPageSize = 200;

Future<List<T>> fetchAllPages<T>({required Future<(List<T> rows, PageMeta meta)> Function(int page) fetchPage}) async {
  final all = <T>[];
  var page = 0;
  while (true) {
    final (rows, meta) = await fetchPage(page);
    all.addAll(rows);
    if (rows.isEmpty || page + 1 >= meta.totalPages) break;
    page++;
  }
  return all;
}
```
Uses a Dart record type `(List<T>, PageMeta)` as the callback's return — walks every backend page at `size: 200` (the backend caps page size at 200 server-side too, confirmed in `PurchaseOrderController`'s own `Math.min(Math.max(1, size), 200)` pattern for a similar list endpoint) regardless of the ~20-row on-screen page size.

One concrete report method, `salesByItem`:
```dart
Future<PagedResult<SalesByItemRow>> salesByItem({required String from, required String to,
    int? fromHour, int? toHour, int? employeeId, int? page, int? size, String? sort}) async {
  final params = {'from': from, 'to': to, if (fromHour != null) 'fromHour': '$fromHour', ...};
  final resp = await _api.get<Map>('/api/reports/sales-by-item', queryParameters: params);
  return _pagedFrom(resp, SalesByItemRow.fromJson);
}
```

Full PDF export flow, `sales_by_item_screen.dart::_printReport()`:
```dart
Future<void> _printReport() async {
  final company = await ref.read(settingsServiceProvider).getCompanyProfile();
  final cur = currencySymbol(readCurrency(ref));
  final allRows = await fetchAllPages<SalesByItemRow>(
    fetchPage: (page) async {
      final pageData = await ref.read(reportServiceProvider).salesByItem(
          from: _filter.fromStr, to: _filter.toStr, page: page, size: reportPrintPageSize, sort: _sort);
      return (pageData.content, pageData.meta);   // record literal matching fetchAllPages's expected shape
    },
  );
  final rows = allRows.map((r) => [resolveBilingual(en: r.nameEn, km: r.nameKm, language: language),
      r.sku ?? '', _fmtNum(r.quantitySold), '$cur${_fmtNum(r.grossSales)}', ...]).toList();
  final pdfBytes = await A4ReportPdf.build(
      title: l10n.reportsSalesByItem, businessName: '${company['businessName'] ?? ''}',
      columns: [...], rows: rows, summary: [...],
      generatedAt: DateTime.now(), generatedLabel: l10n.reportPdfGeneratedLabel, pageLabel: l10n.reportPdfPageLabel);
  await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'sales_by_item_report');
}
```
Notice: `A4ReportPdf.build` needs the company profile (fetched fresh here, via `SettingsService.getCompanyProfile()` — the SAME function Day 19 wires into Settings), and this screen calls `Printing.layoutPdf` (not `sharePdf` — contrast with `purchase_orders_screen.dart`'s PDF export, which uses `sharePdf`; the choice between the two varies screen by screen in the existing app, not a fixed rule).

## C. Backend/API Chain

```text
GET /api/reports/sales-by-item?from=&to=&page=&size=200&sort=
↓
ReportController -> ReportService (backend) -> Page<SalesByItemRow-equivalent>
```
Every report method follows this same GET-with-query-params, Spring-`Page`-response shape. The backend supports 14 distinct report endpoints total (`daily`, `sales-summary`, `sales`, `category-performance`, `monthly`, `tax`, `top-products`, `payment-mix`, `cashier-performance`, `stock-movements`, `inventory-valuation`, `sales-by-item`, `sales-by-modifier`, `discounts`, `tax-report`) — all under `ReportController`'s `/api/reports` base path.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `services/report_service.dart` | — | `fetchAllPages<T>` | `{fetchPage: Function(int) -> Future<(List<T>, PageMeta)>}` | `Future<List<T>>` | Call unchanged for every report's PDF export |
| `services/report_service.dart` | `ReportService` | one method per report type | varies | `Future<PagedResult<T>>` | Call unchanged |
| `core/services/printing/a4_report_pdf.dart` | `A4ReportPdf` | `build` | see signature above | `Future<Uint8List>` | Call unchanged |
| `services/settings_service.dart` | `SettingsService` | `getCompanyProfile` | — | `Future<Map>` | Needed for PDF header branding |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_reports_hub_screen.dart
# plus a mobile screen per report type, following the SAME fetchAllPages -> A4ReportPdf.build -> Printing pattern
```

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
class MobileSalesByItemScreen extends ConsumerStatefulWidget {
  const MobileSalesByItemScreen({super.key});
  @override
  ConsumerState<MobileSalesByItemScreen> createState() => _State();
}
class _State extends ConsumerState<MobileSalesByItemScreen> {
  Future<void> _exportPdf() async {
    // STEP 1: reuse fetchAllPages EXACTLY — never export just the on-screen page.
    final allRows = await fetchAllPages<SalesByItemRow>(fetchPage: (page) async {
      final pageData = await ref.read(reportServiceProvider).salesByItem(
          from: _filter.fromStr, to: _filter.toStr, page: page, size: reportPrintPageSize);
      return (pageData.content, pageData.meta);
    });
    // STEP 2: build rows/summary the same shape A4ReportPdf.build expects.
    final company = await ref.read(settingsServiceProvider).getCompanyProfile();
    final pdfBytes = await A4ReportPdf.build(
        title: context.l10n.reportsSalesByItem, businessName: '${company['businessName'] ?? ''}',
        columns: [/* ... */], rows: [/* mapped from allRows */],
        generatedAt: DateTime.now(), generatedLabel: '', pageLabel: '');
    // STEP 3: mobile-friendly action — Share is often more useful than Print on a phone.
    await Printing.sharePdf(bytes: pdfBytes, filename: 'sales_by_item.pdf');
  }
  @override
  Widget build(BuildContext context) {
    // STEP 4: on-screen table still uses the SMALL page size for display responsiveness —
    // only the export path uses fetchAllPages/reportPrintPageSize.
    return Scaffold(body: Column(children: [/* filter bar, paginated table */]));
  }
}
```

## G. Function Inputs and Outputs

`fetchAllPages<SalesByItemRow>({required fetchPage})`
INPUT: a callback that, given a page number, returns `(rows, meta)` for that page
DOES: loops calling `fetchPage(0)`, `fetchPage(1)`, ... accumulating `rows`, until an empty page or `page+1 >= meta.totalPages`
OUTPUT: `Future<List<SalesByItemRow>>` — the COMPLETE filtered dataset, not just what's on screen
CALLER: your export button's handler
NEXT: fed into `A4ReportPdf.build`'s `rows` parameter.

## H. State Before and After

Not Riverpod-driven for the export path itself — a one-shot async operation triggered by a button tap, producing bytes, not stored state.

## I. What Should Be Shared vs Mobile-Only?

```text
fetchAllPages / ReportService (every method) / A4ReportPdf.build / reportPrintPageSize
🟢 KEEP EXACTLY

report_charts.dart (ReportBarChart/LineChart/PieChart, fl_chart-based)
🟢 KEEP EXACTLY — no platform-specific rendering in fl_chart

Desktop report screen layouts (filter bar inline, wide tables)
🔴 DO NOT COPY layout — 🟢 KEEP EXACTLY their fetchAllPages usage
```

## J. Build Order Inside the Day

1. Open `report_service.dart`, read `fetchAllPages` and one concrete method (`salesByItem`) fully.
2. Open `sales_by_item_screen.dart`, read `_printReport()` end to end.
3. Build `MobileReportsHub` (simple menu/list).
4. Build 2–3 representative mobile report screens as templates (recommend: Sales Summary for table+chart, Sales by Item for table+sort-toggle+chart, Payment Mix for pie-chart) — port the remaining report screens from these templates.
5. Wire PDF export on every report screen via the exact `fetchAllPages` + `A4ReportPdf.build` pattern — never skip `fetchAllPages` "to keep it simple."
6. Wire the Day 17 inventory screens' PDF export buttons through the identical mechanism.
7. Test: apply a filter that yields more than one page of results (>200 rows if your test data allows, or lower `reportPrintPageSize` temporarily for testing), export, confirm the PDF contains ALL matching rows, not just the first page.
8. Confirm Khmer company/product names render correctly in these PDFs via `A4ReportPdf`'s own `KhmerTextRasterizer` path (Day 14's note: this is a DIFFERENT code path from the receipt Khmer strategy).

## K. "When I Click This, What Happens?"

# Tap "Export PDF" on a filtered report
```text
Tap export icon
↓
fetchAllPages<SalesByItemRow>(fetchPage: (page) => reportService.salesByItem(..., page: page, size: 200))
↓
loop: GET /api/reports/sales-by-item?page=0&size=200, then page=1, ... until exhausted
↓
List<SalesByItemRow> allRows  (COMPLETE dataset, e.g. 350 rows across 2 backend pages)
↓
SettingsService.getCompanyProfile() -> header branding data
↓
A4ReportPdf.build(columns, rows, summary, ...) -> pre-rasterizes any Khmer strings -> pw.MultiPage -> bytes
↓
Printing.sharePdf(bytes: bytes, filename: ...) -> OS share sheet
```

## L. "Where Does This Value Come From?"

A row's product name in the exported PDF:
```text
Backend SalesByItemRow{nameEn, nameKm, ...}
↓
resolveBilingual(en: r.nameEn, km: r.nameKm, language: appLanguage)   (SAME utility as Day 6's product cards)
↓
row cell string passed into A4ReportPdf.build's `rows` parameter
↓
KhmerTextRasterizer.textOrImage(cellText, ...) if it contains Khmer, else native pw.Text
```

## M. Navigation Flow

`MobileReportsHub` → individual report screen: `Navigator.push`. PDF export doesn't navigate — same OS dialog pattern as Day 13.

## N. Error Flow

```text
fetchAllPages succeeds -> full PDF built and shared

Any page fetch within fetchAllPages throws
→ the WHOLE loop throws (no partial-PDF fallback) — propagates to your export button's handler,
  which must catch it and show a clear error, exactly like sales_by_item_screen.dart's own
  _printReport() wraps its body in try/catch with a SnackBar on failure.

getCompanyProfile fails
→ same — propagates, must be caught; a report PDF with no company header is arguably still
  useful, so consider (deliberately, not by accident) whether to make company profile fetch
  failure non-fatal to the export vs. blocking it entirely — the existing desktop code does NOT
  make this distinction (it fails the whole export), so decide if mobile should differ.
```

## O. Test Flow

Existing tests: `test/a4_report_pdf_details_test.dart`, `test/a4_report_pdf_khmer_test.dart`, `test/report_print_pagination_test.dart` — target the PDF builder/pagination logic directly, reusable unmodified.
```bash
flutter test test/report_print_pagination_test.dart
```
Manual test: filter a report to a date range with a known large result count, export, count rows in the resulting PDF, confirm it matches the total (not just 20 or 200).

## What I Should Understand Before Day 19

That `A4ReportPdf`'s Khmer handling (per-string, cached `KhmerTextRasterizer`) is architecturally distinct from the receipt pipeline's whole-document `ReceiptBitmapRenderer` (Day 14) — recognizing which one a given screen uses tells you which test files and which mental model apply when something looks wrong.

---

# Day 19 — Settings: Company, Tax, Currency, Printer Config

## A. Where Do I Start?

Open `lib/features/pos/services/settings_service.dart`. It's a flat list of `get`/`update` pairs — read the whole file, it's short and every method follows one shape.

## B. Existing Web Function Chain

`SettingsService` — the pattern, shown for company profile and tax:
```dart
Future<Map<String, dynamic>> getCompanyProfile() async => _api.get('/api/settings/company-profile');
Future<Map<String, dynamic>> updateCompanyProfile(Map<String, dynamic> request) async =>
    _api.put('/api/settings/company-profile', data: request);
Future<Map<String, dynamic>> getTax() async => _api.get('/api/settings/tax');
Future<Map<String, dynamic>> updateTax(Map<String, dynamic> request) async => _api.put('/api/settings/tax', data: request);
```
Every settings group is a raw `Map<String, dynamic>` — no typed DTOs anywhere in this file.

`companyProfileProvider` and its consumption pattern:
```dart
final companyProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async =>
    ref.read(settingsServiceProvider).getCompanyProfile());

String watchCompanyName(WidgetRef ref, {required String fallback}) {
  final company = ref.watch(companyProfileProvider).valueOrNull;   // valueOrNull, NOT .when() —
  final name = (company?['businessName'] as String?)?.trim();      // avoids flashing fallback during
  return (name == null || name.isEmpty) ? fallback : name;          // invalidation
}
```

Save handler, `settings_modules_screen.dart::_saveCompany()`:
```dart
Future<void> _saveCompany() async {
  if (_businessNameCtl.text.trim().isEmpty) { _toast(l10n.formPleaseEnterValue, isError: true); return; }
  try {
    await ref.read(settingsServiceProvider).updateCompanyProfile({
      'businessName': _businessNameCtl.text.trim(), 'address': _addressCtl.text.trim(),
      'phone': _phoneCtl.text.trim(), 'website': _websiteCtl.text.trim(),
      'receiptFooter': _receiptFooterCtl.text.trim(),
    });
    ref.invalidate(companyProfileProvider);   // ONLY on success — a failed PUT leaves stale data cached
    _toast(l10n.settingsCompanyProfile);
  } catch (e) { _toast(e is ApiException ? e.message : l10n.errorGeneric, isError: true); }
}
```
Consumption elsewhere (`pos_screen.dart`'s AppBar): `watchCompanyName(ref, fallback: '${l10n.appName} ${l10n.navPos}')` — the SAME provider, invalidated by the save above, automatically refreshes everywhere it's watched.

**Important gotcha, confirmed by direct code inspection — paper width lives in TWO separate places:**
```dart
// Place 1: pos_settings_screen.dart's 58/80mm dropdown -> backend-persisted, NOT read by printing code:
await service.updatePosLayout({..., 'receiptPaperWidth': _receiptPaperWidth, ...});   // PUT /api/settings/pos-layout

// Place 2: settings_modules_screen.dart's _thermalPrinterSection -> device-local, ACTUALLY used by printing:
await ref.read(thermalPrinterServiceProvider).saveConfig(
    PrinterConfig(paperSize: _paperSize, transportType: _transportType, ...));   // SharedPreferences only
```
`PrinterConfig.paperSize` (`PrinterPaperSize` enum, Day 13–16's actual print path) is what genuinely controls receipt formatting. The `receiptPaperWidth` int field saved via `updatePosLayout` is currently **not read anywhere in the printing code path** — it's stored but unused by `ThermalPrinterService`/`PrintService`/`ReceiptBitmapRenderer`. Build your mobile settings screen aware of this split: don't assume setting one automatically updates the other.

`_saveThermalConfig()` — the function that actually feeds the print pipeline:
```dart
Future<void> _saveThermalConfig() async {
  final config = PrinterConfig(
      transportType: _transportType, paperSize: _paperSize, bluetoothAddress: _bluetoothAddress,
      usbVendorId: int.tryParse(_usbVendorCtl.text.trim()), usbProductId: int.tryParse(_usbProductCtl.text.trim()),
      networkHost: _networkHostCtl.text.trim().isEmpty ? null : _networkHostCtl.text.trim(),
      networkPort: int.tryParse(_networkPortCtl.text.trim()) ?? 9100);
  await ref.read(thermalPrinterServiceProvider).saveConfig(config);
}
```

`debug_settings_screen.dart::_save()` — confirmed only 2 writes, both in-memory-only (process lifetime, reset on app restart, not persisted to SharedPreferences):
```dart
void _save() {
  setState(() {
    AppConfig.useApiCartService = _useApiCart;
    AppConfig.enableHeldTicketSync = _syncHeldTickets;
  });
}
```
`AppConfig.useApiTableService` exists (`app_config.dart`) but is confirmed absent from this screen — a pre-existing gap, not mobile-specific.

## C. Backend/API Chain

```text
GET/PUT /api/settings/company-profile
↓
SettingsController (@PreAuthorize PERM_SETTINGS_MANAGE for BOTH get and put — stricter than /general)
    -> SettingsService.getCompanyProfile()/updateCompanyProfile() [backend]
↓
BusinessSettings entity (@Table "business_settings") via getOrCreateBusinessSettings() + repository.save()
```
**Confirmed**: company profile and general settings share the SAME backend table/row (`BusinessSettings`), just expose different DTO field subsets — editing one doesn't create a separate record from the other.

## D. Exact Existing Functions to Reuse

| File | Class | Function | Input | Output | Mobile use |
|---|---|---|---|---|---|
| `services/settings_service.dart` | `SettingsService` | `getCompanyProfile`/`updateCompanyProfile` | `Map` | `Future<Map>` | Call unchanged |
| `services/settings_service.dart` | `SettingsService` | `getTax`/`updateTax` | `Map` | `Future<Map>` | Call unchanged (note: no shared provider invalidated on save) |
| `core/providers/company_provider.dart` | — | `companyProfileProvider`/`watchCompanyName` | — | — | Reuse unchanged everywhere company name is displayed |
| `services/printing/thermal_printer_service.dart` | `ThermalPrinterService` | `loadConfig`/`saveConfig` | `PrinterConfig` | — | Call unchanged for printer settings |
| `core/providers/currency_provider.dart` | — | `currencyCodeProvider` | — | `FutureProvider<String>` | Reuse unchanged |

## E. Exact New Mobile Files to Create

```text
lib/features/pos/mobile/screens/mobile_settings_screen.dart
# grouped list -> drill into sub-pages per section (General, Company, Tax, Printers, Payment Methods,
# Currencies, POS Operations), mirroring settings_modules_screen.dart's sections but full-screen each.
```

## F. Exact Function I Need to Write

EDUCATIONAL SKELETON — not production copy/paste.
```dart
class MobileCompanyProfileScreen extends ConsumerStatefulWidget {
  const MobileCompanyProfileScreen({super.key});
  @override
  ConsumerState<MobileCompanyProfileScreen> createState() => _State();
}
class _State extends ConsumerState<MobileCompanyProfileScreen> {
  final _businessNameCtl = TextEditingController();
  // ... other controllers, populated from ref.read(companyProfileProvider.future) in initState

  Future<void> _save() async {
    if (_businessNameCtl.text.trim().isEmpty) { /* show error */ return; }
    try {
      // STEP 1: reuse the EXISTING service call.
      await ref.read(settingsServiceProvider).updateCompanyProfile({
        'businessName': _businessNameCtl.text.trim(), /* ... */
      });
      // STEP 2: SAME invalidation — this is what makes the POS AppBar name update live.
      ref.invalidate(companyProfileProvider);
    } catch (e) { /* show error */ }
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: Column(children: [
    TextField(controller: _businessNameCtl),
    ElevatedButton(onPressed: _save, child: Text(context.l10n.commonSave)),
  ]));
}
```

## G. Function Inputs and Outputs

`SettingsService.updateCompanyProfile(Map<String, dynamic> request)`
INPUT: `{'businessName': 'KAKNNEA Store', 'address': '...', 'phone': '...', 'website': '...', 'receiptFooter': '...'}`
DOES: `PUT /api/settings/company-profile`
OUTPUT: `Future<Map<String, dynamic>>` (the updated record)
CALLER: your mobile save handler
NEXT: `ref.invalidate(companyProfileProvider)` — every `watchCompanyName` consumer across the whole app (POS AppBar, PDF headers) refetches and updates.

## H. State Before and After

BEFORE:
```text
companyProfileProvider = AsyncValue.data({'businessName': 'Old Name', ...})
```
Call: `updateCompanyProfile({'businessName': 'New Name', ...})` then `ref.invalidate(companyProfileProvider)`
AFTER:
```text
companyProfileProvider re-fetches -> AsyncValue.data({'businessName': 'New Name', ...})
```
Then: every screen using `watchCompanyName`/`ref.watch(companyProfileProvider)` rebuilds with the new name — including any receipt/report PDF headers built after this point.

## I. What Should Be Shared vs Mobile-Only?

```text
SettingsService (all methods) / companyProfileProvider / watchCompanyName / currencyCodeProvider
🟢 KEEP EXACTLY

ThermalPrinterService.loadConfig / saveConfig
🟢 KEEP EXACTLY

settings_modules_screen.dart / pos_settings_screen.dart (layouts)
🔴 DO NOT COPY layout — 🟢 KEEP EXACTLY their save/invalidate call sequences

debug_settings_screen.dart's mechanism (writing to AppConfig statics)
🟠 SMALL ADAPTATION — consider also exposing useApiTableService (currently missing even on
   desktop) and consider persisting to SharedPreferences instead of process-memory-only —
   both deliberate, documented improvements, not silent changes

MobileSettingsScreen and sub-screens
🔵 NEW MOBILE UI
```

## J. Build Order Inside the Day

1. Open `settings_service.dart`, read every method (it's a short, flat file).
2. Open `company_provider.dart`, read `companyProfileProvider` and `watchCompanyName`.
3. Open `settings_modules_screen.dart`, read `_saveCompany`, `_saveTax`, the currency edit dialog's save call, and `_thermalPrinterSection`/`_saveThermalConfig` — note the paper-width duplication (section B).
4. Open `debug_settings_screen.dart`, confirm the 2-flag, in-memory-only mechanism.
5. Build `MobileSettingsScreen`'s section-navigation shell.
6. Build each section's sub-screen, porting the exact save/invalidate patterns from section B — General/Company/Tax/Payment Methods/Currencies first (straightforward forms).
7. Build the printer config sub-screen, wiring in Day 15/16's permission flows (request Bluetooth permission when the user SELECTS "Bluetooth" as transport, not only at print time — a better UX than waiting for a failed print to discover a missing permission).
8. Port `pos_settings_screen.dart`'s operational settings.
9. Extend the mobile debug-settings screen to include `useApiTableService`; decide and document your persistence choice.
10. Test: change the company name, confirm the POS AppBar updates immediately without app restart; change a printer setting, confirm the next print job uses it.

## K. "When I Click This, What Happens?"

# Save company profile
```text
Tap Save on Company Profile form
↓
validate businessName non-empty
↓
SettingsService.updateCompanyProfile({...}) -> PUT /api/settings/company-profile
↓ (success)
ref.invalidate(companyProfileProvider)
↓
companyProfileProvider refetches -> GET /api/settings/company-profile
↓
EVERY ref.watch(companyProfileProvider) / watchCompanyName(ref, ...) consumer across the app rebuilds
   (POS AppBar title, drawer/nav header, any PDF header built after this moment)
```

## L. "Where Does This Value Come From?"

The company name shown in the mobile home shell's header:
```text
Backend BusinessSettings entity (shared table with general settings)
↓
SettingsController GET /api/settings/company-profile
↓
companyProfileProvider (FutureProvider, cached until invalidated)
↓
watchCompanyName(ref, fallback: '...')
↓
Text(companyName) in your mobile shell's AppBar
```

## M. Navigation Flow

`MobileSettingsScreen` → each section: `Navigator.push` to a dedicated sub-screen (full-screen forms, not the desktop's single long scrolling page).

## N. Error Flow

```text
updateCompanyProfile succeeds -> invalidate -> everything updates (shown above)

updateCompanyProfile fails (network error, validation error)
→ caught in YOUR save handler's try/catch (mirror settings_modules_screen.dart's own pattern:
  catch, check `e is ApiException` for a specific message, else a generic error string)
→ CRITICALLY: ref.invalidate is only called on the success path — a failure leaves the
  cached companyProfileProvider value untouched, so stale (but at least consistent) data
  continues to display rather than showing something broken

updateTax succeeds
→ NO shared provider is invalidated for tax (confirmed — no tenderCurrenciesProvider-style
  invalidation exists for tax specifically) — if you need tax rate reflected live elsewhere
  (e.g. cart's syncTaxRate, Day 7), that's a SEPARATE fetch (CartNotifier.syncTaxRate calls
  SettingsService.getTax() directly, not through a cached provider) — don't assume saving
  tax here automatically updates an open cart's tax rate.
```

## O. Test Flow

Existing tests: `test/settings_service_test.dart`, `test/company_provider_test.dart`, `test/debug_settings_screen_test.dart` (adapt the last for your new mobile debug screen, same underlying `AppConfig` flags) — reusable/adaptable, not full rewrites.
```bash
flutter test test/settings_service_test.dart test/company_provider_test.dart
```
Manual test: change company name, confirm AppBar updates without restart; change printer transport type + host, confirm the next Day 15 print attempt uses the new config; toggle a debug flag, force-quit the app, relaunch, confirm it reset to default (in-memory-only, as documented).

## What I Should Understand Before Day 20

The paper-width duplication (section B) is a good final example of this whole plan's core lesson: **read the actual code path a feature uses, don't assume a setting labeled correctly is the one that's actually wired up.** Carry that instinct into Day 20's full-flow QA pass.

---

# Day 20 — Full Application Flow: One Diagram, One Real Scenario

## A. Where Do I Start?

Nowhere new — today you retrace the ENTIRE chain below, end to end, on real devices. If any single arrow in this diagram surprises you, go back to that day's section B and re-read it.

## B. The Complete Application Chain

```text
main()
  -> WidgetsFlutterBinding.ensureInitialized()
  -> AppConfig.initialize()
  -> runApp(ProviderScope(child: PosApp()))
↓
PosApp.build -> ref.watch(authProvider) -> home: LoginScreen (no session) or MobileHomeShell (session restored)
↓
[Day 4] MobileLoginScreen._login() -> AuthNotifier.login() -> AuthService.login() -> POST /api/auth/login
  -> AuthController.login -> AuthService.login [backend] -> JwtUtil.generateToken -> AuthDtos.LoginResponse
  -> AuthNotifier.state = AsyncValue.data(user) -> Navigator.pushReplacementNamed(mobile home)
↓
[Day 5] MobileHomeShell (bottom nav) -> tap POS -> Navigator.pushNamed('/pos')
↓
[Day 10] MobileShiftScreen -> ShiftNotifier.openShift() -> POST /api/shifts/open -> ShiftState.isShiftOpen = true
↓
[Day 6] MobileProductGrid -> ProductNotifier.loadProducts() -> GET /api/products/pos-catalog -> ProductState.products
↓
[Day 8] (optional) MobileScanScreen -> CartNotifier.addProductByBarcode(barcode) -> fast/slow path lookup
↓
[Day 7] tap product / confirm modifier sheet -> CartNotifier.addItem() -> persistCart() -> _syncService()
  -> MobileCartBadge rebuilds
↓
[Day 9] (optional) MobileTableSelectorScreen -> tableSelectionProvider.select() + cartProvider.setTable()
        (optional) MobileCustomerPickerScreen -> cartProvider.setCustomer()
        (optional) Hold -> HeldTicketNotifier.holdCurrentCart() -> cart clears -> restore later via restoreTicket()
↓
[Day 7] MobileCartScreen -> tap Charge -> Navigator.push(MobilePaymentScreen(total: cart.finalTotal, ...))
↓
[Day 11] MobilePaymentScreen._submitSaleToBackend()
  -> SaleService.createSale(request) -> POST /api/pos/sales -> SaleController.create -> SaleService.create [backend]
     (clientRef idempotency check, DRAFT sale, stock AVAILABILITY checked but not yet deducted)
  -> SaleService.paySale(saleId, payments) -> POST /api/pos/sales/{id}/pay -> SaleService.pay [backend]
     (stock ACTUALLY deducted here, via applyStockForSale/applyStockMovement with a pessimistic lock)
  -> HeldTicketNotifier.releaseTicketById() [if applicable, fire-and-forget]
  -> WaitingNumberService.saveWaitingTicket(status: paid)
  -> CartNotifier.clear(releaseWaitingNumber: false)
  -> _paymentState = completed
  -> (background) SaleService.getReceipt(saleId)
↓
[Day 12] MobileReceiptPreviewScreen -> ReceiptViewModel.fromReceiptResponse() -> ReceiptContent renders
↓
[Day 13/14/15/16] tap Print -> PrintService.printReceipt()
  -> ThermalPrinterService.loadConfig() -> PrinterConfig.transportType
  -> pdfDriver: buildReceiptPdf() -> Printing.layoutPdf()          [Day 13]
     Khmer branch inside buildReceiptPdf: ReceiptBitmapRenderer    [Day 14]
  -> network: ThermalPrinterService.printReceipt() -> NetworkPrinterTransport [Day 15]
  -> bluetooth/usb: same, via BluetoothPrinterTransport/UsbPrinterTransport, permission-gated [Day 16]
↓
[Day 17] (separately) MobilePurchaseOrdersScreen -> createOrder/transition() -> inventory workflow
↓
[Day 18] (separately) MobileReportsHub -> fetchAllPages() -> A4ReportPdf.build() -> Printing
↓
[Day 19] (any time) MobileSettingsScreen -> SettingsService.update*() -> ref.invalidate() -> app-wide refresh
↓
[Day 10] MobileShiftScreen -> ShiftNotifier.getClosePrecheck() -> ShiftNotifier.closeShift()
  -> POST /api/shifts/{id}/close -> backend variance calc -> CLOSED or PENDING_APPROVAL
```

## C. A Realistic Cashier Scenario, Traced With Real Function Names

```text
1. Cashier opens the app -> AuthNotifier._initializeAuth() finds a valid, unexpired token
   -> state = AsyncValue.data(user) -> MobileHomeShell appears directly (no login needed today).
2. Taps Shift -> ShiftNotifier.loadCurrentShift() -> no open shift -> opens one:
   ShiftNotifier.openShift(openingFloat: 100.00) -> POST /api/shifts/open.
3. Taps POS -> ProductNotifier.loadProducts() -> GET /api/products/pos-catalog -> grid populates.
4. Scans a barcode -> MobileScanScreen -> CartNotifier.addProductByBarcode('885...') -> fast-path hit
   (product already in memory) -> addItemFromProduct() -> CartState.items = [1 item].
5. Long-presses a second product -> ProductModifierSheet -> selects a modifier -> confirms ->
   CartNotifier.addItem(cartItemWithModifiers) -> CartState.items = [2 items].
6. Selects a table -> MobileTableSelectorScreen -> tableSelectionProvider.select(table) THEN
   cartProvider.setTable(table.id).
7. Taps cart badge -> MobileCartScreen -> reviews items, adjusts qty via incrementItem/decrementItem.
8. Taps Charge -> Navigator.push(MobilePaymentScreen(total: cart.finalTotal, ...)).
9. Selects Cash, enters tendered amount -> _changeDue computed -> taps Complete Sale.
10. _submitSaleToBackend(): createSale() -> POST /api/pos/sales -> DRAFT sale created, clientRef stored.
    paySale() -> POST /api/pos/sales/{id}/pay -> stock deducted, sale marked paid.
    releaseTicketById() skipped (no held ticket). saveWaitingTicket(status: paid).
    cartProvider.notifier.clear(releaseWaitingNumber: false) -> cart badge drops to 0.
11. Taps "View Receipt" -> MobileReceiptPreviewScreen -> getReceipt(saleId) -> ReceiptViewModel built.
12. Taps Print -> PrintService.printReceipt() -> config.transportType == network ->
    ThermalPrinterService.printReceipt() -> NetworkPrinterTransport connects, writes ESC/POS bytes,
    disconnects -> physical receipt prints.
13. Later, opens Receipts history -> MobileReceiptsScreen -> ref.watch(receiptProvider) ->
    state.filteredSales (default: All, unfiltered). Taps the "Refunded" chip to spot-check an
    earlier return -> ReceiptNotifier.setStatusFilter('REFUNDED') -> backendStatusQueryFor('REFUNDED')
    -> null -> loadAllSales(status: null) -> SaleService.listSales(status: null) -> state.sales ->
    state.filteredSales -> saleMatchesStatusFilter narrows to REFUNDED + PARTIALLY_REFUNDED only.
    Switches to "Paid" -> finds this morning's sale from step 10 -> taps it ->
    ReceiptNotifier.loadReceipt(saleId) -> confirms only Print/Save PDF/Email/Refund show (no Pay,
    since it's PAID not VOID) -> taps reprint -> PrintService.printReceipt(context, saleId) ->
    the EXACT SAME ReceiptViewModel/PrintService path as step 12, not a second pipeline.
14. At end of day: ShiftNotifier.getClosePrecheck() -> no blocking open tickets -> ShiftNotifier.closeShift(
    closingCash: 245.00) -> POST /api/shifts/{id}/close -> backend computes variance -> within $10 ->
    status CLOSED -> ShiftState.isShiftOpen = false.
```

## D. Test Flow — Full Regression

Run the ENTIRE existing automated suite against your mobile-targeted build, not just the individual tests referenced per-day:
```bash
flutter test
flutter test integration_test
```
Add new `integration_test/` entries mirroring `app_test.dart`'s scope, but exercising `MobileHomeShell`'s navigation and the mobile screens built across this plan.

## E. Definition of Done — Release Readiness Checklist

- [ ] Full scenario (section C) completes on a real Android phone, in English.
- [ ] Full scenario completes on a real Android phone, in Khmer.
- [ ] Full scenario completes on a real iPhone, in English.
- [ ] Full scenario completes on a real iPhone, in Khmer.
- [ ] All 4 printer transports (PDF, Network, Bluetooth, USB) tested against real or realistically-simulated hardware on both platforms; iOS USB result documented either way (Day 16).
- [ ] Camera permission denied path tested (Day 8) — app shows guidance, doesn't crash.
- [ ] Bluetooth/local-network permission denied paths tested (Day 15/16) — app shows guidance, doesn't crash.
- [ ] Offline/slow-network behavior tested: cart still works offline (Day 7), sale submission retry is verified idempotent (Day 11), report/settings screens fail gracefully when the network is down.
- [ ] Tested on at least 2 different screen sizes per platform.
- [ ] `android/app/build.gradle.kts`'s `applicationId` and release signing config are real (not the debug-keystore placeholder from Day 2) — or a documented plan exists for finishing this before store submission.
- [ ] `ios/Runner.xcodeproj`'s bundle ID and provisioning are real, or a documented plan exists.
- [ ] 12-hour JWT expiry behavior tested mid-shift — confirm the app shows a clear re-login prompt rather than a silent, confusing failure.
- [ ] Receipts history: All/Paid/Void/Refunded filters all verified — Refunded shows both REFUNDED and PARTIALLY_REFUNDED, no PENDING chip exists, filter selection survives an All/Shift toggle round-trip (Day 12 addendum).
- [ ] Receipts history: VOID rows confirmed to show no Pay action and no Refund action; PARTIALLY_REFUNDED rows confirmed to still offer Refund per current backend/frontend permission.
- [ ] Reprint from Receipts history confirmed to use the exact same `ReceiptViewModel`/`PrintService.printReceipt` path as a fresh post-checkout print (Day 12 addendum, Day 13).
- [ ] Release checklist drafted: store listing text, privacy-policy language covering camera/Bluetooth/local-network permission usage (required by both app stores).

## What I Should Understand at the End of This Plan

The thesis this entire 20-day plan tested: that a POS app's business logic — money math, sale/shift/inventory rules, receipt content, Khmer rendering — is platform-agnostic almost by construction, PROVIDED it's kept out of the UI layer, which this codebase already does consistently. "Porting to mobile" turned out to be overwhelmingly a UI-and-permissions exercise, not a rewrite. If Day 20 required touching `CartNotifier`, `SaleService`, `ShiftNotifier`, or `ReceiptViewModel` at all to make mobile work correctly, that's a genuine architecture gap worth fixing upstream — one that would have affected the web app too, not something mobile-specific to patch around.

---

## From UI to Database — 5 Deep Examples

### 1. Login

```text
MobileLoginScreen._login()                         [new mobile widget]
  ↓
ref.read(authProvider.notifier).login(email, password)
  ↓
AuthNotifier.login()  [core/providers/auth_provider.dart]  — state = loading, then .data/.error
  ↓
AuthService.login()  [core/services/auth_service.dart]  — builds LoginRequest, saves response
  ↓
ApiService.post<Map>('/api/auth/login', data: request.toJson())  [core/services/api_service.dart]
  ↓  HTTP POST
AuthController.login(@Valid LoginRequest, HttpServletRequest)  [backend, controller/AuthController.java]
  ↓
AuthService.login(request, ip, userAgent)  [backend, service/AuthService.java]
  ↓
UserRepository.findByEmail(email)  [backend, repository/UserRepository.java]
  ↓
User entity (table "users": email, passwordHash, roles, failedLoginAttempts, lockoutUntil)
  ↓ (password verified, roles/permissions collected)
JwtUtil.generateToken(email, roles, permissions)  [backend, security/JwtUtil.java] — HS256, 720min expiry
  ↓
AuthDtos.LoginResponse{token, user: {id, email, fullName, roles, permissions}}  (DTO, JSON serialized)
  ↓  HTTP response
AuthResponse.fromJson(response)  [Flutter, core/models/auth_models.dart]
  ↓
AuthService._saveAuthData()  — SharedPreferences['auth_token'], ['user_data']
  ↓
AuthNotifier.state = AsyncValue.data(user)
  ↓
ref.watch(authProvider) in PosApp/MobileHomeShell — widget rebuilds
  ↓
LoginScreen: Navigator.pushReplacementNamed(mobile home route)
```

### 2. Add Product to Cart

```text
ProductCard.onTap (from MobileProductGrid)                [new mobile widget, reused ProductCard]
  ↓
ref.read(cartProvider.notifier).addItemFromProduct(product)  [features/pos/providers/cart_provider.dart]
  ↓ (merge or new CartItem)
CartNotifier.addItem(item)
  ↓
WaitingNumberService.issueNumber() (if no waiting number yet — fully offline, no backend call)
  ↓
state = state.copyWith(items: [...state.items, item])
  ↓
CartNotifier.persistCart()  — SharedPreferences['cart_state_v2'] (ALWAYS runs, local-first)
  ↓
CartNotifier._syncService(() => service.saveCartItems(items))  — best-effort, errors swallowed
  ↓ (only if AppConfig.useApiCartService == true)
ApiCartService.saveCartItems()  [features/pos/services/cart_service.dart]
  ↓  HTTP DELETE + POST
CartController.createCart / addItemToCart  [backend, controller/CartController.java]
  ↓
CartService.addItemToCart()  [backend, service/CartService.java]
  ↓
ProductRepository.findById(productId), CartItemRepository.save(), Cart.calculateTotal(), CartRepository.save()
  ↓
Cart/CartItem entities (tables "carts"/"cart_items")
  — NOTE: this backend Cart is confirmed DISCONNECTED from Sale (see Day 7 section C) —
    it's a background persistence mechanism, NOT part of the checkout path.
  ↓ (back in Flutter, regardless of remote sync outcome)
ref.watch(cartProvider) — MobileCartBadge and MobileCartScreen rebuild with the new item.
```

### 3. Complete Sale

```text
MobilePaymentScreen (Complete Sale button)                 [new mobile widget]
  ↓
_submitSaleToBackend()  [ported near-verbatim from features/pos/screens/payment_screen.dart]
  ↓
build request map: {lines, clientRef, customerId?, tableId?, orderMode, payments?, taxRate, invoiceDiscount?}
  ↓
SaleService.createSale(request)  [features/pos/services/sale_service.dart]
  ↓  HTTP POST /api/pos/sales
SaleController.create(@Valid SaleCreateRequest)  [backend, controller/SaleController.java]
  ↓
SaleService.create(request)  [backend, service/SaleService.java, @Transactional]
  ↓
SaleRepository.findByClientRef(clientRef)  — IDEMPOTENCY CHECK, returns existing sale if found
  ↓ (new sale)
ProductRepository.findById() per line, validateSaleStockAvailable() (checks, does NOT deduct)
ShiftRepository.findFirstByOpenedByIdAndStatusOrderByOpenedAtDesc() — attaches current open shift
  ↓
Sale.status = "DRAFT", SaleRepository.save(sale)
  ↓
SaleDtos.SaleResponse{id, status: "DRAFT", grandTotal, ...}
  ↓ (back in Flutter — IF payments were authorized)
SaleService.paySale(saleId, payments)  ↓  HTTP POST /api/pos/sales/{id}/pay
SaleController.pay → SaleService.pay()  [backend]
  ↓
applyStockForSale() → applyStockMovement() per line:
  StockItemRepository.findByProductIdAndStoreIdForUpdate()  — PESSIMISTIC LOCK
  StockItem.quantity -= saleQuantity, StockItemRepository.save()
  StockMovementRepository.save(new StockMovement(type: "SALE"))  — audit row
  ↓
Sale/SaleLine/StockItem/StockMovement entities (tables "sales", "sale_lines", "stock_items", "stock_movements")
  ↓
SaleDtos.SaleResponse{status: <paid>, grandTotal, paidAmount, payments: [...]}
  ↓ (back in Flutter)
CartNotifier.clear(releaseWaitingNumber: false), WaitingNumberService.saveWaitingTicket(status: paid)
  ↓
MobilePaymentScreen rebuilds to "completed" state; MobileCartBadge drops to 0.
```

### 4. Open/Close Shift

```text
MobileShiftScreen (Open button)                             [new mobile widget]
  ↓
ShiftNotifier.openShift(openingFloat: 100.00)  [features/pos/providers/shift_provider.dart]
  ↓
ApiShiftService.openShift(100.00)  [features/pos/services/shift_service.dart]
  ↓  HTTP POST /api/shifts/open
ShiftController.open(@Valid OpenShiftRequest)  [backend, controller/ShiftController.java]
  ↓
ShiftService.open(request)  [backend, service/ShiftService.java]
  ↓
ShiftRepository.findFirstByOpenedByIdAndStoreIdAndStatusOrderByOpenedAtDesc(actor, store, "OPEN")
  — guards against a second concurrent open shift for the same cashier/store
  ↓
Shift entity created (status="OPEN"), ShiftRepository.save()
CashEventService.recordInternal(shift, "OPEN_SHIFT", openingCash, ...)  — audit event
  ↓
ShiftDtos.ShiftResponse{id, status: "OPEN", openingCash, ...}
  ↓
ShiftNotifier.state = ShiftState(isShiftOpen: true, currentShift: shift)

--- later, at end of shift ---

MobileShiftScreen (Close button, closingCash: 245.00)
  ↓
ShiftNotifier.closeShift(closingCash: 245.00)
  ↓
ApiShiftService.closeShift(shiftId, 245.00)  ↓  HTTP POST /api/shifts/{id}/close {closingCash, forceClose: false}
ShiftController.close  →  ShiftService.close()  [backend]
  ↓
CashEventRepository.sumByShiftIdAndTypes()  — SALE_CASH, REFUND_CASH, CASH_IN/OUT, PAID_IN/OUT
  ↓
expected = openingCash + cashSales + cashRefunds + manualCashEvents
variance = (closingCash - expected).setScale(2, HALF_UP)
  ↓
if (|variance| > 10.00) { OWNER/MANAGER → CLOSED (self-approve) : else → PENDING_APPROVAL }
else { CLOSED }
  ↓
Shift entity updated (closingCash, expectedCash, variance, status, closedAt)
  ↓
ShiftDtos.ShiftResponse{status: "CLOSED" | "PENDING_APPROVAL", variance, ...}
  ↓
ShiftNotifier.state = ShiftState(isShiftOpen: false, currentShift: <response>)
  — mobile UI must read currentShift.status, not just isShiftOpen, to distinguish the two outcomes.
```

### 5. Create Purchase Order

```text
MobileCreatePurchaseOrderScreen (Save button)                [new mobile widget]
  ↓
build validLines from form rows (skip rows with no product or qty <= 0)
  ↓
ref.read(purchaseOrdersProvider.notifier).createOrder(PurchaseOrder(supplierId, storeId, lines, ...))
  [features/inventory/providers/inventory_provider.dart]
  ↓
ApiInventoryService.createPurchaseOrder(order)  [features/inventory/services/inventory_service.dart]
  ↓  HTTP POST /api/purchase-orders  {supplierId, storeId?, taxRate, notes?, lines: [...]}
PurchaseOrderController.create(@Valid PurchaseOrderRequest)  [backend, controller/PurchaseOrderController.java]
  ↓
PurchasingWorkflowService.createPurchaseOrder(request)  [backend, service/PurchasingWorkflowService.java]
  ↓
SupplierRepository.findById(supplierId)  — throws ApiException("Supplier not found") if missing
ProductRepository.findById(productId) per line
  — throws ApiException("... not allowed for purchasing") if !purchasable || !trackInventory
  ↓
PurchaseOrder.status = "SUBMITTED" (confirmed set directly here — see Day 17's flagged discrepancy
  against the Flutter model's local 'DRAFT' default and the UI's DRAFT-reachable action map)
PurchaseOrderRepository.save(order), assignPoReference(saved)
PurchaseActivityService.log("PO", id, "CREATE", ...)  — audit trail
  ↓
PurchaseOrder/PurchaseOrderLine entities (tables "purchase_orders", "purchase_order_lines")
  ↓
PurchasingWorkflowDtos.PurchaseOrderResponse{id, referenceNumber, status, supplierName, lines: [...]}
  ↓ (back in Flutter)
purchaseOrdersProvider.notifier.loadOrders()  — full list refetched, not patched in place
  ↓
Navigator.of(context).pop(true)  — form closes, list screen reloads
```

---

## Mobile POS Function Map

Grouped by module. Every function below is EXISTING, unmodified code to call from new mobile UI — not something to reimplement.

### Authentication

```text
FUNCTION: AuthNotifier.login(String email, String password, {String? terminalId})
FILE: lib/core/providers/auth_provider.dart
CALLED BY: LoginScreen._login() (desktop) / MobileLoginScreen._login() (new)
CALLS: AuthService.login()
INPUT: email, password
OUTPUT: Future<void> (result observed via state)
CHANGES STATE: authProvider — loading -> data(user) or error(e) [never rethrows]
NEXT STEP: caller checks ref.read(authProvider) and navigates

FUNCTION: AuthService.login(String email, String password, {String? terminalId})
FILE: lib/core/services/auth_service.dart
CALLED BY: AuthNotifier.login
CALLS: ApiService.post, AuthResponse.fromJson, _saveAuthData
INPUT: email, password
OUTPUT: Future<AuthResponse>
CHANGES STATE: SharedPreferences['auth_token'], ['user_data']
NEXT STEP: returns to AuthNotifier

FUNCTION: AuthNotifier.logout()
FILE: lib/core/providers/auth_provider.dart
CALLED BY: any logout button; ApiService.onUnauthorized callback (auto-logout on 401)
CALLS: AuthService.logout()
INPUT: —
OUTPUT: Future<void>
CHANGES STATE: authProvider = AsyncValue.data(null); SharedPreferences cleared
NEXT STEP: PosApp/MobileHomeShell rebuilds home: to LoginScreen
```

### Products

```text
FUNCTION: ProductNotifier.loadProducts({String? query, int? categoryId})
FILE: lib/features/pos/providers/product_provider.dart
CALLED BY: PosScreen.initState / MobileProductGrid init, searchProducts, filterByCategory
CALLS: ProductService.getProducts
INPUT: optional query/categoryId
OUTPUT: Future<void>
CHANGES STATE: productsProvider.products, currentPage=0, hasMore
NEXT STEP: grid widget rebuilds

FUNCTION: ProductNotifier.findByBarcode(String barcode)
FILE: lib/features/pos/providers/product_provider.dart
CALLED BY: CartNotifier.addProductByBarcode (slow path only)
CALLS: ProductService.findByBarcode
INPUT: barcode string
OUTPUT: Future<Product?>
CHANGES STATE: none (does not touch ProductState)
NEXT STEP: caller (CartNotifier) decides add/reject
```

### Cart

```text
FUNCTION: CartNotifier.addItemFromProduct(Product product)
FILE: lib/features/pos/providers/cart_provider.dart
CALLED BY: ProductCard quick-add tap
CALLS: incrementItem (if existing line) or addItem (new line)
INPUT: Product
OUTPUT: Future<void>
CHANGES STATE: cartProvider.items
NEXT STEP: badge/cart screen rebuild

FUNCTION: CartNotifier.addProductByBarcode(String barcode)
FILE: lib/features/pos/providers/cart_provider.dart
CALLED BY: MobileScanScreen._onDetect, desktop barcode TextField onSubmitted
CALLS: fast in-memory check, else ProductNotifier.findByBarcode; addItemFromProduct
INPUT: barcode string
OUTPUT: Future<BarcodeAddResult>
CHANGES STATE: cartProvider.items (if found+valid)
NEXT STEP: caller shows result.message

FUNCTION: CartNotifier.clear({bool releaseWaitingNumber = true})
FILE: lib/features/pos/providers/cart_provider.dart
CALLED BY: after successful checkout (Day 11), Hold action (Day 9), manual Clear button
CALLS: WaitingNumberService.releaseNumber (conditionally), persistCart, _syncService(clearCart)
INPUT: releaseWaitingNumber flag
OUTPUT: Future<void>
CHANGES STATE: cartProvider = CartState.initial()
NEXT STEP: all cart-watching widgets rebuild to empty
```

### Sale

```text
FUNCTION: SaleService.createSale(Map<String,dynamic> request)
FILE: lib/features/pos/services/sale_service.dart
CALLED BY: PaymentScreen/MobilePaymentScreen._submitSaleToBackend, step 1
CALLS: ApiService.post -> POST /api/pos/sales
INPUT: request map (lines, clientRef, ...)
OUTPUT: Future<SaleResponse>
CHANGES STATE: backend Sale row (DRAFT), no local state change directly
NEXT STEP: paySale (if payments present)

FUNCTION: SaleService.paySale(int saleId, List<Map> payments)
FILE: lib/features/pos/services/sale_service.dart
CALLED BY: _submitSaleToBackend, step 2
CALLS: ApiService.post -> POST /api/pos/sales/{id}/pay
INPUT: saleId, payments
OUTPUT: Future<SaleResponse>
CHANGES STATE: backend Sale row (paid), StockItem quantities, StockMovement rows
NEXT STEP: heldTicket release, waiting ticket save, cart clear
```

### Printing

```text
FUNCTION: PrintService.printReceipt(BuildContext context, int saleId)
FILE: lib/features/pos/services/print_service.dart
CALLED BY: any print button
CALLS: ApiService.get (receipt fetch), ReceiptViewModel.fromReceiptResponse,
    ThermalPrinterService.loadConfig, buildReceiptPdf + Printing.layoutPdf OR
    ThermalPrinterService.printReceipt
INPUT: context, saleId
OUTPUT: Future<bool>
CHANGES STATE: none (side effect: OS print dialog or physical print)
NEXT STEP: caller shows success/failure feedback based on the bool

FUNCTION: ThermalPrinterService.printReceipt(BuildContext, ReceiptViewModel, PrinterConfig)
FILE: lib/features/pos/services/printing/thermal_printer_service.dart
CALLED BY: PrintService.printReceipt (non-pdfDriver path)
CALLS: _transportFor (picks Network/Usb/Bluetooth), EscPosReceiptBuilder.build, transport.connect/write/disconnect
INPUT: context, receipt, config
OUTPUT: Future<void> (throws on failure)
CHANGES STATE: none (side effect: physical print)
NEXT STEP: caller's try/catch handles failure
```

### Receipts

```text
FUNCTION: ReceiptNotifier.setStatusFilter(String? status)
FILE: lib/features/pos/providers/receipt_provider.dart
CALLED BY: filter chip tap (MobileReceiptsScreen / desktop ReceiptsScreen)
CALLS: — (synchronous, local state only)
INPUT: String? status  — one of null (All), 'PAID', 'VOID', 'REFUNDED' — the raw UI filter value,
    NOT resolved through backendStatusQueryFor first
OUTPUT: void
CHANGES STATE: receiptProvider.statusFilter  (does NOT touch state.sales — independent of loadAllSales)
NEXT STEP: state.filteredSales re-derives; any widget watching receiptProvider rebuilds

FUNCTION: ReceiptNotifier.loadAllSales({String? status})
FILE: lib/features/pos/providers/receipt_provider.dart
CALLED BY: Shift/All toggle, pull-to-refresh, filter-chip handler (alongside setStatusFilter)
CALLS: SaleService.listSales(status: status) -> GET /api/pos/sales?status=
INPUT: String? status — the RESOLVED backend query value (caller must pass
    backendStatusQueryFor(uiFilter), never the raw UI filter string directly)
OUTPUT: Future<void>
CHANGES STATE: receiptProvider.sales, .loading, .error  (does NOT touch state.statusFilter)
NEXT STEP: state.filteredSales re-derives from the new state.sales + the UNCHANGED statusFilter

FUNCTION: saleMatchesStatusFilter(String saleStatus, String filterStatus)
FILE: lib/features/pos/providers/receipt_provider.dart
CALLED BY: ReceiptState.filteredSales (internally, on every access)
CALLS: — (pure function)
INPUT: a sale's actual status string, the active UI filter string
OUTPUT: bool — true if filterStatus == 'REFUNDED' and saleStatus is REFUNDED OR PARTIALLY_REFUNDED,
    else true only on an exact string match
CHANGES STATE: none (pure)
NEXT STEP: ReceiptState.filteredSales includes/excludes the sale accordingly

FUNCTION: backendStatusQueryFor(String? filterStatus)
FILE: lib/features/pos/providers/receipt_provider.dart
CALLED BY: every call site of loadAllSales (filter-chip handler, Shift/All toggle, pull-to-refresh)
CALLS: — (pure function)
INPUT: the raw UI filter string (or null for All)
OUTPUT: String? — same value for 'PAID'/'VOID'/null; ALWAYS null for 'REFUNDED' (backend can't
    express the 2-status family in one query param)
CHANGES STATE: none (pure)
NEXT STEP: its return value is passed as loadAllSales's `status` argument
```

---

## Where Should I Write Code? (recap — see the table near the top of this document for the full version)

New screen → `lib/features/pos/mobile/screens/` (or `lib/features/inventory/mobile/screens/`). New reusable widget → `lib/features/pos/mobile/widgets/`. New business state → check `providers/` first, it almost certainly already exists. New API operation → check `services/` first, same reasoning. New translated string → both `.arb` files + `flutter gen-l10n`. New printer transport → `services/printing/`, implementing `PrinterTransport`. New permission → `AndroidManifest.xml` / `Info.plist`.

## Do Not Put Code Here (recap)

No money/tax math in widgets. No direct `Dio`/`ApiService` calls from widgets — always through a service. No copying `lib/pos/` (legacy). No hand-editing generated localization files. No forking `ReceiptContent`/`ReceiptViewModel`. No platform `if` branches in provider/service/business code — only inside the 3 printer transport classes and `AppConfig.baseUrl`. No copying confirmed-dead files (`product.dart`, `product_api_service.dart`, `cart_panel_footer.dart`, `cart_footer.dart`, `status_bar.dart`).

---

## What I Will Have After Day 20

One Flutter codebase (this repo, with its already-present `android/`/`ios/` targets fully configured) buildable as:
```text
Android -> APK/AAB
iOS     -> Xcode archive / App Store build
```
sharing, unchanged, with the existing web app: the same backend and full API contract; the same `CartNotifier`/`SaleService`/`ShiftNotifier` business logic; the same inventory/production workflow rules; the same `ReceiptViewModel` and printing architecture (PDF everywhere, Network/Bluetooth/USB on native platforms); the same English/Khmer localization — with a genuinely different, phone-optimized UI built entirely by calling the functions this document traced, not by reimplementing them.

## What Still Requires Real Hardware Testing

USB thermal printer on iOS (MFi-gated, unverified — the single biggest open risk this plan surfaces); Bluetooth thermal printer pairing/mid-print-disconnect behavior on both platforms; network printer over real Wi-Fi including iOS's local-network permission prompt's real-world UX; camera barcode scan reliability under real lighting/angle conditions; the 12-hour JWT expiry's actual mid-shift UX; and cross-device screen-size coverage beyond whatever emulators/simulators you have access to.
