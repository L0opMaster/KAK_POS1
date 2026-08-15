# Day 14 Plan — Khmer Rendering (PDF scope only)

Not yet executed — this is the plan to follow when implementing it, written
against the actual current state of both projects (not the original 20-day
plan's text, which predates Days 9–13's real scope decisions).

## 1. Goal

Day 13 shipped the PDF printing pipeline but explicitly stubbed its Khmer
branch: `print_service.dart`'s `_pageContent` always takes the `pw.Text` +
`KhmerPdfFont`-fallback path, documented as "Khmer text renders through
the fallback font, imperfectly shaped but functional, never a crash."
Day 14 replaces that stub with the real thing: for a receipt containing
Khmer text, render the on-screen `ReceiptContent` widget off-screen to a
bitmap and embed it as a `pw.Image`, so Khmer glyphs are pixel-perfect
(matching what the cashier saw in `ReceiptPaperView`) instead of relying
on `package:pdf`'s imperfect non-weight-aware font-fallback shaping.

**Scope narrowed from the original 20-day plan, deliberately**: source's
Day 14 bundles both the PDF bitmap path (`receipt_bitmap_renderer.dart`)
*and* the ESC/POS bitmap path (`escpos_receipt_builder.dart`), because on
desktop's own timeline, working bluetooth/usb/network transports already
existed before its Day 14 ran. Mobile's timeline is different — Day
15/16 (real ESC/POS transports) hasn't happened yet, `ThermalPrinterService`
is still the Day 13 partial port (`loadConfig`/`saveConfig` only), and
`printReceipt`'s non-`pdfDriver` branch is an intentionally-unreachable
stub. Porting `escpos_receipt_builder.dart` now would be dead code with
zero callers — same reasoning that dropped `buildReceiptsPdf` in Day 13.
**Recommendation: this day ports `receipt_bitmap_renderer.dart` and wires
it into `print_service.dart`'s PDF path only. `escpos_receipt_builder.dart`
moves to whichever day actually builds a real ESC/POS transport (Day
15/16), where it will finally have a caller.**

## 2. Source Files to Study

```text
frontend-flutter-pos/lib/features/pos/services/printing/receipt_bitmap_renderer.dart   (179 lines — port this)
frontend-flutter-pos/lib/features/pos/services/print_service.dart                       (the Khmer branch this plan restores — already read in full for Day 13)
frontend-flutter-pos/test/khmer_receipt_dispatch_test.dart                              (the ONLY sanctioned way to test this — see §6)
frontend-flutter-pos/test/receipt_bitmap_renderer_test.dart                             (read for what NOT to attempt — see §6)
```

Do **not** open `escpos_receipt_builder.dart` for this day — out of scope
per §1.

## 3. Exact Code to Port — `receipt_bitmap_renderer.dart`

`ReceiptRenderException` (define in the same file, matching source):

```dart
class ReceiptRenderException implements Exception {
  const ReceiptRenderException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

`ReceiptBitmapRenderer` — a `const` class, two methods. `renderImage`
mounts `ReceiptContent` (already ported Day 12, `widgets/receipt_paper_view.dart`)
off-screen via an `OverlayEntry` positioned at `left: -100000` (laid out
and painted, never visible), reads back a `RenderRepaintBoundary`, and
converts to raw RGBA — deliberately *not* PNG-encode-then-decode, to skip
a wasted zlib round trip (this was a real profiled bottleneck in source,
~2.3s for one receipt — see `print_service.dart`'s doc comment on
`_khmerImagePageContent`, already ported Day 13, which explains the same
thing from the caller's side):

```dart
Future<img.Image> renderImage(
  BuildContext context,
  ReceiptViewModel receipt,
  PrinterPaperSize paperSize,
) async {
  const logicalWidth = kReceiptContentWidth; // 300, from receipt_paper_view.dart
  final pixelRatio = paperSize.dotWidth / logicalWidth; // 384/300 or 576/300 — NOT paperSize.dotWidth used as a layout width, that was the old bug
  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -100000,
      top: 0,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.white,
          child: RepaintBoundary(
            key: boundaryKey,
            child: Container(
              width: logicalWidth,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: ReceiptContent(receipt: receipt),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await timePrintStage('receiptWidgetMount', () async {
      await WidgetsBinding.instance.endOfFrame; // mount + layout
      await WidgetsBinding.instance.endOfFrame; // repaint
    });
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw const ReceiptRenderException(
        'Unable to render Khmer receipt: bitmap boundary failed to mount.',
      );
    }
    final uiImage = await timePrintStage(
      'receiptToImage',
      () => renderObject.toImage(pixelRatio: pixelRatio),
    );
    final byteData = await timePrintStage(
      'receiptToRawBytes',
      () => uiImage.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    if (byteData == null) {
      throw const ReceiptRenderException('Unable to render Khmer receipt: no pixel data.');
    }
    return img.Image.fromBytes(
      width: uiImage.width,
      height: uiImage.height,
      bytes: byteData.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  } finally {
    entry.remove();
  }
}

Future<img.Image> render(
  BuildContext context,
  ReceiptViewModel receipt,
  PrinterPaperSize paperSize,
) async {
  final decoded = await renderImage(context, receipt, paperSize);
  return timePrintStageSync(
    'receiptDither',
    () => img.ditherImage(decoded, kernel: img.DitherKernel.floydSteinberg),
  );
}
```

Note: `render()` (dithered, black/white) is the ESC/POS-only entry point —
out of scope per §1, don't call it from anywhere yet. `renderImage()`
(full-color/grayscale, undithered) is the one `print_service.dart` needs
for PDF embedding — PDF viewers render full color fine, dithering an image
that's about to go into a PDF would only make it look worse.

**Re-verify the exact code against source before porting** — this section
was reconstructed from a research pass, not pasted mechanically; treat it
as a strong reference, not a guaranteed byte-for-byte quote.

## 4. Wiring Into `print_service.dart` (already-ported Day 13 file)

Day 13 left this exact stub, quoted from the current mobile source:

```dart
/// See this class's doc comment for why the Khmer-bitmap branch isn't
/// here yet — always takes the `pw.Text` path for now.
pw.Widget _pageContent(
  BuildContext? context,
  ReceiptViewModel r,
  PrinterPaperSize paperSize,
) {
  return _receiptPageContent(r, paperSize);
}
```

Restore it to source's real branch:

```dart
Future<pw.Widget> _pageContent(
  BuildContext? context,
  ReceiptViewModel r,
  PrinterPaperSize paperSize,
) async {
  if (r.containsKhmer && context != null && context.mounted) {
    return _khmerImagePageContent(context, r, paperSize);
  }
  return _receiptPageContent(r, paperSize);
}
```

This makes `_pageContent` async — `buildReceiptPdf`'s call site
(`final content = _pageContent(context, r, paperSize);`) needs an `await`
added back. Add the new method:

```dart
Future<pw.Widget> _khmerImagePageContent(
  BuildContext context,
  ReceiptViewModel r,
  PrinterPaperSize paperSize,
) async {
  final decoded = await timePrintStage(
    'receiptPdfBitmapRender',
    () => bitmapRenderer.renderImage(context, r, paperSize),
  );
  final targetWidth = paperSize.pdfPageFormat.availableWidth;
  final targetHeight = targetWidth * decoded.height / decoded.width;
  return pw.Image(
    pw.ImageImage(decoded),
    width: targetWidth,
    height: targetHeight,
    fit: pw.BoxFit.fill,
  );
}
```

`PrintService` needs the injectable field back (source's exact pattern,
`EscPosReceiptBuilder` uses the identical shape — cited in the Day 14
research pass as precedent even though that file itself stays out of
scope):

```dart
class PrintService {
  PrintService(this._api, this._ref, {this.bitmapRenderer = const ReceiptBitmapRenderer()});
  final ApiService _api;
  final Ref _ref;
  final ReceiptBitmapRenderer bitmapRenderer;
  ...
}
```

Update this class's own header doc comment (currently says "the Khmer
bitmap-image branch... is Day 14 scope" as a *dropped* item) to reflect
that it's now implemented, and correct `printer_pdf_format.dart`'s
`availableWidth` usage if the mobile `PdfPageFormat` port doesn't expose
that getter identically — verify against `package:pdf`'s actual API
before assuming source's exact call compiles unchanged.

## 5. New/Modified Mobile Files

```text
mobile: lib/features/pos/services/printing/receipt_bitmap_renderer.dart   (NEW — §3)
mobile: lib/features/pos/services/print_service.dart                      (MODIFY — §4)
mobile: pubspec.yaml                                                      (MODIFY — add `image` as an explicit direct dependency)
```

On the `image` package: it's already present **transitively** (pulled in
by `pdf`/`printing`, locked at 4.8.0 per `pubspec.lock` — checked during
this planning pass) but not declared directly. Add `image: ^4.3.0`
(matching source's pin) explicitly rather than relying on transitive
resolution, so a future `pdf`/`printing` upgrade can't silently drop or
change the version this file needs. Confirm `img.ditherImage`/
`img.DitherKernel.floydSteinberg`/`img.Image.fromBytes`/`img.ChannelOrder.rgba`
all still exist at whatever version actually resolves (4.8.0 is newer than
source's pinned 4.3.0 — these are long-stable APIs but verify, don't
assume).

## 6. Testing — read this before writing any test

**Source's own test for the real renderer is deliberately absent.**
`receipt_bitmap_renderer_test.dart` only tests `ReceiptRenderException`'s
constructor/message — its header comment documents that mounting a real
`OverlayEntry` + double `endOfFrame` under `flutter_test` renders
correctly but then **hangs at shutdown** (`Bad state: Cannot close sink
while adding stream`), reproduced across multiple attempts regardless of
context source. This is a `flutter_test`-sandbox limitation, not a
renderer bug — do not spend time trying to make a widget test exercise
the real `renderImage`/`render` methods end-to-end. It will hang the test
runner.

**The sanctioned pattern** (`khmer_receipt_dispatch_test.dart`): inject a
fake `ReceiptBitmapRenderer` subclass that overrides both methods to
return a tiny synthetic `img.Image` instantly, with call counters:

```dart
class _FakeBitmapRenderer extends ReceiptBitmapRenderer {
  int renderCalls = 0;
  int renderImageCalls = 0;

  @override
  Future<img.Image> renderImage(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) async {
    renderImageCalls++;
    return img.Image(width: paperSize.dotWidth, height: 24);
  }

  @override
  Future<img.Image> render(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) async {
    renderCalls++;
    return img.Image(width: paperSize.dotWidth, height: 24);
  }
}
```

Inject via `PrintService(api, ref, bitmapRenderer: fake)`. Get a real
`BuildContext` via `pumpWidget(MaterialApp(home: Builder(builder: (ctx) { capturedContext = ctx; return const SizedBox(); })))`,
then call `buildReceiptPdf` inside `tester.runAsync(...)` (needed because
`renderImage`'s real `endOfFrame` waits — even bypassed here by the fake
— still cross real async boundaries the fake widget-pump machinery
doesn't like without `runAsync`). Assert:

- `fake.renderImageCalls == 1` and `fake.renderCalls == 0` for a Khmer
  receipt going through `buildReceiptPdf` (PDF path calls `renderImage`,
  undithered — never `render`).
- For an English-only receipt, both counters stay `0` — confirms the
  `pw.Text` fallback path is still taken when `containsKhmer` is false,
  exactly like Day 13's existing `print_service_test.dart` already
  verifies (that test suite doesn't need to change, just gains new
  Khmer-with-context cases).
- The PDF bytes contain `/Subtype /Image` (confirms an image was actually
  embedded, not just that the fake was called) — same technique source's
  test uses; a plain substring search on the returned `Uint8List` decoded
  as latin1/ascii is enough, no PDF parser needed.

Also keep Day 13's existing "Khmer receipt with `context: null`" test
case passing unchanged — `buildReceiptPdf` called without a `context`
must still take the `pw.Text` fallback path (source's own documented
behavior, unaffected by this day's change), so `print_service_test.dart`'s
current "a Khmer receipt still renders... rather than failing to produce
a PDF" test should keep passing as-is once `_pageContent`'s `context`
null-check is ported correctly.

## 7. Manual Verification (real rendering can't be unit-tested — see §6)

Since the actual off-screen rendering path is untestable under
`flutter_test`, this day's real correctness signal is a live device/
simulator run: generate a receipt PDF containing Khmer product names,
customer name, or business name, and visually confirm:

- Khmer glyphs render correctly (proper subscript/vowel-stacking —
  `pw.Text` + font fallback was the imperfect baseline this replaces).
- The embedded image is sized to fill the page's content width with no
  distortion (aspect ratio preserved — `targetHeight` is derived from
  `decoded.height / decoded.width`, never a fixed value).
- An English-only receipt is unaffected — still crisp native `pw.Text`,
  not routed through the bitmap path unnecessarily (`containsKhmer` gates
  correctly).
- A mixed English+Khmer receipt (e.g. Khmer customer name, English
  product names) renders as one bitmap covering the whole page — confirm
  it doesn't look worse than a hypothetical "per-line" mixed approach;
  source made the same whole-document tradeoff deliberately (see
  `print_service.dart`'s own doc comment on `_pageContent`), not
  something to "improve" here.

Record explicitly in this day's write-up whether this manual check was
actually performed on a device, or deferred for lack of one — Day 8's
precedent (`BarcodeScannerScreen`'s camera path) already established
this project's convention of stating that limitation honestly rather
than glossing over it.

## 8. Definition of Done (for whoever executes this plan)

- [ ] `receipt_bitmap_renderer.dart` ported, `ReceiptRenderException` +
      `ReceiptBitmapRenderer.renderImage`/`.render` present
- [ ] `image` added as an explicit `pubspec.yaml` dependency, version
      verified compatible with what actually resolves
- [ ] `print_service.dart`'s `_pageContent`/`_khmerImagePageContent`
      restored, `PrintService` gains the injectable `bitmapRenderer` field
- [ ] `print_service.dart`'s class-level doc comment updated (no longer
      lists the Khmer bitmap branch as dropped)
- [ ] Dispatch-level tests added per §6 (fake renderer, call-count +
      `/Subtype /Image` assertions) — NOT an attempt at real-rendering
      widget tests (§6 explains why that hangs)
- [ ] `flutter analyze` — 0 new errors/warnings
- [ ] `flutter test` — full suite still green, including Day 13's
      existing `print_service_test.dart` cases
- [ ] Manual on-device visual check performed, or its absence stated
      honestly (§7)
- [ ] `escpos_receipt_builder.dart` confirmed still NOT ported — scope
      boundary from §1 held, not silently expanded mid-implementation
