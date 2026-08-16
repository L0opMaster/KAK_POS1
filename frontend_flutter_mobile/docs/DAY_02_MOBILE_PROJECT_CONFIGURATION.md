# Day 2 — Mobile Project Configuration

## Goal

Per the task instructions and `frontend-flutter-pos/docs/MOBILE_ANDROID_IOS_20_DAY_BUILD_PLAN.md`'s Day 2 section: `frontend_flutter_mobile` **already exists** (confirmed Day 1) as a bare `flutter create` scaffold. Day 2 is **not** `flutter create` — it is inspection, verification, and minimal configuration: confirm what already exists, establish `flutter pub get`/`flutter analyze` baselines, understand Android/iOS platform config, decide what assets/fonts Day 3 needs, and verify the shell boots. No feature code (products/cart/screens) is written today.

## Existing Project State Before Changes

Confirmed by direct inspection (`ls`, `find`, file reads) before any edit:

- **`pubspec.yaml`**: unmodified `flutter create` default — `name: frontend_flutter_mobile`, `sdk: ^3.11.1`, only `cupertino_icons: ^1.0.8` as a dependency, only `flutter_lints: ^6.0.0` as dev dependency. No assets, no fonts, no state-management or persistence packages.
- **`lib/`**: only `main.dart`, the unmodified counter-app template (`MyApp extends StatelessWidget`, `MyHomePage`/`_MyHomePageState`).
- **`test/`**: only `widget_test.dart`, the unmodified default counter-increment smoke test (references `MyApp`, taps a `+` icon, asserts `'0'`→`'1'`).
- **`android/`**: standard `flutter create` output — `app/build.gradle.kts`, manifests (main/debug/profile), Kotlin `MainActivity.kt` under `com/example/frontend_flutter_mobile/`, default launcher icons/themes. No `.gitignore`-tracked build artifacts checked in (a `.gradle/` cache directory exists locally but isn't part of the source tree).
- **`ios/`**: standard `flutter create` output — `Runner.xcodeproj`, `Runner.xcworkspace`, `Info.plist`, `AppDelegate.swift`, `SceneDelegate.swift`, default asset catalogs/launch screens/storyboards, `RunnerTests/RunnerTests.swift`. **No `Podfile`** — expected, since no plugin requiring native iOS pods has been added yet (`cupertino_icons` is pure Dart).
- **`docs/`**: already contained one file, `DAY_01_ARCHITECTURE_MAP.md`, from an earlier pass in this project's history (different filename than this task's canonical `DAY_01_ARCHITECTURE_AND_MAPPING.md`, which was created today). Left in place, not deleted.
- Also present (all default/untouched, no action needed today): `linux/`, `macos/`, `windows/`, `web/`, `analysis_options.yaml`, `.metadata`, `README.md`, `.github/`, `.idea/`, `frontend_flutter_mobile.iml`.

**No useful existing mobile work was overwritten** — everything found was either default scaffold or this session's own Day 1 doc.

## Flutter SDK / Packages

```
$ flutter --version
Flutter 3.41.4 • channel stable
Framework revision ff37bef603 (2026-03-03)
Engine e4b8dca3f1
Dart 3.11.1 • DevTools 2.54.1
```

`$ flutter pub get` — succeeded on the first run (default deps only), and again after this day's pubspec edits (see `## Files Changed`). Both runs report only "newer versions available" advisories (non-blocking), no resolution errors.

`$ flutter analyze` — **baseline (before any Day 2 edits): "No issues found!"** Re-run after edits: also **"No issues found!"** — so there is no PRE-EXISTING vs INTRODUCED-BY-DAY-2 distinction to make; both are clean.

`$ flutter doctor -v` — full output:
```
[✓] Flutter (Channel stable, 3.41.4, on Ubuntu 24.04.4 LTS 7.0.0-28-generic, locale en_US.UTF-8)
[✓] Android toolchain - develop for Android devices (Android SDK version 36.1.0)
    • Android SDK at /home/luffy/Android/Sdk, platform android-36.1, build-tools 36.1.0
    • Java binary bundled with Android Studio (OpenJDK 21.0.7)
    • All Android licenses accepted.
[✓] Chrome - develop for the web
[✓] Linux toolchain - develop for Linux desktop
[✓] Connected device (3 available):
    • CPH2711 (mobile) • android-arm64 • Android 16 (API 36)   ← a real physical Android phone
    • Linux (desktop)  • linux-x64
    • Chrome (web)     • web-javascript
[✓] Network resources
• No issues found!
```
**No Xcode / iOS toolchain section appears at all** — this environment is Linux, not macOS, so Xcode cannot be installed and iOS builds/runs cannot be attempted here. This is an environment limitation, not a project defect.

`$ flutter devices` — confirms the same three: a real Android phone (`CPH2711`, API 36), Linux desktop, Chrome. No Android emulator or iOS simulator is currently running, but a **real device** is available and was used for build verification.

## Android Configuration

**[NEW/MOBILE — READ]** `frontend_flutter_mobile/android/app/build.gradle.kts`:
```kotlin
android {
    namespace = "com.example.frontend_flutter_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    defaultConfig {
        applicationId = "com.example.frontend_flutter_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        ...
    }
}
```
`compileSdk`/`minSdk`/`targetSdk` are all inherited from the Flutter SDK's own gradle defaults (`flutter.compileSdkVersion` etc., resolved from the Flutter tool at build time, currently Android SDK 36.1.0 per `flutter doctor`) rather than hardcoded — this is standard for a fresh `flutter create` project and does not need to be touched.

**[NEW/MOBILE — READ]** `frontend_flutter_mobile/android/app/src/main/AndroidManifest.xml` — no `<uses-permission>` entries at all (only an `<application>` block and a `<queries>` block for text-processing intents). **[NEW/MOBILE — READ]** `frontend_flutter_mobile/android/app/src/debug/AndroidManifest.xml` — adds `android.permission.INTERNET`, but only for **debug** builds (Flutter's own debug-manifest overlay, needed for hot reload/DevTools, not something this project added).

Verified against the plan's explicit Day 2 checklist item ("Verify current: INTERNET, CAMERA, cleartext development behavior"):
- **INTERNET**: present in the debug manifest only, **absent from `main/AndroidManifest.xml`**. This is a real gap: a **release** build of this POS app (which must call the backend API) will have no INTERNET permission and all network calls will fail at the OS level. Flagged in `## Blockers` below — **not fixed today**, since the task instructions say "Day 2 should prepare the shell, not implement printer permissions prematurely," and by the same reasoning this is a Day 4 (first real network call) concern, not a Day 2 one; recorded now so it isn't silently forgotten.
- **CAMERA**: not present anywhere yet — correctly deferred (Day 8, barcode scanning, per this task's explicit scope boundaries).
- **Cleartext**: no `android:usesCleartextTraffic` override exists in the manifest, and no `network_security_config.xml` exists. `AppConfig.baseUrl` (Day 1 finding) resolves to plain `http://` for every platform branch (`localhost:8081` / `10.0.2.2:8081`), so **Android 9+'s default cleartext block will break local dev networking** the moment `ApiService` is wired up (Day 4) unless a debug-only `usesCleartextTraffic="true"` (or a network security config scoped to debug) is added then. Not fixed today — same reasoning as INTERNET above, recorded as a Day 4 prerequisite.
- **No Bluetooth/USB permissions added** — correctly deferred to Days 15–16 per explicit task scope boundaries; confirmed none exist in the manifest.

## iOS Configuration

**[NEW/MOBILE — READ]** `frontend_flutter_mobile/ios/Runner/Info.plist` — standard default keys only (`CFBundleDisplayName: "Frontend Flutter Mobile"`, `CFBundleIdentifier: $(PRODUCT_BUNDLE_IDENTIFIER)`, scene manifest, launch storyboard, supported orientations). **No usage-description keys** (`NSCameraUsageDescription`, `NSBluetoothAlwaysUsageDescription`, `NSLocalNetworkUsageDescription`) exist yet — correct for today's scope; all three become required only when their owning feature (camera scanning Day 8, Bluetooth printing Day 16, network printing Day 15/16) is actually built, per this task's explicit instruction not to add printer/camera permissions prematurely.

`IPHONEOS_DEPLOYMENT_TARGET = 13.0` (confirmed in `project.pbxproj`, three occurrences — Debug/Release/Profile configs all agree). No `Podfile` exists yet (expected — no plugin needing native iOS code has been added; `shared_preferences`/`flutter_riverpod` added today are also pure-Dart-or-federated-plugin packages that CocoaPods will only need once an actual iOS build is attempted, which this environment cannot do).

**Future required Info.plist keys** (documented now, not added):
- `NSCameraUsageDescription` — Day 8 (barcode scanning)
- `NSBluetoothAlwaysUsageDescription` — Day 16 (Bluetooth printer)
- `NSLocalNetworkUsageDescription` — Day 15/16 (network printer, iOS 14+ local-network prompt)

## Package / Bundle IDs

**[NEW/MOBILE — READ]**
- Android `namespace` / `applicationId` (`build.gradle.kts`): **`com.example.frontend_flutter_mobile`**
- iOS `PRODUCT_BUNDLE_IDENTIFIER` (`project.pbxproj`, all 3 build configs): **`com.example.frontendFlutterMobile`** (+ `com.example.frontendFlutterMobile.RunnerTests` for the test target)

Both are the **unmodified `flutter create` placeholder** (`com.example.*`). Per this task's explicit instruction — *"DO NOT invent identifiers if already configured... If organization identifier is unclear: do not guess. Document it as a blocker/TODO"* — **these were NOT changed today.**

A plausible real identifier can be inferred from context (the shared backend's Java package is `com.kaknnea.pos`, confirmed in Day 1's auth research — e.g. `com.kaknnea.pos.controller.AuthController`; `AppConfig.appName = 'KAKNNEA'`), which suggests something like `com.kaknnea.pos.mobile` or `com.kaknnea.pos`. **This is a plausible inference, not a confirmed decision** — a real app/bundle ID is effectively permanent once published to the Play Store / App Store, so changing it is exactly the kind of consequential, hard-to-reverse action this task's own instructions say to stop and confirm rather than guess. **Recorded as a blocker below; owner confirmation needed before Day 4** (the plan's own Day 1 naming note makes the same point about the project name itself, 30 seconds now vs. renaming pain later).

## Assets and Fonts

**[OLD/SOURCE — READ]** `frontend-flutter-pos/pubspec.yaml` declares:
```yaml
assets:
  - assets/images/
  - assets/icons/
  - assets/fonts/
fonts:
  - family: NotoSans
    fonts:
      - asset: assets/fonts/NotoSans-Regular.ttf
      - asset: assets/fonts/NotoSans-Bold.ttf
        weight: 700
  - family: NotoSansKhmer
    fonts:
      - asset: assets/fonts/NotoSansKhmer-Regular.ttf
      - asset: assets/fonts/NotoSansKhmer-Bold.ttf
        weight: 700
```
Only `assets/fonts/` (4 `.ttf` files: `NotoSans-Regular/Bold.ttf`, `NotoSansKhmer-Regular/Bold.ttf`) is needed for Day 3's theme/localization/Khmer-typography foundation. `assets/images/` and `assets/icons/` were **not** copied — they back specific POS screens (product placeholders, feature icons) that are out of scope through Day 3 per this task's explicit scope boundaries; copying them now would be exactly the "copy every old asset blindly" the task instructions warn against.

**Action taken**: copied the 4 font files read-only from `frontend-flutter-pos/assets/fonts/` into **[NEW/MOBILE]** `frontend_flutter_mobile/assets/fonts/`, and declared the same two font families in `frontend_flutter_mobile/pubspec.yaml` (see `## Files Changed`). Source project files were only *read*, never modified.

## Files Changed

**[NEW/MOBILE — CREATE/MODIFY]** (all inside `frontend_flutter_mobile/`, nothing in `frontend-flutter-pos/` touched):

- **Created**: `assets/fonts/NotoSans-Regular.ttf`, `assets/fonts/NotoSans-Bold.ttf`, `assets/fonts/NotoSansKhmer-Regular.ttf`, `assets/fonts/NotoSansKhmer-Bold.ttf` (copied from `frontend-flutter-pos/assets/fonts/`, byte-identical).
- **Modified**: `pubspec.yaml` — added:
  - `flutter_localizations` (SDK package, required for `GlobalMaterialLocalizations`/etc. delegates — Day 3 needs this immediately for `MaterialApp.localizationsDelegates`).
  - `flutter_riverpod: ^2.6.1` — matches `frontend-flutter-pos`'s state-management architecture (Day 1 finding: `StateNotifierProvider` throughout); needed starting Day 3 for `mainColorProvider`/theme provider.
  - `shared_preferences: ^2.5.3` — matches source app's persistence mechanism (Day 1 finding: `SharedPreferences` used for cart/auth/theme); needed starting Day 3 for main-color/language persistence.
  - `assets:` section pointing at `assets/fonts/`, and a `fonts:` section declaring `NotoSans`/`NotoSansKhmer` — identical family/weight structure to the source app's `pubspec.yaml`.
- **Created**: `docs/DAY_02_MOBILE_PROJECT_CONFIGURATION.md` (this file).

No `android/`, `ios/`, `lib/`, or `test/` files were modified today — package/bundle ID and manifest permission gaps are documented as blockers, not silently patched, per task instructions to report source-adjacent findings rather than fix them without confirmation.

## Commands Run

```
$ flutter pub get                    # baseline — succeeded, default deps only
$ flutter doctor -v                  # environment report, see above — no issues
$ flutter devices                    # 3 devices: real Android phone, Linux desktop, Chrome
$ flutter analyze                    # baseline — "No issues found!"
$ flutter build apk --debug          # baseline boot verification — succeeded (123.8s), app-debug.apk built
# --- pubspec.yaml edited: + flutter_localizations, flutter_riverpod, shared_preferences, fonts ---
$ flutter pub get                    # re-resolve after edits — succeeded
$ flutter analyze                    # re-run after edits — still "No issues found!"
$ flutter build apk --debug          # re-verify boot after adding a native-backed plugin (shared_preferences) — succeeded (19.6s, incremental)
```

## Build Results

### Android Result
**PASS.** `flutter build apk --debug` succeeded both before and after this day's pubspec changes (`build/app/outputs/flutter-apk/app-debug.apk`). A real physical device (`CPH2711`, Android 16/API 36) is connected and visible to `flutter devices`, so an actual `flutter run` install could be performed if desired — not done today since `flutter run` is interactive/long-running and the non-interactive `build apk --debug` already proves the shell compiles and packages correctly for this day's purpose.

### iOS Result
**IOS BUILD NOT VERIFIED IN CURRENT ENVIRONMENT.** This machine is Ubuntu Linux (`flutter doctor -v` shows no Xcode/iOS toolchain section at all) — Xcode is Apple-only and cannot be installed here, so `flutter build ios`/`flutter run` targeting iOS cannot be attempted, and no CocoaPods install can be verified either (there is no `Podfile` yet regardless). Static configuration (`Info.plist`, `project.pbxproj` bundle ID/deployment target) was inspected and reported above by direct file read, which is the extent of what's verifiable without macOS/Xcode.

## Blockers

1. **Package name / bundle ID still `com.example.*` placeholder** on both platforms. A plausible real identifier (`com.kaknnea.pos*`) can be inferred from the shared backend's Java package and `AppConfig.appName`, but per task instructions this must be confirmed by whoever owns the org's naming convention before Day 4 — not guessed. Changing it later (after any real device testing, TestFlight/Play Console registration, or CI wiring) is possible but disruptive.
2. **`android/app/src/main/AndroidManifest.xml` has no `INTERNET` permission** — only the debug-only manifest overlay grants it. A release build cannot reach the backend until this is added. Deliberately not fixed today (Day 2 scope is "prepare the shell," and this only becomes load-bearing once Day 4 wires up real network calls) — flagging now so it isn't forgotten.
3. **No cleartext-traffic allowance for local HTTP dev backends** — `AppConfig.baseUrl` (ported from source, Day 1 finding) resolves to plain `http://`, which Android 9+ blocks by default for non-localhost hosts (i.e. the `10.0.2.2` emulator-host alias and any real-device LAN IP). Needs a debug-scoped `network_security_config.xml` or manifest override when `ApiService` is wired up (Day 4), not before.
   **Update (real-device testing, post-Day-13):** this deferral point was reached — login failed with a generic `DioExceptionType.connectionError` on a physical device with the backend confirmed reachable. Fixed via `android/app/src/main/res/xml/network_security_config.xml` using `<debug-overrides>` (Android's own debug-only cleartext mechanism, auto-stripped from release builds) scoped to `AppConfig.baseUrl`'s three dev hosts, referenced from `main/AndroidManifest.xml`'s `<application android:networkSecurityConfig=...>`. The main-manifest `INTERNET` permission gap from item 2 above was fixed in the same pass, for the same reason (real network calls are now load-bearing everywhere, not deferred).
4. **iOS cannot be built or run in this environment** — no macOS/Xcode available. All iOS verification for the remainder of this plan will be static (file inspection) only, unless run in a different environment.

None of these block Day 3 (theme/localization is pure Dart/Flutter framework code, no network or platform-permission dependency) — recorded so they aren't silently dropped before Day 4.

## Definition of Done

- [x] existing mobile project inspected
- [x] `flutter pub get` succeeds
- [x] `flutter analyze` baseline known (clean, both before and after edits)
- [x] Android project configuration understood
- [x] iOS configuration understood (static inspection; runtime build not possible in this environment)
- [x] app launches/builds where environment permits (Android debug APK built successfully; iOS explicitly not verified, reported honestly rather than assumed)
- [x] no `frontend-flutter-pos` platform files modified (only read; fonts were copied *from* it, never written *to* it)
- [x] `DAY_02_MOBILE_PROJECT_CONFIGURATION.md` created

**DAY 2 STATUS: PASS.** No fundamental project-configuration breakage found. The four items in `## Blockers` are real gaps but are all correctly scoped to later days (Day 4 for INTERNET/cleartext, Day 4 for bundle ID confirmation, environment-only for iOS) per this task's own scope boundaries — none of them block starting Day 3.

## What I Must Understand Before Day 3

Day 3 is pure Dart/Flutter-framework work — `PosTheme`, a Riverpod theme/main-color provider, `khmerAwareTextScaler`, and `l10n` setup — none of it touches Android/iOS platform code, so today's platform blockers (bundle ID, INTERNET permission, cleartext config) don't block it. What Day 3 *does* need from today: `flutter_riverpod` and `shared_preferences` are now in `pubspec.yaml` (for the main-color provider and its persistence), and the four Noto font files are now in `frontend_flutter_mobile/assets/fonts/` and declared in `pubspec.yaml` (for `PosTheme`'s text styles and the Khmer-fallback font strategy). Day 3 also needs to set up `frontend_flutter_mobile/l10n.yaml` and seed `lib/l10n/app_en.arb`/`app_km.arb` from the source app's ARBs — that has not been done yet, it's explicitly Day 3 scope.
