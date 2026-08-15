# QA — How the Language Switch Works (`frontend_flutter_mobile`)

Source of truth: current code in `frontend_flutter_mobile` (verified by direct read at the time
this was written, not assumed from the plan doc). Where relevant, compared against
`frontend-flutter-pos` (read-only reference — see `docs/DAY_03_THEME_LOCALIZATION_FOUNDATION.md`
for the full OLD/SOURCE → NEW/MOBILE mapping).

## STEP 1 — All language-related files

| File | Role |
|---|---|
| `lib/core/providers/language_provider.dart` | Owns the `AppLanguage` enum, the `appLanguageProvider`, and `AppLanguageNotifier` (state + persistence) |
| `lib/core/dev/theme_demo_screen.dart` | The **only** UI in the project right now that lets you actually tap English/Khmer |
| `lib/main.dart` | `MobileApp.build` — watches the provider, feeds `MaterialApp.locale` and the Khmer text scaler |
| `lib/core/utils/khmer_text_scaler.dart` | `khmerAwareTextScaler`/`KhmerTextScaler` — the +2/+3px Khmer bump |
| `lib/core/utils/l10n_extensions.dart` | `context.l10n` shorthand for `AppLocalizations.of(context)` |
| `lib/l10n/app_en.arb`, `lib/l10n/app_km.arb` | Source translation strings (hand-authored input) |
| `lib/l10n/generated/app_localizations.dart` (+ `_en.dart`, `_km.dart`) | **Generated** by `flutter gen-l10n` from the two ARBs above — where `AppLocalizations.of(context)` and the delegate actually live |

No other file in the project references `appLanguageProvider`, `Locale`, or `context.l10n` yet.

## STEP 2 — The UI button

```
FILE:     lib/core/dev/theme_demo_screen.dart
CLASS:    ThemeDemoScreen extends ConsumerWidget
WIDGET:   SegmentedButton<AppLanguage>
CALLBACK: onSelectionChanged
```

```dart
SegmentedButton<AppLanguage>(
  segments: const [
    ButtonSegment(value: AppLanguage.en, label: Text('English')),
    ButtonSegment(value: AppLanguage.km, label: Text('ខ្មែរ')),
  ],
  selected: {language},
  onSelectionChanged: (selection) => ref
      .read(appLanguageProvider.notifier)
      .setLanguage(selection.first),
),
```

- `SegmentedButton<AppLanguage>` — generic over the enum itself, not a string, so there's no string-matching in the UI.
- `segments` — each `ButtonSegment(value:, label:)` pairs a display label (`'English'`/`'ខ្មែរ'`, hardcoded, not localized) with an `AppLanguage` value.
- `selected: {language}` — `language` comes from `final language = ref.watch(appLanguageProvider);` earlier in `build`, so the highlighted segment always mirrors the provider's current state — no separate widget state, no manual `setState`.
- `onSelectionChanged: (selection) => ...` — Flutter calls this the instant a segment is tapped; `selection` is a `Set<AppLanguage>` (always, even in single-select mode).
- `ref.read(appLanguageProvider.notifier)` — `.read` (not `.watch`, because this is an event callback, not `build`) fetches the notifier object, not its state value.
- `.setLanguage(selection.first)` — calls the method, passing the tapped `AppLanguage` value.

Tapping "Khmer" resolves to exactly one call: `AppLanguageNotifier.setLanguage(AppLanguage.km)`.

## STEP 3 — The provider/notifier function

```
FILE:     lib/core/providers/language_provider.dart
CLASS:    AppLanguageNotifier extends StateNotifier<AppLanguage>
FUNCTION: Future<void> setLanguage(final AppLanguage language)
```

```dart
Future<void> setLanguage(final AppLanguage language) async {
  state = language;
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(_languagePreferenceKey, language.name);
}
```

- `state = language` — **the most important line.** `StateNotifier`'s `state` setter stores the new value and **synchronously** notifies every watcher of `appLanguageProvider`, before the `await` below even starts.
- `await SharedPreferences.getInstance()` — fetches the singleton (async on first access).
- `await prefs.setString(_languagePreferenceKey, language.name)` — writes to disk.
  - `_languagePreferenceKey` = `'app_language'` — **the exact SharedPreferences key**.
  - `language.name` — Dart enum built-in getter; `AppLanguage.km.name == 'km'`, `AppLanguage.en.name == 'en'`.

**Parameter passed:** `AppLanguage.km` (enum value, not a string).
**State that changes:** `AppLanguageNotifier.state`, `AppLanguage.en` → `AppLanguage.km`.
**SharedPreferences key written:** `'app_language'`, value `'km'`.

## STEP 4 — How the saved value comes back on next app start

```dart
AppLanguageNotifier() : super(AppLanguage.en) {
  _loadPreference();
}

Future<void> _loadPreference() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? saved = prefs.getString(_languagePreferenceKey);
  if (saved == AppLanguage.km.name) {
    state = AppLanguage.km;
    return;
  }
  state = AppLanguage.en;
}
```

- Every fresh notifier defaults to English (`super(AppLanguage.en)`) before anything is read from disk.
- `_loadPreference()` fires from the constructor, unawaited by the caller.
- Direct string comparison against `AppLanguage.km.name` (`'km'`). Anything else — `null`, `'en'`, garbage — falls through to English. There's no explicit "en" branch; English is the fallback for everything that isn't exactly `'km'`.

## STEP 5 — What `MaterialApp` watches, and how `.locale` changes

```
FILE:     lib/main.dart
CLASS:    MobileApp extends ConsumerWidget
FUNCTION: Widget build(BuildContext context, WidgetRef ref)
```

```dart
Widget build(BuildContext context, WidgetRef ref) {
  PosTheme.applyMainColor(ref.watch(mainColorProvider));
  final isKhmer = ref.watch(appLanguageProvider).isKhmer;      // watch #1

  return MaterialApp(
    ...
    locale: ref.watch(appLanguageProvider).toLocale(),          // watch #2
    ...
  );
}
```

- `ref.watch(appLanguageProvider)` appears twice — Riverpod caches the value, so both reads are cheap. Because these are `.watch` calls inside `build`, Riverpod re-runs this whole method whenever `appLanguageProvider` changes — no manual `setState`/`notifyListeners` anywhere.
- `.isKhmer` — extension getter: `bool get isKhmer => this == AppLanguage.km;`. Stored for the `builder:` callback (Step 7).
- `.toLocale()` — extension: `Locale toLocale() => Locale(name);`. `AppLanguage.km.toLocale()` → `const Locale('km')`.
- `locale: ref.watch(appLanguageProvider).toLocale()` — the one line where the app's language enum becomes Flutter's own locale system.

## STEP 6 — How `AppLocalizations` picks EN vs KM

```
FILE: lib/l10n/generated/app_localizations.dart   (GENERATED — never hand-edit)
```

```dart
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'km': return AppLocalizationsKm();
  }
  throw FlutterError(...);
}
```

- `isSupported(locale)` checked first — `locale.languageCode` (`'en'`/`'km'`) is matched against the hardcoded supported list (mirrors `supportedLocales: const [Locale('en'), Locale('km')]` in `main.dart`).
- `load(locale)` returns an already-resolved `SynchronousFuture` wrapping `lookupAppLocalizations(locale)`.
- `lookupAppLocalizations` is a plain `switch` on `languageCode` → picks `AppLocalizationsKm()` or `AppLocalizationsEn()`, each a flat bag of getters returning hardcoded translated strings from the matching ARB.

Chain: **enum → `.name` string → `Locale` → `.languageCode` string → `switch` → one of two generated classes.**

`context.l10n` (`l10n_extensions.dart`) is just:
```dart
static AppLocalizations of(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations)!;
```
— asks the nearest `Localizations` widget (installed by `MaterialApp`) for whichever `AppLocalizations` instance is currently active.

## STEP 7 — How `Text` widgets rebuild

No manual refresh anywhere:

1. `state = language` (Step 3) → Riverpod synchronously notifies watchers.
2. `ThemeDemoScreen` (watches `appLanguageProvider`) is scheduled for rebuild.
3. `MobileApp` (also watches it, twice) is scheduled for rebuild too — independently, not because it's a parent.
4. `MobileApp.build` re-runs → new `MaterialApp` with a new `locale:`.
5. Flutter's `Localizations` widget sees the locale changed → re-invokes the delegate's `load()` → new `AppLocalizationsKm`/`AppLocalizationsEn` → published down the tree.
6. `ThemeDemoScreen.build` re-runs anyway → `context.l10n` resolves to the new instance → every `Text(l10n.something)` shows the new language's string because the whole method re-executed from scratch.

Nothing is mutated in place — old `Text` widgets are replaced by a fresh tree, which Flutter diffs/patches efficiently.

## STEP 8 — How the Khmer `TextScaler` becomes active

```dart
// main.dart, MaterialApp.builder
builder: (context, child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaler:
        khmerAwareTextScaler(MediaQuery.of(context).textScaler, isKhmer: isKhmer),
  ),
  child: child!,
),
```

- `MaterialApp.builder` wraps the entire rest of the app (`child`) in whatever is returned here; re-runs on every `MobileApp.build` with the fresh `isKhmer`.
- `MediaQuery.of(context).copyWith(textScaler: ...)` swaps out just the `textScaler` field of the ambient `MediaQueryData`.
- `khmerAwareTextScaler(base, isKhmer:)` (`khmer_text_scaler.dart`):
  ```dart
  TextScaler khmerAwareTextScaler(TextScaler base, {required bool isKhmer}) =>
      isKhmer ? KhmerTextScaler(base) : base;
  ```
  `isKhmer == false` → returns `base` unchanged, no wrapping. `isKhmer == true` → wraps in `KhmerTextScaler`, whose `scale(fontSize)` adds +2px (small text), +3px (medium text), or +0 (≥28px display text) on top of `base.scale(fontSize)`.
- Injected above `child`, so **every** `Text` widget anywhere in the app renders through this scaler automatically — no per-widget font-size changes needed.

## STEP 9 — Why the screen changes immediately

- `state = language` is a plain synchronous assignment — the very first line of `setLanguage`, before `await SharedPreferences.getInstance()` even starts.
- Riverpod's `state =` setter notifies listeners synchronously, in the same call stack.
- Flutter schedules a rebuild for the next frame (~16ms on a real device — imperceptible).
- The `await prefs.setString(...)` disk write happens *after* the UI has already been told to rebuild — persistence is a trailing side effect, not a gate the UI waits on.

**Tap → state assigned → UI rebuild scheduled, all before any disk I/O begins.**

## Full chain, summarized

```
User taps "Khmer" segment
↓ SegmentedButton.onSelectionChanged  (theme_demo_screen.dart)
ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.km)
↓ parameter passed: AppLanguage.km
AppLanguageNotifier.setLanguage()  (language_provider.dart)
↓ state = AppLanguage.km   ← synchronous, notifies watchers immediately
↓ (then, async) SharedPreferences key 'app_language' written as 'km'
MobileApp.build re-runs  (main.dart)  — because it ref.watch(appLanguageProvider)
↓ isKhmer = true
↓ locale: AppLanguage.km.toLocale() → const Locale('km')  → MaterialApp.locale changes
Flutter's Localizations widget re-resolves via AppLocalizations.delegate
↓ isSupported('km') → true → lookupAppLocalizations(Locale('km')) → AppLocalizationsKm()
ThemeDemoScreen.build re-runs (also watches appLanguageProvider)
↓ context.l10n now returns AppLocalizationsKm
↓ every Text(l10n.xxx) shows the Khmer string
MaterialApp.builder wraps the tree in MediaQuery(textScaler: khmerAwareTextScaler(..., isKhmer: true))
↓ every Text anywhere renders +2/+3px larger via KhmerTextScaler.scale()
Screen visibly updates on the next frame — no spinner, no delay, disk write finishes in the background
```
