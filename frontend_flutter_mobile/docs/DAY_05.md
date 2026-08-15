# Day 5 — Mobile Navigation Shell

## 1. Goal

Give the mobile app a real post-login home — replacing Day 3/4's temporary
`ThemeDemoScreen` placeholder with the actual navigation shell a cashier
will use — and register the routing infrastructure Days 6-10 will hang
their screens off of. This day builds the SHELL only: chrome, tabs,
navigation wiring. It does not build product grids, cart, tables, tickets,
customers, or shifts — those are Days 6-10, and every destination this
shell exposes that isn't built yet renders an explicit, labelled
placeholder rather than pretending to be finished.

## 2. Source Project Investigation

```text
frontend-flutter-pos/lib/main.dart                              (the flat ~35-entry `routes` table + `home:` auth gate)
frontend-flutter-pos/lib/features/pos/screens/pos_screen.dart    (Scaffold(appBar: _PosAppBar(), drawer: PosDrawer()) — confirms the drawer is the actual top-level nav mechanism)
frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart   (the real, ACTIVE PosDrawer class starts at line 607 — lines 1-606 are old, fully commented-out dead code kept in the same file; only the class at line 607 is used)
```

`PosDrawer` (the real one, from line 607) contents actually traced:
header (business name via `watchCompanyName`, static "Online · Cashier"
status), then a flat list of nav tiles/expansion menus: Register (`pos`),
Held Tickets (`open-tickets`), Inventory Management (expansion, several
sub-routes), Receipts (`receipts`), Reports (expansion), Items (expansion),
Employees (expansion), Customers (expansion), Tables (expansion), Shifts
(expansion) — roughly 10 top-level entries plus their sub-menus, all
reachable via one permanent hamburger-triggered drawer, appropriate for a
desktop/tablet-width screen where the drawer can stay one tap away from
anywhere.

## 3. Mobile Target

```text
frontend_flutter_mobile/lib/features/shell/mobile_shell_screen.dart   (NEW)
frontend_flutter_mobile/lib/main.dart                                  (MODIFIED — home: now MobileShellScreen when logged in)
frontend_flutter_mobile/lib/l10n/app_en.arb                            (MODIFIED — added navMore)
frontend_flutter_mobile/lib/l10n/app_km.arb                            (MODIFIED — added navMore)
frontend_flutter_mobile/test/mobile_shell_screen_test.dart             (NEW)
frontend_flutter_mobile/test/login_screen_test.dart                    (MODIFIED — post-login assertion now checks MobileShellScreen)
```

## 4. Architecture Flow

```text
MobileApp.home (authState.maybeWhen)
    ↓ (user != null)
MobileShellScreen
    ↓
NavigationBar (bottom nav) selects one of 4 destinations, held in local State (_index)
    ↓
IndexedStack shows the selected destination's body
    ↓
"More" tab → _MoreTab → ListView of secondary destinations
    ↓ (tap Logout)
ref.read(authProvider.notifier).logout()
    ↓
AuthNotifier.logout() → AuthService.logout() (clears SharedPreferences) → state = AsyncValue.data(null)
    ↓
MobileApp rebuilds → home: re-evaluates → LoginScreen
```

No backend/API layer is involved in this day at all — this is pure
client-side navigation chrome. The only backend-touching call reachable
from this screen is the already-existing `AuthService.logout()` (Day 4),
which itself makes no network call (it's a local SharedPreferences clear).

## 5. Files To Create

**`frontend_flutter_mobile/lib/features/shell/mobile_shell_screen.dart`**
Purpose: the post-login navigation shell.
Classes: `MobileShellScreen`/`_MobileShellScreenState` (the
`NavigationBar` + `IndexedStack` shell), `_MoreTab` (the drawer-overflow
stand-in list), `_ComingSoon` (explicit placeholder for any destination a
later day hasn't built yet).
Important functions: `_MobileShellScreenState.build()` (assembles the 4
destinations and their bodies), `_MoreTab.build()`, `_MoreTab._openComingSoon()`.

**`frontend_flutter_mobile/test/mobile_shell_screen_test.dart`**
Purpose: covers tab switching, the More tab's contents, and the full
logout round-trip through the real `MobileApp` (not just the shell in
isolation).

## 6. Files To Modify

**`frontend_flutter_mobile/lib/main.dart`**
Existing: `home:`'s logged-in branch built `const ThemeDemoScreen()`.
Change: now builds `const MobileShellScreen()`. Why: this is the actual
Day 5 deliverable — without it, `MobileShellScreen` would exist as a file
but never be reachable. `ThemeDemoScreen` itself was NOT deleted — it's
still reachable via the shell's More tab ("Theme / language demo" entry),
since it remains a genuinely useful manual QA tool for the main-color/
language/dark-mode/Khmer-scaling work Day 3 built.

**`frontend_flutter_mobile/lib/l10n/app_en.arb` / `app_km.arb`**
Existing: no `navMore` key (checked — it doesn't exist in
`[OLD/SOURCE]`'s ARB files either, since the desktop UI has no "More tab"
concept at all).
Change: added `"navMore": "More"` / `"navMore": "ច្រើនទៀត"`. Why: this is
a genuinely NEW mobile-only UI string, not a reused one — flagged
explicitly rather than silently added, and regenerated via `flutter
gen-l10n` (the generated `app_localizations*.dart` files were never
hand-edited).

**`frontend_flutter_mobile/test/login_screen_test.dart`**
Existing: the "successful login" test asserted `find.byType(ThemeDemoScreen)`
appears post-login.
Change: now asserts `find.byType(MobileShellScreen)` instead. Why: direct
consequence of the `main.dart` change above — this is not this test file's
own design decision.

## 7. Functions

### Function: `_MobileShellScreenState.build(context)`

FILE: `frontend_flutter_mobile/lib/features/shell/mobile_shell_screen.dart`
CLASS: `_MobileShellScreenState`
SIGNATURE: `Widget build(BuildContext context)`
CALLED BY: the Flutter framework, whenever `MobileShellScreen` needs to
rebuild (locale change, `_index` change via `setState`, theme change).
CALLS: `context.l10n` (per-destination labels), `IndexedStack`,
`NavigationBar`.
INPUT: none beyond `context`.
OUTPUT: a `Scaffold` with an `AppBar` (title = current destination's
label), an `IndexedStack` body, and a `NavigationBar`.
STATE CHANGES: none directly — `onDestinationSelected` calls
`setState(() => _index = i)`.
UI EFFECT: tapping a `NavigationDestination` swaps which of the 4 bodies
is visible (all 4 stay mounted via `IndexedStack`, so tab state — e.g. a
scroll position — isn't lost when switching away and back; relevant once
Days 6-10 replace the placeholders with real, potentially-scrollable
content).

NEW FUNCTION.

### Function: `_MoreTab.build(context, ref)`

FILE: `frontend_flutter_mobile/lib/features/shell/mobile_shell_screen.dart`
CLASS: `_MoreTab`
SIGNATURE: `Widget build(BuildContext context, WidgetRef ref)`
CALLED BY: `IndexedStack` when the More tab (index 3) is selected.
CALLS: `ref.watch(currentUserProvider)` (Day 4), `context.l10n`,
`_openComingSoon()`, `ref.read(authProvider.notifier).logout()` (Day 4).
INPUT: none beyond `context`/`ref`.
OUTPUT: a `ListView` of `ListTile`s.
STATE CHANGES: none of its own — logout mutates `authProvider`'s state
(Day 4's `AuthNotifier.logout()`).
UI EFFECT: tapping Customers/Shifts/Settings pushes a `_ComingSoon` route;
tapping Logout triggers the full sign-out flow described in section 8.

NEW FUNCTION.

## 8. User Click Flow

```text
User taps "More" (bottom nav)
↓
onDestinationSelected(3) → setState(() => _index = 3)
↓
IndexedStack shows _MoreTab
↓
User taps "Logout"
↓
ref.read(authProvider.notifier).logout()
↓
AuthNotifier.logout()  (Day 4 — REUSE EXISTING FUNCTION, no changes)
↓
AuthService.logout()  — SharedPreferences.remove('auth_token'), remove('user_data')
↓
AuthNotifier state = AsyncValue.data(null)
↓
MobileApp (ConsumerWidget, watches authProvider) rebuilds
↓
home: authState.maybeWhen(data: (user) => user != null ? Shell : Login, orElse: () => Login) → user is null → LoginScreen
```

Note there is no explicit `Navigator.push`/`pushReplacementNamed` call
anywhere in this flow (unlike Day 4's login flow) — `MobileApp` itself is
the thing rebuilding `home:`, and because `MobileShellScreen` IS the
current default route's content, a plain provider-driven rebuild is
sufficient to swap it for `LoginScreen`. (This is different from Day 4's
`_login()`, which explicitly calls `pushReplacementNamed('/')` — needed
there because a route had already been imperatively PUSHED via
`pushReplacementNamed` during the login attempt itself; here, nothing was
ever pushed on top of `home:`, so there's no stale route to replace.)

## 9. Data Flow

```text
current tab index (int)
↓
_MobileShellScreenState._index (local State, not a provider — no other
  widget needs to know or react to which tab is selected, so this is
  correctly local UI state, not global app state)
↓
IndexedStack.index
↓
visible destination body (a _ComingSoon placeholder for every destination
  in this task's Day 4-10 scope except Register, which will become real
  content once Day 6/7 land)
```

```text
logged-in user's display name
↓
currentUserProvider (Day 4, derived from authProvider)
↓
ref.watch(currentUserProvider) in _MoreTab.build()
↓
Text(currentUser.fullName)
```

## 10. Mobile UI

`[OLD/SOURCE]`'s navigation is a permanent `Scaffold.drawer` (`PosDrawer`)
holding ~10 top-level items plus several expansion sub-menus, reachable
from `PosScreen` via a hamburger icon, layered under a flat 35-entry named
`routes` table in `main.dart` covering every screen in the whole desktop
app (POS, inventory, reports, employees, settings — everything).

That shape doesn't fit a phone. A drawer with 10+ items plus sub-menus
demands either a lot of scrolling or deep nesting on a 6" screen, and
`main.dart`'s 35-route table spans far more screens than a phone cashier
app needs open concurrently (most of those routes are desktop-oriented
back-office screens — inventory counts, PDF reports, employee/role
management — genuinely out of THIS task's Day 4-10 scope regardless of
device).

The mobile shell instead uses a **bottom `NavigationBar`** with 4
destinations — Register, Tables, Held Tickets, More — the handful of
screens a cashier actually taps between many times per shift, each one
reachable in a single tap with no drawer-open gesture needed, which is the
better-fit pattern for one-handed phone use (and matches the mobile
patterns of the Loyverse-style POS apps this project already cites as its
design inspiration in `pos_theme.dart`). The **More** tab is a plain
full-screen `ListView` standing in for the drawer's overflow items
(Customers, Shifts, Settings, and now Logout) — a common "5th tab as
overflow menu" mobile pattern, chosen over ALSO adding a literal
`Scaffold.drawer` since a 4-destination bottom nav plus a dedicated More
list already covers every destination without needing two redundant
navigation surfaces for the same handful of items. This is a **deliberate,
reported UI adaptation** — not a business-logic change (nothing about
what a cashier can DO changes, only how many taps it takes to get there)
and not a silently-invented pattern (it directly answers the task's own
"bottom navigation where appropriate... drawers where appropriate"
instruction by choosing the one that fits a phone screen, rather than
reproducing both desktop navigation surfaces verbatim).

Portrait is the primary target (a bottom nav bar is a portrait-first
pattern); no landscape-specific layout was added since none of this day's
content (placeholders + a list) has landscape-sensitive layout needs — the
same `IndexedStack`/`ListView` structure works unchanged in landscape,
just wider.

## 11. API

None. This day makes no new network calls — `AuthService.logout()`
(exercised by the Logout tile) is Day 4's existing local-only
SharedPreferences clear, not a backend call.

## 12. Error Handling

Not meaningfully applicable — there's no async/network work in this shell
itself. The one state-changing action (Logout) reuses Day 4's
`AuthNotifier.logout()`, which has no failure path of its own (clearing
local storage keys doesn't throw in normal operation).

## 13. State Management

`_index` (current tab): local `State<MobileShellScreen>` field, mutated
via `setState()` — correctly NOT a Riverpod provider, since no other part
of the app needs to read or react to which bottom-nav tab is currently
selected.

`currentUserProvider` (Day 4): `ref.watch()`'d in `_MoreTab.build()` to
show the logged-in user's name — rebuilds `_MoreTab` if the user object
ever changes (it won't, in the current app, without a logout/re-login,
but this is the correct reactive read regardless).

`authProvider` (Day 4): `ref.read(authProvider.notifier).logout()` in the
Logout tile's `onTap` — a one-shot write, not watched here (this widget
doesn't need to rebuild when the state changes; `MobileApp`, which DOES
watch it, is what reacts and swaps the screen away).

## 14. Testing

`frontend_flutter_mobile/test/mobile_shell_screen_test.dart` (NEW):
- all 4 bottom nav destinations render, Register selected by default
- switching tabs swaps the visible destination (Tables' placeholder
  replaces Register's)
- the More tab lists Customers/Shifts/Settings placeholders, the
  logged-in user's name, and a Logout tile
- tapping a More-tab placeholder (Customers) opens the correct `_ComingSoon`
  screen labelled "Day 9"
- tapping Logout calls the (faked) `AuthService.logout()`
- end-to-end: logging out from inside the real `MobileApp` (not the shell
  in isolation) correctly returns to `LoginScreen`

`frontend_flutter_mobile/test/login_screen_test.dart` (MODIFIED, see
section 6).

All tests are in `frontend_flutter_mobile/test/`.

## 15. Verification

```text
$ flutter analyze
Analyzing frontend_flutter_mobile...
No issues found! (ran in 1.5s)

$ flutter test
00:02 +32: All tests passed!
```

32 tests total after this day's additions (6 new in
`mobile_shell_screen_test.dart`, all Day 1-4 tests still passing).

`flutter run` against a device/emulator was NOT performed this session
(none available) — recorded honestly, not claimed.

## 16. Definition of Done

- [x] `MobileShellScreen` built with a bottom `NavigationBar` (4
      destinations) — phone-appropriate, not a shrunk drawer
- [x] `MobileApp.home` routes to the shell post-login
- [x] Every not-yet-built destination shows an explicit, correctly-labelled
      placeholder — nothing silently faked as complete
- [x] Logout is fully functional end-to-end (shell → `AuthNotifier` →
      `AuthService` → back to `LoginScreen`)
- [x] `ThemeDemoScreen` (Day 3) preserved and still reachable, not deleted
- [x] One new, explicitly-flagged l10n key (`navMore`) added via the ARB
      files + `flutter gen-l10n`, no generated file hand-edited
- [x] `flutter analyze` clean
- [x] `flutter test` — 32/32 passing
- [ ] `flutter run` against a live device (not performed — none available
      this session)

## 17. What I Should Understand Before Moving to Day 6

The Register tab's body is currently a `_ComingSoon` placeholder — Day 6
replaces exactly that one widget (`destinations[0].body` in
`_MobileShellScreenState.build()`) with the real product grid / POS
register screen, and nothing else in this file should need to change to
make that swap (the tab/label/icon plumbing is already correct). The
Tables and Held Tickets tabs are Day 9 scope, not Day 6 — don't be tempted
to build them early just because their tab already exists; the tab
existing is exactly this day's job, filling it in is a later day's. The
`_ComingSoon` placeholder pattern (day label + feature name) should be
reused verbatim for any other not-yet-built destination Days 6-10
introduce, rather than inventing a second placeholder style.
