# Printing System — Zero to Hero

This is a teaching document, not API documentation. It explains how the printing
system in **this project** (`write-test-pos`, Flutter frontend + Spring Boot
backend) actually works *today*, so you could rebuild an equivalent system
from nothing in a future Flutter mobile POS app.

Every file path, class name, and method signature in this document was
verified against the repository at the time of writing (including a live
`[PrintPerf]`/`[ReceiptLayout]` capture from a real Khmer print job — see
§14/§17). Where the project's design differs from a "textbook" approach,
that's called out explicitly. Where a snippet is a teaching simplification
rather than a copy of production code, it's labeled **"Educational
simplified example."**

---

## 1. What This System Does

This project prints/generates three fundamentally different kinds of
documents. They're easy to conflate because they all end up as "a PDF" or
"paper coming out of a printer," but they exist for different reasons and
are built by different code:

| Document | Physical form | Purpose | Built by |
|---|---|---|---|
| **Receipt** | 58mm/80mm thermal roll, or driver-printed PDF | Proof of purchase, handed to the customer at checkout | Flutter (`print_service.dart`, `escpos_receipt_builder.dart`) |
| **Invoice / Estimate** | A4 PDF | Formal billing document, HTML→PDF, usually emailed | Spring Boot backend (`PdfService.java`) |
| **Report** | A4 PDF, portrait or landscape | Internal/analytical document (sales, inventory) | Flutter (`a4_report_pdf.dart`) |

**Receipt ≠ Invoice ≠ Report.** They share *infrastructure* (Khmer fonts,
PDF page-geometry helpers, localization patterns) but intentionally do
**not** share one giant "document" class or one giant layout. A receipt is
narrow, single-column, thermal-paper-shaped. A report is wide, tabular,
multi-page A4. An invoice is a formal HTML-rendered document generated
server-side. Forcing all three through one shared layout is exactly the
kind of mistake §35 documents this project having made (with receipts) and
undone — twice, as it turns out (see §35's newest entry).

Same-category documents, however, **must** share one visual specification —
that rule, and how thoroughly this project actually applies it, is §7's and
§14's subject.

## 2. Current Printing Architecture Overview

Every document, regardless of type, flows through the same five conceptual
layers. This diagram is adapted from the actual current code, not a generic
template:

```
Business Data                  (Sale, ReceiptResponse, report row models)
      |
      v
Document/View Model            (ReceiptViewModel — receipts only; reports
      |                          pass plain columns/rows straight through)
      v
Document Layout                (receipt_layout_spec.dart typography/spacing
      |                         for the PDF-text path; ReceiptContent widget
      |                         for the on-screen + raster path — §7)
      v
Renderer                       (pw.Document builder, EscPosReceiptBuilder,
      |                         ReceiptBitmapRenderer, KhmerTextRasterizer)
      v
Output                         (Uint8List of PDF bytes, or List<int> of
      |                         ESC/POS bytes)
      v
Transport                      (Printing.layoutPdf / NetworkPrinterTransport
      |                         / UsbPrinterTransport / BluetoothPrinterTransport)
      v
Printer
```

What each layer owns, and — just as important — what it must **not** do:

1. **Business Data** — the backend's finalized, authoritative numbers. Never
   recalculated downstream (§5).
2. **Document/View Model** — a flat, print-ready shape built once
   (`ReceiptViewModel`). Knows nothing about PDF, ESC/POS, or Flutter
   widgets.
3. **Document Layout** — named typography/spacing shared by every renderer
   of one document type, so they can't drift apart. Contains no business
   logic.
4. **Renderer** — turns the view model + layout into actual pixels/bytes.
   Never knows *how* the bytes reach the printer.
5. **Output** — a dumb byte buffer. No behavior.
6. **Transport** — moves bytes to a destination. Never knows or cares
   what's *inside* them (§22's `PrinterTransport` interface; §21 covers why
   the Khmer-vs-English decision is made before this layer, never inside
   it).

Keeping these layers separate is the single biggest lesson this document
has to teach — §50 restates it as a checklist.

## 3. Printing File Map

All paths are relative to `frontend-flutter-pos/lib/` unless marked
`backend-spring-boot/`.

**Models (business data)**
```
features/pos/models/receipt_models.dart       ReceiptResponse, ReceiptLine, ReceiptPayment
features/pos/models/cart_models.dart          CartItem (pre-checkout, in-memory)
features/reports/models/report_models.dart    PageMeta, PagedResult<T>, report row types
features/inventory/models/inventory_models.dart  InventoryValuationItem, ...Report
```

**View models**
```
features/pos/services/printing/receipt_view_model.dart   ReceiptViewModel, ReceiptLineViewModel,
                                                            ReceiptAdjustment(Type)
features/pos/services/printing/receipt_labels.dart        ReceiptLabels
```
Reports have **no** equivalent view-model class — their "view model" is
just the `List<String> columns` / `List<List<String>> rows` /
`List<MapEntry<String,String>> summary` parameters passed straight into
`A4ReportPdf.build`. See §26 for why this is intentionally simpler than the
receipt path.

**Services (orchestration)**
```
features/pos/services/print_service.dart                  PrintService (PDF pipeline)
features/pos/services/printing/thermal_printer_service.dart  ThermalPrinterService (ESC/POS)
features/pos/services/sale_service.dart                   SaleService (fetches ReceiptResponse)
features/reports/services/report_service.dart              fetchAllPages, reportPrintPageSize
```

**Receipt UI + renderers**
```
features/pos/widgets/receipt_paper_view.dart          ReceiptPaperView (screen wrapper),
                                                         ReceiptContent (the shared receipt
                                                         body — used by BOTH the on-screen
                                                         preview AND the Khmer raster path,
                                                         see §7/§14), kReceiptContentWidth
features/pos/widgets/receipt_preview_screen.dart       ReceiptPreviewScreen (post-checkout)
features/pos/screens/receipts_screen.dart              ReceiptsScreen (Receipts, Print One/All)
features/pos/services/printing/escpos_receipt_builder.dart   EscPosReceiptBuilder
features/pos/services/printing/receipt_bitmap_renderer.dart  ReceiptBitmapRenderer,
                                                                ReceiptRenderException
```

**Report renderers**
```
core/services/printing/a4_report_pdf.dart          A4ReportPdf (shared A4 table/header/footer)
features/reports/screens/*.dart                     report screens (§26)
features/inventory/screens/inventory_valuation_screen.dart  the one inventory report screen
```

**Khmer rendering**
```
core/utils/khmer_text.dart                          containsKhmerText(String)
core/services/printing/khmer_text_rasterizer.dart    KhmerTextRasterizer (per-string, reports)
features/pos/services/printing/receipt_bitmap_renderer.dart  (per-document, receipts)
features/pos/services/printing/khmer_pdf_font.dart   KhmerPdfFont (shared pw.ThemeData)
```

**Printer configuration & transports**
```
features/pos/services/printing/printer_profile.dart          PrinterPaperSize, PrinterTransportType,
                                                                PrinterConfig
features/pos/services/printing/printer_pdf_format.dart        PrinterPaperSize -> PdfPageFormat
features/pos/services/printing/receipt_layout_spec.dart        ReceiptTypography, ReceiptSpacing
features/pos/services/printing/printer_transport.dart          abstract PrinterTransport
features/pos/services/printing/network_printer_transport.dart  NetworkPrinterTransport
features/pos/services/printing/usb_printer_transport.dart      UsbPrinterTransport
features/pos/services/printing/bluetooth_printer_transport.dart BluetoothPrinterTransport
features/pos/screens/settings_modules_screen.dart              Settings UI (§25)
features/pos/screens/print_test_screen.dart                    Dev-only print/raster test screen (§36)
```

**Fonts**
```
assets/fonts/NotoSans-Regular.ttf, NotoSans-Bold.ttf
assets/fonts/NotoSansKhmer-Regular.ttf, NotoSansKhmer-Bold.ttf
pubspec.yaml  (`flutter: fonts:` block registers both families for Flutter widgets)
```

**Localization**
```
lib/l10n/app_en.arb, app_km.arb            source strings
lib/l10n/generated/app_localizations*.dart  generated by `flutter gen-l10n`
core/utils/l10n_extensions.dart             context.l10n getter
core/providers/language_provider.dart       AppLanguage, appLanguageProvider
```

**Misc utilities**
```
core/utils/bounded_concurrency.dart   mapBounded<T,R>() — Print All's fetch-throttling
core/utils/receipt_date_format.dart   formatReceiptDate/formatReceiptTime
core/utils/print_perf.dart            timePrintStage/timePrintStageSync ([PrintPerf] logs)
```

**Backend (Spring Boot, Java)**
```
backend-spring-boot/src/main/java/com/kaknnea/pos/service/PdfService.java     HTML -> PDF (OpenHTMLtoPDF)
backend-spring-boot/src/main/java/com/kaknnea/pos/service/EmailService.java   Spring Mail attachments
backend-spring-boot/src/main/java/com/kaknnea/pos/service/SaleService.java    invoicePdf(), estimatePdf()
backend-spring-boot/src/main/java/com/kaknnea/pos/service/ReportService.java  dailyZReportPdf()
backend-spring-boot/src/main/resources/fonts/NotoSansKhmer-*.ttf              9 weights (Thin..Black)
```

**Tests directly covering printing** (§36 explains each)
```
test/receipt_labels_test.dart              test/receipt_financial_fields_test.dart
test/receipt_bitmap_renderer_test.dart     test/khmer_receipt_dispatch_test.dart
test/khmer_text_rasterizer_test.dart       test/a4_report_pdf_khmer_test.dart
test/escpos_receipt_adjustments_test.dart  test/print_service_batch_test.dart
test/printer_pdf_format_test.dart          test/pdf_font_test.dart
test/report_print_pagination_test.dart     test/receipts_print_all_selection_test.dart
test/receipt_image_decoder_test.dart       test/bounded_concurrency_test.dart
test/receipt_pdf_page_format_test.dart
```

### Verified package versions (`pubspec.lock`, not assumed)

| Package | Constraint (`pubspec.yaml`) | Resolved |
|---|---|---|
| `pdf` | `^3.10.4` | **3.11.3** |
| `printing` | `^5.12.0` | **5.14.2** |
| `image` | `^4.3.0` | **4.3.0** |
| `esc_pos_utils_plus` | — | **2.0.4** |
| `flutter_pos_printer_platform_image_3` | `^1.2.4` | **1.2.4** |
| `print_bluetooth_thermal` | `^1.2.1` | **1.2.1** |
| `shared_preferences` | — | **2.5.3** |
| `flutter_riverpod` | — | **2.6.1** |
| `archive` (transitive, pulled in by `pdf`/`image`) | — | **3.6.1** |
| Dart SDK | `>=3.0.0 <4.0.0` | **3.11.1** (this checkout) |

Two things worth flagging up front, both explained in depth later: the
project targets `pdf: ^3.10.4`, which currently resolves to **3.11.3**, not
3.12.0 — if you've seen 3.12.0 referenced elsewhere (an earlier profiling
session assumed it), that was never actually the resolved version; the two
versions' relevant `pw.ImageImage`/`pw.MemoryImage` APIs are identical
either way (§16). And `archive` — a *pure-Dart* zlib/deflate implementation
— matters a lot more than its transitive-dependency status suggests; see
§17.

## 4. Complete Sale → Receipt Flow

Trace one real transaction, left to right, with the actual class/method at
each step:

```
Product tap on POS grid
  -> CartItem added to cart state       (features/pos/providers/cart_provider.dart)
  -> Payment screen                     (features/pos/screens/payment_screen.dart)
  -> sale finalized on the backend      (SaleService.pay() / .createSale(), Java)
  -> backend returns the finalized Sale
  -> Flutter fetches the receipt        SaleService.getReceipt(saleId)
       GET /api/pos/sales/{saleId}/receipt  -> ReceiptResponse.fromJson(json)
  -> ReceiptViewModel.fromReceiptResponse(receipt, language, l10n)
  -> ReceiptPreviewScreen shows it via ReceiptPaperView
  -> user taps Print
       -> PrintService.printReceipt(context, saleId)   [pdfDriver transport]
       -> ThermalPrinterService.printReceipt(...)        [bluetooth/usb/network]
```

There are **two** points where a `ReceiptViewModel` can be built, and this
matters:

1. **`ReceiptViewModel.fromCart(...)`** — built immediately after payment
   succeeds, straight from the in-memory cart, *before* the backend's
   receipt endpoint has necessarily finished loading. Used by
   `ReceiptPreviewScreen` so the post-sale screen isn't stuck on a spinner.
2. **`ReceiptViewModel.fromReceiptResponse(...)`** — built from the
   backend's `GET /api/pos/sales/{id}/receipt` response. Used for reprints
   (`ReceiptsScreen`) and, once it loads, to *override* the cart-derived
   preview's paid/change amounts with the backend's authoritative values.

### Why receipt printing must use finalized sale data, not recalculate it

The cart, at the moment of tapping "Pay," doesn't yet know whether a
discount rule changed server-side, what exact tax rounding the backend
used, or what payment split actually got recorded. The backend is the only
place that has ever actually *committed* money — the only trustworthy
source for what to print. `ReceiptsScreen`'s reprint path never uses
`fromCart` at all — a reprint, by definition, only has the backend's
stored record to work from.

**Educational simplified example:**
```dart
// Right after payment succeeds — show something immediately.
var receipt = ReceiptViewModel.fromCart(items: cart.items, paidAmount: tendered, ...);
setState(() {});

// In the background, fetch the authoritative version and swap it in.
final response = await saleService.getReceipt(saleId);
receipt = ReceiptViewModel.fromReceiptResponse(response, language, l10n);
setState(() {});
```

## 5. Authoritative Financial Data

From `backend-spring-boot/.../service/SaleService.java`:
```
taxable    = subtotal - invoiceDiscount
taxAmount  = taxable * taxRate
grandTotal = taxable + taxAmount + deliveryCharge + otherCharge
```
And for payments:
```
appliedAmount = min(requestTotal, remainingBeforePayment)   // "Paid" — never exceeds the total
changeAmount  = requestTotal - appliedAmount                 // what's handed back
```

| Term | Meaning | Can exceed total? |
|---|---|---|
| **Paid** (`paidAmount`) | Amount actually *applied* to the sale | No — capped at the total |
| **Tendered / Cash Received** | Raw cash the customer physically handed over | Yes |
| **Change** | `tendered − applied` | — |

`ReceiptViewModel` doesn't store "tendered" as its own field — it derives
"Cash Received" for display as `paidAmount + changeAmount`. `Change` is
only ever shown *together with* Cash Received, never alone — a lone Change
row next to a Paid row that already equals the total reads as change
appearing from nowhere.

### Why PDF/ESC-POS code must never calculate tax itself

Every renderer — `print_service.dart`'s `_receiptPageContent`,
`escpos_receipt_builder.dart`'s `_buildLatinText`, and (via
`ReceiptContent`, §7) both the on-screen preview and the Khmer raster —
reads `receipt.subtotal`, `receipt.total`, `receipt.adjustments` directly.
None of them add, subtract, or apply a tax rate:
```dart
// receipt_view_model.dart — the ONE place adjustments are assembled,
// from already-computed amounts, never recomputed:
List<ReceiptAdjustment> get adjustments => [
  if (discountAmount > 0) ReceiptAdjustment(ReceiptAdjustmentType.discount, discountAmount),
  if (deliveryCharge > 0) ReceiptAdjustment(ReceiptAdjustmentType.delivery, deliveryCharge),
  if (otherCharge > 0)    ReceiptAdjustment(ReceiptAdjustmentType.otherCharge, otherCharge),
  if (taxAmount > 0)      ReceiptAdjustment(ReceiptAdjustmentType.tax, taxAmount),
];
```
If a renderer recomputed `subtotal + tax` itself instead of reading
`receipt.total`, a rounding difference of even $0.01 between the backend's
math and the renderer's math would mean **the printed receipt doesn't
match what the customer was actually charged** — an accounting problem,
not a cosmetic one. `test/receipt_financial_fields_test.dart` encodes this
directly: it builds a `ReceiptViewModel` where the adjustments deliberately
don't arithmetically sum to `total - subtotal`, and asserts `r.total` is
still reported exactly as given.

## 6. ReceiptViewModel

### Why it exists

Before this pattern existed, each print pipeline — PDF, ESC/POS text, the
on-screen preview — read directly from `ReceiptResponse`/`CartItem` and
reformatted the same numbers independently. Three places could each get
"Cash Received," "Discount," or Khmer/English label wording subtly wrong in
three different ways, and nothing would catch it. `ReceiptViewModel` fixes
this by being the *only* thing every renderer reads:
```
              API Model (ReceiptResponse)  or  Cart (List<CartItem>)
                             |
                             v
                     ReceiptViewModel        <- ONE place: formatting, labels,
                             |                   adjustment list, currency,
                             |                   containsKhmer detection
              +--------------+---------------+---------------+
              v              v               v               v
      On-screen preview   PDF (PrintService)  ESC/POS text   Khmer bitmap
      (ReceiptContent)    (_receiptPageContent) (_buildLatinText) (ReceiptContent, §14)
```

### What it carries (`receipt_view_model.dart`, verified)

```dart
class ReceiptViewModel {
  final AppLanguage language;
  final String businessName;
  final String? address, phone;
  final String invoiceNumber, date, time;
  final String? cashierName, customerName, tableNumber;
  final List<ReceiptLineViewModel> lines;
  final double subtotal, discountAmount, taxAmount, deliveryCharge, otherCharge, total;
  final double paidAmount, changeAmount;
  final String? currencyCode;
  final double? exchangeRateKhr;
  final String? qrImageData, logoUrl;   // carried, but nothing in the
                                        // current print path reads qrImageData
  final String footer;
  final String? paymentMethodLabel;
  final ReceiptLabels labels;          // §39

  bool get containsKhmer => language.isKhmer || containsKhmerText(_allText);
  List<ReceiptAdjustment> get adjustments => [...];   // §5
  String fmt(double amount) => formatAmount(amount, currencyCode);
  String fmtAdjustment(ReceiptAdjustment a) => a.isSubtraction ? '-${fmt(a.amount)}' : fmt(a.amount);
  static String khrGroup(num v) => ...;   // "82000" -> "82,000"

  factory ReceiptViewModel.fromReceiptResponse(ReceiptResponse r, AppLanguage language, AppLocalizations l10n);
  factory ReceiptViewModel.fromCart({required List<CartItem> items, ...});
}
```

### What it supports

| Use case | Entry point |
|---|---|
| Checkout receipt (immediate) | `ReceiptPreviewScreen` via `.fromCart` |
| Reprint from history | `ReceiptsScreen` via `.fromReceiptResponse` |
| Print One | `PrintService.printReceipt(context, saleId)` |
| Print All | `ReceiptsScreen._printAllReceipts` → `mapBounded` → many `ReceiptViewModel`s |
| PDF output | `PrintService.buildReceiptPdf` |
| ESC/POS output | `EscPosReceiptBuilder.build` |

**Educational simplified example** (nowhere near the real field count, but
the shape is right):
```dart
class ReceiptViewModel {
  ReceiptViewModel({required this.total, required this.lines, required this.labels});
  final double total;
  final List<ReceiptLineViewModel> lines;
  final ReceiptLabels labels;

  bool get containsKhmer => containsKhmerText(lines.map((l) => l.name).join());

  factory ReceiptViewModel.fromApi(SaleResponse sale, AppLocalizations l10n) {
    return ReceiptViewModel(
      total: sale.total,                       // <-- copied, never recomputed
      lines: sale.items.map((i) => ReceiptLineViewModel(name: i.name, total: i.lineTotal)).toList(),
      labels: ReceiptLabels.fromL10n(l10n),
    );
  }
}
```

## 7. One Receipt Design System

### The problem this solves

Three surfaces show or produce a receipt's visual content: the post-checkout
`ReceiptPreviewScreen`, `ReceiptsScreen`'s reprint detail pane, and — as of
this session — the Khmer raster/PDF path. If each has its own layout code,
they *will* drift apart. This project hit that problem twice: once between
the two on-screen screens (fixed earlier — see below), and again, more
subtly, between the on-screen preview and the Khmer raster path (fixed in
this session — §14 has the full story).

### Current source of truth

```
ReceiptViewModel                                  <- data (§6)
        |
        v
ReceiptContent (widgets/receipt_paper_view.dart)   <- the ONE receipt-body
        |                                             widget: header, info,
        |                                             items, totals, payment,
        |                                             exchange rate, footer
   +----+----+--------------------+
   v         v                    v
ReceiptPreviewScreen   ReceiptsScreen's    ReceiptBitmapRenderer
(post-checkout,         detail pane         (Khmer PDF image AND
 via ReceiptPaperView)  (reprint, via        Khmer/mixed ESC/POS —
                         ReceiptPaperView)   §14)
```

`ReceiptPaperView` (the on-screen wrapper) and `ReceiptBitmapRenderer` (the
rasterizer) both mount the *same* `ReceiptContent` widget — not three
independent copies of "draw a receipt." `receipt_paper_view.dart`:
```dart
const double kReceiptContentWidth = 300;

class ReceiptPaperView extends StatelessWidget {
  final ReceiptViewModel receipt;
  final double width;
  const ReceiptPaperView({super.key, required this.receipt, this.width = kReceiptContentWidth});

  @override
  Widget build(BuildContext context) =>
      _ReceiptPaper(width: width, child: ReceiptContent(receipt: receipt));
}

class ReceiptContent extends StatelessWidget {
  final ReceiptViewModel receipt;
  const ReceiptContent({super.key, required this.receipt});
  @override
  Widget build(BuildContext context) => Column(children: [/* header, info, items, totals, ... */]);
}
```
`_ReceiptPaper` is on-screen-only chrome (a white card with a drop shadow
and rounded corners, simulating paper on a page background) — deliberately
**not** reused by the raster path, since a printed receipt has no "card"
sitting on a page to cast a shadow. `ReceiptBitmapRenderer` wraps the same
`ReceiptContent` in a plain opaque white `Container` instead (§14).

Only the *width* differs between the two on-screen call sites — a
full-screen modal (`ReceiptPreviewScreen`, `width: 300` — the same as
`kReceiptContentWidth`, the default) vs. a split-pane detail view
(`ReceiptsScreen`, `width: 380`) — surrounding layout, not receipt content.
Everything drawn *inside* `ReceiptContent` is identical code, run once, for
every consumer.

The PDF-text path (`print_service.dart`'s English/native
`_receiptPageContent`) can't literally share `ReceiptContent` — Flutter
widgets and `package:pdf` widgets are unrelated type systems. It shares the
*typography and spacing values* instead, via `receipt_layout_spec.dart`'s
`ReceiptTypography`/`ReceiptSpacing` constants, measured to match
`ReceiptContent`'s own on-screen sizing.

### What's shared vs. what's per-renderer

| Shared across every renderer | Renderer-specific |
|---|---|
| `ReceiptViewModel` (data) | How glyphs actually get drawn (Flutter `Text` vs `pw.Text` vs ESC/POS raster) |
| `ReceiptLabels` (localized strings) | Pixel/point sizing mechanics |
| `ReceiptContent` widget (preview + raster) | The PDF-text path's own `pw.Text` tree (values match, tree doesn't) |
| Financial rules (§5) | — |
| `ReceiptAdjustmentTypeLabel.labelFrom` | — |

### Why duplicate templates caused problems

```
BAD:
  CheckoutReceiptTemplate    <- its own header/info/items/totals code
  HistoryReceiptTemplate     <- a SECOND, slightly different copy
  RasterReceiptTemplate      <- a THIRD copy, drifted differently again

  A bug fixed in one template stays broken in the other two. A financial
  row present in one silently goes missing in another.

GOOD (current project):
        ReceiptViewModel
               |
         ReceiptContent  <- ONE widget, mounted by every consumer that can
               |             mount real Flutter widgets
      +--------+--------+
      v                 v
  On-screen (both     Khmer raster
  preview screens)    (PDF image + ESC/POS)
```

A concrete historical bug this pattern caused (before the fix, both times):
`escpos_receipt_builder.dart` used to check `discountAmount`/`taxAmount`
directly instead of iterating `receipt.adjustments`, so a receipt with a
delivery or "other" charge silently never printed that row on thermal
output even though the on-screen preview showed it. The fix, now
everywhere:
```dart
for (final adj in receipt.adjustments) {
  row(adj.type.labelFrom(labels), receipt.fmtAdjustment(adj));
}
```

## 8. Receipt Paper Sizes

Thermal receipt printers print in **dots**, at a fixed density — this
project's printers are 8 dots/mm, the near-universal thermal-head standard.

| Stock | Nominal width | Printable width | Dots (@ 8 dots/mm) |
|---|---|---|---|
| "58mm" | ~57mm actual roll | 48mm | **384** |
| "80mm" | 80mm actual roll | 72mm | **576** |

Verified, current, `printer_profile.dart`:
```dart
enum PrinterPaperSize {
  mm58, mm80;
  int get dotWidth => this == PrinterPaperSize.mm58 ? 384 : 576;
  PaperSize get escPosPaperSize => this == PrinterPaperSize.mm58 ? PaperSize.mm58 : PaperSize.mm80;
}
```
`test/printer_pdf_format_test.dart` pins these exact numbers down as a
regression test.

### Three, not two, unit systems

Beginners usually track two units (mm and pixels) and miss a third that
matters here:

- **Physical mm** — the roll's real-world width.
- **PDF points** (`package:pdf`) — 1/72 inch, physical-unit-based. A
  `PdfPageFormat` is defined in millimeters-converted-to-points.
- **Printer dots** (ESC/POS raster) — literal pixel columns the print head
  fires. No "inch" concept exists at that layer at all.
- **Flutter logical pixels** — what `ReceiptContent` is actually laid out
  in when mounted for rasterization (§14) — related to dots only via
  whatever `pixelRatio` the rasterizer applies, *not* 1:1.

`printer_pdf_format.dart` derives the PDF page format from the *same* 8
dots/mm density the ESC/POS path uses, so a receipt printed via the
PDF/driver transport and one printed via direct ESC/POS use the *same*
usable content width:
```dart
// 58mm: 384 dots / 8 dots-per-mm = 48mm printable -> 4.5mm margin each side
const PdfPageFormat _mm58Format = PdfPageFormat(
  57 * PdfPageFormat.mm, double.infinity,
  marginLeft: 4.5 * PdfPageFormat.mm, marginRight: 4.5 * PdfPageFormat.mm,
  marginTop: 5 * PdfPageFormat.mm, marginBottom: 5 * PdfPageFormat.mm,
);
// 80mm: 576 dots / 8 dots-per-mm = 72mm printable -> 4mm margin each side
const PdfPageFormat _mm80Format = PdfPageFormat(
  80 * PdfPageFormat.mm, double.infinity,
  marginLeft: 4 * PdfPageFormat.mm, marginRight: 4 * PdfPageFormat.mm,
  marginTop: 5 * PdfPageFormat.mm, marginBottom: 5 * PdfPageFormat.mm,
);
```
Page **height** is `double.infinity` — a receipt is one continuous roll,
not a fixed-height page; `pw.Page` grows as long as needed.

**Educational simplified example**, if rebuilding from scratch:
```dart
enum PaperWidth { mm58, mm80 }
extension PaperWidthDots on PaperWidth {
  int get dots => this == PaperWidth.mm58 ? 384 : 576;          // ESC/POS
  double get pdfPointsWide => dots / 8 * 2.8346;                  // dots -> mm -> points
}
```
Deriving both units from the *same* dot count — like the real project does
— is what keeps the two output paths visually consistent. Computing them
independently ("58mm PDF ≈ 2 inches, close enough") is how they silently
drift apart.

## 9. PDF Page Format

`printer_pdf_format.dart` is the single shared mapper from
`PrinterPaperSize` to `PdfPageFormat`, used by every receipt PDF call site
(`print_service.dart`, `receipt_preview_screen.dart`). Nothing about
receipt *language* ever enters this mapping — `paperSize.pdfPageFormat` is
looked up purely from the configured paper size, so a Khmer receipt and an
English receipt at the same `PrinterPaperSize` always get byte-identical
page geometry (locked in by `test/receipt_pdf_page_format_test.dart`,
originally written as regression coverage for a bug where a Khmer receipt
PDF became wide/landscape/A4-like while English stayed correctly narrow).

Reports and invoices never import this file at all — A4 page geometry
(§32) is fixed and must never be influenced by the receipt printer's
configured paper size, and vice versa: nothing in the receipt path ever
reads `PdfPageFormat.a4`.

## 10. English Receipt PDF Path

```
ReceiptViewModel
      |
      v
PrintService.buildReceiptPdf(r, paperSize, {context})
      |
      +-- await KhmerPdfFont.loadTheme()          <- cached after first call
      +-- content = await _pageContent(context, r, paperSize)
      |        +-- r.containsKhmer && context != null -> _khmerImagePageContent()  (§14)
      |        +-- else                                -> _receiptPageContent()    (below)
      +-- doc.addPage(pw.Page(pageFormat: paperSize.pdfPageFormat, build: (_) => content))
      +-- return doc.save()   -> Uint8List
      v
Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'receipt_$saleId')
      v
Chrome / OS print dialog -> printer driver -> printer
```

For a non-Khmer receipt, `_receiptPageContent` builds an ordinary
`package:pdf` widget tree — `pw.Column` of `pw.Text`/`pw.Row`, reading
sizes from `paperSize.receiptTypography` (§7):
```dart
pw.Widget _receiptPageContent(ReceiptViewModel r, PrinterPaperSize paperSize) {
  final t = paperSize.receiptTypography;
  final labels = r.labels;
  return pw.Column(children: [
    _clipped(r.businessName, pw.TextStyle(fontSize: t.businessTitle, fontWeight: pw.FontWeight.bold)),
    ...
    for (final adj in r.adjustments)
      _summaryRow(adj.type.labelFrom(labels), r.fmtAdjustment(adj), t),
    _totalRow(labels.total, r.fmt(r.total), t),
  ]);
}
```
`_clipped` wraps every `pw.Text` with `overflow: pw.TextOverflow.clip` —
`package:pdf` only wraps text on whitespace, and Khmer script is
traditionally written without spaces between words, so an unbroken long
Khmer name would otherwise render past the page's content width.

This path is fast precisely because nothing here is a bitmap: `pw.Text`
draws vector glyph-reference operators into the PDF content stream — a few
hundred bytes total, regardless of receipt length — and `doc.save()` has no
image data to deflate-compress. A real captured number, same receipt
design, same run: **236ms** total `receiptPdfDocSave` for an English
receipt vs. **5251ms** for the Khmer image path on the same device (§17
explains exactly where that gap comes from).

Nothing in this file picks the paper size itself — `PrinterPaperSize
paperSize` is a parameter, read by the caller from `PrinterConfig.paperSize`
(§25). `paperSize.pdfPageFormat` (§9) and `paperSize.receiptTypography`
(§7) both derive from that one enum value.

**Batch**: `buildReceiptsPdf(List<ReceiptViewModel> receipts, paperSize,
{context})` loops and calls `doc.addPage(...)` once per receipt into the
*same* `pw.Document` — §29 covers why.

## 11. Khmer Receipt Problem

This project hit — and fixed — several distinct Khmer problems.
Understanding them as *separate* failure modes matters: they have
different symptoms and different fixes, and conflating them wastes time.

**1. Asset missing / 404.** The font file isn't bundled or isn't declared
in `pubspec.yaml`'s `flutter: fonts:` block. Symptom: build failure or a
runtime asset-load exception.

**2. Font missing at the PDF layer specifically.** `package:pdf` has its
*own*, separate font-registration mechanism (`pw.Font.ttf(...)`,
`pw.ThemeData.withFont(...)`) — registering a font for Flutter widgets via
`pubspec.yaml` does **not** make it available inside a `pw.Document`.
`KhmerPdfFont.loadTheme()` (§13) exists specifically to load the same
`.ttf` files a *second* time through `package:pdf`'s own API.

**3. Glyph coverage ("tofu" boxes, □□□).** The font loads, but has no
glyph for a specific codepoint. `NotoSansKhmer-Regular.ttf` in this project
is verified (direct cmap-table inspection, recorded in `khmer_pdf_font.dart`'s
comments) to be a **Khmer-only subset**: 175 codepoints, *zero* Latin
letters or digits. Using it as a document's *primary* font breaks every
English string in the document.

**4. Font fallback.** The fix for #3: register `NotoSansKhmer` as a
**fallback**, never primary. `package:pdf` resolves `TextStyle.fontFallback`
*per glyph* — for each rune the primary font can't draw, it tries each
fallback font in list order.

**5. Complex script shaping — the hard one.** Fixing #3 and #4 makes
glyphs *appear*. It does **not** make them appear *correctly assembled*.
`package:pdf`'s fallback mechanism picks a font per rune; it does not run a
real text-shaping engine. **"The font contains Khmer glyphs" does not mean
"Khmer will display correctly."** Correct Khmer needs actual *shaping*
(§12), which `package:pdf` doesn't implement. §13 covers the fix.

**6. Thermal printer firmware limitations.** Even with shaping solved in
software, most thermal printer *firmware* doesn't reliably support Khmer at
all — codepage tables vary by brand. This project's answer (§13): never
send Khmer Unicode to the printer at all — always send pixels.

## 12. Khmer Complex Text Shaping

A beginner's map of the terms:

- **Glyph** — the actual drawn shape for a character (or part of one).
- **GSUB** (Glyph *Sub*stitution table, inside a font file) — rules for
  swapping one glyph for another based on context. Khmer's "coeng"
  mechanism: a consonant following a special invisible marker (`្`,
  U+17D2) gets replaced with its *subscript* form and moved underneath the
  preceding consonant.
- **GPOS** (Glyph *Pos*itioning table) — rules for *moving* glyphs relative
  to each other, e.g. positioning a vowel sign above/below its base
  consonant, or stacking diacritics without overlap.
- **Coeng / subscript consonants** — Khmer's way of writing consonant
  clusters: a smaller version of the second consonant is drawn stacked
  below the first, not written side-by-side like Latin.
- **Vowels / diacritics** — Khmer vowel signs can appear before, after,
  above, or below their consonant depending on the specific vowel — visual
  order isn't the same as logical (typed) order.

Getting all of this right is exactly what a real text-shaping engine
(Flutter's own text stack, via Skia) does — and what `package:pdf` does
not attempt.

## 13. "Make It an Image" Strategy

> "Make it an image."

Rather than teach `package:pdf` or ESC/POS firmware to shape Khmer
correctly (hard, brittle, and in ESC/POS's case often impossible), let
**Flutter** shape it — because Flutter's text engine already does this
correctly, for free, via the same rendering stack that draws Khmer
perfectly on-screen everywhere else in the app — then hand the printer a
picture of the result instead of the text itself.
```
String (contains Khmer)
      |
      v
Flutter widget tree / TextPainter    <- real text shaping happens HERE
      |
      v
raster image (pixels)
      |
   +--+--+
   v     v
ESC/POS  PDF
(printer (embedded as
 raster)  pw.Image)
```
Once shaping has happened and the result is a bitmap, **the printer itself
never needs to understand Khmer Unicode at all** — it receives dots to
fire, same as a logo. This is why §21 insists the Khmer-vs-English decision
belongs in the *builder*, never inside a transport: by the time bytes
reach `NetworkPrinterTransport`, the decision is already baked in.

`KhmerPdfFont.loadTheme()` (§9's font-fallback fix) still matters even on
this strategy — it's what keeps the *English/Latin* portions of a mixed
document, and any receipt that ends up on the plain `pw.Text` fallback path
(§14's "without a context" case), rendering correctly.

## 14. Current ReceiptBitmapRenderer

`features/pos/services/printing/receipt_bitmap_renderer.dart` renders a
`ReceiptViewModel` to a raster image, for both the Khmer PDF path
(`print_service.dart`) and the Khmer/mixed ESC/POS path
(`escpos_receipt_builder.dart`, §21).

### The mechanism

Build the receipt as an ordinary Flutter widget tree, mount it off-screen
via a real `OverlayEntry` positioned far outside the viewport, and
rasterize it with `RenderRepaintBoundary.toImage`. Because it's a real,
attached widget subtree, Flutter's own text shaping engine does the hard
part.

### What changed this session — and why it mattered

Until this session, the widget mounted for rasterization was a private
class, `_ReceiptDocument`, with its **own**, independently hand-authored
font sizes, spacing constants, and — critically — its own logical width:
`Container(width: paperSize.dotWidth)`, i.e. **384 or 576 logical pixels**,
at `pixelRatio: 1.0`. That's nearly double the on-screen preview's 300
logical-pixel width, laid out with different font sizes on top, and it was
even missing the "Item / Qty / Total" column-header row the preview has.
The result: a Khmer receipt's raster/PDF output looked structurally
different from — and much wider than — what the cashier had just previewed
on screen. This was a real, reported, screenshotted bug, not a
hypothetical.

**The fix**: `renderImage` now mounts `ReceiptContent` (§7) — the exact
same widget the on-screen preview uses — at the exact same logical width,
and reaches the printer's required *pixel* width via `pixelRatio` instead
of by stretching the widget:

```dart
Future<img.Image> renderImage(
  BuildContext context,
  ReceiptViewModel receipt,
  PrinterPaperSize paperSize,
) async {
  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context, rootOverlay: true);

  const logicalWidth = kReceiptContentWidth;                    // 300 — same as on-screen
  final pixelRatio = paperSize.dotWidth / logicalWidth;          // e.g. 576/300 = 1.92
  double? measuredMaxWidth;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: -100000, top: 0,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.white,
          child: RepaintBoundary(
            key: boundaryKey,
            child: Container(
              width: logicalWidth,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),  // same as on-screen _ReceiptPaper
              child: LayoutBuilder(
                builder: (context, constraints) {
                  measuredMaxWidth = constraints.maxWidth;      // confirms an explicit, bounded width
                  return ReceiptContent(receipt: receipt);       // <- THE SAME WIDGET the preview uses
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  // ... two frame pumps, then:
  final uiImage = await renderObject.toImage(pixelRatio: pixelRatio);
}
```

`_ReceiptDocument` and its private helpers were deleted entirely — not
deprecated, not kept as a fallback. There is exactly one Flutter receipt
widget in this codebase now.

### Real captured diagnostic — logical width vs. output pixel width

The renderer logs a temporary, `kDebugMode`-gated diagnostic,
`[ReceiptLayout]`, on every raster render — added specifically so this fix
could be verified on a real device rather than assumed:
```
[ReceiptLayout] mode=raster paper=mm80 logicalWidth=300 maxWidth=252 pixelRatio=1.920
[PrintPerf] receiptToImage=16ms
[ReceiptLayout] mode=raster paper=mm80 outputPixels=576x999
```
Read literally: `logicalWidth=300` is what `Container` was given.
`maxWidth=252` is what `ReceiptContent` actually receives inside it — 300
minus the `_ReceiptPaper`-matching padding (24px each side: 300 − 48 =
252, exactly). `pixelRatio=1.920` is `576 (mm80's dotWidth) / 300`. The
*rendered* image comes out at `outputPixels=576x999` — 576 confirms the
pixel-ratio math landed exactly on the printer's dot width; 999 is
whatever height that receipt's actual content needed at this width — never
hand-picked, never assumed.

`ReceiptPaperView` logs the matching preview-side line for comparison:
```
[ReceiptLayout] mode=preview logicalWidth=300
```
This on-screen preview is deliberately paper-size-agnostic (same `width`
regardless of the store's configured 58mm/80mm printer) — a real,
documented current scope limit, not a bug: see **Known Current
Limitations** near the end of this document.

### logicalWidth vs. output pixel width, conceptually

These are two different numbers answering two different questions:
- **logicalWidth** — how wide `ReceiptContent` is *laid out*, in Flutter's
  device-independent logical pixels. Controls word-wrap points, how much
  the business-name/item-name text needs to shrink/ellipsize.
  Fixed at `kReceiptContentWidth` regardless of paper size, specifically so
  the two paper sizes share one proportion (§7) — only the *pixel density*
  scales.
- **output pixel width** — the actual raster's width, `logicalWidth *
  pixelRatio`, which must equal `paperSize.dotWidth` for the printer/PDF
  to receive exactly the resolution it expects.

Confusing them — e.g. setting the widget's own width to `dotWidth` — is
precisely the bug this session fixed.

## 15. Khmer PDF Rendering — Current Implementation

`print_service.dart`'s `_khmerImagePageContent`, in full, as it exists
right now:
```dart
Future<pw.Widget> _khmerImagePageContent(
  BuildContext context,
  ReceiptViewModel r,
  PrinterPaperSize paperSize,
) async {
  final decoded = await bitmapRenderer.renderImage(context, r, paperSize);   // §14
  final targetWidth = paperSize.pdfPageFormat.availableWidth;
  final targetHeight = targetWidth * decoded.height / decoded.width;         // preserves aspect ratio
  return pw.Image(
    pw.ImageImage(decoded),           // <- raw img.Image straight into the PDF, no encoding step
    width: targetWidth,
    height: targetHeight,
    fit: pw.BoxFit.fill,
  );
}
```
So: **whole receipt → Flutter bitmap → `pw.ImageImage` → PDF.** This is
still the whole-document rasterization strategy (§13) — nothing has
changed about *that* decision. What changed is *how* the already-decoded
bitmap gets into the PDF — §16.

`fit: pw.BoxFit.fill` here does **not** distort anything: `targetHeight` is
computed *from* the source image's own aspect ratio (`decoded.height /
decoded.width`) one line above, so by the time `fill` runs, the target box
already has the source's exact proportions — `fill` and `contain` would
produce an identical result here. Verified by the PDF-embedding-vs-raster
distinction in §14/§17: if the raster itself is correct, this step cannot
introduce distortion.

The English/native path (§10) never touches any of this — `r.containsKhmer
&& context != null` (`_pageContent`'s branch) is the only gate, checked
once per document, before either code path runs.

## 16. Raw Image Embedding Optimization

### The old, wasteful pipeline

Before this session, `_khmerImagePageContent` did:
```dart
// BEFORE
final pngBytes = img.encodePng(decoded);      // compress raw pixels to PNG
return pw.Image(pw.MemoryImage(pngBytes), ...);  // hand package:pdf the PNG bytes
```
This looks reasonable — `pw.MemoryImage` is the obvious "embed an image"
API. The problem is what `pw.MemoryImage` is actually *for*: accepting an
already-*encoded* file (e.g. a PNG downloaded from a server), which it
decodes back to raw pixels internally, lazily, the first time the document
is actually built:
```dart
// pdf-3.11.3/lib/src/widgets/image_provider.dart — MemoryImage.buildImage
PdfImage buildImage(Context context, {int? width, int? height}) {
  if (width == null) {
    return PdfImage.file(context.document, bytes: bytes);   // <- decodes the PNG HERE
  }
  ...
}
// PdfImage.file -> im.decodeImage(bytes) -> full PNG decode, every save()
```
So the pre-fix pipeline was, per Khmer receipt:
```
raw RGBA (already exactly what package:pdf ultimately needs)
   -> img.encodePng          (compress — wasted work)
   -> pw.MemoryImage(bytes)  (just holds the bytes, decodes nothing yet)
   -> doc.save()
        -> MemoryImage.buildImage() -> PdfImage.file() -> img.decodeImage(bytes)
           (decompress the PNG we JUST made — wasted work, again)
        -> PdfRasterBase.fromImage() -> raw pixels, split into RGB + alpha planes
        -> deflate-compress those planes into the PDF stream (the ONLY step
           that was ever actually necessary)
```
A full compress-then-decompress round trip on bytes that existed for no
reason except to satisfy an API that never actually needed them.

### The fix

`package:pdf` exports `pw.ImageImage` — wraps an `img.Image` **directly**,
no bytes/encoding step at all:
```dart
// pdf-3.11.3/lib/src/widgets/image_provider.dart
class ImageImage extends ImageProvider {
  ImageImage(this._image, {double? dpi, PdfImageOrientation? orientation}) : ...;
  final im.Image _image;
  @override
  PdfImage buildImage(Context context, {int? width, int? height}) {
    if (width == null) return PdfImage.fromImage(context.document, image: _image);
    ...
  }
}
```
`PdfImage.fromImage` goes straight from the already-decoded `img.Image` to
the RGB+alpha planes — no PNG anywhere in the path:
```
raw img.Image (the exact same object ReceiptBitmapRenderer already produced)
   -> pw.ImageImage(decoded)
   -> doc.save()
        -> PdfRasterBase.fromImage() -> raw pixels, split into RGB + alpha planes
        -> deflate-compress those planes into the PDF stream
```
One fewer full pass over the image data, in both directions, for zero
change in output: the two paths are **pixel-identical**, since PNG is
lossless and both ultimately construct the PDF's RGB+alpha stream from the
exact same source pixels. (Confirmed directly, not assumed — a scratch
benchmark building the same receipt both ways produced byte-identical PDF
output at every tested size.)

Both `pw.MemoryImage` and `pw.ImageImage` are public API, unchanged between
the declared constraint (`pdf: ^3.10.4`) and 3.12.0 — verified by diffing
`image_provider.dart` between the two versions in `pub-cache`; only
formatting differs.

### Was this actually necessary, or could raw bytes have been embedded
without `img.Image` at all?

Yes, via `pw.RawImage(bytes:, width:, height:)` (also public API) — but
`ReceiptBitmapRenderer.renderImage` already returns a decoded `img.Image`
(it needs one internally for ESC/POS dithering, §21), so `pw.ImageImage`
is the more direct fit; `pw.RawImage` would need re-deriving raw bytes from
that same `img.Image` for no benefit.

## 17. Print Performance Profiling

`core/utils/print_perf.dart` — lightweight, `kDebugMode`-gated timing:
```dart
Future<T> timePrintStage<T>(String stage, Future<T> Function() action) async {
  if (!kDebugMode) return action();
  final sw = Stopwatch()..start();
  try { return await action(); }
  finally { debugPrint('[PrintPerf] $stage=${sw.elapsedMilliseconds}ms'); }
}
```
Zero-cost in release builds (the stopwatch never starts). Current stages,
in call order for a Khmer PDF receipt:
```
receiptWidgetMount        <- two frame pumps (mount + full repaint) inside the Overlay
receiptToImage             <- RenderRepaintBoundary.toImage(pixelRatio)
receiptToRawBytes          <- ui.Image.toByteData(rawRgba)
receiptBytesToImage        <- img.Image.fromBytes (wraps the raw bytes, no decode)
receiptPdfBitmapRender     <- wraps the whole renderImage() call above
receiptPdfBitmapDimensions <- NOT timed — a plain debugPrint of width/height/rawBytes (§14, new this session)
receiptPdfDocSave          <- doc.save() — builds AND compresses the whole PDF
```
A real captured sequence (mm80, one Khmer receipt, this session, on the
actual deployed target):
```
[PrintPerf] receiptWidgetMount=89ms
[ReceiptLayout] mode=raster paper=mm80 logicalWidth=300 maxWidth=252 pixelRatio=1.920
[PrintPerf] receiptToImage=16ms
[PrintPerf] receiptToRawBytes=6ms
[PrintPerf] receiptBytesToImage=3ms
[ReceiptLayout] mode=raster paper=mm80 outputPixels=576x999
[PrintPerf] receiptPdfBitmapRender=116ms
[PrintPerf] receiptPdfBitmapDimensions=576x999 rawBytes=2301696
[PrintPerf] receiptPdfDocSave=5251ms
```
vs. the same session's English receipt on the same device:
```
[PrintPerf] receiptPdfDocSave=236ms
```
### How to read this

`receiptPdfBitmapRender` (116ms) is cheap — mounting, laying out, and
rasterizing the widget is not the bottleneck. `receiptPdfDocSave` (5251ms)
dwarfs everything else combined — **that's** where to look, and profiling
is what proves it rather than guessing (§48's rule).

### Why profiling before optimizing matters here specifically

An intuitive first guess — "the whole Khmer rendering pipeline must be
slow" — would point at the wrong 89-135ms of work and miss the actual
~5-second cost sitting inside `doc.save()`. The `rawBytes=2301696` line
(576 × 999 × 4 channels) is the concrete number that explains *why*
`doc.save()` is slow: it has to deflate-compress roughly 2.3MB of raw pixel
data into the PDF's RGB+alpha image streams — §18/§19 trace exactly what
inside `doc.save()` costs that much, and why English's `doc.save()` (no
image at all) doesn't.

## 18. Why Khmer Can Still Be Slower Than English

```
English PDF  -> vector/text commands only  -> a few hundred bytes to compress -> doc.save() fast
Khmer raster -> a full-page pixel image    -> ~2.3MB to compress             -> doc.save() slow
```
Raw byte size for a Khmer receipt's bitmap: `width × height × 4 channels
(RGBA)`. For the captured example above: `576 × 999 × 4 = 2,301,696 bytes`
— confirmed against the actual `rawBytes` log line, not estimated.
`PdfImage`'s constructor (§16) splits that into an RGB plane (`width ×
height × 3`) and a separate grayscale alpha/SMask plane (`width × height ×
1`), both of which get deflate-compressed into the PDF's object streams
during `doc.save()`. That compression work is proportional to how much
pixel data there is — a 30-item Khmer receipt (taller image) costs
proportionally more than an 8-item one; removing the PNG round-trip (§16)
removed a *redundant* pass over that data, not the *necessary* one — the
necessary compression still has to happen exactly once, and the rest of
this section explains why that one remaining pass can still be slow.

### The platform-dependent piece: native zlib vs. pure-Dart deflate

`package:pdf`'s `doc.save()` compresses every stream (including the
Khmer image's RGB+alpha planes) via a `deflate` callback whose
implementation is chosen by a **conditional import**, resolved at compile
time per target:
```dart
// pdf-3.11.3/lib/src/pdf/document.dart
import 'io/na.dart'
    if (dart.library.io) 'io/vm.dart'          // native targets
    if (dart.library.js_interop) 'io/js.dart'; // Flutter Web
```
```dart
// io/vm.dart  (Android/iOS/desktop — dart:io is available)
DeflateCallback defaultDeflate = zlib.encode;               // native C zlib — fast

// io/js.dart  (Flutter Web — no dart:io)
DeflateCallback defaultDeflate = const ZLibEncoder().encode; // package:archive — pure Dart
```
On native targets, `doc.save()`'s compression is backed by the platform's
real, C-implemented zlib and is fast regardless of how much image data
there is. **On Flutter Web, there is no `dart:io`, so `package:pdf` falls
back to `package:archive`'s pure-Dart `ZLibEncoder`** — the same class of
unaccelerated, interpreted-loop compression that made the old PNG-encode
step slow (§16's "before" pipeline used this exact encoder, at its default
level 6 with the `PngFilter.paeth` adaptive filter, both expensive).

The `[PrintPerf]` capture in §17 was taken through `Printing.layoutPdf` on
Flutter Web (Chrome's print dialog), so its `receiptPdfDocSave=5251ms` is
compressing ~2.3MB of raw image bytes through that pure-Dart path — not a
regression from §16's fix, but a *pre-existing, separate* platform
limitation that §16 never touched (§16 removed one redundant compression
pass; this is the one remaining, *necessary* pass, which happens to be slow
specifically because of where it's running). English's `doc.save()` stays
fast on the same platform because there's no image stream to run through
that same slow encoder — a few hundred bytes of vector text commands
compress trivially fast even in pure Dart.

This is a genuinely important, previously-undocumented architecture fact:
**this app's Khmer-receipt performance ceiling on Flutter Web is
currently gated by a third-party library's platform-conditional
compression choice, not by anything in this project's own rendering code.**
See **Known Current Limitations** for what this means practically.

## 19. Khmer Performance Strategy

### Implemented

- **Raw-image PDF embedding** (§16) — `pw.ImageImage(decoded)` instead of
  `pw.MemoryImage(img.encodePng(decoded))`. Removes one full
  compress-then-decompress round trip per Khmer receipt, with zero visual
  change (pixel-identical output, verified).
- **Raw RGBA extraction, not PNG, when building the `img.Image`** —
  `ReceiptBitmapRenderer.renderImage` reads `uiImage.toByteData(format:
  ui.ImageByteFormat.rawRgba)` and wraps it with `img.Image.fromBytes(...)`
  directly, rather than requesting a PNG-encoded `ByteData` from the engine
  and decoding it. An uncompressed memory copy on both sides instead of a
  compress+decompress round trip for bytes about to be discarded anyway.
- **Font caching** — `KhmerPdfFont.loadTheme()` loads all four `.ttf` files
  (Latin regular/bold, Khmer regular/bold) once per app session into
  `static pw.Font?` fields; every later call reuses them.
- **`CapabilityProfile` (ESC/POS) internal caching** — `EscPosReceiptBuilder`
  calls `CapabilityProfile.load()` fresh on every `build()` (no app-level
  memoization — confirmed by reading the call site directly), but the
  *library itself* caches the expensive part: `esc_pos_utils_plus`
  2.0.4's `ensureProfileLoaded()` guards the actual JSON-asset parse behind
  a package-level static map —
  ```dart
  // esc_pos_utils_plus-2.0.4/lib/src/capability_profile.dart
  static Future ensureProfileLoaded({String? path}) async {
    if (printCapabilities.isEmpty == true) {
      // ...parse capabilities.json, populate printCapabilities...
    } else {
      print("capabilities.length is already loaded");
    }
  }
  ```
  verified directly from the package source in `pub-cache`, not assumed —
  so a 64-receipt "Print All" batch parses that JSON once, not 64 times,
  even though the app's own code re-invokes `load()` every iteration.
- **Rendering at (approximately) final printer resolution, not larger** —
  `pixelRatio = paperSize.dotWidth / kReceiptContentWidth` (§14) targets
  the printer's actual dot width directly; nothing renders at an
  arbitrarily higher resolution and downsamples afterward.
- **Sequential, not concurrent, rendering** — `ThermalPrinterService
  .printReceipts` and `PrintService.buildReceiptsPdf` (§29/§30) render one
  receipt at a time in a batch, deliberately. `ReceiptBitmapRenderer` shares
  app-wide `Overlay`/frame-pump state across calls; concurrent real-device
  rendering was never validated as safe, so batches don't attempt it.
  `mapBounded` (§28) parallelizes the API *fetch* stage of Print All, never
  the rendering stage.

### Potential future optimization (not implemented — flagged, not done)

- **JPEG instead of PNG/raw for the PDF embed** — would let `PdfImage.jpeg`
  embed the already-compressed DCT bytes as-is (`/Filter /DCTDecode`),
  skipping `doc.save()`'s deflate pass on the image entirely. Not adopted:
  JPEG's lossy block compression risks blurring Khmer diacritics/thin
  strokes, and that trade-off needs a human visual check on a real device
  before shipping, not an automated assumption.
- **Grayscale/alpha-stripped embedding** — investigated and found to have
  **no benefit** through the public `pw.ImageImage`/`pw.RawImage` API:
  `PdfRasterBase.fromImage()` unconditionally converts to 4-channel RGBA
  and `PdfImage`'s constructor always emits a 3-channel RGB plane plus a
  separate alpha/SMask plane, regardless of whether the source was already
  grayscale or opaque — confirmed empirically (identical output PDF size
  for a grayscale vs. RGB source at the same benchmark size). Achieving a
  true `/DeviceGray`, alpha-free embed would require bypassing the
  documented widget API and hand-constructing a `PdfImage`, which wasn't
  pursued given the measured non-benefit.
- **A short-lived render cache keyed by receipt ID + paper size + locale**
  — considered, not implemented. No current call path actually re-renders
  the same receipt twice in one session (each Print action triggers exactly
  one `renderImage` call), so there's no measured problem for a cache to
  solve yet, and the risk (stale financial data if invalidation is ever
  wrong) outweighs a currently-hypothetical win.

## 20. ESC/POS Fundamentals

ESC/POS is a command language most thermal receipt printers understand —
plain bytes sent over whatever transport, where certain byte sequences are
*commands* (align text, cut paper, print a raster image) rather than
characters to print. "ESC" and "GS" name specific leading control bytes
(`0x1B`/`0x1D`) marking the start of a command — similar in spirit to ANSI
terminal escape codes.

This project uses `esc_pos_utils_plus` (resolved **2.0.4**) — its
`Generator` class hides the actual byte construction:
```
generator.text('Hello')            -> print this text, current alignment/style
generator.row([...])               -> a two-column row (label ... value)
generator.hr()                     -> a horizontal rule
generator.feed(2)                  -> advance paper 2 lines
generator.cut()                    -> fire the paper cutter
generator.imageRaster(image, ...)  -> print a raster image (the GS v 0 command)
```
`CapabilityProfile`, `PosStyles`, `PosColumn`, `PosAlign`, `PosTextSize` all
come from the same package, imported via its one barrel file
`esc_pos_utils_plus.dart`.

## 21. EscPosReceiptBuilder

`features/pos/services/printing/escpos_receipt_builder.dart`, in full
shape:
```dart
class EscPosReceiptBuilder {
  const EscPosReceiptBuilder({this.bitmapRenderer = const ReceiptBitmapRenderer()});
  final ReceiptBitmapRenderer bitmapRenderer;

  Future<List<int>> build(BuildContext context, ReceiptViewModel receipt, PrinterPaperSize paperSize) async {
    final profile = await timePrintStage('escposCapabilityLoad', () => CapabilityProfile.load());
    final generator = Generator(paperSize.escPosPaperSize, profile);
    var bytes = <int>[]..addAll(generator.reset());

    if (receipt.containsKhmer) {
      final image = await timePrintStage('escposBitmapRender',
          () => bitmapRenderer.render(context, receipt, paperSize));         // §14, dithered — see below
      bytes += timePrintStageSync('escposImageRasterEncode',
          () => generator.imageRaster(image, align: PosAlign.center));
    } else {
      bytes += timePrintStageSync('escposLatinText', () => _buildLatinText(generator, receipt));
    }

    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }
}
```
That's the entire dispatch: **English → `_buildLatinText` (native ESC/POS
text commands). Khmer or mixed → whole-receipt bitmap → `imageRaster`.**
`_buildLatinText` iterates `receipt.adjustments` the same way the PDF path
does (§5/§7) — `row(adj.type.labelFrom(labels), receipt.fmtAdjustment(adj))`.

### `render` vs. `renderImage` — the dithering step

`ReceiptBitmapRenderer.render(context, receipt, paperSize)` (used here,
not `renderImage` directly) calls `renderImage` (§14) and then applies
Floyd–Steinberg dithering:
```dart
Future<img.Image> render(BuildContext context, ReceiptViewModel receipt, PrinterPaperSize paperSize) async {
  final decoded = await renderImage(context, receipt, paperSize);
  return img.ditherImage(decoded, kernel: img.DitherKernel.floydSteinberg);
}
```
Direct thermal (ESC/POS) printing is strictly black/white — no
antialiasing, no grayscale — so the full-quality raster `renderImage`
produces gets dithered down to 1-bit here. The Khmer **PDF** path
(`print_service.dart`, §15) calls `renderImage` directly, skipping
dithering entirely: a PDF viewer/driver renders grayscale/antialiased
images natively, and dithering would only make the printed page look
noisier on screen for no benefit.

### Why the Khmer decision belongs in the builder, not the transport

`NetworkPrinterTransport.write(bytes)` — and `UsbPrinterTransport`/
`BluetoothPrinterTransport`'s equivalents (§23-25) — take a plain
`List<int>` and send it. They have **no branch for Khmer anywhere**, and
that's correct: by the time `EscPosReceiptBuilder.build()` returns, the
Khmer-vs-English decision has already been made and baked into the bytes
themselves. A transport re-detecting Khmer would be redundant and would
violate the layering from §2/§22.

## 22. Printer Transport Abstraction

Three completely different physical connections — a TCP socket, a USB
device handle, a paired Bluetooth connection — need to be swappable behind
one call site (`ThermalPrinterService`, §27) without that call site caring
which is active. `features/pos/services/printing/printer_transport.dart`,
the entire file:
```dart
abstract class PrinterTransport {
  Future<void> connect();
  Future<void> write(List<int> bytes);
  Future<void> disconnect();
  bool get isConnected;
}
```
Four members, nothing else. No paper size, no language, no document
knowledge. **A `PrinterTransport`'s only job is moving bytes.**

| Class | File | Underlying mechanism |
|---|---|---|
| `NetworkPrinterTransport` | `network_printer_transport.dart` | `dart:io Socket` (TCP) |
| `UsbPrinterTransport` | `usb_printer_transport.dart` | `flutter_pos_printer_platform_image_3` (**1.2.4**) |
| `BluetoothPrinterTransport` | `bluetooth_printer_transport.dart` | `print_bluetooth_thermal` (**1.2.1**) |

`ThermalPrinterService._transportFor(config)` (§26) is the *only* place in
the app that branches on transport type — every print call site downstream
of it just calls `connect()`/`write()`/`disconnect()` on whichever instance
it got.

## 23. Network Printing

`network_printer_transport.dart`, the entire file:
```dart
class NetworkPrinterTransport implements PrinterTransport {
  NetworkPrinterTransport(this.host, {this.port = 9100});
  final String host;
  final int port;
  Socket? _socket;

  @override
  bool get isConnected => _socket != null;

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
  }

  @override
  Future<void> write(List<int> bytes) async {
    final socket = _socket;
    if (socket == null) throw StateError('Network printer is not connected');
    socket.add(bytes);
    await socket.flush();
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}
```
**Port 9100** is the near-universal "raw print" port most network thermal
printers listen on — no driver negotiation, just a TCP socket that accepts
raw bytes. **One `write` call, one `add`** — the whole byte array goes in a
single call, then flushed, not many tiny writes.

| Symptom | Likely cause |
|---|---|
| `Socket.connect` times out (5s) | Wrong IP, printer off, or different subnet/VLAN |
| Connects, then `write` throws | Firewall blocked between connect and write, or printer dropped |
| Nothing happens, no error | Correct IP but wrong port |
| Works from one network, not another | Port 9100 traffic isn't routed between the two subnets |

Restating §21's point concretely: by the time `write(bytes)` is called,
`bytes` is already either native text or a raster-image command — the
socket doesn't know or care which. Print One and Print All both route
through this same transport for a `network`-configured printer; Print All
just connects once for the whole batch (§27/§30).

## 24. USB Printing

`usb_printer_transport.dart`, the entire file:
```dart
class UsbPrinterTransport implements PrinterTransport {
  UsbPrinterTransport({this.vendorId, this.productId, this.name});
  final String? vendorId, productId, name;
  bool _connected = false;

  @override
  Future<void> connect() async {
    _connected = await PrinterManager.instance.connect(
      type: PrinterType.usb,
      model: UsbPrinterInput(name: name, vendorId: vendorId, productId: productId),
    );
    if (!_connected) throw StateError('Could not connect to USB printer');
  }

  @override
  Future<void> write(List<int> bytes) async {
    final ok = await PrinterManager.instance.send(type: PrinterType.usb, bytes: bytes);
    if (!ok) throw StateError('Failed to write to USB printer');
  }

  @override
  Future<void> disconnect() async {
    await PrinterManager.instance.disconnect(type: PrinterType.usb);
    _connected = false;
  }

  static Stream<PrinterDevice> discover() => PrinterManager.instance.discovery(type: PrinterType.usb);
}
```
Vendor ID / Product ID identify a specific USB device model — stored as
`PrinterConfig.usbVendorId`/`usbProductId` (§26), entered as plain numeric
fields in Settings (§25) rather than picked from a live scan in the current
UI. All actual USB communication is delegated to
`flutter_pos_printer_platform_image_3`'s `PrinterManager`; this class is a
thin adapter mapping `PrinterTransport`'s three methods onto that package's
API. The package's own doc comment states this is an **Android/Windows**
capability — Flutter Web cannot open arbitrary USB device handles the way
a native app can (WebUSB is a different, permission-gated API this package
doesn't target), so USB is a native-platform-only transport here.

## 25. Bluetooth Printing

`bluetooth_printer_transport.dart`, the entire file:
```dart
class BluetoothPrinterTransport implements PrinterTransport {
  BluetoothPrinterTransport(this.macAddress);
  final String macAddress;
  bool _connected = false;

  @override
  Future<void> connect() async {
    _connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    if (!_connected) throw StateError('Could not connect to Bluetooth printer $macAddress');
  }

  @override
  Future<void> write(List<int> bytes) async {
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) throw StateError('Failed to write to Bluetooth printer');
  }

  @override
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
    _connected = false;
  }

  static Future<List<BluetoothInfo>> pairedDevices() => PrintBluetoothThermal.pairedBluetooths;
}
```
Device discovery only lists **already-paired** devices — pairing itself
happens at the OS level (Settings → Bluetooth), outside the app; this
app's Settings screen (§25) just picks from what's already paired.
Classic Bluetooth (not BLE) — `print_bluetooth_thermal` targets the
serial-profile connection most thermal printers implement. No explicit
runtime-permission-request code exists in this file — permission handling
for a future mobile build is a gap to design in, not something already
solved here (§39 covers what changes on Android/iOS).

## 26. PrinterConfig

`printer_profile.dart`, the relevant shape (verified unchanged this
session):
```dart
enum PrinterTransportType { pdfDriver, bluetooth, usb, network }

class PrinterConfig {
  const PrinterConfig({
    required this.transportType,
    required this.paperSize,
    this.bluetoothAddress,
    this.usbVendorId,
    this.usbProductId,
    this.networkHost,
    this.networkPort = 9100,
  });
  final PrinterTransportType transportType;
  final PrinterPaperSize paperSize;
  final String? bluetoothAddress;
  final int? usbVendorId, usbProductId;
  final String? networkHost;
  final int networkPort;

  factory PrinterConfig.fromJson(Map<String, dynamic> json) => ...;
  Map<String, dynamic> toJson() => ...;
  PrinterConfig copyWith({...}) => ...;

  static const defaultConfig = PrinterConfig(
    transportType: PrinterTransportType.pdfDriver,
    paperSize: PrinterPaperSize.mm80,
  );
}
```
```
config.transportType
      |
      +-- pdfDriver  -> PrintService.buildReceiptPdf -> Printing.layoutPdf
      +-- network    -> ThermalPrinterService -> NetworkPrinterTransport(config.networkHost, port: config.networkPort)
      +-- usb        -> ThermalPrinterService -> UsbPrinterTransport(vendorId: ..., productId: ...)
      +-- bluetooth  -> ThermalPrinterService -> BluetoothPrinterTransport(config.bluetoothAddress!)
```

### Persistence

`ThermalPrinterService.loadConfig()`/`saveConfig()` — **`SharedPreferences`**
(not Hive, not any file-based store), under one string key,
`thermal_printer_config` (the `_printerConfigPrefKey` constant), holding
the whole `PrinterConfig` as a single JSON blob. A malformed/missing stored
value falls back to `PrinterConfig.defaultConfig` rather than throwing.

This is a distinct store from the backend-persisted business `printers`
settings (printer display name, invoice footer text — fetched via
`settingsServiceProvider.getPrinters()`/`updatePrinters()`,
`GET`/`PUT /api/settings/printers`) — the device-local *connection* config
and the server-side *label* metadata are two different concerns, saved two
different ways.

### Settings UI

There's no separate dedicated printer-settings screen — the connection
config lives in a section, `_thermalPrinterSection`, inside
`features/pos/screens/settings_modules_screen.dart`. It exposes: a
transport-type dropdown (all 4 values), a paper-size dropdown (mm58/mm80),
and — shown conditionally based on the selected transport — a Bluetooth
device dropdown (`BluetoothPrinterTransport.pairedDevices()`, paired
devices only, no active scan), plain numeric Vendor ID/Product ID text
fields for USB (no live device picker in the current UI), or IP
address/port text fields for network. A "Test print" button runs the real
production print pipeline against a sample `ReceiptViewModel`; a
debug-only "Print test suite" button opens `print_test_screen.dart` (§36).

### Why transport selection must not be hardcoded inside screens

If `ReceiptsScreen`'s Print One button directly constructed a
`NetworkPrinterTransport`, changing the user's printer to Bluetooth in
Settings would do nothing there — every print call site would need its own
branch, and it would be trivial for one to be forgotten (exactly the kind
of drift §7 describes for receipt layouts). Centralizing the switch in
`ThermalPrinterService._transportFor` (§27) is what makes "change the
printer in Settings, every print call site immediately respects it" true.

## 27. ThermalPrinterService

`features/pos/services/printing/thermal_printer_service.dart`, traced:
```dart
class ThermalPrinterService {
  ThermalPrinterService({this.builder = const EscPosReceiptBuilder()});
  final EscPosReceiptBuilder builder;

  Future<PrinterConfig> loadConfig() async { ... }     // SharedPreferences, §26
  Future<void> saveConfig(PrinterConfig config) async { ... }

  PrinterTransport _transportFor(PrinterConfig config) {
    switch (config.transportType) {
      case PrinterTransportType.bluetooth: return BluetoothPrinterTransport(config.bluetoothAddress!);
      case PrinterTransportType.usb: return UsbPrinterTransport(vendorId: ..., productId: ...);
      case PrinterTransportType.network: return NetworkPrinterTransport(config.networkHost!, port: config.networkPort);
      case PrinterTransportType.pdfDriver: throw StateError('pdfDriver is handled by PrintService');
    }
  }

  Future<void> printReceipt(BuildContext context, ReceiptViewModel receipt, PrinterConfig config) async {
    final transport = _transportFor(config);
    await transport.connect();
    try {
      final bytes = await builder.build(context, receipt, config.paperSize);
      await transport.write(bytes);
    } finally {
      await transport.disconnect();
    }
  }

  Future<void> printReceipts(BuildContext context, List<ReceiptViewModel> receipts, PrinterConfig config,
      {void Function(int done, int total)? onProgress}) async {
    final transport = _transportFor(config);
    await transport.connect();                              // ONCE
    try {
      for (var i = 0; i < receipts.length; i++) {
        if (!context.mounted) return;
        final bytes = await builder.build(context, receipts[i], config.paperSize);
        await transport.write(bytes);                        // each receipt still gets its own feed+cut
        onProgress?.call(i + 1, receipts.length);
      }
    } finally {
      await transport.disconnect();                          // ONCE
    }
  }
}

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) => ThermalPrinterService());
final printerConfigProvider = FutureProvider<PrinterConfig>((ref) =>
    ref.read(thermalPrinterServiceProvider).loadConfig());
```
**Order of operations**: load config → choose transport → connect → build
receipt bytes → write → disconnect (in a `finally`, so a build/write
failure still disconnects cleanly). §30 covers why `printReceipts` connects
once instead of once per receipt.

`printServiceProvider` (`print_service.dart`) is the PDF-side equivalent
provider — `Provider<PrintService>((ref) => PrintService(ref.read(apiServiceProvider), ref))`,
depending on `apiServiceProvider` for the receipt-fetch call and keeping
the `Ref` for reading `appLanguageProvider`/`thermalPrinterServiceProvider`.

## 28. Print One

Traced through `ReceiptsScreen`'s Print One button:
```
row tap
  -> sale.id
  -> SaleService.getReceipt(id)      GET /api/pos/sales/{id}/receipt   <- full record
  -> PrintService.printReceipt(context, id)
        -> ReceiptResponse.fromJson(...)
        -> ReceiptViewModel.fromReceiptResponse(...)
        -> pdfDriver? buildReceiptPdf + Printing.layoutPdf
           else?      ThermalPrinterService.printReceipt(...)
```
### Why the list row's summary data isn't enough

The on-screen sale list is built from a lightweight summary — enough for a
row (date, total, status) but missing line items, per-line modifiers, and
payment method detail. `summary list item != full receipt document`:
printing directly from the row's data would produce an incomplete receipt,
so Print One always re-fetches the full `ReceiptResponse` first — the same
"use finalized, authoritative data" principle from §4, applied to the
reprint path.

## 29. Print All

Traced through `ReceiptsScreen._printAllReceipts`:
```dart
final ids = {for (final s in filteredSales) s.id}.toList();   // de-duped, from the CURRENT filtered list — test/receipts_print_all_selection_test.dart pins this exact source

final results = await mapBounded<int, ReceiptViewModel>(
  ids,
  (id) async {
    final raw = await saleService.getReceipt(id);              // full receipt, same as Print One
    return ReceiptViewModel.fromReceiptResponse(ReceiptResponse.fromJson(raw), language, l10n);
  },
  isCancelled: () => cancelled,
  onProgress: (done, total) => progress.value = _PrintAllProgress(done, total),
);
final viewModels = results.where((r) => r.isOk).map((r) => r.value!).toList();
// -> ONE PDF batch (§30), or ONE thermal batch (§31)
```
### Selection source and deduplication

`test/receipts_print_all_selection_test.dart` verifies Print All operates
on `filteredSales` — the same list backing the on-screen "Receipts: N"
count, respecting the active status filter and search query — not the
unfiltered full dataset, and that Print One always requests the exact
tapped sale's id (not a stale previous one).

### Bounded concurrency — fetch throttling, not render concurrency

Firing all N `getReceipt` calls at once would open N simultaneous HTTP
connections, spike backend load all at once, and make one slow/failing
request harder to isolate. `mapBounded` (`core/utils/bounded_concurrency.dart`,
default `concurrency: 5`) caps how many are ever in flight *at once*:
```
64 receipts, max concurrency 5:
  worker 1: [id 1] -> [id 6] -> [id 11] -> ...
  worker 2: [id 2] -> [id 7] -> [id 12] -> ...
  worker 3: [id 3] -> [id 8] -> [id 13] -> ...
  worker 4: [id 4] -> [id 9] -> [id 14] -> ...
  worker 5: [id 5] -> [id 10] -> [id 15] -> ...
  Never more than 5 requests in flight. All 64 still complete;
  a failure on id 37 doesn't stop ids 1-36 or 38-64.
```
A pool of `concurrency` workers pulls from a shared cursor, each writing
its result into a pre-sized array at *its own* index (results stay in
original order despite unpredictable completion order). Per-item
exceptions are caught into `BoundedResult.failed(item, error)`.
`test/bounded_concurrency_test.dart` verifies the concurrency cap with an
actual overlap counter, exact-once processing, order preservation, and
`isCancelled` honoring.

**This throttles the API *fetch* stage only.** It never parallelizes
rendering — see §19's "sequential, not concurrent" note.

**Educational simplified example:**
```dart
Future<List<R>> mapBoundedSimple<T, R>(List<T> items, Future<R> Function(T) fn, {int concurrency = 5}) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final i = next++;
      results[i] = await fn(items[i]);
    }
  }
  await Future.wait(List.generate(concurrency, (_) => worker()));
  return results.cast<R>();
}
```

## 30. PDF Print All

`PrintService.buildReceiptsPdf(receipts, paperSize, {context})`:
```dart
final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());
for (final r in receipts) {
  final content = await _pageContent(context, r, paperSize);   // §10/§15
  doc.addPage(pw.Page(pageFormat: paperSize.pdfPageFormat, build: (_) => content));
}
return doc.save();
```
```
GOOD (current project):
  64 receipts -> ONE pw.Document, 64 pages -> ONE Printing.layoutPdf -> ONE OS print dialog
BAD (deliberately avoided):
  64 receipts -> 64 separate pw.Document/save/layoutPdf calls -> 64 OS print dialogs
```
64 print dialogs would mean 64 manual confirmations (or 64 silent
auto-triggered jobs most OS print UIs actively resist). One document with
64 pages is one job, one confirmation.

### The physical cutter limitation

`buildReceiptsPdf`'s own doc comment calls this out directly: **nothing in
the `pw`/OS-driver pipeline can command a physical receipt printer's cutter
between logical receipts.** A `pw.Page` boundary only separates *pages* in
the PDF sense — it's not a "cut here" instruction any driver-attached
printer acts on. For an actual paper cut between each receipt in a batch,
use the direct ESC/POS transport instead (§31), where
`ThermalPrinterService.printReceipts` issues a real `generator.cut()`
after every receipt.

## 31. Thermal Print All

Already shown in full in §27 (`ThermalPrinterService.printReceipts`):
```
connect                    <- ONCE
  receipt 1 bytes -> write -> [feed, cut already baked into the bytes]
  receipt 2 bytes -> write -> [feed, cut]
  ...
disconnect                 <- ONCE
```
Bluetooth connection setup (pairing handshake, service discovery) can take
a meaningful fraction of a second *per connection* — reconnecting for
every receipt in a 64-receipt batch would pay that cost 64 times instead
of once. The physical *output* is identical either way — each receipt
still gets its own `feed`+`cut` baked into its own byte array by
`EscPosReceiptBuilder.build` (§21); only the *connection* overhead is
batched, not the per-receipt formatting. A batch can freely mix
English-only and Khmer/mixed receipts — each one's `build()` call makes
its own dispatch decision independently (§21), so a 64-receipt batch with
3 Khmer receipts rasterizes exactly those 3, not all 64.

## 32. Invoice Architecture

### Confirmed: no frontend invoice PDF path exists

A thorough search of `lib/` for `Invoice` (excluding the `invoiceNumber`
*field*, which just labels a receipt's sale number — a metadata row inside
the receipt, §5) turns up **zero** invoice-specific PDF-building code. No
`invoice_pdf_builder.dart`, no invoice screen. "Invoice" in this codebase
is entirely `receipt.invoiceNumber`/`ReceiptLabels.invoiceNumber` — a field
on the single receipt document. Invoices, as an actual separate document
type, are generated **exclusively on the backend**.

### The actual backend flow

```
Invoice model (persisted Sale + line items, Java)
      |
      v
SaleService.invoicePdf(saleId, thermal)      <- picks HTML template
      +-- thermal ? generateThermalReceiptHtml(sale)
      +-- else     ? generateStandardInvoiceHtml(sale)     <- the "A4 invoice" template
      v
PdfService.renderHtmlToPdf(html)             <- OpenHTMLtoPDF, §33
      v
byte[] (PDF)
  +---+---+
  v       v
GET /{id}/invoice.pdf     POST /{id}/email  -> EmailService.sendReceipt(...)
```
`SaleController.java` exposes `GET /{id}/invoice.pdf?thermal=false` for
direct download, and `POST /{id}/email` (builds the same PDF, emails it).
Estimates are a parallel, separate flow — `SaleService.estimatePdf(id)` →
its own HTML template → the same shared `PdfService.renderHtmlToPdf`.

### Confirmed: the Flutter app never calls these endpoints

`ApiService.getBytes()` — a generic byte-download helper — exists but has
**zero callers** anywhere in the Flutter codebase. No file in `lib/` calls
`/invoice.pdf`, `/estimate.pdf`, or any backend PDF route. Flutter's
receipt fetch (`SaleService.getReceipt`) requests and parses plain JSON,
nothing else.

### Why invoice should not reuse receipt layout

A receipt is optimized for a narrow thermal roll and register-side speed.
An invoice is a formal billing document — full A4, letterhead-style header,
often emailed rather than handed over in person. Reusing the receipt's
narrow 58/80mm layout for an invoice would either look cramped on A4 or
require enough conditional branches that it stops being "the receipt
layout" at all. This project keeps them fully separate: receipt = Flutter
`package:pdf`, invoice = backend HTML→PDF — different languages, different
renderers, different runtimes, by design.

## 33. Backend Invoice/PDF Architecture

`backend-spring-boot/src/main/java/com/kaknnea/pos/service/PdfService.java`
— the whole approach in one method:
```java
@Service
public class PdfService {
    public byte[] renderHtmlToPdf(String html) {
        PdfRendererBuilder builder = new PdfRendererBuilder();
        registerOptionalFont(builder);            // Khmer fonts, below
        builder.withHtmlContent(html, null);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        builder.toStream(out);
        builder.run();
        return out.toByteArray();
    }
}
```
- **OpenHTMLtoPDF** (`openhtmltopdf-pdfbox`, `pom.xml`) — every document
  (invoice, estimate, daily Z-report) is first built as a Java `String` of
  inline-styled HTML by its own `generate*Html(...)` method elsewhere in
  `SaleService`/`ReportService`, then rendered to PDF bytes by this one
  shared method. **PDFBox** is the underlying low-level PDF library
  OpenHTMLtoPDF is built on.
- **Fonts**: `backend-spring-boot/src/main/resources/fonts/NotoSansKhmer-*.ttf`
  — nine weights (Thin through Black), unlike the Flutter bundle's two
  (Regular/Bold — see §38's asymmetry note). Because OpenHTMLtoPDF's
  `useFont` API needs an actual `File`, not a classpath resource stream,
  the loader copies each font resource to a temp file first
  (`File.createTempFile`, `deleteOnExit`).
- **`PDF_KHMER_FONT_PATH`** — an environment variable overriding the font
  source with a directory or file at deploy time, without rebuilding the
  JAR — an operational escape hatch.

### Why this is separate from Flutter `package:pdf`, and confirmed not coupled to it

Two completely different rendering models: OpenHTMLtoPDF takes HTML/CSS
and lays it out like a browser would; `package:pdf` is an imperative
widget-tree API. They share no code, no runtime (JVM vs. Dart), and —
confirmed in §32 — the Flutter app never calls into this system at all.
Flutter's own Khmer font pipeline (`KhmerPdfFont`, §13, loaded from
Flutter assets via `rootBundle`) and the backend's (`PdfService`, loaded
from `resources/fonts` or `PDF_KHMER_FONT_PATH`) are two **independent**
Khmer font stacks that happen to solve the same class of problem for two
unrelated document-generation systems.

## 34. Report Architecture

### Every report screen, and what it prints (file:line call sites, verified)

| Nav section | Screen file | Calls `A4ReportPdf.build`? |
|---|---|---|
| Sales Reports | `sales_summary_report_screen.dart` | ✅ |
| Sales Reports | `sales_by_item_screen.dart` | ✅ |
| Sales Reports | `category_performance_screen.dart` | ✅ |
| Sales Reports | `cashier_performance_screen.dart` | ✅ |
| Sales Reports | `payment_mix_screen.dart` | ✅ |
| Sales Reports | `sales_report_screen.dart` ("Receipts") | ✅ |
| Sales Reports | `sales_by_modifier_screen.dart` | ✅ |
| Sales Reports | `discounts_screen.dart` | ✅ |
| Other Reports | `DailyReportScreen` (inline in `reports_hub_screen.dart`) | ❌ |
| Other Reports | `top_products_screen.dart` | ❌ |
| Performance | `monthly_sales_screen.dart` | ❌ |
| Inventory | `stock_movement_screen.dart` | ✅ |
| Inventory (own hub, not Reports nav) | `inventory_valuation_screen.dart` | ✅ |

Every ✅ row follows the identical pattern: `A4ReportPdf.build(...)` →
`Printing.layoutPdf(...)`, triggered by a print icon in the app bar. The ❌
rows are view-only screens today — no PDF/print code exists in them at
all, not a bug, just current scope. No report screen has independent,
hand-rolled PDF-building code outside the shared builder — verified by
searching every file under `features/reports/` and `features/inventory/`
for `pw.Document`/`pdf/widgets` imports; only the 10 ✅ files above have
them, and all 10 call the one shared builder.

### One shared visual system, per-report content

```
Shared (A4ReportPdf, every report):
  - business header (name/address/phone)
  - report title + subtitle (date range)
  - table style (header row color, borders, alternating row shading)
  - footer (generated-at timestamp, page N / M)
  - Khmer rasterization mechanism (§37)

Different per report:
  - title text, column headers, row data (different shape entirely per report)
  - summary block (or none)
  - orientation (portrait, except developer-test-only landscape toggles — §35)
```
The same "shared specification, per-renderer content" idea from §7,
applied to a completely different document type.

## 35. Dynamic Report Columns

Unlike receipts, reports have **no** dedicated view-model class — no
`ReportColumn`/`ReportRow` type exists in this codebase. `A4ReportPdf.build`
takes plain, already-formatted data directly:
```dart
static Future<Uint8List> build({
  required String title,
  String? subtitle, String? businessName, String? businessAddress, String? businessPhone,
  required List<String> columns,
  required List<List<String>> rows,
  Map<int, pw.Alignment> columnAlignments = const {},
  List<MapEntry<String, String>> summary = const [],
  required DateTime generatedAt, required String generatedLabel, required String pageLabel,
  bool landscape = false,
})
```
Every report screen already has its own strongly-typed row model
(`CashierPerformance`, `SalesByItemRow`, `InventoryValuationItem`, ...) —
a second, generic `ReportRow` abstraction on top would mean converting to
and from it for no behavioral benefit, since nothing downstream needs the
generic shape reusable beyond "a list of strings for one table row." Two
real, verified call sites showing the same builder handling entirely
different schemas:
```dart
// cashier_performance_screen.dart:123 — 3 columns, right-aligned {1,2}
A4ReportPdf.build(columns: ['Cashier', 'Transactions', 'Total'],
    rows: rows, columnAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight}, ...);

// sales_by_item_screen.dart:148 — 6 columns, right-aligned {2,3,4,5}
A4ReportPdf.build(columns: ['Item', 'SKU', 'Qty', 'Gross', 'Discount', 'Net'],
    rows: rows, columnAlignments: {2: r, 3: r, 4: r, 5: r}, ...);
```
Both hit the exact same `pw.TableHelper.fromTextArray` table-drawing code.

**Educational simplified example**, if a new project wanted the stronger
typed version:
```dart
class ReportColumn {
  const ReportColumn(this.label, {this.alignment = pw.Alignment.centerLeft});
  final String label;
  final pw.Alignment alignment;
}
class ReportDocument {
  const ReportDocument({required this.title, required this.columns, required this.rows});
  final String title;
  final List<ReportColumn> columns;
  final List<List<String>> rows;
}
Future<Uint8List> buildReport(ReportDocument doc) async { ... }  // same renderer, typed input
```
Reasonable if you find yourself repeating the same `columnAlignments` map
across many screens — but **not** what the current project does; adding it
would be a real design change, not documentation.

## 36. A4 Portrait / Landscape

`landscape: bool = false` swaps `PdfPageFormat.a4` for
`PdfPageFormat.a4.landscape`. Verified: **none** of the 10 real
report/inventory call sites pass `landscape: true` — every production
report currently prints portrait. The only place `landscape:` is passed
explicitly is the developer diagnostic screen `print_test_screen.dart`
(a manual toggle for testing orientation, not a production report).

Report paper geometry never touches `printer_pdf_format.dart` (§9) at all
— `A4ReportPdf` hardcodes `PdfPageFormat.a4`/`.landscape`, completely
independent of whatever thermal `PrinterPaperSize` is configured in
Settings. Receipt paper configuration must never leak into reports, and
it structurally can't: the two files don't import each other.

## 37. Multi-page Reports

`A4ReportPdf.build` uses `pw.MultiPage`, not `pw.Page` — `pw.MultiPage`
automatically flows content across as many physical pages as needed and
re-invokes its `header`/`footer` callbacks on *every* page:
```dart
pw.MultiPage(
  pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
  margin: const pw.EdgeInsets.all(32),
  header: (context) => pw.Column(children: [...]),   // repeats every page
  footer: (context) => pw.Row(children: [
    generatedWidget,
    pw.Text(' ${context.pageNumber} / ${context.pagesCount}'),   // per-page, native pw.Text — always numeric
  ]),
  build: (context) => [
    pw.TableHelper.fromTextArray(headers: headerCells, data: rowCells, ...),   // headers repeat automatically
    if (summaryWidgets.isNotEmpty) ...[ /* summary block, once, after the table */ ],
  ],
)
```
`pw.TableHelper.fromTextArray` marks its header row `repeat: true`
internally — a 200-row report spanning 4 pages shows column headers at the
top of every page.

### Why report printing must fetch ALL matching records, not just visible rows

The on-screen report table is paginated for UI performance. Printing must
include **every** row matching the active filters, not just what's loaded
for the current on-screen page. `report_service.dart`'s `fetchAllPages`:
```dart
Future<List<T>> fetchAllPages<T>({required Future<(List<T>, PageMeta)> Function(int) fetchPage}) async {
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
walks every backend page under the *same active filters* the screen used,
at `reportPrintPageSize = 200` (matching the backend's own hard cap), until
the server reports no pages remain. `test/report_print_pagination_test.dart`
verifies no dropped/duplicated rows across page-size scenarios, correct
call counts, and that `A4ReportPdf.build` genuinely produces multiple
physical pages once row count exceeds one page's capacity (counting
`/Type /Page` objects in the raw PDF bytes).

This is applied, but via two different mechanisms depending on whether the
screen was ever paginated to begin with: most report screens (sales
by-item, cashier performance, etc.) genuinely re-walk backend pages via
`fetchAllPages` before printing; `stock_movement_screen.dart` loads its
full date-range result set in one non-paginated call to begin with, so
there's nothing to re-fetch; `inventory_valuation_screen.dart` loads the
full valuation list once into provider state and both the on-screen table
(client-paginated at 10/page) and the PDF derive from that same full list.
In every case, the PDF is verified to reflect the full filtered dataset,
never just the on-screen page.

## 38. Khmer Reports

`A4ReportPdf` loads the same font theme receipts use —
`KhmerPdfFont.loadTheme()` — but layers a **separate, per-string** Khmer
strategy on top, via `core/services/printing/khmer_text_rasterizer.dart`'s
`KhmerTextRasterizer.textOrImage(text, {fontSize, bold, color})`:
```dart
if (containsKhmerText(text)) {
  // Khmer/mixed -> Flutter TextPainter shaping -> pw.Image, per cell
} else {
  // English/number -> pw.Text, per cell
}
```
Applied at **every** text-producing spot in `A4ReportPdf.build` — title,
business header, table column headers, table row cells, summary
label/value pairs, and the footer's static labels — all pre-rasterized up
front (before `pw.MultiPage` is built, since its callbacks are synchronous).

### Why hybrid, not "rasterize the whole report" (the receipt strategy)

A report is a **table** — vector-drawn borders, header background color,
alternating row shading — all real PDF drawing operations
`pw.TableHelper.fromTextArray` produces automatically from column widths
and row heights it computes *from the cell content*. If the whole page
were one image (§13's receipt strategy), you'd lose all of that structure:
no real table borders, no page-break-aware row splitting for 100+ rows,
one giant image per page instead of small per-cell ones. The hybrid keeps
everything structural as real PDF vector drawing, swapping in a bitmap
only for the handful of *cells* that actually contain Khmer:
```dart
final headerCells = await Future.wait(columns.map((c) =>
    KhmerTextRasterizer.textOrImage(c, fontSize: 9.5, bold: true, color: PdfColors.white)));
final rowCells = await Future.wait(rows.map((row) =>
    Future.wait(row.map((c) => KhmerTextRasterizer.textOrImage(c, fontSize: 9)))));
pw.TableHelper.fromTextArray(headers: headerCells, data: rowCells, ...);   // same table code either way
```
`fromTextArray` accepts either plain strings or pre-built `pw.Widget`s as
cells — non-Khmer cells become ordinary `pw.Text` (identical to what it
would have built internally anyway); only Khmer cells become `pw.Image`.
Column widths, borders, padding, alternating-row color — all computed from
the *cells*, whichever type each turns out to be, unchanged either way.

`KhmerTextRasterizer` caches by `text + fontSize + bold + color` — repeated
static content (column headers, footer labels) across a report's many
calls, or across print runs, reuses the same rendered bytes. **The cache
key must be a pure function of everything the output depends on, and
nothing less** — never cache anything transaction-specific (a report row's
actual numbers change every run and is never cached; only static
boilerplate like a column header word is).

## 39. Localization — English ↔ Khmer

### The real flow, traced

```
User taps language toggle
      -> appLanguageProvider.notifier.setLanguage(AppLanguage.km)   (Riverpod StateNotifier)
      -> state updates immediately (every ref.watch(appLanguageProvider) rebuilds)
      -> persisted to SharedPreferences, key 'app_language'
      -> language.toLocale()  ->  MaterialApp's locale
      -> AppLocalizations.of(context) resolves to the Khmer .arb-generated class
      -> context.l10n.someKey   (l10n_extensions.dart's L10nX extension)
      -> ReceiptLabels.fromL10n(l10n)  /  report screen columns  <- built from context.l10n
      -> ReceiptViewModel.labels  /  A4ReportPdf's columns/summary params
      -> printed document shows the correct language
```
`core/providers/language_provider.dart`:
```dart
enum AppLanguage { en, km }
final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) => AppLanguageNotifier());
extension AppLanguageX on AppLanguage {
  bool get isKhmer => this == AppLanguage.km;
  Locale toLocale() => Locale(name);
}
class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.en) { _loadPreference(); }
  Future<void> setLanguage(AppLanguage language) async {
    state = language;                                          // synchronous — UI updates instantly
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', language.name);       // persisted after
  }
}
```
`lib.main.dart` watches this provider at the `MaterialApp` root
(`locale: ref.watch(appLanguageProvider).toLocale()`), so any
`setLanguage()` call rebuilds the whole app under the new `Locale` and
every `AppLocalizations.of(context)` call picks up the new strings.

`.arb` source: `lib/l10n/app_en.arb`, `app_km.arb` — flat key→string maps
(e.g. `receiptSubtotal`, `receiptTotal`, `receiptPaid`, `receiptChange`,
`receiptInvoiceNumber`, `paymentScreenInvoiceNumber` with an ICU
placeholder). Generated by `flutter gen-l10n` (configured via `l10n.yaml`)
into `lib/l10n/generated/app_localizations*.dart`.

### Where PDF-layer labels come from — `ReceiptLabels`

`PrintService`/`EscPosReceiptBuilder`/`ReceiptBitmapRenderer` have **no
`BuildContext`** — they can't call `context.l10n` themselves.
`ReceiptLabels` (`receipt_labels.dart`) resolves every label string
**once**, at the moment `ReceiptViewModel` is built (both factories
already receive an `AppLocalizations l10n` parameter):
```dart
factory ReceiptLabels.fromL10n(AppLocalizations l10n) => ReceiptLabels(
  subtotal: l10n.receiptSubtotal,
  discount: l10n.receiptDiscount,
  total: l10n.receiptTotal,
  paid: l10n.receiptPaid,
  telFormat: l10n.receiptsScreenTelLabel,   // a function: (phone) -> "Tel: {phone}"
  ...
);
```
`ReceiptLabels` then travels with the `ReceiptViewModel` (`receipt.labels`)
— every renderer reads `receipt.labels.subtotal` instead of hardcoding
`"Subtotal"`. A `static const ReceiptLabels.fallback` (hardcoded English)
exists only to prevent a crash if a `ReceiptViewModel` is ever built
without l10n — no production call site currently hits it.
`test/receipt_labels_test.dart` verifies English and Khmer both produce
their own distinct, correct strings (not silently falling back to English),
and that a checkout preview and a later reprint of the same sale produce
identical labels.

Report screens have **no** equivalent `ReportLabels` class — each screen
passes `l10n.xxx` directly as `A4ReportPdf.build`'s string arguments, from
inside its own print-button handler where it *does* have a `BuildContext`
— no context-smuggling problem exists there, since the builder never
resolves a label itself.

### Why document builders must not hardcode strings

If `EscPosReceiptBuilder` hardcoded `"Subtotal"` directly, a thermal
receipt would say "Subtotal" in English even with the app set to Khmer —
exactly the bug `ReceiptLabels` fixes. **Any string a document renderer
draws must arrive as data — never as a literal inside the renderer.**

### A real, current asymmetry worth knowing

The Flutter bundle ships only `NotoSans-Regular/Bold.ttf` and
`NotoSansKhmer-Regular/Bold.ttf` (2 weights each). The backend ships 9
Khmer weights (Thin through Black). Not a bug — the Flutter side only ever
needs regular/bold for receipts and reports; the backend's HTML/CSS
templates had more weight options available from the start.

## 40. Chrome / Windows Printing

```
Flutter Web app
      |
      v
Uint8List (PDF bytes) — from A4ReportPdf.build / PrintService.buildReceiptPdf
      |
      v
Printing.layoutPdf(...)
      |
      v
Chrome's built-in print preview
      |
      v
Windows print subsystem
      |
      v
printer driver (vendor-specific)
      |
      v
physical printer
```

| The app controls | The driver/OS controls |
|---|---|
| PDF page dimensions (`PdfPageFormat`, §9) | Physical paper size actually loaded |
| Font/image content | Print scaling ("fit to page" vs. "actual size") |
| Layout (margins, columns, table structure) | Hardware margins the printer can't physically print inside |
| — | Whether/how the physical cutter fires |
| — | Color/grayscale rendering choices |

Once bytes leave `Printing.layoutPdf` and enter Chrome's print pipeline,
this app has **no further programmatic control** — Chrome hands the
rendered PDF to the OS, the OS hands it to whatever driver is installed,
and the driver decides how to rasterize/scale/cut it onto physical paper.
This is exactly why `PrinterTransportType.pdfDriver` can't reliably fire a
physical thermal cutter between batched receipts (§30's caveat) — that's a
direct-ESC/POS-transport capability (`generator.cut()`, raw bytes this app
itself controls, §31), not achievable through a print-dialog-mediated PDF.

## 41. Receipt Printer vs. A4 Printer

Selecting a normal office/photo A4 printer (instead of a configured
receipt/roll printer) in the OS print dialog can make Chrome show "A4" as
the selected paper size **even though this app's generated PDF geometry is
narrow** (§9's receipt page format, never A4). That's the *driver's*
default for whichever physical printer is selected — not evidence this
app generated the wrong document.

The debugging sequence: **Save PDF first** (§42) → confirm the app's own
geometry is correct (narrow, matching `PrinterPaperSize`, never A4) → *then*
diagnose the physical print (driver/paper-tray configuration) as a
separate step. Doing these two checks in the wrong order — assuming a
wide physical printout means the app is broken — is the single most common
way to misdiagnose a printer-driver issue as a code bug.

## 42. Save PDF as a Diagnostic Tool

`ReceiptsScreen`'s "Save PDF" and `print_test_screen.dart`'s "Save 58mm/80mm
receipt PDF" buttons use `Printing.sharePdf(bytes:, filename:)` instead of
`Printing.layoutPdf(...)`.

| | `Printing.layoutPdf` | `Printing.sharePdf` |
|---|---|---|
| What it does | Opens the OS/Chrome print dialog | Saves/shares the raw file (browser download, share sheet) |
| Goes through a driver? | Yes | No |
| Useful for | Actually printing | Inspecting exactly what bytes were generated |

```
Saved PDF file looks wrong (bad layout, wrong Khmer, missing rows):
    -> the bug is in THIS APP's rendering code
    -> look at ReceiptViewModel / ReceiptContent / A4ReportPdf / KhmerTextRasterizer

Saved PDF file looks correct, but the PHYSICAL PRINTED PAPER is wrong
(wrong size, cut off, scaled weirdly):
    -> the bug is in the OS PRINT DRIVER / printer configuration
    -> not this app's problem to fix in code
```
This session added a further split for the Khmer raster specifically
(§14/§43): a debug-only "Save raw Khmer raster" button in
`print_test_screen.dart` exports the *pre-PDF* bitmap itself, so you can
tell apart "the raster is already wrong" (bug in `ReceiptBitmapRenderer`/
`ReceiptContent`) from "the raster is right but the PDF is wrong" (bug in
`_khmerImagePageContent`'s embedding, §15) — before ever involving a
driver at all.

## 43. Error Handling

### Payment failure vs. printing failure — a hard boundary

**A successfully completed sale must never become "failed" because
printing afterward failed.** Payment/sale finalization is persisted
**first**, entirely independent of whether a receipt ever successfully
prints. Printing happens *after*, and its failure is caught, logged, and
surfaced to the cashier as its own error — never rolled back into "the
sale failed":
```dart
// print_service.dart — printReceipt catches everything and returns a bool,
// never propagates a print failure as if the SALE failed:
Future<bool> printReceipt(BuildContext context, int saleId) async {
  try {
    ...
    return true;
  } catch (e) {
    if (e is ReceiptRenderException) debugPrint('Khmer receipt render failed: ${e.message}');
    else debugPrint('Print failed: $e');
    return false;   // <- caller shows "print failed," the sale itself is untouched
  }
}
```

### Retry/reprint design

Because printing is decoupled from sale finalization, "retry" is simply
"reprint" — Print One (§28) works on *any* past sale via the exact same
code path a fresh receipt would use. There's no separate "retry the
failed print" flow; reprinting an already-completed sale *is* the retry
mechanism.

### Distinct exception types, not generic catch-alls

`ReceiptRenderException` (`receipt_bitmap_renderer.dart`) exists
specifically so a Khmer-rendering failure can be told apart from other
failures (network down, printer offline) and surface a clear, specific
message — `"Unable to render Khmer receipt: ..."` — instead of a generic
"print failed." `receipt_preview_screen.dart`, `settings_modules_screen.dart`,
and `receipts_screen.dart`'s Save PDF/Print All all explicitly check
`e is ReceiptRenderException` and show `e.message` when it applies, a
generic fallback string otherwise.

## 44. Common Printing Errors

| Symptom | Likely layer | What to inspect |
|---|---|---|
| Khmer shows as □□□ (tofu boxes) | Font/glyph coverage (§11 #1-3) | Is the font bundled? Is `NotoSansKhmer` in `fontFallback`, not primary? Does the specific glyph exist in the subset font? |
| Khmer glyphs visible but malformed (wrong stacking/order) | Shaping (§11 #5) | `package:pdf`/ESC-POS firmware can't shape Khmer — confirm the receipt is going through the raster path (§13/§14), not falling back to `pw.Text` |
| Khmer printing is slow | Performance (§17-19) | Profile with `[PrintPerf]`/`[ReceiptLayout]` first — don't assume; check whether `receiptPdfDocSave` or the render stages dominate |
| Receipt looks structurally wide / different from preview | Raster layout (§14 — the bug this session fixed) | `[ReceiptLayout] mode=raster logicalWidth=...` — should equal `kReceiptContentWidth`, never `paperSize.dotWidth` |
| Wrong physical paper size on the printed page | Driver/printer config (§41/§42), not app code | Save PDF first — confirm app geometry is correct before touching the driver |
| Print All missing some receipts | Data-selection layer (§29/§37) | `filteredSales`/`fetchAllPages` — is it reading the full filtered dataset, or only what's currently loaded on screen? |
| "Unable to guess/decode the image type" exception | QR/image data validation | Check the actual image bytes at the source — historically a `qrImageData` issue, unrelated to the Khmer raster path |
| Network printer does nothing at all | Transport layer (§23's table) | Verify host/port/socket with a plain TCP tool before touching code |
| Tax/total looks wrong on the receipt | NOT a printing bug (§5) | Business data — the backend's `Sale` computation, or what `ReceiptResponse` actually sent |
| Preview looks right, printed PDF looks different | §14 (now fixed for the shared-widget case) or §16 (embedding) | Use the debug raw-raster export (§42) to isolate "raster is wrong" from "PDF embedding is wrong" |

## 45. Debugging Decision Tree

```
Wrong total on the receipt/report?
  -> NOT a printing bug. Look at payment/domain data (§5).

Correct screen, but the RECEIPT looks wrong (missing row, wrong label)?
  -> ReceiptViewModel / ReceiptContent / the specific renderer (§6/§7) —
     check receipt.adjustments and receipt.labels first.

Khmer showing as □□□ (tofu boxes)?
  -> Font/glyph coverage problem (§11, #1-3).

Khmer glyphs visible but visually malformed (wrong stacking/order)?
  -> Shaping problem (§11, #5) — rasterize via Flutter (§13), don't fight it.

Raster/PDF structurally wider or differently laid out than the preview?
  -> ReceiptBitmapRenderer's mounted width (§14) — check the
     [ReceiptLayout] logicalWidth/maxWidth/pixelRatio lines match what
     you expect before assuming anything else is wrong.

PDF file (via Save PDF) looks correct, but physical paper is wrong?
  -> Driver/printer configuration problem, not app code (§41/§42).

Network printer does nothing at all?
  -> Host/port/socket/device problem (§23's table) — not a rendering bug.

Print All is missing some receipts?
  -> Check the DATA SELECTION/FETCHING layer first (§29/§37) — is it
     reading the full filtered dataset, or only what's currently loaded?

Printing is slow?
  -> Profile first (§17) — don't guess. Add [PrintPerf]/[ReceiptLayout]
     timing, find the ACTUAL slow stage, then decide whether/how to fix it.
     Remember §19's platform caveat: on Flutter Web specifically, a slow
     doc.save() for a Khmer receipt may be a package:pdf/package:archive
     platform limitation, not something fixable in this app's own code.
```

## 46. Tests

### What's covered today, and by which file

| Concern | Test file |
|---|---|
| Paper-size → dot-width mapping, geometry | `printer_pdf_format_test.dart`, `receipt_pdf_page_format_test.dart` |
| PDF font coverage (cmap-level ASCII/Khmer checks) | `pdf_font_test.dart` |
| `containsKhmer`/dispatch (image XObject present/absent) | `khmer_receipt_dispatch_test.dart` |
| `ReceiptViewModel` financial fields (adjustments, paid/change, never-recomputed total) | `receipt_financial_fields_test.dart` |
| `ReceiptLabels` localization (EN/KM) | `receipt_labels_test.dart` |
| PDF generation (single + batch, QR-removal regression) | `print_service_batch_test.dart` |
| `KhmerTextRasterizer` (text-vs-image, bold, caching) | `khmer_text_rasterizer_test.dart` |
| A4 report Khmer embedding, multi-page | `a4_report_pdf_khmer_test.dart` |
| Report pagination (`fetchAllPages`, multi-page PDF page-count) | `report_print_pagination_test.dart` |
| ESC/POS adjustment-row completeness | `escpos_receipt_adjustments_test.dart` |
| Print All data selection (`filteredSales`, Print One's exact id) | `receipts_print_all_selection_test.dart` |
| `mapBounded` worker-pool correctness | `bounded_concurrency_test.dart` |
| QR image decoding (now-orphaned code path) | `receipt_image_decoder_test.dart` |
| `ReceiptRenderException` message/type | `receipt_bitmap_renderer_test.dart` — **deliberately does not** exercise real rendering, see below |

### Unit vs. integration vs. visual vs. physical-hardware

- **Unit**: `printer_pdf_format_test.dart`, `pdf_font_test.dart`,
  `bounded_concurrency_test.dart`, `receipt_financial_fields_test.dart` —
  pure data/logic, no widget tree, no PDF bytes inspected.
- **Integration-ish (byte-structure assertions)**:
  `print_service_batch_test.dart`, `a4_report_pdf_khmer_test.dart`,
  `khmer_receipt_dispatch_test.dart`, `receipt_pdf_page_format_test.dart` —
  build real PDF/ESC-POS bytes and assert on structure (page count,
  presence/absence of an image `XObject`, `MediaBox` dimensions) without a
  real printer.
- **Visual**: not automated. Khmer shaping correctness was verified by
  rendering a real PDF/raster and inspecting it as an image — including,
  this session, the debug raw-raster export described below. There's no
  automated "does this glyph look right" test; that's a genuinely hard
  problem to automate reliably.
- **Physical hardware**: not automated at all — `print_test_screen.dart`
  (§3's project map) is the manual equivalent: a `kDebugMode`-only
  developer screen with buttons to trigger real print jobs, save
  diagnostic PDFs, and — new this session — export the raw pre-PDF Khmer
  raster for direct visual comparison against the on-screen preview.

### A real testing gotcha this project hit — worth knowing before you copy this pattern

`ReceiptBitmapRenderer.render`/`renderImage` mounts a real `OverlayEntry`
and awaits `WidgetsBinding.instance.endOfFrame` twice. Under `flutter
test`, this reliably renders correctly (confirmed by writing the output to
a real file and visually inspecting it) but then the **test process hangs
at shutdown** afterward (`Bad state: Cannot close sink while adding
stream`) — reproduced identically across multiple attempts, with different
context sources, with and without `pumpAndSettle`. An environment
limitation of `flutter test`'s rendering pipeline, not a bug in the
renderer — landing a test that reliably hangs would be a permanent false
CI failure, worse than no coverage.

**The fix used throughout this project's test suite**: both
`EscPosReceiptBuilder` and `PrintService` accept an **injectable**
`ReceiptBitmapRenderer`:
```dart
class EscPosReceiptBuilder {
  const EscPosReceiptBuilder({this.bitmapRenderer = const ReceiptBitmapRenderer()});
  final ReceiptBitmapRenderer bitmapRenderer;
}
```
Tests substitute a fake subclass returning a trivial image instantly, no
`Overlay` involved:
```dart
class _FakeBitmapRenderer extends ReceiptBitmapRenderer {
  @override
  Future<img.Image> renderImage(BuildContext c, ReceiptViewModel r, PrinterPaperSize p) async =>
      img.Image(width: p.dotWidth, height: p.dotWidth * 3);   // synthetic — NOT a real layout measurement
}
```
This proves **dispatch wiring** (Khmer → bitmap path called; English →
never called) and **page-geometry math** (§9's regression coverage)
without needing real rendering. It's exactly the dependency-injection
pattern to reach for if you hit the same test hang rebuilding this
elsewhere. One caveat worth internalizing: because the fake's dimensions
are synthetic (`dotWidth × dotWidth*3`, chosen only to be "tall and
narrow, unlike A4"), these tests can verify geometry/dispatch but
**cannot** catch a `ReceiptContent`-vs-preview layout drift like §14's bug
— that class of bug can only be caught by real rendering, which is why the
debug raw-raster export (below) exists as the manual substitute.

### New this session: debug raw-raster export

`print_test_screen.dart` gained two buttons, "Save 58mm/80mm Khmer
raster," alongside the existing "Save 58mm/80mm receipt PDF" ones:
```dart
Future<void> _saveRawRaster(String label, PrinterPaperSize paperSize, _ReceiptContent content) {
  return _run('Save raw raster — $label', () async {
    final receipt = _receiptFixture(content: content, itemCount: 12);
    final image = await const ReceiptBitmapRenderer().renderImage(context, receipt, paperSize);
    final doc = pw.Document();
    final pngBytes = img.encodePng(image);            // debug-only export encode — NOT the production path
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(image.width.toDouble(), image.height.toDouble(), marginAll: 0),
      build: (_) => pw.Image(pw.MemoryImage(pngBytes)),
    ));
    await Printing.sharePdf(bytes: await doc.save(), filename: '${label}_raster.pdf');
  });
}
```
This dumps the *exact* pre-PDF bitmap `ReceiptBitmapRenderer` produces —
the same `img.Image` `_khmerImagePageContent` embeds via `pw.ImageImage`
(§15) — wrapped 1:1 in a throwaway single-image PDF purely so it can be
downloaded through the same `Printing.sharePdf` mechanism every other
debug export on this screen already uses. The PNG encode here is a
one-off diagnostic convenience, not a reintroduction of §16's removed
production round-trip — `print_service.dart` still calls
`pw.ImageImage(decoded)` directly, unaffected by this button existing.
Use it exactly as §42 describes: if this raster already looks
structurally wrong, the bug is in `ReceiptBitmapRenderer`/`ReceiptContent`;
if it looks right but the final "Save receipt PDF" doesn't, the bug is in
`_khmerImagePageContent`'s embedding step.

## 47. Building the System From Zero

A suggested build order, each stage buildable and testable before starting
the next.

| Stage | Build | Depends on | Done when |
|---|---|---|---|
| 1. Sale model | `Sale`/`SaleResponse` — line items, subtotal, tax, total, payments | — | You can fetch a finalized sale as JSON |
| 2. `ReceiptViewModel` | Flat, print-ready shape (§6) | 1 | `.fromApi(sale)` and `.fromCart(cart)` both exist, identical shape |
| 3. Shared receipt content | One widget (`ReceiptContent` equivalent) reading only from the view model (§7) | 2 | Same widget renders correctly for a fresh checkout AND a historical reprint |
| 4. Paper-size model | `PrinterPaperSize`/`PdfPageFormat` mapping, derived from ONE dot-width source (§8/§9) | — | 58mm/80mm PDFs and ESC/POS rasters agree on content width |
| 5. PDF receipt | `package:pdf` + `printing`, English/native text path (§10) | 2 | Prints via any installed driver |
| 6. Printer config | `PrinterTransportType`/`PrinterPaperSize`/`PrinterConfig`, persisted (§26) | — | A Settings screen saves/loads a config |
| 7. Transport abstraction | `connect`/`write`/`disconnect` interface (§22) | — | Interface + one fake implementation for testing |
| 8. Network transport | `NetworkPrinterTransport` (§23) — simplest real one | 7 | Raw bytes reach a real network printer |
| 9. ESC/POS builder | Native text for the common case (§21) | 2, 8 | A plain-English receipt prints correctly |
| 10. Khmer raster rendering | Whole-document renderer, mounted at a fixed logical width with a computed pixelRatio (§13/§14) — this is the step where §14's bug is easiest to accidentally reintroduce; mount the SAME widget as your on-screen preview, at the SAME logical width, from day one | 3, 9 | A receipt with your target script prints correctly shaped, on PDF AND ESC/POS raster — AND visually matches the on-screen preview, verified by actually looking, not just "no exception thrown" |
| 11. Raw image embedding | `pw.ImageImage(decoded)`, not `pw.MemoryImage(encodePng(decoded))` (§16) | 10 | `doc.save()` isn't wasting a compress+decompress round trip |
| 12. Print One | Fetch one full record, print it (§28) | 1-11 | Reprinting an old sale produces the same output as printing it fresh |
| 13. Print All | Bounded-concurrency batch fetch + batch PDF/thermal print (§29-31) | 12 | Printing 50+ receipts doesn't freeze the UI or open 50 dialogs |
| 14. Invoice | A *separate* document type/renderer — don't reuse the receipt layout (§32) | 1 | Looks like a formal A4 document, not a stretched receipt |
| 15. A4 reports | Shared table/header/footer builder any report screen can call (§34-37) | 5 | Two reports with completely different columns render through the same builder |
| 16. Localization | `.arb`-generated strings, a language provider, a `Labels` pattern for BuildContext-less renderers (§39) — ideally alongside stage 2-3, not bolted on last | — | Switching app language changes every printed document's labels, zero hardcoded strings in any renderer |
| 17. Testing | Unit tests for pure logic, byte-structure assertions for PDF/ESC-POS, DI fakes for anything needing a real widget tree, PLUS a manual raw-raster-export debug tool for the one thing tests can't catch (§46) | All above | You can refactor a renderer with confidence, without a physical printer, AND you have a way to visually catch a §14-style layout drift before shipping it |
| 18. Profiling | `[PrintPerf]`/`[ReceiptLayout]`-style temporary, `kDebugMode`-gated timing logs (§17) | All above | You can answer "which stage is actually slow" with a number, not a guess |

## 48. Educational Mini Architecture

**Educational simplified example** — a complete, tiny, runnable-in-spirit
architecture sketch. Not production code; missing error handling, caching,
most fields real code needs. Shows how the *pieces fit together* in
isolation.
```dart
// ---- Printer configuration ----
enum PrinterPaperSize { mm58, mm80 }
extension on PrinterPaperSize {
  int get dotWidth => this == PrinterPaperSize.mm58 ? 384 : 576;
}
enum PrinterTransportType { pdfDriver, network, usb, bluetooth }
class PrinterConfig {
  const PrinterConfig({required this.transportType, required this.paperSize, this.networkHost});
  final PrinterTransportType transportType;
  final PrinterPaperSize paperSize;
  final String? networkHost;
}

// ---- Receipt data ----
class ReceiptItem {
  const ReceiptItem(this.name, this.qty, this.total);
  final String name; final int qty; final double total;
}
class ReceiptViewModel {
  const ReceiptViewModel({required this.total, required this.items, required this.footer});
  final double total; final List<ReceiptItem> items; final String footer;
  bool get containsKhmer => items.any((i) => containsKhmerText(i.name)) || containsKhmerText(footer);
}

// ---- Shared receipt widget (mounted by BOTH preview and raster — the §14 lesson) ----
const double kReceiptLogicalWidth = 300;
class ReceiptContent extends StatelessWidget {
  const ReceiptContent({super.key, required this.receipt});
  final ReceiptViewModel receipt;
  @override
  Widget build(BuildContext context) => Column(children: [
    for (final item in receipt.items) Text('${item.name}  ${item.qty}  ${item.total}'),
    Text('TOTAL ${receipt.total}'),
    Text(receipt.footer),
  ]);
}

// ---- Transport abstraction ----
abstract class PrinterTransport {
  Future<void> connect();
  Future<void> write(List<int> bytes);
  Future<void> disconnect();
}
class NetworkPrinterTransport implements PrinterTransport {
  NetworkPrinterTransport(this.host, {this.port = 9100});
  final String host; final int port;
  Socket? _socket;
  @override
  Future<void> connect() async => _socket = await Socket.connect(host, port);
  @override
  Future<void> write(List<int> bytes) async { _socket!.add(bytes); await _socket!.flush(); }
  @override
  Future<void> disconnect() async => await _socket?.close();
}

// ---- ESC/POS builder (English fast path only, for brevity) ----
class EscPosReceiptBuilder {
  List<int> build(ReceiptViewModel r) {
    final bytes = <int>[];
    for (final item in r.items) bytes.addAll('${item.name}  x${item.qty}  \$${item.total}\n'.codeUnits);
    bytes.addAll('TOTAL \$${r.total}\n'.codeUnits);
    bytes.addAll(r.footer.codeUnits);
    return bytes;
  }
}

// ---- Khmer raster renderer: mount ReceiptContent at a FIXED logical width,
//      reach the printer's dot width via pixelRatio — never via widget width ----
Future<img.Image> renderKhmerRaster(BuildContext context, ReceiptViewModel r, PrinterPaperSize paperSize) async {
  final pixelRatio = paperSize.dotWidth / kReceiptLogicalWidth;
  // mount Container(width: kReceiptLogicalWidth, child: ReceiptContent(receipt: r))
  // off-screen, then: renderObject.toImage(pixelRatio: pixelRatio)
  throw UnimplementedError('see §14 for the real mounting/capture code');
}

// ---- Report document sketch ----
class ReportColumn { const ReportColumn(this.label); final String label; }
class ReportDocument {
  const ReportDocument({required this.title, required this.columns, required this.rows});
  final String title; final List<ReportColumn> columns; final List<List<String>> rows;
}

// ---- Print service, tying it together ----
class PrintService {
  Future<void> printReceipt(ReceiptViewModel r, PrinterConfig config) async {
    final bytes = EscPosReceiptBuilder().build(r);       // English fast path
    final transport = NetworkPrinterTransport(config.networkHost!);
    await transport.connect();
    await transport.write(bytes);
    await transport.disconnect();
  }
}
```

## 49. Future Flutter Mobile Version

### What can stay mostly unchanged

- **Business models** — `Sale`, `ReceiptResponse`, report row models. Pure
  data, platform-independent.
- **`ReceiptViewModel`** — pure Dart, no platform-specific imports.
- **`ReceiptContent`** (§7) — pure Flutter widget, no platform-specific
  imports; the exact same layout-unification lesson from §14 applies with
  zero changes on mobile.
- **PDF builder** (`_receiptPageContent`, `A4ReportPdf`) — `package:pdf`
  is pure Dart, works identically on mobile, **and gets the native-zlib
  `doc.save()` path "for free"** on Android/iOS/desktop (§19's `io/vm.dart`
  branch) — the Flutter-Web-specific slow-compression limitation
  documented in this session simply does not apply to a mobile build.
- **Report model/renderer**, **localization concepts** (`ReceiptLabels`,
  the `.arb`/`AppLocalizations` pipeline) — platform-independent.

### What changes

| Concern | Web (this project) | Mobile |
|---|---|---|
| PDF/driver printing | `Printing.layoutPdf` → Chrome → OS driver | Still `Printing.layoutPdf` (the `printing` package supports mobile), but usually no "driver" step — goes to iOS's/Android's native print/share sheet directly |
| Bluetooth | `print_bluetooth_thermal` (already cross-platform) | Same package, but now needs **runtime permission prompts** (Android 12+ `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN`, iOS `NSBluetoothAlwaysUsageDescription`) — none of that exists as app-level code in this project today |
| USB | `flutter_pos_printer_platform_image_3` | Needs Android's `UsbManager.requestPermission` flow; iOS doesn't support arbitrary USB accessory access the same way — USB may simply not be offered as a transport on iOS |
| File system | Browser download (`Printing.sharePdf`) | Real file system access, or the native share sheet |
| Doc.save() compression (Khmer receipts specifically) | Pure-Dart `package:archive` (§19) — the current bottleneck | Native `dart:io zlib.encode` — this specific bottleneck disappears |

| | Flutter Web | Android | iOS | Windows Desktop |
|---|---|---|---|---|
| PDF/driver print | ✅ via Chrome | ✅ via `printing` pkg | ✅ via `printing` pkg | ✅ via native dialog |
| Bluetooth | ⚠️ limited/no | ✅ (needs runtime perms) | ✅ (needs Info.plist + prompt) | ✅ (needs Windows Bluetooth stack) |
| USB | ❌ | ✅ (needs host-mode perms) | ❌ (not generally available) | ✅ |
| Network (raw socket) | ⚠️ browser-sandboxing dependent | ✅ | ✅ | ✅ |
| Khmer `doc.save()` speed | Gated by pure-Dart deflate (§19) | Native zlib — fast | Native zlib — fast | Native zlib — fast |

### The key point: the interface boundary is what makes a mobile port cheap

Because `ThermalPrinterService`/`EscPosReceiptBuilder`/`ReceiptViewModel`
never import anything platform-specific, swapping *which*
`PrinterTransport` implementation gets constructed (§26's `_transportFor`)
is the *only* place that needs platform-aware code for the thermal path.
Everything above that line in the architecture (§1-21) is untouched by a
mobile port — and, per the table above, the Khmer-performance ceiling this
session investigated is actually a *web-specific* problem that a mobile
port sidesteps entirely, for free, without any code change.

## 50. Architecture Rules to Remember

1. **Business calculation has one source of truth.** The backend computes
   money exactly once, at sale finalization (§5). No renderer ever
   recomputes tax/total.
2. **Document data is separate from document layout.** `ReceiptViewModel`
   is just data; `ReceiptContent`/`receipt_layout_spec.dart` own sizing
   (§6/§7). Neither knows the other's internals.
3. **Layout is separate from transport.** A renderer produces bytes; a
   transport moves bytes (§22).
4. **Printer transport only moves bytes.** `PrinterTransport`'s entire
   interface is `connect`/`write(bytes)`/`disconnect` — no document
   knowledge, no language detection (§21/§22).
5. **Receipt, invoice, and report are different documents.** They may
   share fonts, localization patterns, and PDF page-geometry helpers —
   they must not share one layout (§1/§32).
6. **The same receipt shown or rendered in multiple places must use one
   specification.** `ReceiptContent`, shared by the on-screen preview
   *and* the Khmer raster path (§7/§14) — not independently-maintained
   copies. This project got this wrong twice before getting it right.
7. **Complex-script shaping must happen before a dumb printer receives
   data.** Thermal firmware and `package:pdf` can't shape Khmer correctly
   — Flutter can, so shape it first and hand the printer pixels (§11-13).
8. **Full export ≠ visible rows.** Print All and report export must use
   the full filtered dataset (`fetchAllPages`, `filteredSales`), never
   just what's currently loaded on screen (§29/§37).
9. **Profile before optimizing.** The actual bottleneck (a redundant
   PNG round trip, then a platform-specific pure-Dart deflate path) was
   never the first guess — real `[PrintPerf]` numbers found it (§16-19).
10. **Keep printer infrastructure independent from UI.** Screens read
    `PrinterConfig` and call `ThermalPrinterService`/`PrintService` — they
    never construct a transport or make a Khmer-vs-English decision
    themselves (§26/§27). Protect this boundary during UI refactors —
    §14's fix touched only the rendering layer and never needed to touch
    `NetworkPrinterTransport`, USB, Bluetooth, payment logic, or receipt
    geometry, precisely because the boundary held.

## 51. Glossary

| Term | Meaning |
|---|---|
| **PDF** | Portable Document Format — this project generates it via `package:pdf` (Flutter) and OpenHTMLtoPDF (backend Java) |
| **ESC/POS** | A command language most thermal receipt printers understand — plain bytes where certain sequences are commands (cut, feed, print image) rather than characters |
| **Unicode** | The standard assigning every character a unique numeric codepoint |
| **Glyph** | The actual visual shape drawn for a character (or part of one) — a font file is a collection of glyphs |
| **Shaping** | Converting a sequence of Unicode codepoints into the correctly-positioned, correctly-substituted sequence of glyphs to draw — critical for Khmer (§12) |
| **GSUB** | Glyph Substitution table (in a font) — rules for swapping one glyph for another based on context |
| **GPOS** | Glyph Positioning table — rules for moving/stacking glyphs relative to each other |
| **Raster / bitmap** | An image represented as a grid of pixels/dots, as opposed to vector shapes or text |
| **RGBA** | Red/Green/Blue/Alpha — 4 bytes per pixel, this project's raw in-memory image format before any encoding |
| **PNG** | A lossless, compressed image file format — used to matter in this pipeline; no longer part of the production Khmer-PDF-embedding path as of §16 |
| **DPI** | Dots Per Inch — a measure of print resolution; this project's thermal printers are effectively 8 dots/mm (~203 DPI) |
| **dotWidth** | The number of physical print-head dots across a receipt's printable width — 384 for 58mm stock, 576 for 80mm (§8) |
| **PDF point** | 1/72 inch — the physical unit `package:pdf`'s `PdfPageFormat` is defined in |
| **logicalWidth vs. pixelRatio** | Flutter's device-independent layout unit vs. the multiplier applied at capture time to reach a target *pixel* resolution — conflating them was §14's bug |
| **deflate** | The compression algorithm PDF streams use — this project's `doc.save()` uses either native `zlib` or pure-Dart `package:archive`, chosen per-platform (§19) |
| **SMask** | A PDF image's separate soft-mask (alpha/transparency) stream, embedded alongside its RGB stream |
| **XObject** | A PDF "external object" — how an embedded image (or form) is represented inside a PDF's object graph; tests assert on its presence/absence to detect the Khmer-image-vs-native-text dispatch |
| **TCP** | Transmission Control Protocol — the protocol `NetworkPrinterTransport` uses via `dart:io Socket` |
| **Port 9100** | The near-universal "raw print" TCP port most network thermal printers listen on |
| **USB VID/PID** | Vendor ID / Product ID — two numbers every USB device advertises, together identifying its make/model |
| **View model** | A data shape built specifically to be easy for a UI/renderer to consume — `ReceiptViewModel` |
| **Transport** | The mechanism that moves already-built bytes to a physical destination — `PrinterTransport` and its three implementations |
| **Driver** | OS/vendor software translating a print job into the specific commands a particular printer model understands |
| **Bounded concurrency** | Limiting how many async operations run *simultaneously*, without limiting the *total* — `mapBounded` (§29) |
| **Localization (l10n)** | Adapting an app's displayed text to a specific language/locale — `AppLocalizations`, `.arb` files, `context.l10n` |

## 52. Quick Reference Cheat Sheet

**Receipt**
```
ReceiptViewModel -> containsKhmer?
  no  -> native pw.Text / ESC/POS text
  yes -> ReceiptContent (shared with preview) -> ReceiptBitmapRenderer -> bitmap
-> pdfDriver? Printing.layoutPdf : ThermalPrinterService.printReceipt
```

**English PDF**
```
ReceiptViewModel -> _receiptPageContent (pw.Text tree, receipt_layout_spec.dart sizes)
-> pw.Document -> doc.save() -> Printing.layoutPdf
```

**Khmer PDF**
```
ReceiptContent (logicalWidth=300) -> ReceiptBitmapRenderer.renderImage(pixelRatio=dotWidth/300)
-> img.Image -> pw.ImageImage(decoded)   [NOT pw.MemoryImage(encodePng(...))]
-> pw.Document -> doc.save() -> Printing.layoutPdf
```

**ESC/POS Khmer**
```
ReceiptContent -> ReceiptBitmapRenderer.render() [renderImage + Floyd-Steinberg dither]
-> generator.imageRaster(image) -> ThermalPrinterService -> PrinterTransport.write(bytes)
```

**Network**
```
EscPosReceiptBuilder.build() -> List<int>
-> NetworkPrinterTransport(host, port: 9100)
-> socket.connect -> socket.add(bytes) -> socket.flush() -> socket.close()
```

**Print One**
```
row tap -> SaleService.getReceipt(id) -> ReceiptViewModel.fromReceiptResponse
-> pdfDriver? PrintService.printReceipt : ThermalPrinterService.printReceipt
```

**Print All**
```
filteredSales -> ids -> mapBounded(ids, getReceipt, concurrency: 5) -> ReceiptViewModels
-> pdfDriver? buildReceiptsPdf (ONE doc, many pages)
   else?      ThermalPrinterService.printReceipts (ONE connection, per-receipt cut)
```

**Invoice**
```
Sale (Java) -> SaleService.invoicePdf/estimatePdf -> HTML string -> PdfService.renderHtmlToPdf
-> byte[] -> GET .../invoice.pdf  or  POST .../email
(entirely backend-side — Flutter never calls this)
```

**Report**
```
screen's typed rows -> mapped to List<String> per row
-> fetchAllPages (ALL filtered rows, not just on-screen page)
-> A4ReportPdf.build(title, columns, rows, summary, ...)
     -> per-cell: KhmerTextRasterizer.textOrImage (Khmer -> image, else -> pw.Text)
-> Printing.layoutPdf
```

**Localization**
```
appLanguageProvider.setLanguage(km) -> MaterialApp.locale rebuilds
-> context.l10n -> ReceiptLabels.fromL10n(l10n) [receipts]  /  l10n.xxx directly [reports]
-> receipt.labels.xxx / A4ReportPdf's columns/summary params -> printed document
```

**Debugging**
```
Wrong number?           -> business data, not printing (§5)
Wrong on-screen only?   -> ReceiptViewModel/ReceiptContent (§6/§7)
Khmer boxes?            -> font/glyph (§11)
Khmer malformed?        -> shaping -> rasterize (§11/§13)
Raster wider than preview? -> ReceiptBitmapRenderer's mounted width (§14)
PDF right, paper wrong? -> driver, not app code (§41/§42)
Print All incomplete?   -> data-fetching layer, not renderer (§29/§37)
Slow?                   -> profile first (§17); check the Web/pure-Dart-deflate
                           caveat (§19) before assuming it's this app's bug
```

---

## Known Current Limitations

Verified against current code/architecture — not a wish list, not
speculative:

- **Khmer receipt PDF generation is measurably slower than English on
  Flutter Web specifically**, and the remaining gap after this session's
  optimization (§16) is a `package:pdf`/`package:archive` platform
  limitation (pure-Dart deflate compressing the receipt's raw image
  stream, because `dart:io`'s native zlib doesn't exist in a browser
  context, §19) — not something fixable inside this app's own rendering
  code without either bypassing `package:pdf`'s image-embedding path
  entirely or accepting a JPEG-quality trade-off that hasn't been visually
  validated yet (§19's "potential future optimization" list).
- **The on-screen receipt preview is paper-size-agnostic** — it always
  renders at a fixed logical width (`kReceiptContentWidth = 300`)
  regardless of whether the store's configured printer is 58mm or 80mm
  (§14). The Khmer raster path now correctly scales its *pixel* output per
  paper size via `pixelRatio`, but the on-screen preview itself doesn't
  visually distinguish the two paper sizes. Not a rendering bug — a real,
  current scope limit.
- **`Printing.layoutPdf`-mediated (OS-driver) printing cannot reliably
  trigger a physical thermal cutter between batched receipts** (§30) —
  nothing in the PDF/print-dialog pipeline can send a "cut here" command;
  only the direct ESC/POS transport can (§31).
- **Chrome cannot be forced to select a specific paper size on the
  underlying Windows printer driver from this app** (§40/§41) — paper
  selection in the OS print dialog is entirely the user's/driver's
  responsibility; this app only controls the PDF's own page geometry.
- **USB and, to a lesser extent, Bluetooth are platform-restricted
  transports** (§24/§25) — USB is Android/Windows-only per the underlying
  plugin's own documentation (no Flutter Web or iOS support); a future
  mobile build needs new runtime-permission-request code neither transport
  currently has, since a web/desktop target never surfaced that
  requirement.
- **Report screens are inconsistently print-capable** — of the report
  screens under Reports/Inventory, 3 (`DailyReportScreen`/X-report,
  `top_products_screen.dart`, `monthly_sales_screen.dart`) have no
  PDF/export code at all today (§34) — a real, current gap, not
  documented elsewhere as intentional or unintentional; flagged here as
  observed fact only.
- **`CapabilityProfile.load()` is called fresh on every `EscPosReceiptBuilder.build()`**,
  including every iteration of a Print All batch loop — the app itself
  does no memoization at that call site. The underlying package happens to
  cache the expensive JSON-parse step internally (§19), so this isn't
  currently a measured performance problem, but the app-level call is not
  itself cached, which is worth knowing if that library's internal
  behavior ever changes.
- **The on-screen preview's `ReceiptContent` width differs between its two
  screen call sites** (`ReceiptPreviewScreen` uses 300, `ReceiptsScreen`'s
  reprint pane uses 380, §7) — an intentional, pre-existing difference for
  two different screen layouts, not a bug, but worth knowing if you're
  trying to reproduce "exactly what the cashier saw" pixel-for-pixel from
  a screenshot, since it depends on which screen took it.

---

## Cross-Platform Printer Architecture

This section answers one question, verified against the actual repository
(not general Flutter advice): **is the current printer architecture ready
to be built for Windows desktop, Android, and iOS, in addition to its
current Flutter Web deployment, or does it need architectural changes
first?**

Verification method: read every printer-related file's actual imports;
read the `pubspec.yaml` platform declarations of every plugin involved
directly from `pub-cache`; ran `flutter build web --release` against this
repo (succeeded); read the actual patched `dart:io` source this project's
Flutter SDK (3.41.4) ships for the web compile target, to see precisely
what happens at runtime, not just at compile time.

### The layered picture

```
ReceiptViewModel -> ReceiptContent / EscPosReceiptBuilder / PdfBuilder   <- 100% portable, pure Dart/Flutter
                              |
                        ThermalPrinterService
                              |
                        PrinterTransport (interface — portable, unchanged)
                +-------------+-------------+
                v             v             v
         NetworkPrinterTransport  UsbPrinterTransport  BluetoothPrinterTransport
         (dart:io Socket)         (flutter_pos_printer_  (print_bluetooth_thermal)
                                    platform_image_3)
```
Only these three transport classes contain platform-specific code. Every
other file in the printing stack — `ReceiptViewModel`, `ReceiptContent`,
`ReceiptBitmapRenderer`, `EscPosReceiptBuilder`, `PrintService`'s PDF
building, `A4ReportPdf`, `KhmerPdfFont` — has zero platform-conditional
code and zero platform-specific imports, confirmed by grep across the
entire `features/pos/services/printing/` and `core/services/printing/`
trees.

### Verified per-transport portability

| Transport | Mechanism | Compiles on Web? | Works at runtime on Web? | Android | iOS | Windows |
|---|---|---|---|---|---|---|
| **PDF/driver** (`Printing.layoutPdf`) | `printing: 5.14.2` | ✅ | ✅ (confirmed — package declares android/ios/linux/macos/web/windows in its own `pubspec.yaml`) | ✅ | ✅ | ✅ |
| **Network** (`NetworkPrinterTransport`) | `dart:io Socket`, port 9100 | ✅ (verified: `flutter build web --release` succeeds against this repo) | **❌ — throws `UnsupportedError("Socket constructor")` at runtime**, verified by reading `flutter/bin/cache/dart-sdk/lib/_internal/js_runtime/lib/io_patch.dart:532`, this project's exact shipped SDK. Universal browser limitation — no browser exposes raw-TCP-to-arbitrary-host access, not a Dart implementation gap. | ✅ (native `dart:io`) | ✅ (native `dart:io`) | ✅ (native `dart:io`) |
| **USB** (`UsbPrinterTransport`) | `flutter_pos_printer_platform_image_3: 1.2.4` | (no web platform implementation registered at all) | **❌ — no platform-side implementation exists for web in this plugin's own `pubspec.yaml`** (`plugin.platforms` lists only `android`, `ios`, `windows`) | ✅ (registered; needs new runtime-permission code, §"Android" below) | ⚠ registered by the plugin, but real device USB accessory access is separately MFi-gated by Apple — untested against real hardware | ✅ (registered; untested in this repo) |
| **Bluetooth** (`BluetoothPrinterTransport`) | `print_bluetooth_thermal: 1.2.1`, Bluetooth Classic | (web platform entry exists in the package's source but is **explicitly commented out** in this resolved version's `pubspec.yaml`) | ❌ (disabled in this exact resolved version) | ✅ (registered; needs new runtime-permission code) | ✅ (registered; needs `Info.plist` + prompt code) | ✅ (registered, via the plugin's bundled `win_ble` dependency; untested in this repo) |

The Network-on-Web finding is the most important one in this review: the
code **compiles cleanly and shows no error until a user actually tries to
connect**, at which point it throws. Nothing in the current codebase
guards against a user selecting `PrinterTransportType.network` (or `usb`)
in Settings while running the Web build.

### Platform scaffolding status (unrelated to printing code, but a real prerequisite)

This repository currently has `android/`, `ios/`, `macos/`, and `web/`
platform folders. It does **not** have a `windows/` (or `linux/`) folder
yet — `flutter build windows` will fail immediately, before ever reaching
any printing code, until `flutter create --platforms=windows .` is run.

### What's already portable, unchanged

`ReceiptViewModel`, `ReceiptLabels`, `receipt_layout_spec.dart`,
`ReceiptContent` (§7 of this document), `ReceiptBitmapRenderer` (§14),
`EscPosReceiptBuilder` (§21), `PrintService`'s PDF-building code (§10/§15),
`A4ReportPdf`/`KhmerTextRasterizer` (§34-38), `PrinterConfig`/
`PrinterPaperSize`/`PrinterTransportType` (§26), and the `PrinterTransport`
interface itself (§22) — all pure Dart/Flutter, verified free of platform
imports, and require **zero changes** for Windows/Android/iOS. One
practical bonus: `doc.save()`'s Khmer-receipt slowness documented earlier
in this file is a Flutter-*Web*-specific side effect of `package:pdf`
falling back to pure-Dart compression (§19) — every other target gets
native `zlib` for free, so Khmer PDF generation should be *faster*, not
just equally portable, on Windows/Android/iOS.

### What requires new work before/during a platform port

Not a rewrite — narrow, additive gaps:

1. **A capability-check, not a new transport abstraction.** The
   `PrinterTransport` interface (§22) does not need to change — it's
   already exactly "connect/write/disconnect," platform-agnostic by
   design. What's missing is something upstream of it: a small lookup
   answering "is this `PrinterTransportType` expected to work on the
   current platform?" so Settings/`ThermalPrinterService` can refuse or
   warn *before* attempting a connection that's guaranteed to fail (Network
   and USB on Web, today, with zero guard) rather than surfacing a raw
   `UnsupportedError`/missing-plugin exception to the cashier.
2. **Android runtime permissions** — `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN`
   (Android 12+) and USB host-mode permission requests. No app-level code
   for either exists yet; only the underlying plugins' capability to
   support them once asked.
3. **iOS Bluetooth** — `NSBluetoothAlwaysUsageDescription` in `Info.plist`
   plus a runtime permission prompt; neither exists yet.
4. **Windows platform folder** — `flutter create --platforms=windows .`,
   a one-time prerequisite unrelated to printing code.

### Recommended future structure — deliberately small

```
features/pos/services/printing/
  ...(every existing file, unchanged)...
  printer_transport.dart           <- unchanged interface
  network_printer_transport.dart   <- unchanged
  usb_printer_transport.dart       <- unchanged
  bluetooth_printer_transport.dart <- unchanged
  printer_platform_support.dart    <- NEW: given a PrinterTransportType
                                       (+ kIsWeb/defaultTargetPlatform),
                                       returns whether it's expected to
                                       work on the current platform — a
                                       lookup table, not a rewrite
```
A `printer/transports/{web,windows,android,ios}/` directory split was
considered and **rejected** — each transport is already a single,
platform-scoped file with no internal platform branching to extract; that
directory shape would spread one file's logic across four for no
structural benefit. `if (dart.library.io)`-style conditional imports were
also considered and rejected: the concrete transport files already compile
identically everywhere (proven by the successful web build) — the actual
failure is at *runtime*, not compile time, so a compile-time mechanism is
the wrong tool. A plain runtime capability check is simpler and correct.

### MUST / SHOULD / CAN WAIT / DO NOT

- **MUST** before any further platform work: add the capability-check
  (item 1 above) so Network/USB aren't silently attempted where they
  cannot work — this matters for the *current* Web deployment, independent
  of any future mobile/desktop build; add the Windows platform folder
  before attempting `flutter build windows`.
- **SHOULD**: Android Bluetooth/USB runtime-permission flow; iOS
  `Info.plist` Bluetooth entry + prompt.
- **CAN WAIT**: per-platform directory restructuring (not justified by
  anything found in this review); validating USB-on-iOS against real
  hardware (do it when hardware is available, not preemptively).
- **DO NOT change**: `PrinterTransport`, `ReceiptViewModel`,
  `ReceiptContent`, `receipt_layout_spec.dart`, `EscPosReceiptBuilder`,
  `ReceiptBitmapRenderer`, the PDF builder, or any of the three existing
  transport classes — all confirmed portable/correct as they stand; none
  of the findings above implicate their internal logic.

---

*This document was rewritten by inspecting the current repository at
`/home/luffy/KAKNNEA/write-test-pos` directly — every file path, class
name, method signature, package version, and log line above was verified
against real source files and a real captured `[PrintPerf]`/
`[ReceiptLayout]` print job, not assumed or carried forward from a prior
version of this document without re-checking. Where this project's
implementation differs from a "textbook" approach, or from what an earlier
version of this document said, that difference is called out explicitly
rather than silently smoothed over.*

