# Day 4 — Auth: Login

## 1. Goal

Give `frontend_flutter_mobile` a working, backend-verified login flow: a
phone-optimized Login screen, a Riverpod auth provider that owns session
state, an `AuthService`/`ApiService` pair that talks to the exact same
Spring Boot `/api/auth/login` endpoint the desktop app uses, and a startup
guard that restores (or safely discards) a cached session. This is the
first day mobile makes a real network call to the shared backend.

## 2. Source Project Investigation

Files actually read and traced in `frontend-flutter-pos/` before writing
any mobile code:

```text
frontend-flutter-pos/lib/core/config/app_config.dart
frontend-flutter-pos/lib/core/services/api_service.dart
frontend-flutter-pos/lib/core/models/auth_models.dart
frontend-flutter-pos/lib/core/models/auth_models.g.dart   (generated — read to confirm the JSON shape, not ported)
frontend-flutter-pos/lib/core/services/auth_service.dart
frontend-flutter-pos/lib/core/providers/auth_provider.dart
frontend-flutter-pos/lib/core/utils/jwt_utils.dart
frontend-flutter-pos/lib/features/auth/screens/login_screen.dart
frontend-flutter-pos/lib/main.dart                        (PosApp.build's authState.maybeWhen home gate)
frontend-flutter-pos/pubspec.yaml                          (confirmed dio: ^5.3.3, no json_serializable/equatable listed as a *project convention* — auth_models.dart is the only file using them)
frontend-flutter-pos/lib/features/pos/models/cart_models.dart  (confirmed as the "plain hand-written model, no codegen" precedent used instead — see section 7)
```

Backend, read to confirm the exact contract (request/response shape, error
status codes, and that login failure is a genuine business path, not
something to invent):

```text
backend-spring-boot/src/main/java/com/kaknnea/pos/controller/AuthController.java
backend-spring-boot/src/main/java/com/kaknnea/pos/dto/AuthDtos.java
backend-spring-boot/src/main/java/com/kaknnea/pos/service/AuthService.java
backend-spring-boot/src/main/java/com/kaknnea/pos/exception/ApiException.java
backend-spring-boot/src/main/java/com/kaknnea/pos/exception/GlobalExceptionHandler.java
```

## 3. Mobile Target

```text
frontend_flutter_mobile/pubspec.yaml                                  (MODIFIED — added dio)
frontend_flutter_mobile/lib/core/config/app_config.dart                (NEW)
frontend_flutter_mobile/lib/core/services/api_service.dart             (NEW)
frontend_flutter_mobile/lib/core/models/auth_models.dart               (NEW)
frontend_flutter_mobile/lib/core/services/auth_service.dart            (NEW)
frontend_flutter_mobile/lib/core/providers/auth_provider.dart          (NEW)
frontend_flutter_mobile/lib/core/utils/jwt_utils.dart                  (NEW)
frontend_flutter_mobile/lib/features/auth/screens/login_screen.dart    (NEW)
frontend_flutter_mobile/lib/core/dev/theme_demo_screen.dart            (MODIFIED — logout action)
frontend_flutter_mobile/lib/main.dart                                  (MODIFIED — auth gate)
frontend_flutter_mobile/test/auth_provider_test.dart                   (NEW)
frontend_flutter_mobile/test/login_screen_test.dart                    (NEW)
frontend_flutter_mobile/test/widget_test.dart                          (MODIFIED — Day 3 smoke test updated for the new default screen)
```

## 4. Architecture Flow

```text
LoginScreen (user taps LOGIN)
    ↓
_login()
    ↓
ref.read(authProvider.notifier).login(email, password)
    ↓
AuthNotifier.login()
    ↓
AuthService.login()
    ↓
ApiService.post('/api/auth/login', data: LoginRequest.toJson())
    ↓
Dio HTTP POST (Authorization header NOT yet present — this is the call that gets the token)
    ↓
Spring Boot AuthController.login()
    ↓
AuthService.login() (backend) — validates credentials, issues JWT
    ↓
database (UserRepository, LoginAuditRepository)
    ↓
AuthDtos.LoginResponse { token, user }
    ↓
JSON response body
    ↓
AuthResponse.fromJson() (Flutter model)
    ↓
AuthService._saveAuthData() — SharedPreferences['auth_token'], SharedPreferences['user_data']
    ↓
AuthNotifier state = AsyncValue.data(user)
    ↓
LoginScreen rebuilds (ref.watch(authProvider)) → MobileApp rebuilds (ref.watch(authProvider) too)
    ↓
Navigator.pushReplacementNamed('/') — re-resolves MobileApp.home, now ThemeDemoScreen
```

Every layer above is actually used by this feature; there is no
inventory/reports/printing layer involved.

## 5. Files To Create

**`frontend_flutter_mobile/lib/core/config/app_config.dart`**
Purpose: base URL resolution (per-platform) + SharedPreferences key names,
identical contract to source.
Class: `AppConfig` (static-only, ported).
Important members: `baseUrl` (platform-conditional getter), `apiBaseUrl`
(alias), `authTokenKey`, `userKey`.

**`frontend_flutter_mobile/lib/core/services/api_service.dart`**
Purpose: the one Dio wrapper every networked service in the mobile app will
call through (`get`/`post`/`put`/`delete`), with the auth-token interceptor
and the same HTTP-status → friendly-message mapping as source.
Class: `ApiService`.
Important functions: `get<T>`, `post<T>`, `put<T>`, `delete<T>`,
`_handleError` (private), `_setupInterceptors` (private, wires the
`Authorization: Bearer <token>` request interceptor and the 401 →
`onUnauthorized` callback).

**`frontend_flutter_mobile/lib/core/models/auth_models.dart`**
Purpose: `User`, `AuthResponse`, `LoginRequest` — the exact JSON shape the
backend's `AuthDtos.UserResponse`/`LoginResponse`/`LoginRequest` produce and
consume.
Classes: `User`, `AuthResponse`, `LoginRequest` — plain classes with
hand-written `fromJson`/`toJson` (see section 7 for why, vs. source's
`json_annotation`).

**`frontend_flutter_mobile/lib/core/services/auth_service.dart`**
Purpose: the ONLINE login call + OFFLINE cached-session read/write.
Class: `AuthService`.
Important functions: `login()`, `logout()`, `getToken()`,
`getCurrentUser()`, `_saveAuthData()` (private).

**`frontend_flutter_mobile/lib/core/providers/auth_provider.dart`**
Purpose: the single source of truth for "who is logged in" as a Riverpod
`StateNotifierProvider<AuthNotifier, AsyncValue<User?>>`.
Class: `AuthNotifier`.
Important functions: `_initializeAuth()` (private, runs on provider
creation — the startup JWT-expiry guard), `login()`, `logout()`,
`refreshUser()`. Convenience providers: `currentUserProvider`,
`isAuthenticatedProvider`.

**`frontend_flutter_mobile/lib/core/utils/jwt_utils.dart`**
Purpose: `isJwtExpired(token)` — decodes the JWT payload's `exp` claim
without any backend call, pure Dart.

**`frontend_flutter_mobile/lib/features/auth/screens/login_screen.dart`**
Purpose: the phone-optimized login form (see section 10 for the UI
adaptation from source's two-panel desktop layout).
Class: `LoginScreen` / `_LoginScreenState`.
Important functions: `_login()`, `build()`.

## 6. Files To Modify

**`frontend_flutter_mobile/pubspec.yaml`**
Existing: no HTTP client dependency.
Change: added `dio: ^5.3.3` under `dependencies` (same version pin as
source). Why: `ApiService` is a Dio wrapper; nothing in the mobile project
could make an HTTP call before this.

**`frontend_flutter_mobile/lib/core/dev/theme_demo_screen.dart`**
Existing: Day 3's temporary theme/locale verification screen, no auth
awareness.
Change: added an `IconButton(Icons.logout)` AppBar action calling
`ref.read(authProvider.notifier).logout()`, and a "Logged in as ..." banner
reading `currentUserProvider`. Why: without this, there was no way to
manually exercise the full login → home → logout → back-to-login round
trip before Day 5 builds the real post-login shell — see section 15.

**`frontend_flutter_mobile/lib/main.dart`**
Existing: `home: const ThemeDemoScreen()` unconditionally (Day 3).
Change: `home:` now branches on `ref.watch(authProvider)` exactly like
`[OLD/SOURCE]` `PosApp.build()`'s `authState.maybeWhen(...)` — `LoginScreen`
when logged out (including while the startup guard is still loading, via
`orElse`), `ThemeDemoScreen` when a user is present. Why: this is the
actual auth gate — without it, Day 4's LoginScreen would exist as a file
but never be reachable. Also added
`ApiService.onUnauthorized = () => ref.read(authProvider.notifier).logout();`,
ported verbatim from `[OLD/SOURCE] PosApp.build()` — wires `ApiService`'s
401 interceptor to force a logout (and thus, via the `home:` gate, back to
`LoginScreen`) if any future authenticated call gets rejected by the
backend.

**`frontend_flutter_mobile/test/widget_test.dart`**
Existing: asserted `find.text('KAKNNEA')` (ThemeDemoScreen's AppBar title)
appears on boot.
Change: now asserts `find.byType(LoginScreen)` appears on boot instead.
Why: the default (logged-out, no cached session) screen changed as a direct
consequence of the `main.dart` change above — this is not a design choice
of this file, it's `main.dart`'s new behavior making the old assertion
false.

## 7. Functions

### Function: `AuthNotifier._initializeAuth()`

FILE: `frontend_flutter_mobile/lib/core/providers/auth_provider.dart`
CLASS: `AuthNotifier`
SIGNATURE: `Future<void> _initializeAuth()` (private, no parameters)
CALLED BY: `AuthNotifier`'s own constructor, once, at provider creation
(app startup, or first `ref.watch(authProvider)`/`ref.read(authProvider)`).
CALLS: `AuthService.getToken()`, `isJwtExpired()`, `AuthService.logout()`
(only if the cached token is expired), `AuthService.getCurrentUser()`.
INPUT: none (reads cached state via `AuthService`).
OUTPUT: none directly — mutates `this.state`.
STATE CHANGES: `state` starts as `AsyncValue.loading()` (set in the
constructor's `super(...)` call before this even runs); becomes
`AsyncValue.data(null)` (no valid session) or `AsyncValue.data(user)`
(restored session) or `AsyncValue.error(...)` (unexpected exception).
UI EFFECT: `MobileApp.home` re-evaluates once this resolves — `LoginScreen`
while `state.isLoading`, then either stays on `LoginScreen` (no session) or
switches to `ThemeDemoScreen` (restored session).

REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` — byte-identical logic.
Line by line: reads the cached token; if it's `null` OR
`isJwtExpired(token)` is true, it discards any cached token (calling
`logout()` only when a token actually existed, to also clear the cached
user) and sets `state = AsyncValue.data(null)` — this is the fix (already
present upstream, ported as-is) that stops a stale-but-cached token from
booting the app straight past Login only to fail on the first real API
call. Otherwise it trusts the cached token and loads the cached `User` via
`getCurrentUser()`.

### Function: `AuthNotifier.login(email, password, {terminalId})`

FILE: `frontend_flutter_mobile/lib/core/providers/auth_provider.dart`
CLASS: `AuthNotifier`
SIGNATURE: `Future<void> login(String email, String password, {String? terminalId})`
CALLED BY: `LoginScreen._login()`.
CALLS: `AuthService.login()`.
INPUT: trimmed email string, trimmed password string, optional terminal id
(unused by the mobile Login form — see section 10).
OUTPUT: `Future<void>` — result communicated via `state`, not a return
value.
STATE CHANGES: `state = AsyncValue.loading()` immediately (drives the
LOGIN button's spinner via `authState.isLoading`), then either
`AsyncValue.data(authResponse.user)` on success or
`AsyncValue.error(error, stackTrace)` on failure — **this method never
rethrows**, see the "Problems Found" note below.
UI EFFECT: `LoginScreen` rebuilds (spinner shows/hides); once state
resolves, `MobileApp` rebuilds and `home:` re-evaluates.

REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` — byte-identical logic.

### Function: `AuthService.login(email, password, {terminalId})`

FILE: `frontend_flutter_mobile/lib/core/services/auth_service.dart`
CLASS: `AuthService`
SIGNATURE: `Future<AuthResponse> login(String email, String password, {String? terminalId})`
CALLED BY: `AuthNotifier.login()`.
CALLS: `ApiService.post()`, `AuthResponse.fromJson()`, `_saveAuthData()`
(private).
INPUT: email, password, optional terminal id.
OUTPUT: `Future<AuthResponse>` (token + user) — or throws `ApiException` on
any non-2xx response (propagated from `ApiService`).
STATE CHANGES: none of its own; delegates persistence to `_saveAuthData()`.
UI EFFECT: none directly (service layer).
API: `POST /api/auth/login` — see section 11.

REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` — byte-identical logic.

### Function: `AuthService._saveAuthData(authResponse)`

FILE: `frontend_flutter_mobile/lib/core/services/auth_service.dart`
CLASS: `AuthService`
SIGNATURE: `Future<void> _saveAuthData(AuthResponse authResponse)` (private)
CALLED BY: `AuthService.login()`, only on success.
CALLS: `SharedPreferences.getInstance()`, `prefs.setString()` ×2.
INPUT: the `AuthResponse` just returned by the backend.
OUTPUT: none.
STATE CHANGES: writes `SharedPreferences['auth_token']` (raw JWT string)
and `SharedPreferences['user_data']` (JSON-encoded `User`).
UI EFFECT: none directly — this is what makes the session survive an app
restart (read back by `AuthService.getToken()`/`getCurrentUser()` on the
next launch's `_initializeAuth()`).

REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` — byte-identical logic.

### Function: `ApiService.post<T>(path, {data, queryParameters, fromJson})`

FILE: `frontend_flutter_mobile/lib/core/services/api_service.dart`
CLASS: `ApiService`
SIGNATURE: `Future<T> post<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, T Function(Object? data)? fromJson})`
CALLED BY: `AuthService.login()` (and every other `Api***Service` this
project will add in later days).
CALLS: `Dio.post()`; on `DioException`, `_handleError()`.
INPUT: the endpoint path, request body, optional query params, optional
response-mapping function.
OUTPUT: `Future<T>` — either the raw decoded JSON cast to `T`, or the
result of `fromJson(response.data)` if provided.
STATE CHANGES: none (stateless request wrapper). The auth-token
interceptor (see `_setupInterceptors`) reads `SharedPreferences` on every
outgoing request to stamp the `Authorization` header — irrelevant for the
login call itself (no token exists yet) but this is the exact code path
every OTHER authenticated call in later days will go through.
UI EFFECT: none directly.

REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` — byte-identical logic.

### Function: `LoginScreen._login()`

FILE: `frontend_flutter_mobile/lib/features/auth/screens/login_screen.dart`
CLASS: `_LoginScreenState`
SIGNATURE: `Future<void> _login()`
CALLED BY: the LOGIN button's `onPressed`, and the password field's
`onFieldSubmitted` (pressing "done" on the keyboard).
CALLS: `_formKey.currentState!.validate()`,
`ref.read(authProvider.notifier).login()`,
`Navigator.of(context).pushReplacementNamed('/')`,
`ScaffoldMessenger.of(context).showSnackBar()` (in the catch block — see
"Problems Found", this branch is currently unreachable).
INPUT: `_emailController.text.trim()`, `_passwordController.text.trim()`
(from the two `TextEditingController`s bound to the form fields).
OUTPUT: none (`Future<void>`).
STATE CHANGES: none of its own — delegates to `AuthNotifier.login()`.
UI EFFECT: on validation failure, the form fields show their error text
(no async work happens). On completion (which — see below — currently
always means "success or swallowed failure", not "success only"),
navigates away from `LoginScreen`.

REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` — identical body except
the destination route (`'/'` vs. source's `'/pos'`, since the mobile app's
real post-login home route doesn't exist yet — Day 5 scope).

## 8. User Click Flow

```text
User taps LOGIN
↓
onPressed → _login()
↓
_formKey.currentState!.validate()  (both fields non-empty, password >= 6 chars)
↓ (valid)
ref.read(authProvider.notifier).login(email, password)
↓
AuthNotifier.login()  — state = AsyncValue.loading()  (button shows a spinner)
↓
AuthService.login(email, password)
↓
ApiService.post('/api/auth/login', data: {email, password, terminalId: null})
↓
Dio HTTP POST http://<baseUrl>/api/auth/login
↓
Spring Boot AuthController.login()
↓
backend AuthService.login() — UserRepository lookup, password check, lockout/failed-attempt bookkeeping, JwtUtil issues a signed JWT
↓
AuthDtos.LoginResponse { token, user: {id, email, fullName, roles, permissions} }
↓
AuthResponse.fromJson(response) (Flutter)
↓
AuthService._saveAuthData() — SharedPreferences['auth_token'] = token, SharedPreferences['user_data'] = jsonEncode(user)
↓
AuthNotifier state = AsyncValue.data(user)
↓
LoginScreen's `ref.watch(authProvider)` rebuild — button spinner clears
↓
_login() resumes after the await → `if (mounted) Navigator.of(context).pushReplacementNamed('/')`
↓
MobileApp (ConsumerWidget, also watching authProvider) has ALREADY rebuilt with `home:` = ThemeDemoScreen — pushReplacementNamed('/') re-resolves the default route against that current `home:` value
↓
ThemeDemoScreen (temporary Day 3/4 placeholder — Day 5 replaces this with the real mobile shell)
```

## 9. Data Flow

```text
email (TextEditingController)
↓
_emailController.text.trim()
↓
AuthNotifier.login(email, ...)
↓
AuthService.login(email, ...)
↓
LoginRequest(email: email, password: ..., terminalId: null).toJson()
↓
{"email": "...", "password": "...", "terminalId": null}
↓
POST /api/auth/login body
↓
AuthDtos.LoginRequest (Jakarta-validated: @Email @NotBlank)
↓
backend AuthService.login() — UserRepository.findByEmail(email)
```

```text
JWT token
↓
AuthDtos.LoginResponse.token (backend, signed by JwtUtil)
↓
response body {"token": "...", "user": {...}}
↓
AuthResponse.fromJson(response)['token']
↓
AuthService._saveAuthData() → SharedPreferences.setString('auth_token', token)
↓
(next app launch) AuthService.getToken() reads it back
↓
AuthNotifier._initializeAuth() checks isJwtExpired(token)
↓
ApiService's request interceptor reads it on every future authenticated call → Authorization: Bearer <token> header
```

## 10. Mobile UI

`[OLD/SOURCE]` `LoginScreen` is a `Row` split 58%/42% — a wide branding
panel (gradient background, a live Unsplash network image, decorative
circles, marketing copy, feature pills, footer copyright) on the left, and
the actual form in a white rounded card on the right. That layout assumes
a desktop/tablet-width viewport; on a phone in portrait it would either
crush the branding panel to nothing or force the form into a sliver too
narrow to use.

The mobile port drops the two-panel split entirely and uses a single
centered column, scrollable (`SingleChildScrollView`) so it still works
with the on-screen keyboard open on a small phone, capped at 420 logical
pixels wide (`ConstrainedBox`) so it doesn't stretch awkwardly on a
tablet/landscape. It keeps: the branded "K" logo mark, welcome
text/subtitle, the two form fields with identical validation rules, the
password visibility toggle, and the LOGIN button with the identical
loading-spinner behavior.

It intentionally drops: the background image, gradient panel, decorative
circles, feature pills, footer copyright text (all purely decorative, no
functional role), and the "Remember me" checkbox / "Forgot password" link
/ "Register" link — every one of which is a **non-functional stub** in
`[OLD/SOURCE]` (`onChanged: (_) {}` / `onTap: () {}`, literally no-ops).
Dropping non-functional decorative stubs on a space-constrained screen is a
UI adaptation, not a business-logic change — there was no real "forgot
password" or "register" flow to preserve.

Portrait is the only orientation actually exercised (a login form has no
meaningful landscape-specific layout need); the `SingleChildScrollView` +
`ConstrainedBox` combination degrades gracefully in landscape without
needing a separate branch. No Android/iOS-specific code was needed — this
screen is pure Flutter widgets with `autofillHints` for platform password
manager integration on both platforms.

## 11. API

METHOD: `POST`
PATH: `/api/auth/login`
REQUEST:
```json
{ "email": "string (required, valid email)", "password": "string (required)", "terminalId": "string (optional)" }
```
RESPONSE (200):
```json
{ "token": "string (JWT)", "user": { "id": 1, "email": "string", "fullName": "string", "roles": ["string"], "permissions": ["string"] } }
```
RESPONSE (400, invalid credentials / locked / inactive user):
```json
{ "message": "Invalid credentials" }
```
Flutter caller: `AuthService.login()` → `ApiService.post<Map<String, dynamic>>('/api/auth/login', data: request.toJson())`.
Backend controller: `AuthController.login()` (`com.kaknnea.pos.controller.AuthController`).
Backend service: `AuthService.login()` (`com.kaknnea.pos.service.AuthService`) — validates the user exists, isn't locked out, isn't inactive, checks the password hash, tracks failed-attempt lockout (5 attempts → 15 minute lock), updates `lastLoginAt`/`lastLoginTerminal`, issues the JWT via `JwtUtil`, and audits the attempt via `LoginAuditRepository` regardless of outcome.

No endpoint, field, or status code above was invented — all confirmed by reading `AuthController.java`, `AuthDtos.java`, `AuthService.java`, and `GlobalExceptionHandler.java` directly.

## 12. Error Handling

- **Loading**: `authState.isLoading` (true while `AuthNotifier.login()`'s
  `state = AsyncValue.loading()` is current) disables the LOGIN button and
  swaps its label for a `CircularProgressIndicator`.
- **Success**: state becomes `AsyncValue.data(user)`; `_login()` navigates
  away.
- **Validation error** (empty email/password, password < 6 chars): handled
  entirely client-side by `TextFormField.validator` + `_formKey.validate()`
  — no network call is made at all.
- **API error / network error / unauthorized**: `ApiService._handleError()`
  maps every `DioException` to a friendly `ApiException.message` (e.g. 400
  "Invalid credentials" is extracted straight from the backend's JSON
  `message` field; a connection timeout becomes "Connection timeout"). This
  exception is thrown out of `AuthService.login()`.
- **Empty state**: not applicable to this screen (nothing to be "empty" —
  it's always either the form or (briefly) a spinner).

**Problems Found (real, source-inherited defect — not fixed here, per the
source-of-truth rule):** `AuthNotifier.login()` catches its own exception
and stores it as `AsyncValue.error(error, stackTrace)` — it never
rethrows. `LoginScreen._login()`'s `try { await ...login(); nav } catch
(error) { showSnackBar }` therefore has an **unreachable catch block**:
`await ref.read(authProvider.notifier).login(...)` can never throw, so
every call to `_login()` always reaches the `if (mounted)
Navigator.of(context).pushReplacementNamed(...)` line, success or failure
alike. Concretely:

- The "Login failed" SnackBar the UI is clearly designed to show **never
  appears**, in either the source project or this port (verified in
  `test/login_screen_test.dart`'s third test, which reproduces this exactly
  and asserts the SnackBar does NOT appear — a passing assertion, because
  this is the actual current behavior).
- In `frontend_flutter_mobile`, this is **currently benign**: `_login()`
  calls `pushReplacementNamed('/')`, and `MobileApp.home` re-evaluates
  `authProvider` (still `AsyncValue.error`, which falls into `orElse` →
  `LoginScreen`) — so a failed login harmlessly re-lands on the login form,
  just silently, with no error message.
- In `frontend-flutter-pos` (desktop), this is **not obviously benign**:
  `_login()` calls `Navigator.of(context).pushReplacementNamed('/pos')`,
  and `/pos` is a **fixed named route** (`'/pos': (context) =>
  const PosScreen()`) with no auth check inside `PosScreen` observed during
  this investigation — meaning a failed login attempt may navigate an
  unauthenticated user straight into the POS screen. This was NOT
  independently verified end-to-end against a running desktop build (out
  of scope for a mobile-focused day), but the code path is unambiguous:
  `login()` swallows the exception, `_login()`'s `catch` is unreachable,
  and the navigation call is unconditional. **This should be flagged to
  whoever owns `frontend-flutter-pos` as a real bug** — not fixed here,
  since fixing `frontend-flutter-pos` is explicitly out of scope for this
  task, and fixing it silently only in the mobile port would mean the two
  apps' auth flows diverge without that divergence being a deliberate,
  reported decision.

## 13. State Management

Provider: `authProvider` = `StateNotifierProvider<AuthNotifier,
AsyncValue<User?>>`.
State shape: `AsyncValue<User?>` — `loading` during startup and during a
login/logout call in flight, `data(null)` when logged out, `data(User)`
when logged in, `error` when `_initializeAuth()` itself throws
unexpectedly (rare — the method has its own internal try/catch for the
normal "no session"/"expired" paths).

`ref.watch(authProvider)`: `LoginScreen.build()` (drives the button's
loading state) and `MobileApp.build()` (drives the `home:` gate).
`ref.read(authProvider.notifier)`: `LoginScreen._login()` (`.login()`) and
`ThemeDemoScreen.build()`'s new logout button (`.logout()`).
`ref.watch(currentUserProvider)`: `ThemeDemoScreen.build()` (the new
"Logged in as ..." banner) — a derived `Provider<User?>` that unwraps
`authProvider`'s `AsyncValue` via `.maybeWhen`, so consumers that only care
about "who" (not "is it loading/erroring") don't have to pattern-match the
`AsyncValue` themselves.

Invalidation/rebuild: Riverpod rebuilds any widget that `ref.watch()`s
`authProvider` (or a provider derived from it) automatically whenever
`AuthNotifier.state` is reassigned — there is no manual
`ref.invalidate()`/`ref.refresh()` anywhere in this flow; every state
transition is a direct `state = ...` assignment inside `AuthNotifier`.

## 14. Testing

`frontend_flutter_mobile/test/auth_provider_test.dart` (NEW) — ported from
`frontend-flutter-pos/test/auth_provider_test.dart`'s fake-JWT-token +
fake-`AuthService` pattern, extended with login/logout/derived-provider
coverage:
- no cached token → stays logged out
- expired cached token → logs out and stays logged out
- valid cached token → restores the cached user
- successful `login()` sets state to the returned user
- failed `login()` surfaces the error via `AsyncValue.error` (confirms the
  swallow-not-rethrow behavior at the provider level, independent of the
  UI-level dead-catch-block finding above)
- `logout()` clears state and delegates to `AuthService.logout()`
- `currentUserProvider`/`isAuthenticatedProvider` reflect the underlying
  state

`frontend_flutter_mobile/test/login_screen_test.dart` (NEW):
- shows validation errors for empty email/password (no network call)
- reproduces the "Problems Found" defect (SnackBar never appears on a
  failed login) — a passing assertion that documents actual behavior
- successful login swaps `MobileApp.home` from `LoginScreen` to
  `ThemeDemoScreen`, exercised through the real `MobileApp` widget (not a
  hand-rolled route table) so the assertion reflects real navigation
  behavior, not a test-only stand-in

`frontend_flutter_mobile/test/widget_test.dart` (MODIFIED) — Day 3's smoke
test updated to assert `LoginScreen` (not `ThemeDemoScreen`) is the default
boot screen.

All tests are in `frontend_flutter_mobile/test/` — none were added to
`frontend-flutter-pos/test/`.

## 15. Verification

```text
$ flutter analyze
Analyzing frontend_flutter_mobile...
No issues found! (ran in 1.5s)

$ flutter test
00:02 +26: All tests passed!
```

26 tests total in the full suite after this day's additions (7 new in
`auth_provider_test.dart`, 3 new in `login_screen_test.dart`, plus the
pre-existing Day 1–3 tests, all still passing including the corrected
`widget_test.dart`).

`flutter run` against a live backend was NOT performed in this session (no
interactive device/emulator available) — the login flow was verified
end-to-end at the unit/widget-test level (real request/response shape,
real error-mapping code paths, real navigation code paths, all exercised
via fakes that mirror the actual `AuthService`/backend contract exactly).
This is recorded honestly, not claimed as a live device run.

## 16. Definition of Done

- [x] `AppConfig`, `ApiService`, `auth_models.dart`, `AuthService`,
      `AuthNotifier`, `jwt_utils.dart` ported and traced back to source
      function-by-function
- [x] `LoginScreen` built for phone screens (not a shrunk desktop copy)
- [x] `MobileApp.home` gates on `authProvider` exactly like source's
      `PosApp.build()`
- [x] Login screen tracks the configurable main color via
      `Theme.of(context).colorScheme.primary` (never hardcodes a brand
      color) — consistent with the recent `frontend-flutter-pos` change
      listed in this task's "IMPORTANT RECENT CHANGES"
- [x] Startup JWT-expiry guard ported and unit-tested
- [x] `flutter analyze` clean
- [x] `flutter test` — 26/26 passing
- [x] Real defect found in source auth flow, documented, NOT silently
      fixed
- [ ] `flutter run` against a live backend (not performed — no device
      available this session)

## 17. What I Should Understand Before Moving to Day 5

`authProvider` is now the single source of truth for "is anyone logged
in" — `MobileApp.home`'s gate is the ONLY place that decision currently
gets made, and it's a blunt two-way switch (`LoginScreen` vs.
`ThemeDemoScreen`). Day 5 replaces that blunt switch with a real named-route
navigation shell (mirroring `[OLD/SOURCE]` `main.dart`'s `routes` table),
and needs to decide where the auth gate lives once there's more than one
authenticated destination — presumably still in `MobileApp.home`, with the
named routes underneath it assuming an authenticated `authProvider` state
rather than each independently re-checking it. `ApiService.onUnauthorized`
is already wired (this day, to `authProvider.notifier.logout()`, matching
source) — Day 5 doesn't need to revisit that, only build the real
destinations it routes back from.
