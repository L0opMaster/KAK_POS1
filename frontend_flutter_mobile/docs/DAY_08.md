# Day 8 — Barcode Scanner

## 1. Goal

Let a cashier add a product to the cart by scanning its barcode with the
phone's own camera, plus a manual-entry fallback for codes that won't
scan cleanly. This is the day the plan itself flagged as different from
source's architecture: `[OLD/SOURCE]` has no camera (it's a desktop app),
so its "barcode scanner" is a companion-phone relay; `frontend_flutter_mobile`
IS the phone, so it scans directly.

## 2. Source Project Investigation

```text
frontend-flutter-pos/lib/features/pos/screens/phone_screen_scan.dart        (camera controller setup + onDetect dedup logic — the part actually reused)
frontend-flutter-pos/lib/features/pos/services/scanner_relay_role.dart      (read to CONFIRM it's relay-only — not ported, see section 12)
frontend-flutter-pos/lib/features/pos/widgets/phone_scanner_receiver_button.dart  (read to confirm the desktop side of the relay — not ported)
frontend-flutter-pos/lib/features/pos/screens/pos_screen.dart               (_PosAppBarState._submitBarcode() — the manual-entry business logic actually reused)
frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart          (CartNotifier.addProductByBarcode — deferred from Day 7, ported this day)
frontend_flutter_barcode_scanner/pubspec.yaml                               (confirmed mobile_scanner version/pattern, and the exact Android/iOS camera permission strings, reused verbatim)
frontend_flutter_barcode_scanner/android/app/src/main/AndroidManifest.xml
frontend_flutter_barcode_scanner/ios/Runner/Info.plist
```

**Source project discrepancy, reported per this task's instructions**:
`[OLD/SOURCE]`'s actual "barcode scanner" is not one feature but three
different mechanisms layered together: (1) a manual `TextField` in
`pos_screen.dart`'s AppBar that a USB/Bluetooth barcode scanner types into
(acting as a keyboard) or a cashier types into by hand; (2)
`PhoneScannerScreen` — a camera scanner screen meant to run on a SEPARATE
phone, which connects to the desktop session over a WebSocket relay
(`ScannerRelayClient`, 8-character session-code pairing) and forwards
scanned codes; (3) `phone_scanner_receiver_button.dart` — the desktop-side
UI showing relay connection status and receiving those forwarded codes.
None of (2)/(3) apply to a mobile app that already has its own camera in
the same process as its own cart — reproducing the relay would mean this
phone pairing with itself over a network round trip for no reason. The
camera SCANNING mechanics (controller config, detection dedup) were still
directly reusable and were ported; the RELAY was not, and is explicitly
not needed here.

## 3. Mobile Target

```text
frontend_flutter_mobile/lib/features/pos/screens/barcode_scanner_screen.dart  (NEW)
frontend_flutter_mobile/lib/features/pos/providers/cart_provider.dart         (MODIFIED — addProductByBarcode + BarcodeAddResult + Ref field)
frontend_flutter_mobile/lib/features/pos/screens/pos_register_screen.dart     (MODIFIED — scan icon in the search bar)
frontend_flutter_mobile/pubspec.yaml                                          (MODIFIED — mobile_scanner dependency)
frontend_flutter_mobile/android/app/src/main/AndroidManifest.xml              (MODIFIED — CAMERA permission)
frontend_flutter_mobile/ios/Runner/Info.plist                                 (MODIFIED — NSCameraUsageDescription)
frontend_flutter_mobile/lib/l10n/app_en.arb / app_km.arb                      (MODIFIED — one new key, barcodeScannerScreenTitle)
frontend_flutter_mobile/test/cart_provider_test.dart                          (MODIFIED — 8 new addProductByBarcode tests)
```

## 4. Architecture Flow

```text
BarcodeScannerScreen (camera detects a barcode, OR manual TextField submitted)
    ↓
_lookupBarcode(value)
    ↓
CartNotifier.addProductByBarcode(barcode)
    ↓
search the currently-loaded productsProvider list first (fast path)
    ↓ (not found there)
ProductNotifier.findByBarcode(barcode) → ProductService.getProducts(query: barcode) → same GET /api/products / demo fallback as Day 6
    ↓
active / sellable / outOfStock checks
    ↓ (all pass)
CartNotifier.addItemFromProduct(product)  — same Day 7 path a tap uses
    ↓
BarcodeAddResult(added: true, message, product) returned to the screen
    ↓
status card / SnackBar-equivalent shows the message; CartSummaryBar updates
```

No new backend endpoint — barcode lookup reuses `/api/products` (via
`ProductService.findByBarcode`, itself built on the same search endpoint
Day 6 already traced), and adding reuses Day 7's cart-mutation path
end-to-end.

## 5. Files To Create

**`barcode_scanner_screen.dart`** — `BarcodeScannerScreen`/
`_BarcodeScannerScreenState`. Camera view (`MobileScanner` +
`MobileScannerController`) with a green targeting frame overlay, a status
card, and a manual-entry `TextField` fallback below it.

## 6. Files To Modify

**`frontend_flutter_mobile/lib/features/pos/providers/cart_provider.dart`**
Existing (Day 7): `CartNotifier(this.service)` — no way to look up a
product by barcode.
Change: constructor now takes a second `Ref _ref` parameter; added
`BarcodeAddResult` and `CartNotifier.addProductByBarcode()`, ported
byte-identical from source. Why: this is the exact method Day 7's own
file header flagged as deferred to Day 8 — barcode lookup needs
`productsProvider` (Day 6), which `CartNotifier` didn't have a `Ref` to
reach until now.

**`frontend_flutter_mobile/lib/features/pos/screens/pos_register_screen.dart`**
Existing (Day 7): search `TextField` had a `prefixIcon` only.
Change: added a `suffixIcon` scan button that pushes
`BarcodeScannerScreen`. Why: this is the entry point a cashier actually
uses to start scanning.

**`frontend_flutter_mobile/pubspec.yaml`**
Change: added `mobile_scanner: ^7.4.0` — same version
`frontend-flutter-pos` and `frontend_flutter_barcode_scanner` both already
pin, confirmed by reading both `pubspec.yaml` files rather than assumed.

**`frontend_flutter_mobile/android/app/src/main/AndroidManifest.xml` /
`ios/Runner/Info.plist`**
Change: added the `CAMERA` permission / `NSCameraUsageDescription` —
exact strings copied from `frontend_flutter_barcode_scanner`'s already-
working configuration, not invented.

**`frontend_flutter_mobile/lib/l10n/app_en.arb` / `app_km.arb`**
Change: added `"barcodeScannerScreenTitle": "Scan Barcode"` /
`"...": "ស្កេនបាកូដ"`. Why: source's own `phoneScanScreenTitle` ("Phone 1D
Scanner") describes the RELAY screen's purpose specifically, which would
be a misleading title for this screen's actual (in-app, non-relay) job —
flagged and added as a new key rather than reusing an ill-fitting one,
same reasoning as Day 7's `cartSummaryBarViewCart`.

## 7. Functions

### Function: `CartNotifier.addProductByBarcode(barcode)`

FILE: `frontend_flutter_mobile/lib/features/pos/providers/cart_provider.dart`
CLASS: `CartNotifier`
SIGNATURE: `Future<BarcodeAddResult> addProductByBarcode(String barcode)`
CALLED BY: `_BarcodeScannerScreenState._lookupBarcode()` (both the camera
detector and the manual-entry field funnel through this one method).
CALLS: `productsProvider` state read (fast path), `ProductNotifier
.findByBarcode()` (fallback), `addItemFromProduct()`.
INPUT: a raw barcode string (untrimmed — the method trims it itself).
OUTPUT: `Future<BarcodeAddResult>` — `{added, message, product?}`.
STATE CHANGES: (via `addItemFromProduct`) may append/increment a cart
line; never mutates `CartState` directly itself.
UI EFFECT: the calling screen shows `result.message` and, on success,
clears its manual-entry field; `CartSummaryBar`/`CartItemsList` update
via the normal `cartProvider` watch chain.

REUSE EXISTING FUNCTION — byte-identical logic (including the
active/sellable/outOfStock rejection order and exact message strings).

### Function: `_BarcodeScannerScreenState._onDetect(capture)`

FILE: `frontend_flutter_mobile/lib/features/pos/screens/barcode_scanner_screen.dart`
CLASS: `_BarcodeScannerScreenState`
SIGNATURE: `void _onDetect(BarcodeCapture capture)`
CALLED BY: `MobileScanner`'s `onDetect` callback, once per camera frame
that contains a recognizable code.
CALLS: `_lookupBarcode()` (on a genuinely new detection).
INPUT: a `BarcodeCapture` (one or more detected `Barcode`s per frame).
OUTPUT: none.
STATE CHANGES: none directly — updates `_lastDetectedValue`/
`_lastDetectedAt` (plain fields, not `setState`) to drive the dedup
window.
UI EFFECT: triggers `HapticFeedback.mediumImpact()` and, via
`_lookupBarcode`, the same status-card update a manual submission causes.

REUSE EXISTING FUNCTION — the de-duplication logic (ignore a repeat of
the same value within 1200ms) and haptic feedback are byte-identical to
`[OLD/SOURCE]` `PhoneScannerScreen._onDetect`. The one line that changed:
source calls `_relay.sendBarcode(value)`; this calls `_lookupBarcode(value)`
directly — see section 2's discrepancy note for why.

### Function: `_BarcodeScannerScreenState._lookupBarcode(barcode)`

FILE: same as above.
CLASS: `_BarcodeScannerScreenState`
SIGNATURE: `Future<void> _lookupBarcode(String barcode)`
CALLED BY: `_onDetect()` and the manual `TextField`'s `onSubmitted`.
CALLS: `cartProvider.notifier.addProductByBarcode()`.
INPUT: a barcode string from either source.
OUTPUT: none (`Future<void>`).
STATE CHANGES: `setState` for `_lookupInProgress`/`_lastBarcode`/
`_statusMessage` (all local UI state, not cart state).
UI EFFECT: updates the status card text; on success clears the manual
field, on failure selects its text for easy retyping.

NEW FUNCTION — its BODY is a direct adaptation of `[OLD/SOURCE]`
`_PosScreenState._submitBarcode()` (same success/failure UI reaction,
same target method), restructured as a small reusable method instead of
being inlined in one `TextField`'s submit handler, since this screen has
two call sites (camera + manual) that both need the identical reaction.

## 8. User Click Flow

```text
User taps the scan icon in the search bar
↓
Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()))
↓
BarcodeScannerScreen.initState() — MobileScannerController starts the camera
↓
User points the camera at a barcode
↓
MobileScanner's onDetect fires → _onDetect(capture)
↓
first non-empty barcode value extracted, checked against the 1200ms dedup window
↓
HapticFeedback.mediumImpact() → _lookupBarcode(value)
↓
ref.read(cartProvider.notifier).addProductByBarcode(value)
↓
CartNotifier.addProductByBarcode() — catalog search → validity checks → addItemFromProduct()
↓
status card shows "<Product name> added to cart"; the camera keeps running for the next scan
```

```text
User instead types a barcode into the manual field and presses Enter/Done
↓
TextField.onSubmitted → _lookupBarcode(value.trim())
↓
(same path as above from here on)
```

## 9. Data Flow

```text
raw camera frame
↓
MobileScannerController (native camera + ML Kit barcode decoding, platform-side)
↓
BarcodeCapture.barcodes[i].rawValue
↓
_onDetect's dedup filter
↓
_lookupBarcode(value)
↓
CartNotifier.addProductByBarcode(value)
↓
Product.barcode field comparison (case/whitespace-insensitive) against the loaded catalog
↓
CartItem added to cartProvider's state.items
```

## 10. Mobile UI

This entire day IS the mobile UI adaptation — see section 2's discrepancy
note. Concretely: the camera view fills most of the screen (`Expanded`
flex 3) with a green targeting frame overlay and a floating status card
at the bottom (both visual elements ported directly from
`PhoneScannerScreen._buildScanner()`), and a manual-entry field sits below
it rather than being a separate AppBar field the way source's desktop
layout has room for. A torch/flashlight toggle is kept in the AppBar
(same `_cameraController.toggleTorch` call source uses). No relay
connection UI (session code entry, connection status) exists here at all
— there is nothing to connect to.

Portrait is the primary target; `MobileScanner` handles device rotation
internally (the same as it does in source's `PhoneScannerScreen`, which
runs on a phone for the identical reason).

## 11. API

None new. Barcode lookup reuses `GET /api/products?q=<barcode>` (via
`ProductService.findByBarcode`, traced in Day 6) and cart mutation reuses
the Day 7 cart-service switch point — no new backend endpoint was added
or needed for this day.

## 12. Error Handling

- **Empty barcode** (camera somehow emits an empty string, or the manual
  field is submitted blank): `addProductByBarcode` returns
  `added: false` immediately, no lookup attempted.
- **No matching product**: `added: false`, `product: null`, message
  identifies the barcode that wasn't found.
- **Inactive / not-sellable / out-of-stock product**: `added: false`, but
  `product` IS populated (so the UI can still name what was found, even
  though it wasn't added) — this exact behavior/distinction is preserved
  from source.
- **Repeated rapid camera detections of the same code**: suppressed for
  1200ms so one physical scan doesn't fire `addProductByBarcode` (and
  therefore `addItemFromProduct`) many times per second while the camera
  holds the code in frame.
- **Camera permission denied / no camera available**: not explicitly
  handled by this screen beyond whatever `mobile_scanner` itself surfaces
  (its own permission-request UI/error states) — `[OLD/SOURCE]`'s
  `PhoneScannerScreen` doesn't add custom handling for this either, so
  this isn't a regression, just an unhandled case inherited as-is.

**Problems Found**: none new this day beyond the architectural
discrepancy already documented in section 2 (which is a deliberate
divergence, not a bug).

## 13. State Management

`cartProvider`: read (not watched) by `_lookupBarcode` — a one-shot
action, the screen doesn't need to rebuild when cart state changes (it
only cares about the return value of one call). `_lastBarcode`/
`_statusMessage`/`_lookupInProgress`/`_lastDetectedValue`/`_lastDetectedAt`:
all local `State` fields — none of this belongs in a shared provider,
it's transient scan-session UI state scoped to one open screen instance.

## 14. Testing

`test/cart_provider_test.dart` (MODIFIED, +8 tests in a new
`CartNotifier.addProductByBarcode (Day 8)` group): empty barcode
short-circuits, unknown barcode, successful add, case/whitespace-
insensitive matching, scanning an already-cart product increments qty
instead of duplicating the line, and the three rejection paths (inactive/
not-sellable/out-of-stock) each verified independently. A
`_FakeProductService` (network-free, same pattern as
`product_provider_test.dart`'s) backs `productServiceProvider` via
`ProviderContainer` overrides so these tests never touch real HTTP.

**Explicit, honest testing limitation**: `BarcodeScannerScreen`'s actual
camera integration (`MobileScannerController`/`MobileScanner` widget) was
NOT widget-tested — `flutter_test`'s sandbox has no real camera, and
`mobile_scanner`'s platform channels aren't mocked in this project.
Testing `_onDetect`'s dedup/haptic logic in isolation from a real
`BarcodeCapture` would mean re-implementing the plugin's own data types
as fakes for limited additional confidence, given the logic is a
byte-identical, already-shipped port. What IS fully tested is everything
downstream of a detected value — `addProductByBarcode`'s business logic
— which is the part actually written this day; the camera plumbing above
it is a direct, unmodified port of already-working source code.

## 15. Verification

```text
$ flutter analyze
Analyzing frontend_flutter_mobile...
6 issues found. (ran in 1.5s)
```
All 6 are pre-existing-pattern `info`s (2 from Day 6, 2 from Day 7, plus
one NEW pre-existing-pattern info this day: `BarcodeFormat.itf` is
deprecated in favor of `BarcodeFormats.itf14` — kept because it's the
exact enum value `[OLD/SOURCE]` itself still uses; "fixing" it here would
silently diverge from the ported reference). Zero warnings, zero errors.

```text
$ flutter test
00:05 +88: All tests passed!
```
88 tests total (8 new this day, all in `cart_provider_test.dart`; every
Day 1-7 test still passing).

`flutter run` against a live device with a real camera was NOT performed
this session (none available) — recorded honestly. This is the one day
in this task's scope where that gap matters most, since the untested
camera integration is precisely the part a live-device run would exercise
that unit tests structurally cannot.

## 16. Definition of Done

- [x] `CartNotifier.addProductByBarcode`/`BarcodeAddResult` ported,
      function-level traced, fully unit tested
- [x] Camera-based scanning screen built, reusing source's exact
      controller config and detection-dedup logic
- [x] Manual barcode entry fallback, funneling through the identical
      business-logic path as camera scans
- [x] Camera permissions declared for both platforms, using
      already-verified-working strings, not invented
- [x] A real architectural discrepancy (source's 3-mechanism relay setup
      vs. this port's direct in-app scanning) identified and explicitly
      justified, not silently diverged from
- [x] `flutter analyze` — 0 errors/warnings (6 pre-existing-pattern infos)
- [x] `flutter test` — 88/88 passing
- [x] Testing limitation (camera plugin can't be exercised in
      `flutter_test`) stated explicitly rather than glossed over
- [ ] `flutter run` against a live device with a camera (not performed —
      none available this session; see section 15)

## 17. What I Should Understand Before Moving to Day 9

`CartNotifier` now carries a `Ref _ref` field, added specifically for
`addProductByBarcode`'s `productsProvider` read. Day 9's `setCustomer`/
`setTable`/`restoreItems` methods (all deferred from Day 7) don't need
`_ref` themselves based on source's own signatures, but if Day 9
introduces anything that needs to read ANOTHER provider from inside
`CartNotifier`, `_ref` is already there — don't add a second ad-hoc
mechanism for that. `BarcodeScannerScreen` currently has no way to signal
back to `PosRegisterScreen` other than the cart state itself updating
(there's no `Navigator.pop(someValue)` — it's meant to stay open for
repeated scans, unlike `ProductModifierSheet`'s single-result-then-close
pattern). Day 9's table/customer pickers should decide independently
whether they're closer to "stays open" (like this screen) or "picks one
thing and closes" (like the modifier sheet) based on their own actual
UX need, not by copying this screen's choice reflexively.
