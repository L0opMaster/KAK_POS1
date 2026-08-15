# Day 1 — Architecture and Mapping

## Goal

Per `frontend-flutter-pos/docs/MOBILE_ANDROID_IOS_20_DAY_BUILD_PLAN.md` (its own Day 1 section, lines 176–244), Day 1 is **100% read-only study** of `frontend-flutter-pos`. No mobile code is written today. The plan's own words: *"No `mobile-flutter-pos` project exists yet — it is created Day 2. Today is 100% reading. Nothing is written to disk in either project."*

**Staleness note (verify-before-trust, per project memory):** the plan document uses the placeholder project name `mobile-flutter-pos` throughout. The real project already exists at `frontend_flutter_mobile/` (confirmed: standard `flutter create` scaffold — `android/`, `ios/`, `lib/main.dart` counter-app placeholder, default `pubspec.yaml`, nothing else). Every `mobile-flutter-pos` reference below is translated to `frontend_flutter_mobile` — the plan's own "What I Should Understand Before Day 2" section already flags this. This document also goes considerably deeper than the plan's own Day 1 (which is intentionally light — "you can reproduce the three chains from memory") because the task instructions for this session require function-level teaching detail (FILE/CLASS/FUNCTION/INPUT/CALLS/OUTPUT/STATE CHANGE/UI EFFECT/WHY) across every subsystem, not just the three headline chains.

**Files to study** (per plan) and **Definition of Done** (per plan): see the `## Definition of Done` section at the bottom — reproduced verbatim from the plan there. All files listed in the plan were read directly from current source (not assumed from the plan text) using parallel research agents; several discrepancies between the plan's assumptions and current code were found and are called out inline and in `## Problems Found`.

---

## Old Source Architecture

`frontend-flutter-pos` is a Riverpod-based Flutter app (desktop/web-first, `ConsumerWidget`/`StateNotifierProvider` pattern throughout — not the newer `AsyncNotifier`/`Notifier` API) talking to a shared Spring Boot backend (`backend-spring-boot/`). Layering is consistent across every feature:

```
Screen (ConsumerWidget/ConsumerStatefulWidget)
  ↓ ref.watch / ref.read
Provider (StateNotifierProvider<XNotifier, XState>)
  ↓ calls
Service (ApiXService, sometimes with a Local/Demo fallback)
  ↓ calls
ApiService (single shared Dio wrapper)
  ↓ HTTP
Spring Boot Controller → Service → Repository
  ↓ JSON response
Model (fromJson) → State → UI rebuild
```

This shape repeats for auth, products, cart, sales, shift, and inventory — once you understand one chain (e.g. Product), the others differ only in field names and endpoint paths, not in architecture.

---

## App Startup Flow

**[OLD/SOURCE — READ]** `frontend-flutter-pos/lib/main.dart`

### FUNCTION: `main()`
```
FILE:     frontend-flutter-pos/lib/main.dart:59-78
CLASS:    (top-level function)
FUNCTION: Future<void> main() async
INPUT:    none (entrypoint)
CALLS:    WidgetsFlutterBinding.ensureInitialized() → AppConfig.initialize() → SharedPreferences.getInstance()
          → unawaited(_prewarmPrinting()) → runApp(ProviderScope(child: PosApp()))
OUTPUT:   none (starts the widget tree)
STATE CHANGE: none directly — creates the ProviderScope container that all providers live inside
UI EFFECT: mounts PosApp as the root widget
SOURCE OR TARGET: OLD/SOURCE
WHY: order matters — Flutter bindings must exist before anything touches platform channels;
     SharedPreferences is pre-warmed so the very next thing PosApp does (reading authProvider,
     which synchronously checks a cached token) doesn't stall on first disk I/O; printing fonts
     are pre-warmed but fire-and-forget (wrapped in try/catch) so a failure there never blocks boot.
```
Exact body:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  await SharedPreferences.getInstance();
  unawaited(_prewarmPrinting());
  runApp(const ProviderScope(child: PosApp()));
}
```
`AppConfig.initialize()` (`app_config.dart:105`) is a **literal no-op today** — `static Future<void> initialize() async {}`. `_prewarmPrinting()` (`main.dart:80-89`) awaits `KhmerPdfFont.loadTheme()` + `CapabilityProfile.load()` inside try/catch — printing must still work on-demand even if this prewarm fails.

### FUNCTION: `PosApp.build`
```
FILE:     frontend-flutter-pos/lib/main.dart:91-230
CLASS:    PosApp extends ConsumerWidget
FUNCTION: Widget build(BuildContext context, WidgetRef ref)
INPUT:    BuildContext, WidgetRef
CALLS:    ref.watch(authProvider) → ApiService.onUnauthorized assignment → PosTheme.applyMainColor(ref.watch(mainColorProvider))
          → ref.watch(appLanguageProvider) → MaterialApp(...)
OUTPUT:   MaterialApp widget
STATE CHANGE: none in PosApp itself, but re-assigns the static ApiService.onUnauthorized callback on every rebuild
UI EFFECT: rebuilds the entire MaterialApp (theme, locale, home) whenever authProvider, mainColorProvider,
           themeModeProvider, or appLanguageProvider change
SOURCE OR TARGET: OLD/SOURCE
WHY: this one function is the single decision point for both "which screen is home" and "how every
     screen reaches the network" (via the onUnauthorized wiring) — everything else in the app traces
     back to it.
```
Body (condensed to the decision-relevant lines):
```dart
Widget build(final BuildContext context, final WidgetRef ref) {
  final authState = ref.watch(authProvider);
  ApiService.onUnauthorized = () => ref.read(authProvider.notifier).logout();
  PosTheme.applyMainColor(ref.watch(mainColorProvider));
  final isKhmer = ref.watch(appLanguageProvider).isKhmer;
  return MaterialApp(
    title: AppConfig.appName,
    debugShowCheckedModeBanner: false,
    theme: PosTheme.lightTheme,
    darkTheme: PosTheme.darkTheme,
    themeMode: ref.watch(themeModeProvider).value,
    locale: ref.watch(appLanguageProvider).toLocale(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: khmerAwareTextScaler(MediaQuery.of(context).textScaler, isKhmer: isKhmer),
      ),
      child: child!,
    ),
    supportedLocales: const [Locale('en'), Locale('km')],
    localizationsDelegates: const [
      AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
    ],
    routes: <String, WidgetBuilder>{ /* 40 entries, listed below */ },
    home: authState.maybeWhen(
      data: (final User? user) => user != null ? const PosScreen() : const LoginScreen(),
      orElse: () => const LoginScreen(),
    ),
  );
}
```
`authState` is `AsyncValue<User?>`. Only the `data` case is handled explicitly; `loading`/`error` both fall through `orElse` to `LoginScreen()` — **there is no loading spinner branch**, which is a deliberate simplification worth knowing before building the mobile equivalent (a mobile splash/loading screen is a reasonable improvement, not a requirement).

Full 40-key `routes` map (path strings only): `/login`, `/pos`, `/settings`, `/pos-settings`, `/customers`, `/add-customer`, `/open-tickets`, `/receipts`, `/shifts`, `/shift-history`, `/tables`, `/add-table`, `/items`, `/add-item`, `/categories`, `/modifiers`, `/create-modifier`, `/units`, `/inventory`, `/purchase-orders`, `/transfer-orders`, `/stock-adjustments`, `/inventory-counts`, `/productions`, `/suppliers`, `/inventory-history`, `/inventory-valuation`, `/reports`, `/report-sales-summary`, `/report-sales-by-item`, `/report-sales-by-category`, `/report-sales-by-employee`, `/report-sales-by-payment-type`, `/report-receipts`, `/report-sales-by-modifier`, `/report-discounts`, `/report-taxes`, `/employeelist`, `/useraccount`, `/accessRole`, `/permission`.

### Flow diagram
```
main()
↓ WidgetsFlutterBinding → AppConfig.initialize() (no-op) → SharedPreferences prewarm → printing prewarm (fire-and-forget)
↓
ProviderScope
↓
PosApp.build(context, ref)
↓
authProvider (AsyncValue<User?>)  +  ApiService.onUnauthorized wiring  +  mainColorProvider → PosTheme.applyMainColor  +  appLanguageProvider → khmerAwareTextScaler
↓
MaterialApp(theme, darkTheme, themeMode, locale, supportedLocales, localizationsDelegates, routes, home)
↓
home: authState.maybeWhen(data: user!=null ? PosScreen : LoginScreen, orElse: LoginScreen)
↓
Login/POS
```

### **[NEW/MOBILE]** target: `frontend_flutter_mobile/lib/main.dart`

Currently the unmodified `flutter create` default counter app (`MyApp extends StatelessWidget`) — confirmed by direct read. **Do not touch it today** (Day 1 writes no code); this is the target shape for Day 4/5 per the task's own scope boundary ("products/cart/screens belong to later days").

Classification for the eventual rewrite:
- **RECREATE (not copy)**: the `main()` init order and the `MaterialApp` skeleton (theme/locale/localizationsDelegates/builder wiring) — same *shape*, but `routes:` will only contain mobile screens that exist as each day builds them, not all 40 at once.
- **COPY/ADAPT nearly exactly**: `ApiService.onUnauthorized` wiring pattern, `PosTheme.applyMainColor` call, `khmerAwareTextScaler` MediaQuery builder — these are pure Riverpod/business-logic glue with no platform dependency.
- **MOBILE-SPECIFIC**: `home:` will eventually point at a `MobileHomeShell`/bottom-nav shell (Day 5) rather than the desktop `PosScreen` directly — this is new, not a port.

---

## API Flow

**[OLD/SOURCE — READ]**

### `frontend-flutter-pos/lib/core/config/app_config.dart`
```
FILE:     frontend-flutter-pos/lib/core/config/app_config.dart
CLASS:    AppConfig (static-only bag, `// ignore: avoid_classes_with_only_static_members`)
```
Key fields: `enableHeldTicketSync = kDebugMode`, `useApiCartService = true` (online-first), `useApiTableService = kDebugMode`, `appName = 'KAKNNEA'`, `authTokenKey = 'auth_token'`, `userKey = 'user_data'`, `cartKey = 'cart_items'`, `defaultStoreId = 1`, `defaultTerminalId = 'T1'`.

### FUNCTION: `AppConfig.baseUrl` (getter)
```
FILE:     frontend-flutter-pos/lib/core/config/app_config.dart:66-73
CLASS:    AppConfig
FUNCTION: static String get baseUrl
INPUT:    none — reads kIsWeb / defaultTargetPlatform
CALLS:    nothing external
OUTPUT:   a base URL string
STATE CHANGE: none
UI EFFECT: none directly — feeds ApiService's Dio baseUrl
SOURCE OR TARGET: OLD/SOURCE
WHY: lets one codebase target the right backend host across web, Android emulator, and iOS
     simulator/desktop without a build-time flag.
```
```dart
static String get baseUrl {
  if (kIsWeb) return 'http://localhost:8081';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8081'; // Android Emulator host access
  }
  return 'http://localhost:8081'; // iOS Simulator / Desktop
}
```
**Important gap for the mobile port**: this branches on `defaultTargetPlatform`, not `Platform.isAndroid`, and has **no physical-device branch** — a real Android phone still resolves `TargetPlatform.android` → `10.0.2.2`, which is only valid inside the emulator's virtual NIC and will fail on a real device against a LAN backend. `AppConfig.initialize()` (`:105`) is a literal no-op today. This getter is exactly what Day 4's mobile-specific base-URL logic (real device vs emulator vs simulator) needs to extend, not just copy.

### `frontend-flutter-pos/lib/core/services/api_service.dart`

```
FILE:     frontend-flutter-pos/lib/core/services/api_service.dart
CLASS:    ApiService (instance-based: `final ApiService apiService = ApiService();` module singleton
          + `apiServiceProvider` Riverpod Provider wrapping it)
```

### FUNCTION: `ApiService()` constructor + `_createDioOptions`/`_setupInterceptors`
```
FILE:     api_service.dart:62-137
CALLS:    Dio(_createDioOptions()) → _setupInterceptors()
STATE CHANGE: none (Dio client is created once, reused for the app's lifetime)
WHY: centralizes baseUrl/timeouts/headers and auth/logging behavior in one place so every
     feature service shares identical network behavior.
```
```dart
static BaseOptions _createDioOptions() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    );
```
Two interceptors added in `_setupInterceptors()`:
1. **Auth interceptor** (`:80-105`): on every request, reads the cached token (`_getAuthToken()`, from SharedPreferences key `auth_token`) and stamps `Authorization: Bearer $token`. On error, if `statusCode == 401`, clears the token and calls `onUnauthorized?.call()`.
2. **Debug logging interceptor** (`kDebugMode`-guarded, `:110-135`): logs method/path/status/elapsed-ms only — explicitly never logs headers or bodies (comment notes this used to leak passwords/tokens into device logs).

### FUNCTION: `ApiService.get/post/put/patch/delete`
```
FILE:     api_service.dart:44-217
FUNCTION: Future<T> get<T>(path, {queryParameters, fromJson}) / post / put / patch / delete — same shape
INPUT:    path string, optional body/query, optional fromJson mapper
CALLS:    _dio.<verb>(...) inside try/on DioException catch (e) { throw _handleError(e); }
OUTPUT:   T (via fromJson(response.data) if provided, else response.data as T)
STATE CHANGE: none (stateless per-call)
SOURCE OR TARGET: OLD/SOURCE
WHY: one funnel for every HTTP call in the app — every feature service (auth, product, cart,
     sale, shift, inventory) goes through exactly these five methods, never touches Dio directly.
```

### FUNCTION: `ApiService._handleError` / `onUnauthorized`
```
FILE:     api_service.dart:141, 246-284
CALLS:    _extractMessage(data) to pull a `message` field out of error JSON bodies
OUTPUT:   throws ApiException(message, statusCode)
WHY: 401 is handled TWICE — once in the interceptor (clears token, fires the static
     onUnauthorized callback set by PosApp.build), once again here (maps the same DioException
     to a friendly ApiException the calling widget's try/catch actually sees). Both fire on the
     same 401; the interceptor doesn't stop propagation.
```
Status → message map: `400`→bad request, `401`→unauthorized, `403`→forbidden, `404`→not found, `409`→conflict, `422`→validation error, `500`→server error, else→generic; no-response errors branch on `DioExceptionType` (timeout variants, cancel, network error).

### Example feature-service call chain
```
Feature Service (e.g. ProductService.getProducts)
↓
ApiService.get('/api/products/pos-catalog')
↓
Dio.get(...)  [baseUrl=AppConfig.apiBaseUrl, Authorization header auto-attached]
↓
Spring API (ProductController)
↓
response (JSON)
↓
model (Product.fromJson per item)
```

### **[NEW/MOBILE]** target
`frontend_flutter_mobile/lib/core/config/app_config.dart`, `frontend_flutter_mobile/lib/core/services/api_service.dart` — **do not create today** (Day 1 scope), but documented target destinations. Classification: `ApiService`'s interceptor/error-handling logic is **COPY/ADAPT nearly exactly**; `AppConfig.baseUrl`'s platform branch is **RECREATE USING SAME LOGIC** (must be extended with real-device handling, which the source app never needed).

---

## Authentication Flow

**[OLD/SOURCE — READ]**
- `frontend-flutter-pos/lib/core/services/auth_service.dart`
- `frontend-flutter-pos/lib/core/providers/auth_provider.dart`
- `frontend-flutter-pos/lib/features/auth/screens/login_screen.dart`
- `frontend-flutter-pos/lib/core/models/auth_models.dart`

**[SHARED BACKEND — READ]**
- `backend-spring-boot/src/main/java/com/kaknnea/pos/controller/AuthController.java`
- `backend-spring-boot/src/main/java/com/kaknnea/pos/service/AuthService.java`
- `backend-spring-boot/src/main/java/com/kaknnea/pos/security/JwtUtil.java`
- `backend-spring-boot/src/main/java/com/kaknnea/pos/dto/AuthDtos.java`

### FUNCTION: `_LoginScreenState._login`
```
FILE:     login_screen.dart:30-48
CLASS:    _LoginScreenState
FUNCTION: Future<void> _login()
INPUT:    form field values (email, password) via _formKey
CALLS:    ref.read(authProvider.notifier).login(email, password)
OUTPUT:   none (side-effecting)
STATE CHANGE: triggers AuthNotifier.state transitions (loading → data/error)
UI EFFECT: on success, Navigator.pushReplacementNamed('/pos'); on error, SnackBar
SOURCE OR TARGET: OLD/SOURCE
WHY: the only place the login button's tap becomes a provider call; also fires on password-field
     submit (onFieldSubmitted), not just button tap.
```
Button wiring: `ElevatedButton(onPressed: authState.isLoading ? null : _login, ...)` — `authState = ref.watch(authProvider)` disables the button and can swap in a spinner while `AsyncValue.loading()`. Note: `terminalId` is commented out in this screen — modeled end-to-end in the model/service/backend but unused in the actual login UI today.

### FUNCTION: `AuthNotifier.login`
```
FILE:     auth_provider.dart:34-47
CLASS:    AuthNotifier extends StateNotifier<AsyncValue<User?>>
FUNCTION: Future<void> login(String email, String password, {String? terminalId})
INPUT:    email, password
CALLS:    AuthService.login(...)
OUTPUT:   none — result lives in `state`
STATE CHANGE: state = AsyncValue.loading() → AsyncValue.data(user) | AsyncValue.error(e, st)
UI EFFECT: any widget watching authProvider rebuilds (PosApp's home:, login screen's button)
SOURCE OR TARGET: OLD/SOURCE
WHY: the provider type is StateNotifierProvider (older Riverpod API), not AsyncNotifier — worth
     knowing since a mobile rewrite might reasonably modernize this, but must preserve the exact
     state-machine semantics (loading/data/error → screen routing).
```
Notable: `AuthNotifier`'s constructor eagerly runs `_initializeAuth()` (`:8-32`), which locally decodes the cached JWT's `exp` claim (`isJwtExpired`, `core/utils/jwt_utils.dart`) **before** trusting a cached "logged in" session — an expired cached token forces `state = AsyncValue.data(null)` rather than booting straight into `PosScreen` with a dead token. This is a subtlety a naive port could easily drop.

### FUNCTION: `AuthService.login`
```
FILE:     auth_service.dart:24-39
CLASS:    AuthService
FUNCTION: Future<AuthResponse> login(String email, String password, {String? terminalId})
INPUT:    email, password, optional terminalId
CALLS:    ApiService.post('/api/auth/login', data: LoginRequest(...).toJson())
          → AuthResponse.fromJson(response) → _saveAuthData(authResponse)
OUTPUT:   AuthResponse{token, user}
STATE CHANGE: writes SharedPreferences keys 'auth_token' and 'user_data' (plain SharedPreferences,
              NOT flutter_secure_storage)
SOURCE OR TARGET: OLD/SOURCE
WHY: token is persisted to disk here so ApiService's interceptor can read it fresh on every
     subsequent request without threading it through Riverpod state.
```

### Full chain (verified real names)
```
Login button (login_screen.dart ElevatedButton, disabled while authState.isLoading)
↓
_LoginScreenState._login()
↓
AuthNotifier.login(email, password)                         [auth_provider.dart:34]
↓
AuthService.login()                                          [auth_service.dart:24]
↓
ApiService.post('/api/auth/login', data: LoginRequest.toJson())
↓
POST /api/auth/login
↓
AuthController.login(@RequestBody LoginRequest, HttpServletRequest)   [AuthController.java:21]
↓
AuthService.login(request, ip, userAgent)   [backend, AuthService.java:47]
  - userRepository.findByEmail → passwordEncoder.matches → lockout after 5 failed attempts (15 min)
  - OWNER/ADMIN/SYSTEM_ADMIN roles get ALL permissions injected regardless of assigned role
  - device upsert keyed by terminalId; every attempt (success or fail) logged to LoginAuditRepository
↓
JwtUtil.generateToken(email, roles, permissions)   [JwtUtil.java:30] → HS256, exp from app.jwt.access-token-minutes
↓
AuthDtos.LoginResponse{token, user:{id,email,fullName,roles,permissions}}
↓
AuthResponse.fromJson(response)   [auth_models.dart]
↓
AuthService._saveAuthData()  → SharedPreferences['auth_token'], SharedPreferences['user_data']
↓
AuthNotifier.state = AsyncValue.data(user)
↓
UI: login_screen rebuild (button re-enabled/spinner gone) → Navigator.pushReplacementNamed('/pos')
    → PosApp's home: re-evaluates authState → PosScreen
```

### auth_models.dart field lists (exact, matches backend DTO field-for-field, no JSON key renaming)
```dart
class User { final int id; final String email; final String fullName;
             final List<String> roles; final List<String>? permissions; }
class AuthResponse { final String token; final User user; }
class LoginRequest { final String email; final String password; final String? terminalId; }
```

### Notable deviations worth flagging before porting
1. **No secure storage** — token/user live in plain `SharedPreferences`, not `flutter_secure_storage`. Worth a deliberate decision (not silent copy) for the mobile port given phones are more loss/theft-prone than a till.
2. **Global 401 handling lives in `ApiService`**, decoupled from `AuthService`/`AuthNotifier` — wired once in `PosApp.build` via the static `ApiService.onUnauthorized` callback.
3. **Backend does real security logic** (lockout, audit log, permission escalation for privileged roles) — this must NOT be reinvented client-side; the mobile app calls the exact same shared endpoint and gets the exact same guarantees for free.

### **[NEW/MOBILE]** target
`frontend_flutter_mobile/lib/core/services/auth_service.dart`, `.../core/providers/auth_provider.dart`, `.../core/models/auth_models.dart`, `.../features/auth/screens/mobile_login_screen.dart` (new name — desktop `login_screen.dart` layout is reference-only, not copied). Classification: `AuthNotifier`/`AuthService`/models — **COPY/ADAPT nearly exactly**; `MobileLoginScreen` — **MOBILE UI REIMPLEMENT** (Day 4 scope, not today).

---

## Product Flow

**[OLD/SOURCE — READ]**
- `frontend-flutter-pos/lib/features/pos/models/product_models.dart`
- `frontend-flutter-pos/lib/features/pos/providers/product_provider.dart`
- `frontend-flutter-pos/lib/features/pos/services/product_service.dart` (+ `demo_product_service.dart`)
- `frontend-flutter-pos/lib/features/pos/widgets/product_grid.dart`

`Product` model (`product_models.dart:38-276`) carries ~25 fields matching the backend `ProductResponse` DTO exactly (id, sku, barcode, nameEn/nameKm, price, cost, stock, trackInventory, lowStockThreshold, category refs, unit refs, modifierGroups, etc).

### FUNCTION: `ProductNotifier.loadProducts`
```
FILE:     product_provider.dart:68-99
CLASS:    ProductNotifier extends StateNotifier<ProductState>
FUNCTION: Future<void> loadProducts({String? query, int? categoryId})
INPUT:    optional search query, optional category filter
CALLS:    ProductService.getProducts(query, categoryId, page:0, size:48)
OUTPUT:   none — result lives in state
STATE CHANGE: state.products replaced wholesale; isLoading/hasMore/currentPage/totalCount updated
UI EFFECT: ProductGrid (parent-passed data) rebuilds with the new list
SOURCE OR TARGET: OLD/SOURCE
WHY: resets pagination (`currentPage:0`) any time the filter changes — full reload, not append.
```
```dart
Future<void> loadProducts({String? query, int? categoryId}) async {
  _currentQuery = query; _currentCategoryId = categoryId;
  state = state.copyWith(isLoading: true, error: null, currentPage: 0, hasMore: true);
  try {
    final list = await _service.getProducts(query: query, categoryId: categoryId, page: 0, size: _pageSize);
    state = state.copyWith(products: List.of(list), isLoading: false,
        hasMore: list.length >= _pageSize, currentPage: 0, totalCount: list.length);
  } catch (e, st) { state = state.copyWith(isLoading: false, error: e.toString()); }
}
```

### FUNCTION: `ProductNotifier.searchProducts` / `filterByCategory` / `loadMore` / `findByBarcode`
```
FILE:     product_provider.dart:102-143
```
- `searchProducts(query)` (`:129-131`) — thin wrapper: `loadProducts(query: query.isEmpty ? null : query)` (clearing search also clears category, since categoryId isn't passed).
- `filterByCategory(categoryId)` (`:140-143`) — thin wrapper: `loadProducts(categoryId: categoryId)` (drops any active query).
- `loadMore()` (`:102-126`) — **appends** (not replaces) using stored `_currentQuery`/`_currentCategoryId`, guarded by `isLoadingMore`/`hasMore` to prevent duplicate/unneeded fetches.
- `findByBarcode(barcode)` (`:133-138`) — pure passthrough to `_service.findByBarcode`, **does not touch state at all** (so a barcode scan doesn't disturb the visible grid).

### FUNCTION: `ApiProductService.getProducts`
```
FILE:     product_service.dart:67-96
CALLS:    if no query/category → GET /api/products/pos-catalog (flat unpaginated list)
          else → GET /api/products?q=&categoryId=&page=&size= (paginated, reads resp['content'])
```
**Fallback path**: `productServiceProvider` wraps `ApiProductService` + `DemoProductService` inside `_FallbackProductService` (`demo_product_service.dart:228-308`) — every method tries the real API first and **silently falls back to in-memory demo data on any exception**, so the POS screen always works even fully offline/backend-down.

### `product_grid.dart` — column count
`static const int _fixedColumns = 5;` (line 37) — **fixed, not responsive**. `ProductGrid` doesn't watch `productsProvider` itself (parent passes `products`/`hasMore`/`isLoadingMore` down); it does `ref.watch(cartProvider)` per cell to show a cart-quantity badge. Tap → `cartProvider.notifier.addItemFromProduct(product)` directly (Loyverse-style instant add, no modifier prompt); long-press → modifier/edit flow.

### Flow diagram
```
Product UI (POS screen watches productsProvider, passes state into ProductGrid)
↓
productsProvider  (StateNotifierProvider<ProductNotifier, ProductState>)
↓
ProductNotifier.loadProducts / loadMore / searchProducts / filterByCategory / findByBarcode
↓
ProductService (_FallbackProductService: ApiProductService, else DemoProductService on any failure)
↓
ApiService.get(...)
↓
backend (GET /api/products/pos-catalog | GET /api/products?...)
↓
ProductState (products, isLoading, isLoadingMore, hasMore, currentPage, totalCount, error)
↓
UI rebuild (ProductGrid — fixed 5-column grid; ProductCard cells independently rebuild on cart changes)
```

### **[NEW/MOBILE]** target
`frontend_flutter_mobile/lib/features/pos/models/product_models.dart`, `.../providers/product_provider.dart`, `.../services/product_service.dart`, `.../widgets/mobile_product_grid.dart` (responsive columns — mobile screens are narrower than the desktop 5-column layout assumes). Classification: model/provider/service — **COPY/ADAPT nearly exactly**; grid widget — **MOBILE UI REIMPLEMENT** (responsive column count is new work, Day 6 scope).

---

## Cart Flow

**[OLD/SOURCE — READ]**
- `frontend-flutter-pos/lib/features/pos/models/cart_models.dart`
- `frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart`
- `frontend-flutter-pos/lib/features/pos/services/cart_service.dart`

`CartState` fields: `items, discount, discountType, loyalty, loading, orderMode, taxRate (default 0.08), customerId, tableId, waitingNumber, heldTicketId`. Two independent persistence layers exist:
- **OFFLINE UI cache**: `persistCart()`/`restoreCart()` — full `CartState` JSON snapshot in SharedPreferences key `cart_state_v2`, always active regardless of backend availability.
- **ONLINE sync (switch point)**: `service.saveCartItems/getCartItems/clearCart` — `ApiCartService` if `AppConfig.useApiCartService` (default `true`), else `LocalCartService`.

### Mutator flow table (state before → function → state after → persistence/sync → UI rebuild)

```
addItemFromProduct(product) → existing line? incrementItem : new CartItem(id, product, qty:1) → addItem(item)
  → items append, waitingNumber issued if this is the first item
  → persistCart() [SharedPrefs 'cart_state_v2'] + _syncService→saveCartItems [ApiCartService: delete+recreate
    cart then POST each item, or LocalCartService: SharedPrefs 'cart_items']
  → cart panel + ProductGrid cartQty badges rebuild

removeItem(id) → item filtered out of items → persistCart + sync → cart panel rebuild

incrementItem(id) → item.copyWith(qty: qty+1) → persistCart + sync → cart line + totals rebuild

decrementItem(id) → qty<=1 ? delegates to removeItem : item.copyWith(qty: qty-1) → persistCart + sync
  → cart line + totals rebuild

setItemQuantity(id, qty) → qty<=0 ? removeItem : item.copyWith(qty) → persistCart + sync → rebuild

setItemModifiers/setItemNote/setItemDiscount(id, ...) → item field replaced → persistCart + sync → rebuild

restoreItems({items, waitingNumber, heldTicketId, tableId}) → CartState replaced wholesale (used when
  resuming a held ticket) → persistCart + sync → full cart panel rebuild

clear({releaseWaitingNumber:true}) → waiting number released (best-effort) → state = CartState.initial()
  (reset BEFORE sync, so a network failure can't leave a stale persisted snapshot)
  → persistCart + _syncService→clearCart [DELETE /api/carts/{id} or prefs.remove] → cart panel empties

applyDiscount/clearDiscount/setOrderMode/setTaxRate/setCustomer/clearCustomer/setTable/clearTable
  → corresponding state field set → persistCart() ONLY, no service sync (these are cart-level,
    not line-item, and CartService's contract only covers items) → relevant chip/totals UI rebuilds

applyLoyalty/clearLoyalty → loyalty field set → NEITHER persistCart NOR service sync
  (lost on app restart — a documented gap in current behavior, not a bug to silently fix)
```

### FUNCTION: `CartNotifier.addItemFromProduct` (representative example)
```
FILE:     cart_provider.dart:381-400 (delegates into addItem, 495-521)
CLASS:    CartNotifier extends StateNotifier<CartState>
INPUT:    Product
CALLS:    incrementItem(existing.id) if already in cart, else waitingNumberService.issueNumber()
          (only if this is the first item) then addItem(newItem) → persistCart() → service.saveCartItems()
OUTPUT:   none
STATE CHANGE: state.items (+1 line or qty+1), state.waitingNumber (issued once)
UI EFFECT: cart panel line list, totals, ProductGrid cart-qty badge
SOURCE OR TARGET: OLD/SOURCE
WHY: instant-add UX (Loyverse-style) — no modifier prompt on tap; long-press is the separate
     modifier-entry path.
```

### `CartService` — is backend Cart connected to Sale?

**No — confirmed fully separate.** Backend `CartService.completeCart(cartId)` only flips `Cart.status` to `COMPLETED`; it never touches `Sale`/`SaleRepository`. The live checkout path (`PaymentScreen._submitSaleToBackend`) **never calls** `/api/carts/{id}/checkout` — it reads a `CartState` snapshot directly from `cartProvider`, builds its own JSON request, and posts straight to `SaleService.createSale`, entirely bypassing the backend `Cart` entity. `ApiCartService` therefore exists purely as a cross-device/cross-restart mirror of the in-app cart, not as part of the checkout write path. Treat this as pure background persistence in the mobile port — **do not rewrite cart calculation or sync logic differently.**

### **[NEW/MOBILE]** target
`frontend_flutter_mobile/lib/features/pos/models/cart_models.dart`, `.../providers/cart_provider.dart`, `.../services/cart_service.dart` — **COPY/ADAPT nearly exactly**, mutator-for-mutator, including the two-layer persistence split.

---

## Sale → Receipt Flow

**[OLD/SOURCE — READ]**
- `frontend-flutter-pos/lib/features/pos/screens/payment_screen.dart`
- `frontend-flutter-pos/lib/features/pos/services/sale_service.dart`
- `frontend-flutter-pos/lib/features/pos/services/printing/receipt_view_model.dart`
- `frontend-flutter-pos/lib/features/pos/widgets/receipt_paper_view.dart`
- `frontend-flutter-pos/lib/features/pos/services/print_service.dart`

### FUNCTION: `_PaymentScreenState._submitSaleToBackend`
```
FILE:     payment_screen.dart:566-715
CLASS:    _PaymentScreenState
FUNCTION: Future<void> _submitSaleToBackend()
INPUT:    none (reads widget/cart state)
CALLS:    SaleService.createSale(request) → (if payments) SaleService.paySale(saleId, payments)
          → (unawaited) _fetchCompletedReceipt(saleId) → _autoPrintIfEnabled(context, saleId)
OUTPUT:   none — drives PaymentState (completed/failed)
STATE CHANGE: cartProvider.notifier.clear(releaseWaitingNumber:false); heldTicketProvider release;
              local PaymentState flips to completed/failed
UI EFFECT: success screen with receipt preview; failure SnackBar with a Retry action reusing the
           same idempotency key
SOURCE OR TARGET: OLD/SOURCE
WHY: idempotency key `_clientRef` (a `const Uuid().v4()` generated ONCE per PaymentScreen instance,
     not per attempt) lets a retry after a timeout reuse the same key so the backend
     (SaleService.findByClientRef) returns the existing sale instead of creating a duplicate —
     this is the single most important correctness property to preserve exactly in the mobile port.
```
Request body: `{lines, clientRef, customerId?, tableId?, orderMode, payments?, taxRate, invoiceDiscount?}`. Snapshots the cart before submission because a successful sale clears it.

### FUNCTION: `SaleService` endpoints (exact)
```
FILE: sale_service.dart
createSale(request)                          → POST /api/pos/sales                    (:122)
paySale(saleId, payments)                    → POST /api/pos/sales/{id}/pay            (:128)
getSale(saleId)                              → GET  /api/pos/sales/{id}                (:135)
getReceipt(saleId)                           → GET  /api/pos/sales/{id}/receipt        (:141)
getActiveShiftSales({status:'PAID'})         → GET  /api/pos/sales/active-shift?status= (:146)
refundSale(saleId, {amount, method, reason, managerEmail, managerPassword})
                                              → POST /api/pos/sales/{id}/refund         (:159)
listSales({query, status})                   → GET  /api/pos/sales?query=&status=      (:179)
```

### FUNCTION: `ReceiptViewModel.fromReceiptResponse` / `.fromCart`
```
FILE:     receipt_view_model.dart:208-266, 271-341
CLASS:    ReceiptViewModel
INPUT:    ReceiptResponse (backend-persisted) or a live CartState (pre-backend-confirm preview)
OUTPUT:   ReceiptViewModel — the single formatted/localized source of truth every renderer reads
STATE CHANGE: none (pure data transform)
WHY: two factories exist because the immediate post-sale UI needs a receipt preview before the
     background getReceipt() fetch necessarily completes — fromCart covers that gap, fromReceiptResponse
     is authoritative once the backend confirms.
```
`ReceiptContent` (`receipt_paper_view.dart:57`, `kReceiptContentWidth = 300`) is genuinely the same shared widget for on-screen preview AND the Khmer-bitmap rasterization path used by both PDF and thermal ESC/POS output (via `ReceiptBitmapRenderer`) — this is the architectural guarantee that keeps a printed Khmer receipt from structurally drifting from what the cashier previewed. The plain-Latin PDF/ESC-POS text paths are separately-coded renderers reading the *same* `ReceiptViewModel` data, not the same widget tree.

### Full chain (verified names)
```
Cart (CartState via cartProvider)
↓
Charge → PaymentScreen._chargeCash() / _payFullAmount()
↓
Payment → PaymentScreen._submitSaleToBackend()   [stable _clientRef UUID generated once]
↓
createSale → SaleService.createSale(request) → POST /api/pos/sales
↓
paySale → SaleService.paySale(saleId, payments) → POST /api/pos/sales/{id}/pay  (only if payments present)
↓
backend (recomputes tax/discount/total server-side — client never trusts its own math for the record)
↓ (background, unawaited) _fetchCompletedReceipt(saleId) → SaleService.getReceipt(saleId) → GET .../receipt
↓
ReceiptResponse → ReceiptViewModel.fromReceiptResponse(r, language, l10n)
↓
ReceiptContent (shared widget, kReceiptContentWidth=300)
↓
Preview / Print (ReceiptPaperView on-screen | PrintService.buildReceiptPdf | ThermalPrinterService.printReceipt)
```

### **[NEW/MOBILE]** target
`frontend_flutter_mobile/lib/features/pos/screens/mobile_payment_screen.dart` (**MOBILE UI REIMPLEMENT** — desktop 2-column layout doesn't fit a phone, but `_submitSaleToBackend`'s logic, including the idempotency key, is **COPY/ADAPT nearly exactly**), `.../services/sale_service.dart`, `.../services/printing/receipt_view_model.dart`, `.../widgets/receipt_paper_view.dart` — all **COPY/ADAPT nearly exactly**.

---

## Printing Flow

**[OLD/SOURCE — READ]** — all under `frontend-flutter-pos/lib/features/pos/services/printing/` unless noted.

| Class | File | Classification |
|---|---|---|
| `ReceiptViewModel` | `printing/receipt_view_model.dart:79` | **SHARED** — pure Dart, zero platform deps |
| `PrintService` | `services/print_service.dart:42` | **ADAPT** — own logic portable; `Printing.layoutPdf` (package:printing) already handles Android/iOS internally |
| `PrinterConfig`/`PrinterPaperSize`/`PrinterTransportType` | `printing/printer_profile.dart:6,21,29` | **SHARED** — pure data/enum + JSON |
| `ThermalPrinterService` | `printing/thermal_printer_service.dart:22` | **ADAPT** — orchestration portable, but is the seam where a mobile permission-check gate must be added in front of bluetooth/usb branches |
| `EscPosReceiptBuilder` | `printing/escpos_receipt_builder.dart:19` | **SHARED** — pure Dart byte builder (`esc_pos_utils_plus`) |
| `ReceiptBitmapRenderer` | `printing/receipt_bitmap_renderer.dart:39` | **SHARED** — uses only dart:ui/flutter/image, no platform channel |
| `PrinterTransport` (interface) | `printing/printer_transport.dart:4` | **SHARED** — abstract contract, zero deps |
| `NetworkPrinterTransport` | `printing/network_printer_transport.dart:8` | **PLATFORM INFRASTRUCTURE**, but favorable — `dart:io Socket` works natively on Android/iOS (unlike Web, where it throws at runtime, per [[project_printer_web_runtime_limits]]); iOS needs a new `NSLocalNetworkUsageDescription` Info.plist key that doesn't exist in source today |
| `UsbPrinterTransport` | `printing/usb_printer_transport.dart:7` | **PLATFORM INFRASTRUCTURE** — Android-viable (USB host mode); iOS is MFi-certification-gated and effectively unverified for generic printers |
| `BluetoothPrinterTransport` | `printing/bluetooth_printer_transport.dart:7` | **PLATFORM INFRASTRUCTURE**, highest iOS risk — wraps an Android-first classic-Bluetooth (SPP) plugin; iOS's public API doesn't expose classic BT outside MFi `ExternalAccessory` |
| `A4ReportPdf` | `core/services/printing/a4_report_pdf.dart:23` | **SHARED** — separate parallel pipeline (Reports/Inventory), doesn't go through ReceiptViewModel at all |
| `KhmerPdfFont` | `printing/khmer_pdf_font.dart:47` (note: **not** under `core/`, despite the plan doc's assumption) | **SHARED** — loads NotoSans + NotoSansKhmer as fallback-only |
| `KhmerTextRasterizer` | `core/services/printing/khmer_text_rasterizer.dart:36` | **SHARED** — per-string rasterizer (A4 reports), simpler than ReceiptBitmapRenderer (no Overlay/BuildContext needed) |

**Cross-cutting gap found in source, not just docs**: `frontend-flutter-pos/lib/` has zero `permission_handler` imports, and `AndroidManifest.xml`/`Info.plist` declare no Bluetooth/USB/local-network permission keys today. The transport *code* is portable; the permission-request layer in front of it is genuinely new work for the mobile port (owned by Days 15–16 per scope boundaries — **do not build it now**).

### Flow diagram
```
ReceiptViewModel (single source of truth)
↓
PrintService.printReceipt() → loads PrinterConfig.transportType
↓
┌─ pdfDriver → PrintService.buildReceiptPdf() → containsKhmer? ReceiptBitmapRenderer : native pw.Text
│               → Printing.layoutPdf() (OS print dialog / share sheet)
└─ bluetooth/usb/network → ThermalPrinterService.printReceipt() → _transportFor(config)
                              → BluetoothPrinterTransport | UsbPrinterTransport | NetworkPrinterTransport
                              → bytes from EscPosReceiptBuilder.build() (containsKhmer? ReceiptBitmapRenderer.render : native ESC/POS text)
                              → transport.write(bytes) → transport.disconnect()
                              → physical printer
```
`A4ReportPdf` is a separate parallel pipeline for Reports/Inventory (KhmerTextRasterizer + package:pdf directly, never touches ReceiptViewModel).

### **[NEW/MOBILE]** target
All SHARED classes above — **COPY/ADAPT nearly exactly** (same relative path under `frontend_flutter_mobile/lib/features/pos/services/printing/`). PLATFORM INFRASTRUCTURE transports — **ADAPT**, with permission-gating added later (Days 15–16), not today.

---

## Shift Flow

| SCREEN | PROVIDER | SERVICE | MODEL | API |
|---|---|---|---|---|
| `features/pos/screens/shift_screen.dart`, `shift_history_screen.dart` | `features/pos/providers/shift_provider.dart` — `ShiftNotifier`, `ShiftHistoryNotifier` | `features/pos/services/shift_service.dart` — `ApiShiftService` | `features/pos/models/shift_model.dart` — `Shift`, `ShiftState` | `GET /api/shifts/current`, `POST /api/shifts/open`, `POST /api/shifts/{id}/close`, `GET /api/shifts/{id}/close-precheck`, `GET /api/shifts/history` |

**[NEW/MOBILE] destination**: `frontend_flutter_mobile/lib/features/pos/{screens,providers,services,models}/shift_*.dart` — mirrors old paths exactly. Deep-dive deferred to Day 10 per plan scope.

---

## Inventory Map

Two shared files back 7 of the 9 sub-areas (`inventory_provider.dart` / `inventory_service.dart` / `inventory_models.dart`); Productions and Stock Lookup are exceptions.

| Area | Screen | Provider/Service/Model | API |
|---|---|---|---|
| Stock Lookup | `inventory/screens/inventory_hub_screen.dart` | **reuses POS** `productsProvider`/`productServiceProvider` — no inventory-specific provider | product catalog endpoint (not inventory-specific) |
| Purchase Orders | `purchase_orders_screen.dart`, `create_purchase_order.dart` | `inventory_provider.dart` (`purchaseOrdersProvider`) / `inventory_service.dart` / `PurchaseOrder`,`PurchaseOrderLine` | `GET/POST /api/purchase-orders`, `GET/PUT /api/purchase-orders/{id}`, `POST /api/purchase-orders/{id}/{action}` |
| Transfer Orders | `transfer_orders_screen.dart`, `create_transfer_order.dart` | `inventory_provider.dart` (`transferOrdersProvider`) | `GET/POST /api/inventory/transfers`, `POST .../{id}/complete`, `POST .../{id}/cancel` |
| Stock Adjustments | `stock_adjustments_screen.dart` | `inventory_provider.dart` (`movementsProvider` — **shared with Inventory History**) | `POST /api/inventory/adjust` |
| Inventory Counts | `inventory_counts_screen.dart` | `inventory_provider.dart` (`inventoryCountProvider`) | `GET /api/inventory/counts`, `POST /api/inventory/snapshots`, `POST .../counts/entry`, `POST .../counts/post` |
| Productions | `productions_screen.dart`, `create_recipe.dart` | **own** `providers/production_provider.dart`, `services/production_service.dart`, `models/production_models.dart` | `GET/POST /api/production/recipes`, `GET/POST /api/production/orders`, `.../check-availability`, `.../{id}/start\|complete\|cancel` |
| Suppliers | `suppliers_screen.dart`, `create_supplier.dart` | `inventory_provider.dart` (`suppliersProvider`) | `GET/POST /api/suppliers`, `PUT/DELETE /api/suppliers/{id}` |
| Inventory History | `inventory_history_screen.dart` | `inventory_provider.dart` (`movementsProvider` — **same notifier as Stock Adjustments**, read-only view) | `GET /api/inventory/movements` |
| Inventory Valuation | `inventory_valuation_screen.dart` | `inventory_provider.dart` (`inventoryValuationProvider`) | `GET /api/inventory/valuation` |

`locationsProvider`/`getLocations()` (`GET /api/stores`) also lives in `inventory_provider.dart`/`inventory_service.dart` — no dedicated screen, used to populate store pickers across several screens above.

**[NEW/MOBILE] destination**: `frontend_flutter_mobile/lib/features/inventory/{screens,providers,services,models}/...` mirroring old relative paths exactly. **Not implemented today** — Day 1 is mapping only, per scope boundaries.

---

## Receipt Status Architecture

**[OLD/SOURCE — READ, current code, verified — not the plan doc's assumptions]**
- `frontend-flutter-pos/lib/features/pos/providers/receipt_provider.dart`
- `frontend-flutter-pos/lib/features/pos/screens/receipts_screen.dart`

### Current filter values (exact)
```dart
// receipts_screen.dart:47-52
static const List<String?> _statusFilters = [null, 'PAID', 'VOID', 'REFUNDED'];
```
`null` = "All". **`REFUNDED` includes `PARTIALLY_REFUNDED`** — there is no separate chip for partial refunds.

### FUNCTION: `saleMatchesStatusFilter`
```dart
// receipt_provider.dart:10-15
bool saleMatchesStatusFilter(String saleStatus, String filterStatus) {
  if (filterStatus == 'REFUNDED') {
    return saleStatus == 'REFUNDED' || saleStatus == 'PARTIALLY_REFUNDED';
  }
  return saleStatus == filterStatus;
}
```

### FUNCTION: `backendStatusQueryFor`
```dart
// receipt_provider.dart:23-24
String? backendStatusQueryFor(String? filterStatus) =>
    filterStatus == 'REFUNDED' ? null : filterStatus;
```
The backend's `GET /api/pos/sales?status=` only accepts one literal value and can't express the REFUNDED family, so for that chip the fetch is left unfiltered and `saleMatchesStatusFilter` narrows client-side. PAID/VOID pass through unchanged.

### FUNCTION: `setStatusFilter` / `loadAllSales`
```dart
// receipt_provider.dart:152-155
void setStatusFilter(String? status) {
  state = state.copyWith(statusFilter: status, clearStatusFilter: status == null);
}
// receipt_provider.dart:125-141
Future<void> loadAllSales({String? status}) async { ... _service.listSales(status: status) ... }
```
Callers always pass `status: backendStatusQueryFor(...)`, never the raw chip value.

### PENDING / COMPLETED — explicitly verified NOT current
- **`PENDING`**: zero matches in either file — not a filter option, not a status value, not referenced anywhere in current receipt code.
- **`COMPLETED`**: appears exactly once, in a comment (`receipts_screen.dart:886`) explicitly documenting it as a **dead** status no longer checked anywhere — not in any live conditional.
- **If a stale plan doc references PENDING as a filter or COMPLETED as an active status, that is incorrect for current code.** Real current status vocabulary (from `_statusBadgeLabel`/`_statusColor`): `PAID`, `VOID`, `REFUNDED`, `PARTIALLY_REFUNDED`, `CREDIT`, `DRAFT`, `HOLD` — filter chips expose only `PAID`/`VOID`/`REFUNDED` (REFUNDED covering PARTIALLY_REFUNDED).

### VOID is terminal
No code path re-transitions a `VOID` sale. The refund-eligibility check explicitly whitelists only `PAID`/`PARTIALLY_REFUNDED`:
```dart
// receipts_screen.dart:882-889
if (receipt.status == 'PAID' || receipt.status == 'PARTIALLY_REFUNDED')
```
`VOID` is absent from this whitelist — terminality is enforced by omission (no UI action ever changes a VOID sale's status), backed by the backend's `SaleService.refund()` guard (not re-verified against backend source in this pass — flagged as a follow-up if backend-level certainty is needed).

**Do NOT document old "PENDING receipt filter" or "COMPLETED sale status" as current behavior — both are dead/nonexistent in current code, confirmed above.**

---

## OLD → NEW Mapping Table

| OLD/SOURCE | Function/Class | Purpose | Action | NEW/MOBILE |
|---|---|---|---|---|
| `main.dart` | `main()`, `PosApp` | app entry, routes map, auth-gated `home:` | RECREATE (same shape, mobile-scoped routes) | `main.dart` |
| `core/config/app_config.dart` | `AppConfig` | feature flags, base URL, SharedPreferences keys | RECREATE USING SAME LOGIC (baseUrl needs real-device branch) | `core/config/app_config.dart` |
| `core/config/pos_theme.dart` | `PosTheme` | light/dark ThemeData, spacing/radius scale | RECREATE USING SAME LOGIC (Day 3) | `core/config/pos_theme.dart` |
| `core/services/api_service.dart` | `ApiService` | Dio client, JWT interceptor, error mapping | COPY/ADAPT NEARLY EXACTLY | `core/services/api_service.dart` |
| `core/services/auth_service.dart` | `AuthService` | login/logout/token persistence | COPY/ADAPT NEARLY EXACTLY | `core/services/auth_service.dart` |
| `core/providers/auth_provider.dart` | `AuthNotifier` | session state | COPY/ADAPT NEARLY EXACTLY | `core/providers/auth_provider.dart` |
| `core/models/auth_models.dart` | `User`, `AuthResponse`, `LoginRequest` | auth DTOs | COPY/ADAPT NEARLY EXACTLY | `core/models/auth_models.dart` |
| `features/auth/screens/login_screen.dart` | `LoginScreen` | desktop login UI | MOBILE UI REIMPLEMENT | `features/auth/screens/mobile_login_screen.dart` |
| `features/pos/models/product_models.dart` | `Product`, `Category` | product/category models | COPY/ADAPT NEARLY EXACTLY | `features/pos/models/product_models.dart` |
| `features/pos/providers/product_provider.dart` | `ProductNotifier` | product list/search/paginate state | COPY/ADAPT NEARLY EXACTLY | `features/pos/providers/product_provider.dart` |
| `features/pos/services/product_service.dart`, `demo_product_service.dart` | `ApiProductService`, `_FallbackProductService`, `DemoProductService` | product API + offline fallback | COPY/ADAPT NEARLY EXACTLY | `features/pos/services/product_service.dart` |
| `features/pos/widgets/product_grid.dart` | `ProductGrid` | fixed-5-column grid | MOBILE UI REIMPLEMENT (responsive columns) | `features/pos/widgets/mobile_product_grid.dart` |
| `features/pos/models/cart_models.dart` | `CartItem`, `HeldOrder`, `SelectedModifier` | cart line/held-order models | COPY/ADAPT NEARLY EXACTLY | `features/pos/models/cart_models.dart` |
| `features/pos/providers/cart_provider.dart` | `CartNotifier` | cart business logic, every mutator | COPY/ADAPT NEARLY EXACTLY (do not rewrite calc logic) | `features/pos/providers/cart_provider.dart` |
| `features/pos/services/cart_service.dart` | `ApiCartService`, `LocalCartService` | cart backend mirror / offline store | COPY/ADAPT NEARLY EXACTLY | `features/pos/services/cart_service.dart` |
| `features/pos/screens/payment_screen.dart` | `_submitSaleToBackend` | checkout submission, idempotency key | COPY/ADAPT the logic; MOBILE UI REIMPLEMENT the layout | `features/pos/screens/mobile_payment_screen.dart` |
| `features/pos/services/sale_service.dart` | `SaleService` | createSale/paySale/getReceipt/refundSale | COPY/ADAPT NEARLY EXACTLY | `features/pos/services/sale_service.dart` |
| `features/pos/services/printing/receipt_view_model.dart` | `ReceiptViewModel` | print-ready receipt data | COPY/ADAPT NEARLY EXACTLY | `features/pos/services/printing/receipt_view_model.dart` |
| `features/pos/widgets/receipt_paper_view.dart` | `ReceiptContent` | shared preview/raster widget | COPY/ADAPT NEARLY EXACTLY | `features/pos/widgets/receipt_paper_view.dart` |
| `features/pos/services/print_service.dart` | `PrintService` | PDF build + print dispatch | ADAPT (own logic portable) | `features/pos/services/print_service.dart` |
| `features/pos/services/printing/thermal_printer_service.dart` | `ThermalPrinterService` | transport dispatch | ADAPT (add permission gate later) | `features/pos/services/printing/thermal_printer_service.dart` |
| `features/pos/services/printing/escpos_receipt_builder.dart` | `EscPosReceiptBuilder` | ESC/POS byte builder | COPY/ADAPT NEARLY EXACTLY | same path |
| `features/pos/services/printing/receipt_bitmap_renderer.dart` | `ReceiptBitmapRenderer` | Khmer whole-doc rasterizer | COPY/ADAPT NEARLY EXACTLY | same path |
| `features/pos/services/printing/network_printer_transport.dart` | `NetworkPrinterTransport` | TCP socket transport | PLATFORM IMPLEMENTATION (works natively; add iOS Info.plist key later) | same path |
| `features/pos/services/printing/usb_printer_transport.dart` | `UsbPrinterTransport` | USB transport | PLATFORM IMPLEMENTATION (Android-viable; iOS unverified) | same path |
| `features/pos/services/printing/bluetooth_printer_transport.dart` | `BluetoothPrinterTransport` | Bluetooth transport | PLATFORM IMPLEMENTATION (Android-first; iOS doubtful) | same path |
| `core/services/printing/a4_report_pdf.dart` | `A4ReportPdf` | A4 report/invoice PDF | COPY/ADAPT NEARLY EXACTLY | same path |
| `features/pos/providers/shift_provider.dart` | `ShiftNotifier` | shift open/close state | COPY/ADAPT NEARLY EXACTLY (Day 10) | same path |
| `features/inventory/providers/inventory_provider.dart` | movements/counts/suppliers/PO/TO/valuation | inventory state | COPY/ADAPT NEARLY EXACTLY (Day 17) | same path |
| `features/pos/providers/receipt_provider.dart` | `saleMatchesStatusFilter`, `backendStatusQueryFor`, `setStatusFilter` | receipt history + status filters (PAID/VOID/REFUNDED only) | COPY/ADAPT NEARLY EXACTLY | same path |
| `l10n/app_en.arb`, `app_km.arb` | source translation strings | ARB source | COPY/ADAPT (own copies, seeded not shared — Day 3) | `l10n/app_en.arb`, `app_km.arb` |

---

## Do Not Copy

Verified by direct grep/import-trace, not assumed from file naming:

| Path | Verdict | Reason |
|---|---|---|
| `frontend-flutter-pos/lib/pos/` (entire directory — `providers/cart_provider.dart`, `services/cart_service.dart`, `models/cart_model.dart`) | DEAD | Zero imports anywhere in `lib/features/` or `lib/main.dart` resolve into this directory; fully superseded by `lib/features/pos/{providers,services,models}/cart_*.dart` |
| `lib/features/pos/models/product.dart` | DEAD | Only consumer is the also-dead `product_api_service.dart`; real model is `product_models.dart` |
| `lib/features/pos/services/product_api_service.dart` | DEAD | Zero references anywhere in `lib/` |
| `lib/features/pos/widgets/cart_panel_footer.dart` | DEAD | `CartPanelFooter` class unused anywhere |
| `lib/features/pos/widgets/cart_footer.dart` | DEAD | `CartFooter` class unused anywhere |
| `lib/features/pos/widgets/status_bar.dart` | DEAD | `PosStatusBar` class unused anywhere |
| `lib/features/pos/services/scanner_relay_role.dart` + `phone_scanner_receiver_button.dart` + `screens/phone_screen_scan.dart` | ACTIVE in source, but N/A for mobile | Solves "desktop till has no camera" via phone-to-phone WebSocket relay; a mobile app has its own camera — porting this relay protocol would add unneeded networking/pairing complexity for a problem that doesn't exist on mobile |

No other deprecated/legacy/unused markers found in a broader sweep (grep for `deprecated|legacy|TODO: remove|obsolete|_old|old_` across `lib/`, excluding generated l10n) beyond two incidental in-code comments about individual fields (not dead files).

---

## Functions Studied

Startup: `main()`, `PosApp.build`. Config/API: `AppConfig.baseUrl`, `AppConfig.initialize`, `ApiService._createDioOptions`, `ApiService._setupInterceptors`, `ApiService.get/post/put/patch/delete`, `ApiService._handleError`. Auth: `_LoginScreenState._login`, `AuthNotifier.login`/`logout`/`_initializeAuth`, `AuthService.login`/`_saveAuthData`, backend `AuthController.login`, `AuthService.login` (backend), `JwtUtil.generateToken`. Product: `ProductNotifier.loadProducts`/`loadMore`/`searchProducts`/`filterByCategory`/`findByBarcode`, `ApiProductService.getProducts`, `_FallbackProductService._tryApi`. Cart: all 19 public `CartNotifier` mutators (`addItemFromProduct` through `syncTaxRate`), `ApiCartService.saveCartItems`. Sale/Receipt: `_submitSaleToBackend`, `_fetchCompletedReceipt`, `_autoPrintIfEnabled`, `SaleService.createSale/paySale/getReceipt/refundSale/listSales`, `ReceiptViewModel.fromReceiptResponse/.fromCart`. Printing: all 13 classes in the printing table above. Receipt status: `saleMatchesStatusFilter`, `backendStatusQueryFor`, `setStatusFilter`, `loadAllSales`. Shift/Inventory: surveyed at class/endpoint level (not full function bodies — per plan scope, deep dives are per-day later). Legacy audit: `lib/pos/`, `product.dart`, `product_api_service.dart`, `cart_panel_footer.dart`, `cart_footer.dart`, `status_bar.dart`, `scanner_relay_role.dart`.

## Tests/Commands Run

- `wc -l frontend-flutter-pos/docs/MOBILE_ANDROID_IOS_20_DAY_BUILD_PLAN.md` — confirmed doc length (3911 lines).
- `ls -la frontend_flutter_mobile/`, `ls -la frontend_flutter_mobile/lib` — confirmed mobile project is still an untouched `flutter create` scaffold (only `lib/main.dart`, default `pubspec.yaml`).
- `grep -n` sweeps across `frontend-flutter-pos/lib/` for: dead-code markers, `permission_handler` imports, `PENDING`/`COMPLETED` in receipt files, duplicate basenames — all via research agents, results incorporated above.
- Direct reads (agents, full-file) of every source file listed in "Files to study" above, plus the backend Auth/JWT files and the printing-transport plugin `pubspec.yaml`s (for iOS/Android platform support claims).
- Did **not** run `frontend-flutter-pos && flutter run -d chrome` (the plan's step 7 — a live login→browse→checkout run against the real backend) — this requires an interactive browser session and a running backend; flagged as unverified below rather than silently skipped.

## Problems Found

1. **Plan doc uses a placeholder project name** (`mobile-flutter-pos`) throughout instead of the real `frontend_flutter_mobile` — already self-corrected by a prior Day 1 pass (`docs/DAY_01_ARCHITECTURE_MAP.md`, still present alongside this file) and re-confirmed here.
2. **`AppConfig.baseUrl` has no physical-device branch** — `defaultTargetPlatform == TargetPlatform.android` always resolves to `10.0.2.2` (emulator-only loopback alias), which will silently fail against a LAN backend from a real Android phone. This is a genuine gap in the source app, not something to blindly copy — Day 4's mobile base-URL logic must extend it, not just port it.
3. **`AppConfig.initialize()` is a no-op** — safe to copy as-is, but don't assume it does anything today.
4. **No secure storage for auth token** — plain `SharedPreferences`, not `flutter_secure_storage`. Worth a deliberate decision for the mobile port (phones are more loss/theft-prone than a fixed till), not a silent carry-over. Not fixed today — flagged per instructions ("if you find a source bug, REPORT IT, do not silently fix it").
5. **Printing permission layer doesn't exist in source at all** (zero `permission_handler` imports, no Bluetooth/USB/local-network manifest/plist keys) — confirmed by direct grep, not just plan-doc assumption. This is new work for Days 15–16, not a gap in this Day 1 study.
6. **iOS Bluetooth/USB printer transports are architecturally uncertain** — `print_bluetooth_thermal` is an Android-first classic-Bluetooth plugin (iOS's public API doesn't expose classic BT outside MFi `ExternalAccessory`); `flutter_pos_printer_platform_image_3`'s USB support on iOS is MFi-certification-gated. Flagging now so Days 15–16 don't assume parity with Android.
7. **Live login→browse→checkout run against the real backend was not performed** in this Day 1 pass (plan step 7) — requires an interactive `flutter run -d chrome` session and a live backend, out of scope for a non-interactive research pass. Recommend running it manually before Day 4 if not already done.
8. **`khmer_pdf_font.dart` is not under `core/` as the plan doc's file list implies** — actual location is `lib/features/pos/services/printing/khmer_pdf_font.dart`. Corrected in the mapping table above.
9. A prior, differently-named Day 1 document (`frontend_flutter_mobile/docs/DAY_01_ARCHITECTURE_MAP.md`) already exists from an earlier pass in this same project history and covers similar ground at lighter depth. This file (`DAY_01_ARCHITECTURE_AND_MAPPING.md`) is the canonical Day 1 deliverable going forward per the exact filename this task specifies; the older file was left in place rather than deleted (no destructive action taken on existing docs without confirmation).

## Definition of Done

Per the task's Day 1 checklist:
- [x] startup architecture mapped
- [x] API architecture mapped
- [x] authentication mapped
- [x] products mapped
- [x] cart mapped
- [x] payment/sale mapped
- [x] receipt mapped
- [x] printing mapped
- [x] shift mapped (survey-level, per plan scope)
- [x] inventory mapped (survey-level, per plan scope)
- [x] old → new table created
- [x] legacy/dead code documented
- [x] `DAY_01_ARCHITECTURE_AND_MAPPING.md` created

Per the plan document's own Day 1 Definition of Done: *"You can reproduce the three chains in section C from memory with correct OLD/SOURCE-NEW/MOBILE labels, and you can name every file in section D's table without looking."* — satisfied by the Login/Product/Sale chains documented above with verified real names throughout.

**DAY 1 STATUS: PASS.** No blocking architecture/code discrepancies found — only documentation-quality gaps (items 1–9 above), all now recorded rather than silently glossed over.

## What I Must Understand Before Day 2

`frontend_flutter_mobile` already exists as a bare `flutter create` scaffold — Day 2 is **not** `flutter create`, it's inspection + configuration: confirm/adjust `applicationId`/bundle ID/display name, verify `flutter pub get`/`flutter analyze` baselines, understand current Android/iOS manifest/plist state, and determine what assets/fonts (especially Noto Sans Khmer) need to be copied in before Day 3's theme/localization work can build on them. Every file in the OLD → NEW mapping table above is something to actually *write* into `frontend_flutter_mobile/lib/...` on the day that feature comes up — none of it exists yet except the default `main.dart`.
