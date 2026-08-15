# Day 3 — Theme and Localization Foundation

## Goal

Per the task instructions, Day 3 studies the CURRENT `frontend-flutter-pos` implementation of the configurable main-app-color system, dark/light theming, Khmer typography scaling, and localization — then creates the equivalent **foundation** (not the full Settings UI, not the real Login/POS shell) inside `frontend_flutter_mobile`. Scope boundary, explicit: no products/cart/payment/receipt/printer/inventory/reports/full-Settings screens today — only the theme/localization architecture those screens will later consume, plus the minimum test/demo control needed to verify it works.

## Source Files Studied

**[OLD/SOURCE — READ]**
- `frontend-flutter-pos/lib/core/config/pos_theme.dart`
- `frontend-flutter-pos/lib/core/providers/main_color_provider.dart`
- `frontend-flutter-pos/lib/core/providers/theme_provider.dart`
- `frontend-flutter-pos/lib/core/providers/language_provider.dart`
- `frontend-flutter-pos/lib/core/utils/khmer_text_scaler.dart`
- `frontend-flutter-pos/lib/core/utils/l10n_extensions.dart`
- `frontend-flutter-pos/lib/main.dart` (the exact `PosApp.build` wiring, re-verified against Day 1's notes)
- `frontend-flutter-pos/lib/features/pos/screens/settings_modules_screen.dart` (main-color swatch picker UI, for the *pattern* only — not copied, since full Settings is Day 19)
- `frontend-flutter-pos/l10n.yaml`, `frontend-flutter-pos/lib/l10n/app_en.arb` (2548 lines), `frontend-flutter-pos/lib/l10n/app_km.arb` (1249 lines)

## Current Source Main-Color Architecture

Exact names, verified by direct read (not assumed from the plan doc):

- **State owner**: `MainColorNotifier extends StateNotifier<Color>` in `core/providers/main_color_provider.dart`, exposed via `final mainColorProvider = StateNotifierProvider<MainColorNotifier, Color>(...)`.
- **Palette**: `const List<Color> kMainColorOptions` — exactly 6 entries: green `0xFF4CAF50` (default/index 0), blue `0xFF2196F3`, purple `0xFF9C27B0`, orange `0xFFFF9800`, red `0xFFE53935`, teal `0xFF009688`.
- **Persistence key**: `'app_main_color'` (SharedPreferences, `prefs.getInt`/`setInt` storing the color's raw ARGB int value) — device-local only, no backend "appearance" endpoint exists (same OFFLINE pattern as `language_provider.dart`).
- **Resolved-color holder**: `PosTheme._mainColor` (a private static `Color` field) with `PosTheme.primaryGreen`/`primaryGreenDark`/`primaryGreenLight` as **getters, not `const`** — this is the key architectural trick: ~150 existing call sites across the source app read `PosTheme.primaryGreen` and pick up a new color automatically the instant `PosTheme.applyMainColor()` runs, with zero per-call-site changes.
- **UI**: `settings_modules_screen.dart` renders `kMainColorOptions.map(...)` as tappable swatches; tap → `ref.read(mainColorProvider.notifier).setMainColor(color)`. This UI is Day 19 scope — not built today, only its *pattern* (swatch → `setMainColor`) is reused in the temporary demo screen.

## Mobile Main-Color Architecture

**[NEW/MOBILE — CREATE]** `frontend_flutter_mobile/lib/core/providers/main_color_provider.dart` — **COPY/ADAPT nearly exactly**, same class/provider/palette/key names, same OFFLINE SharedPreferences pattern. One adaptation: `color.value` (deprecated in the Flutter version this project's SDK constraint resolves to) replaced with `color.toARGB32()` — identical semantics, no behavior change, just the modern non-deprecated API.

**[NEW/MOBILE — CREATE]** `frontend_flutter_mobile/lib/core/config/pos_theme.dart` — **COPY/ADAPT nearly exactly**: same `_mainColor` getter-backed-by-mutable-field pattern, same `applyMainColor`, same semantic-color constants (`errorRed`/`warningAmber`/`successGreen` — untouched, independent of the main color by design), same spacing/radius/font-size scale, same `lightTheme`/`darkTheme` structure including the `fontFamilyFallback: ['NotoSansKhmer']` line. Two modernizations (same reasoning as above, no behavior change): `Colors.black.withOpacity(x)` → `Colors.black.withValues(alpha: x)`.

## Theme Function Flow

```
FILE:     lib/core/config/pos_theme.dart
CLASS:    PosTheme
FUNCTION: static void applyMainColor(Color color)
INPUT:    Color (from mainColorProvider's current state)
CALLS:    nothing — just reassigns the private static field
OUTPUT:   none
STATE CHANGE: PosTheme._mainColor := color
UI EFFECT: every subsequent PosTheme.primaryGreen/primaryGreenDark/primaryGreenLight
           read (used throughout lightTheme/darkTheme's ColorScheme.fromSeed, AppBarTheme,
           ElevatedButtonTheme, InputDecorationTheme, ChipTheme, etc.) reflects the new color
SOURCE OR TARGET: NEW/MOBILE (ported verbatim from OLD/SOURCE)
WHY: a static mutable field + getters (not `const` colors) is what makes an app-wide color
     change effective without threading the color through every widget's constructor.
```

```
FILE:     lib/main.dart
CLASS:    MobileApp extends ConsumerWidget
FUNCTION: Widget build(BuildContext context, WidgetRef ref)
INPUT:    BuildContext, WidgetRef
CALLS:    PosTheme.applyMainColor(ref.watch(mainColorProvider)) → MaterialApp(theme: PosTheme.lightTheme,
          darkTheme: PosTheme.darkTheme, themeMode: ref.watch(themeModeProvider).value, ...)
OUTPUT:   MaterialApp widget
STATE CHANGE: none in MobileApp itself; re-applies PosTheme's mutable color on every rebuild
UI EFFECT: rebuilds the whole MaterialApp — and therefore every screen's theme-derived
           colors — whenever mainColorProvider, themeModeProvider, or appLanguageProvider change
SOURCE OR TARGET: NEW/MOBILE (mirrors OLD/SOURCE PosApp.build's theme-wiring lines exactly;
                  the auth-gated `home:` itself is Day 4/5 scope, not reproduced today)
WHY: this is the single point where "provider state changed" becomes "theme visibly changed" —
     same function of the same name serves both projects.
```

## Persistence Flow

```
Settings/demo swatch tap
↓
ref.read(mainColorProvider.notifier).setMainColor(color)
↓
MainColorNotifier.setMainColor(color)      [state = color; then persists]
↓
state = color                               → Riverpod notifies watchers immediately (synchronous)
↓
SharedPreferences.getInstance() → prefs.setInt('app_main_color', color.toARGB32())   [async, fire-and-persist]
↓
MobileApp.build (watching mainColorProvider) rebuilds → PosTheme.applyMainColor(color) → MaterialApp rebuilt
↓
On next app cold start: MainColorNotifier() constructor → _loadPreference() →
  prefs.getInt('app_main_color') → match against kMainColorOptions → state = matched color
  (or kMainColorOptions.first if nothing saved / no match)
```
Note the ordering: **state updates before the disk write completes** — so the UI reacts instantly (no waiting on I/O) and the persistence is a background concern. This is identical in OLD/SOURCE and NEW/MOBILE.

## Khmer Typography Flow

```
FILE:     lib/core/utils/khmer_text_scaler.dart
CLASS:    KhmerTextScaler extends TextScaler
FUNCTION: double scale(double fontSize)
INPUT:    a nominal font size (from any Text widget's effective style, via the ambient TextScaler)
CALLS:    _base.scale(fontSize) first (respects the OS/user accessibility text-size setting),
          then adds a flat +2/+3/+0 offset depending on the scaled size band
OUTPUT:   the final font size Flutter actually renders at
STATE CHANGE: none (pure function)
UI EFFECT: every Text/RichText/EditableText in the widget subtree wrapped by the
           MaterialApp.builder's MediaQuery renders Khmer text 2-3px larger than English
SOURCE OR TARGET: NEW/MOBILE (ported near-verbatim from OLD/SOURCE — the plan's own guidance
                  is to port this file "close to verbatim rather than inventing a separate
                  scaling scheme", followed exactly: only a `// ignore: deprecated_member_use`
                  comment was added on the required `textScaleFactor` override, no logic changed)
WHY: a flat, band-based offset (not a multiplicative TextScaler.linear) avoids over-inflating
     large headings and under-inflating small labels relative to each other — Khmer glyphs read
     smaller than Latin at the same nominal size, so this compensates without distorting the
     overall type scale.
```
Bands: `scaled >= 28` → unchanged (large display text — cart totals, hero numbers, deliberately left alone to avoid layout overflow); `20 <= scaled < 28` → `+3`; `scaled < 20` → `+2`.

```
FILE:     lib/main.dart
FUNCTION: MobileApp.build's `builder:` callback
INPUT:    BuildContext, Widget child
CALLS:    khmerAwareTextScaler(MediaQuery.of(context).textScaler, isKhmer: ref.watch(appLanguageProvider).isKhmer)
OUTPUT:   a MediaQuery wrapping `child` with the (possibly Khmer-adjusted) textScaler
UI EFFECT: applies (or doesn't) the Khmer offset to the ENTIRE app UI subtree in one place —
           no per-widget font-size changes anywhere
SOURCE OR TARGET: NEW/MOBILE (identical wiring to OLD/SOURCE PosApp.build)
WHY: centralizing this in MaterialApp.builder is exactly what avoids "manually increasing
     hundreds of TextStyle font sizes" — the task's explicit instruction.
```
**Printing typography separation (verified, not touched today)**: this mechanism only wraps the app's on-screen widget tree via `MaterialApp.builder`. Receipt/PDF/thermal/ESC-POS/A4-report typography (Day 1's Printing Flow — `ReceiptContent`, `EscPosReceiptBuilder`, `A4ReportPdf`, `KhmerTextRasterizer`) renders through an entirely separate `package:pdf` widget system with its own literal font sizes and has **zero code-path connection** to `khmerAwareTextScaler` — confirmed by inspection, no shared function/class between the two systems. Nothing under `services/printing/` was touched today.

## Localization Flow

```
FILE:     l10n.yaml (mobile's own copy, identical config to source)
CONTENT:  arb-dir: lib/l10n, template-arb-file: app_en.arb, output-class: AppLocalizations,
          output-dir: lib/l10n/generated, nullable-getter: false
↓
lib/l10n/app_en.arb, app_km.arb   (seeded — own copies of source's translated strings,
                                    not shared files, per Day 1's OLD→NEW mapping decision)
↓
$ flutter gen-l10n   (or automatic via pubspec's `generate: true`, added today)
↓
lib/l10n/generated/app_localizations.dart, app_localizations_en.dart, app_localizations_km.dart
  (generated — NOT committed as hand-written source, regenerated by tooling; confirmed the task
  instruction "do NOT copy generated localization Dart files" was followed — these were
  generated by running the CLI in the mobile project, never copied from frontend-flutter-pos)
↓
lib/core/utils/l10n_extensions.dart  →  context.l10n  (ergonomic shorthand for
                                          AppLocalizations.of(context))
↓
MaterialApp(supportedLocales: [en, km], localizationsDelegates: [AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate], locale: ref.watch(appLanguageProvider).toLocale())
↓
appLanguageProvider (AppLanguageNotifier, SharedPreferences key 'app_language', OFFLINE,
  same pattern as mainColorProvider) drives MaterialApp.locale directly
```
`themeProvider ↓ MaterialApp.theme` and `languageProvider ↓ MaterialApp.locale` are both wired in the same `MobileApp.build` function (see Theme Function Flow above) — one function is the single point where both provider families become visible app state.

## Files Created

**[NEW/MOBILE]**, all under `frontend_flutter_mobile/`:
- `lib/core/config/pos_theme.dart`
- `lib/core/providers/main_color_provider.dart`
- `lib/core/providers/theme_provider.dart`
- `lib/core/providers/language_provider.dart`
- `lib/core/utils/khmer_text_scaler.dart`
- `lib/core/utils/l10n_extensions.dart`
- `lib/core/dev/theme_demo_screen.dart` — **temporary**, explicitly documented in its own file header as a Day 3 verification-only screen, not the real app shell; exercises the color palette, language toggle, and light/dark toggle so the foundation can be checked by hand. Will be discarded once Day 4/5 (real Login/POS shell) and Day 19 (real Settings color picker) exist.
- `l10n.yaml`
- `lib/l10n/app_en.arb`, `lib/l10n/app_km.arb` (seeded copies)
- `lib/l10n/generated/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_km.dart` (generated by `flutter gen-l10n`, not hand-written or copied)
- `test/main_color_provider_test.dart`, `test/khmer_text_scaler_test.dart`, `test/localization_test.dart`
- `docs/DAY_03_THEME_LOCALIZATION_FOUNDATION.md` (this file)

## Files Modified

- `lib/main.dart` — replaced the default counter-app scaffold (`MyApp`/`MyHomePage`) with `MobileApp`, wiring theme/darkTheme/themeMode/locale/supportedLocales/localizationsDelegates/builder exactly as described above; `home:` points at the temporary `ThemeDemoScreen` (not a real auth-gated shell — that's Day 4/5).
- `test/widget_test.dart` — replaced the default counter-increment test (which referenced the now-deleted `MyApp`) with a smoke test that pumps `MobileApp` and asserts the demo screen renders.
- `pubspec.yaml` — added `generate: true` under `flutter:` (enables `flutter gen-l10n`/build-time codegen from `l10n.yaml`).

No `frontend-flutter-pos` files were modified — only read, and ARBs/fonts were copied *from* it (Day 2/3), never written *to* it.

## Important Functions

```
FUNCTION: MainColorNotifier.setMainColor
FILE:     lib/core/providers/main_color_provider.dart
INPUT:    Color
OUTPUT:   none (Future<void>)
CALLS:    SharedPreferences.getInstance() → prefs.setInt('app_main_color', color.toARGB32())
STATE CHANGE: state = color (immediately, before the disk write)
UI EFFECT: every ref.watch(mainColorProvider) consumer rebuilds; MobileApp.build re-applies
           PosTheme.applyMainColor, cascading into every themed widget
```
```
FUNCTION: AppLanguageNotifier.setLanguage
FILE:     lib/core/providers/language_provider.dart
INPUT:    AppLanguage (en | km)
OUTPUT:   none (Future<void>)
CALLS:    SharedPreferences.getInstance() → prefs.setString('app_language', language.name)
STATE CHANGE: state = language
UI EFFECT: MaterialApp.locale changes → all AppLocalizations.of(context) lookups return the
           other language's strings; MobileApp.build's isKhmer flag flips → khmerAwareTextScaler
           starts/stops adding its offset
```
```
FUNCTION: khmerAwareTextScaler
FILE:     lib/core/utils/khmer_text_scaler.dart
INPUT:    TextScaler base, {required bool isKhmer}
OUTPUT:   TextScaler (either `base` unchanged, or a KhmerTextScaler wrapping it)
CALLS:    nothing — pure
STATE CHANGE: none
UI EFFECT: see Khmer Typography Flow above
```

## Source → Mobile Mapping

| OLD/SOURCE | NEW/MOBILE | Action |
|---|---|---|
| `core/config/pos_theme.dart` | `core/config/pos_theme.dart` | COPY/ADAPT nearly exactly (2 deprecated-API modernizations, no logic change) |
| `core/providers/main_color_provider.dart` | `core/providers/main_color_provider.dart` | COPY/ADAPT nearly exactly (`.value` → `.toARGB32()`) |
| `core/providers/theme_provider.dart` | `core/providers/theme_provider.dart` | COPY/ADAPT nearly exactly (byte-identical logic) |
| `core/providers/language_provider.dart` | `core/providers/language_provider.dart` | COPY/ADAPT nearly exactly (byte-identical logic) |
| `core/utils/khmer_text_scaler.dart` | `core/utils/khmer_text_scaler.dart` | PORT VERBATIM (per plan's own explicit instruction) |
| `core/utils/l10n_extensions.dart` | `core/utils/l10n_extensions.dart` | COPY/ADAPT nearly exactly |
| `l10n/app_en.arb`, `app_km.arb` | `l10n/app_en.arb`, `app_km.arb` | SEEDED COPY (own copies, not shared — full string set copied wholesale rather than hand-picking a subset, since future days will need the rest anyway and translation strings are shared product vocabulary, not app logic) |
| `l10n.yaml` | `l10n.yaml` | COPY/ADAPT nearly exactly (identical config) |
| `features/pos/screens/settings_modules_screen.dart`'s swatch-picker pattern | `core/dev/theme_demo_screen.dart` | MOBILE-SPECIFIC, TEMPORARY (minimum test/demo control only — real Settings UI is Day 19) |
| `main.dart`'s `PosApp.build` theme/locale wiring | `main.dart`'s `MobileApp.build` | RECREATE USING SAME LOGIC (identical wiring; `home:` intentionally simplified since the real auth-gated shell is Day 4/5) |

## Tests Added

- **`test/main_color_provider_test.dart`** (7 tests): default color with no saved pref; `setMainColor` updates state and persists the exact ARGB int; restores a previously-persisted color across a simulated restart (fresh `ProviderContainer`); falls back to default when the saved value matches no current palette entry; `PosTheme.applyMainColor` updates `primaryGreen` synchronously; `lightTheme`/`darkTheme` both reflect the applied color; semantic colors (`errorRed`/`warningAmber`/`successGreen`) stay constant and independent of the main color.
- **`test/khmer_text_scaler_test.dart`** (5 tests): English path returns the base scaler unchanged (identity); Khmer adds +2px below 20; Khmer adds +3px in [20, 28); Khmer leaves ≥28 unchanged; the Khmer offset stacks on top of a non-1.0 platform text-scale setting rather than replacing it.
- **`test/localization_test.dart`** (3 tests): English ARB resolves with expected strings (`appName`, `commonSave`, `settingsMainColor`, `settingsLanguage`); Khmer ARB resolves with expected strings, confirming no silent fallback to English; both `en`/`km` locales report as supported (and an unsupported locale like `fr` correctly does not).
- **`test/widget_test.dart`** (1 test, replacing the deleted counter-app test): `MobileApp` boots inside a `ProviderScope`, settles, and renders `MaterialApp` with the demo screen's app-bar title.

**16/16 tests pass** (verified both in the combined run and by running `test/localization_test.dart` in isolation to rule out a reporter-interleaving artifact in the combined output).

## Commands Run

```
$ flutter pub get                    # after adding `generate: true` to pubspec.yaml
$ flutter gen-l10n                   # generated lib/l10n/generated/*.dart from the seeded ARBs
$ flutter analyze                    # "No issues found!" (after fixing 4 deprecated-API infos —
                                      #  flutter analyze exits 1 on ANY issue in this Flutter
                                      #  version, including info-level, not just errors)
$ flutter test                       # 16/16 passed
$ flutter test test/localization_test.dart --reporter expanded   # isolated re-run, 3/3 passed,
                                                                  # confirms the combined run's
                                                                  # repeated-line output was a
                                                                  # cosmetic reporter artifact
$ flutter build apk --debug          # succeeded (11.4s incremental) — mobile shell still boots
                                      # on the connected real Android device after all Day 3 changes
```

## Problems Found

1. **Real, source-inherited race condition in `MainColorNotifier`** (and, by the identical pattern, `AppLanguageNotifier`): the constructor kicks off `_loadPreference()` without awaiting it. If `setMainColor()`/`setLanguage()` is called before that initial load resolves, the two writes to `state` can interleave, and the late-resolving load can silently overwrite a value the caller just set. This was directly observed while writing `test/main_color_provider_test.dart` — an early version of the test called `setMainColor` immediately after first touching the notifier and got the *old* default color back. **Not a mobile-specific bug** — it's present verbatim in `frontend-flutter-pos/lib/core/providers/main_color_provider.dart` and `language_provider.dart` today. **Harmless in real usage** (a user cannot tap a color swatch before the first frame renders, which is always later than a microtask-fast SharedPreferences read), which is presumably why it's never surfaced in the source app. **Reported here per task instructions rather than silently patched** — the mobile port's provider is a faithful copy of the same behavior, race included.
2. **`flutter analyze` in this Flutter/Dart version (3.41.4/3.11.1) fails (exit 1) on info-level lints, not just errors/warnings** — `deprecated_member_use` (from `Color.value`, `Colors.black.withOpacity`, and `TextScaler.textScaleFactor`, all deprecated in recent Flutter releases in favor of `.toARGB32()`/`.withValues(alpha:)`/nonlinear-scaling-aware APIs) had to be resolved for a clean baseline. Resolved via direct modernization for `.value`/`.withOpacity` (behavior-identical), and a targeted `// ignore: deprecated_member_use` for `textScaleFactor` (a required interface override where the "old" API itself is what's being deprecated, not this code's usage of it).
3. **`themeModeProvider` is not actually async-typed** — Day 1's research notes described `ref.watch(themeModeProvider).value` as "pulled off an AsyncValue," which is a mischaracterization worth correcting here: `themeModeProvider` is a `ChangeNotifierProvider<ThemeModeNotifier>`, and `ThemeModeNotifier extends ValueNotifier<ThemeMode>` — so `.value` is `ValueNotifier`'s own synchronous value getter, not `AsyncValue.value`. Behavior in the ported mobile code is identical either way; this is a documentation correction, not a code change.
4. **No live on-device visual screenshot was captured** for this pass — verification relied on `flutter analyze` (clean), `flutter test` (16/16, including a widget test that pumps the real `MobileApp`/`ThemeDemoScreen` tree and asserts rendered text), and `flutter build apk --debug` succeeding against the connected real device (Day 2's `CPH2711`). A hands-on `flutter run` visual check (toggling color/language/dark-mode live) was not performed in this non-interactive pass — flagged rather than assumed, per the general guidance to say so explicitly when UI can't be manually verified.

## Definition of Done

- [x] mobile theme architecture exists (`core/config/pos_theme.dart`)
- [x] main color state exists (`core/providers/main_color_provider.dart`)
- [x] main color persists (SharedPreferences key `app_main_color`, tested)
- [x] changing color rebuilds ThemeData immediately (`PosTheme.applyMainColor` + `MobileApp.build` watching `mainColorProvider`, tested synchronously via `PosTheme.lightTheme.colorScheme.primary`)
- [x] semantic colors remain separate (tested explicitly — `errorRed`/`warningAmber`/`successGreen` unaffected by `applyMainColor`)
- [x] mobile localization foundation exists (`l10n.yaml`, seeded ARBs, generated `AppLocalizations`)
- [x] English works (tested)
- [x] Khmer works (tested, including verifying no silent fallback to English)
- [x] Khmer app UI text scaling works (tested — all 4 bands + platform-scale stacking)
- [x] English sizing unchanged (tested — identity scaler)
- [x] printing typography untouched (verified — separate `package:pdf` system, zero shared code path, nothing under `services/printing/` created or touched today, since printing itself is out of scope through Day 3)
- [x] tests pass (16/16)
- [x] `flutter analyze` passes for touched code ("No issues found!")
- [x] `DAY_03_THEME_LOCALIZATION_FOUNDATION.md` created

**DAY 3 STATUS: PASS.** One real, pre-existing race condition was found and documented (not fixed, per instructions) rather than silently carried forward unflagged; everything else met its Definition-of-Done item cleanly.

## What I Must Understand Before Day 4

Day 4 builds the real mobile login screen and the auth-gated `home:` (Login vs POS) that `MobileApp.build` currently short-circuits to the temporary `ThemeDemoScreen`. It needs: `AppConfig`/`ApiService` (documented in Day 1, not yet created in code — Day 4's first real task), the Day 2 blockers around `INTERNET` permission and cleartext HTTP for local dev (both still open, and both become load-bearing the moment `ApiService` makes its first real network call), and `AuthNotifier`/`AuthService`/`auth_models.dart` (mapped in Day 1, not yet ported). Day 4 should replace `MobileApp.build`'s `home: const ThemeDemoScreen()` with `authState.maybeWhen(...)` exactly as Day 1 documented for `PosApp.build`, and `MobileLoginScreen` must read `Theme.of(context).colorScheme.primary` rather than a hardcoded brand color — the theme foundation built today (`PosTheme`/`mainColorProvider`) is precisely what makes that possible. `ThemeDemoScreen` itself should be deleted once the real shell exists, not kept around as dead code.
