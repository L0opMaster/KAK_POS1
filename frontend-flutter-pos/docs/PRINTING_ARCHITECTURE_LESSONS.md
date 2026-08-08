# Receipt / Invoice / Report Printing — Architecture Lessons

A teaching reference for how this project generates and prints receipts,
invoices, and reports — written so the same architecture can be rebuilt from
scratch in a future Flutter mobile POS, without copying code blindly.

See `PRINTING_SETUP.md` in this same folder for day-to-day
configuration/troubleshooting — this file is for understanding *why* it's
built this way.

---

## 0. File Map

### Frontend — Receipts (thermal/PDF, per-sale document)

| File | Role |
|---|---|
| `lib/features/pos/services/printing/receipt_view_model.dart` | The print view model — single source of truth every renderer reads from |
| `lib/features/pos/services/printing/receipt_layout_spec.dart` | Typography constants (font sizes, spacing) for the receipt layout |
| `lib/features/pos/services/printing/printer_pdf_format.dart` | 58mm/80mm → PDF page geometry |
| `lib/features/pos/services/printing/printer_profile.dart` | `PrinterConfig`, `PrinterTransportType`, `PrinterPaperSize` — the settings model |
| `lib/features/pos/services/print_service.dart` | Builds the receipt PDF (`buildReceiptPdf`/`buildReceiptsPdf`); picks PDF-vs-thermal |
| `lib/features/pos/services/printing/thermal_printer_service.dart` | Owns a printer transport, drives connect→write→disconnect |
| `lib/features/pos/services/printing/escpos_receipt_builder.dart` | Builds raw ESC/POS byte stream (Latin path) |
| `lib/features/pos/services/printing/receipt_bitmap_renderer.dart` | Renders Khmer receipts to a bitmap for thermal printers |
| `lib/features/pos/services/printing/receipt_image_decoder.dart` | Safe base64/image-signature decoding |
| `lib/features/pos/services/printing/khmer_pdf_font.dart` | Loads/caches the Khmer font theme for PDF |
| `lib/features/pos/services/printing/{bluetooth,usb,network,printer_transport}.dart` | The transport interface + 3 implementations |
| `lib/features/pos/widgets/receipt_preview_screen.dart` | On-screen receipt preview (post-payment) |
| `lib/features/pos/screens/receipts_screen.dart` | Reprint list — Print One / Print All / detail view |
| `lib/features/pos/models/receipt_models.dart` | `ReceiptResponse` — raw JSON model from `GET /receipt` |
| `lib/features/pos/services/sale_service.dart` | HTTP calls: `createSale`, `paySale`, `getReceipt` |
| `lib/features/pos/providers/receipt_provider.dart` | Riverpod state for the Receipts list screen |

### Frontend — Reports (A4 tabular documents)

| File | Role |
|---|---|
| `lib/core/services/printing/a4_report_pdf.dart` | Generic A4 report PDF builder (`pw.MultiPage`) |
| `lib/core/utils/bounded_concurrency.dart` | `mapBounded()` — capped-concurrency fetch helper |
| `lib/features/reports/services/report_service.dart` | Report API calls + `fetchAllPages()` |
| `lib/features/reports/screens/sales_report_screen.dart`, `sales_summary_report_screen.dart` | Report screens with Print buttons |

### Frontend — Payment (produces the numbers everything above renders)

| File | Role |
|---|---|
| `lib/features/pos/screens/payment_screen.dart` | Cart → sale submission → completed-sale screen |
| `lib/features/pos/providers/cart_provider.dart` | `CartState` — subtotal/discount/tax getters |

### Backend

| File | Role |
|---|---|
| `service/PdfService.java` | Generic HTML→PDF renderer (OpenHTMLtoPDF), Khmer font loader |
| `service/SaleService.java` | Builds invoice/receipt HTML; `/invoice.pdf`, `/receipt` JSON |
| `service/ReportService.java` | Report data + the one PDF report (`dailyZReportPdf`) |
| `service/EmailService.java` | Sends the *same* PDF bytes as an attachment |
| `controller/SaleController.java`, `ReportController.java` | The HTTP endpoints |
| `src/main/resources/fonts/NotoSansKhmer-*.ttf` | Backend's own Khmer font set (separate from Flutter's bundled fonts) |

**Correction to a common assumption**: there is no separate backend "Invoice"
entity. `Sale` is the one entity; `SaleService.generateStandardInvoiceHtml()`
picks the title "INVOICE" vs "SALE RECEIPT" at render time based on payment
status.

---

## 1. High-Level Architecture Diagram

```
 ┌──────────────┐   ┌───────────────────┐   ┌───────────────────┐   ┌─────────────────┐   ┌──────────┐
 │  Sale data   │──▶│  ReceiptViewModel  │──▶│  Receipt layout    │──▶│ PDF or ESC/POS   │──▶│ Printer  │
 │ (API/cart)   │   │  (print model)     │   │ (spec/typography)  │   │ (bytes)          │   │ (device) │
 └──────────────┘   └───────────────────┘   └───────────────────┘   └─────────────────┘   └──────────┘
   ReceiptResponse    receipt_view_model.dart   receipt_layout_spec.dart   print_service.dart /   Bluetooth/
   or CartState        (.fromReceiptResponse       printer_pdf_format.dart  escpos_receipt_builder  USB/Network/
                        / .fromCart)                                       .dart                    OS print dialog
```

Two things to internalize, because they explain almost every bug fixed this
session:

- **Every arrow is a place data can go stale or get lost.** The tax bug
  happened because the leftmost box (`Sale data`) never reached the second
  box correctly. The QR bug happened at the third→fourth boundary (wrong
  decode). Bugs cluster at arrows, not inside boxes.
- **Two renderers, one model.** After `ReceiptViewModel`, the pipeline forks:
  PDF (`print_service.dart`) and ESC/POS (`escpos_receipt_builder.dart` /
  `receipt_bitmap_renderer.dart`) are two independent renderers reading the
  *same* model. That fork is why `receipt.adjustments` (tax/discount/etc.)
  only had to be fixed in one place (the model) and both outputs got it for
  free.

### The 8 layers, and what each one must NOT do

| # | Layer | Responsible for | Must NOT do |
|---|---|---|---|
| 1 | UI data (cart/screen state) | What the cashier is doing right now — items, quantities, on-screen totals | Be the final word on a completed sale's numbers — it's provisional until the backend confirms |
| 2 | Business/domain model (`ReceiptResponse`, `SaleResponse`) | Mirror the API contract exactly, typed | Format currency, pick a language, hide/show rows |
| 3 | Print view model (`ReceiptViewModel`) | Merge/normalize domain data into one flat, print-ready shape; own display decisions (adjustment order, zero-hiding) | Know about PDF, ESC/POS, or any specific renderer |
| 4 | Document layout (`receipt_layout_spec.dart`, `printer_pdf_format.dart`) | Pure numbers: font sizes, spacing, page geometry | Contain any business logic or read `ReceiptViewModel` fields |
| 5 | PDF generation (`print_service.dart`, `a4_report_pdf.dart`) | Turn a view model into `pw.Widget` tree → `Uint8List` bytes | Recompute totals, decide printer transport |
| 6 | Printer transport (`PrinterTransport` implementations) | Move bytes to a physical/virtual destination (Bluetooth socket, USB, TCP, OS dialog) | Know what a "receipt" or "tax" is — it only sees bytes |
| 7 | OS print dialog (`Printing.layoutPdf`) | Let the OS/driver pick the physical printer, paper, scaling | Guarantee identical output across every printer driver (see Lesson-adjacent note in Part 9 below) |
| 8 | Direct ESC/POS | Same job as #6+#7 combined, but for printers with no OS driver at all | Try to look like a PDF — it's a completely different byte protocol |

The single biggest architectural idea in this whole codebase is that **layers
3 and 4 are shared by both of the two possible layer-5/6/7/8 paths.** Whether
you end up printing via PDF/driver or raw ESC/POS is decided *after* the
view model and layout spec are built, not before. That's why fixing "receipt
looks different depending on how you print it" is rare here — there's only
one place that could cause it.

---

## 2. One Receipt, Fully Traced

| Step | File : Method | Data in | Data out |
|---|---|---|---|
| 1. Cart total | `cart_provider.dart` : `CartState.finalTotal` getter | items, discount, taxRate | tax-inclusive grand total |
| 2. Navigate to pay | `cart_totals.dart` → `PaymentScreen(total: finalTotal, ...)` | `finalTotal` | `widget.total` on PaymentScreen |
| 3. Submit sale | `payment_screen.dart` : `_submitSaleToBackend()` | cart items, `taxRate`, `invoiceDiscount`, payments | `POST /api/pos/sales` → `SaleResponse` (id, grandTotal — no tax breakdown yet) |
| 4. Backend computes tax | `SaleService.java` : `createSale()` | `taxRate`, `invoiceDiscount`, line totals | persisted `Sale.taxAmount`, `.subtotal`, `.grandTotal` |
| 5. Fetch full receipt | `payment_screen.dart` : `_fetchCompletedReceipt()` → `SaleService.getReceipt(id)` | sale id | `ReceiptResponse` — subtotal/tax/discount/paid/change, all authoritative |
| 6. Build print model | `receipt_view_model.dart` : `ReceiptViewModel.fromReceiptResponse(r, ...)` | `ReceiptResponse` | `ReceiptViewModel` — one flat, print-ready object |
| 7. Preview | `receipt_preview_screen.dart` : `_buildViewModel()` renders it on screen | `ReceiptViewModel` | pixels |
| 8. User taps Print | `receipt_preview_screen.dart` : `_printPdfOrThermal()` | `ReceiptViewModel`, `PrinterConfig` | branches on `config.transportType` |
| 9a. PDF branch | `print_service.dart` : `buildReceiptPdf(r, paperSize)` | `ReceiptViewModel` | `Uint8List` PDF bytes |
| 9b. Thermal branch | `thermal_printer_service.dart` : `printReceipt()` → `escpos_receipt_builder.dart` : `build()` | `ReceiptViewModel` | `List<int>` ESC/POS bytes |
| 10a. Hand to OS | `Printing.layoutPdf(onLayout: (_) => pdfBytes)` | PDF bytes | OS print dialog opens |
| 10b. Hand to transport | `PrinterTransport.write(bytes)` (Bluetooth/USB/Network impl) | ESC/POS bytes | bytes over the wire |
| 11. Physical output | printer firmware | bytes | paper |

---

## 3. The 5 Lessons to Carry Into a Future Mobile App

1. **One authoritative source per number, always.** Tax, discount, total,
   paid, change — each has exactly one place allowed to compute it (the
   backend, for anything post-payment). Every other layer just *displays*
   it.
2. **A print/view model is not optional past trivial size.** The instant
   there's more than one renderer, build the intermediate object.
3. **"Loaded on screen" and "matches the filter" are different sets.** Print
   /export code must re-query "everything matching the current filter,"
   never trust `state.items`.
4. **Untyped/optional data must be validated at the boundary where it
   becomes binary.** Image decode, JSON parse, date parse — validate right
   there, don't hope upstream never sends garbage.
5. **Platform-specific behavior belongs in one swappable seam, not
   scattered through business logic.** `PrinterTransport` is that seam here.

---

# Lesson 1 — The Receipt Model

## Concept

Before you can print anything, you need *data*. The very first layer — before
`ReceiptViewModel`, before any PDF or ESC/POS code — is a plain class whose
only job is: **mirror the backend's JSON exactly, nothing more.**

In this project that's `ReceiptResponse`, in
`lib/features/pos/models/receipt_models.dart` — the typed reflection of
`GET /api/pos/sales/{id}/receipt`'s response body.

Why not just pass the raw `Map<String, dynamic>` around? Three reasons:

1. **Compile-time safety.** `json['taxAmount']` typo'd as `json['taxAmont']`
   in five files is five silent bugs. `receipt.taxAmount` typo'd the same
   way is a compile error.
2. **One parsing point.** All the "what if this field is null / missing /
   the wrong type" defensiveness happens exactly once, in `fromJson`. Every
   other file just trusts `receipt.subtotal` is a real `double`.
3. **A stable seam against backend changes.** Rename a field on the backend,
   fix `fromJson` in one place instead of hunting every screen.

```dart
// receipt_models.dart:78-119 (trimmed)
factory ReceiptResponse.fromJson(Map<String, dynamic> json) {
  return ReceiptResponse(
    businessName: json['businessName'] as String?,
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
    discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
    lines: (json['lines'] as List<dynamic>?)
            ?.map((e) => ReceiptLine.fromJson(e as Map<String, dynamic>))
            .toList() ?? [],
    // ...
  );
}
```

`lines` recurses into a nested model (`ReceiptLine.fromJson`) rather than
staying a raw `List<Map>` — same rule, one level deeper. Every piece of
structured JSON gets its own typed class, all the way down.

**Rule of thumb for telling this layer apart from `ReceiptViewModel`
(Lesson 2):** if a field's *name* or *nullability* comes from the API
contract, it belongs here. If a field's *value* is a business/display
decision — "which language name to show," "hide this row if zero," "format
as currency" — it belongs in the next layer. `ReceiptResponse` doesn't even
know what currency symbol to use for `subtotal`; it just knows it's a
`double`.

### A live example of stale documentation

`receipt_models.dart:189-209` has a `ReceiptSummary` class labeled
`"Legacy summary model kept for compatibility."` Checked via grep — it's
genuinely unused anywhere in the app now. **Lesson inside the lesson:**
comments asserting *why* something still exists rot the fastest — verify
with a grep before trusting them.

## Exercise

The backend's `Sale` entity has a `note` field not currently exposed on
`ReceiptResponse`. Work out (don't need to write it into the file):

1. What field declaration would you add, and what nullability? (What
   happens for a receipt created before this field existed?)
2. What line inside `fromJson` populates it?

*(Answer shape: `final String? note;` in the constructor/fields — nullable
because old rows/old backend versions won't have it — and
`note: json['note'] as String?,` inside `fromJson`, following the exact
pattern every other optional string field already uses.)*

---

# Lesson 2 — ReceiptViewModel

## Concept

`ReceiptViewModel` (`receipt_view_model.dart`, 300 lines) is the **print view
model** — the one object every renderer (on-screen preview, PDF, ESC/POS
text, Khmer bitmap) reads from. Its class doc says this outright:

```dart
/// A fully localized, formatted, print-ready receipt.
///
/// This is the single source of truth for receipt content — the on-screen
/// preview ([ReceiptPreviewScreen]), the PDF pipeline ([PrintService]) and
/// the thermal ESC/POS + bitmap pipeline ([EscPosReceiptBuilder]) all render
/// from the *same* [ReceiptViewModel] instead of three independently
/// formatted copies of the same receipt, so they can never drift apart.
```

### Two factories, two sources, one shape

| Factory | Source | When used |
|---|---|---|
| `ReceiptViewModel.fromReceiptResponse(r, language, l10n)` | Backend `ReceiptResponse` (authoritative, post-save) | Reprints, Print All, post-payment preview once the backend fetch completes |
| `ReceiptViewModel.fromCart(...)` | Live `CartItem`s + explicit totals | The narrow window before the backend receipt has loaded |

This is the pattern to copy: **one model, many ways to construct it,
depending on which data is available yet — never many models.**

### Why it, not the raw response, feeds every renderer

Three concrete jobs `ReceiptViewModel` does that `ReceiptResponse` must not:

**1. Localized line names.** A sale line has `nameEn`/`nameKm` separately;
something has to pick one based on the active language:

```dart
lines: r.lines.map((line) => ReceiptLineViewModel(
      name: line.localizedName(language),
      // ...
```

**2. Which adjustment rows to show, in what order, hidden when zero** — this
is the exact logic that was *missing* in the tax bug fixed earlier this
session:

```dart
// receipt_view_model.dart:147-156
List<ReceiptAdjustment> get adjustments => [
      if (discountAmount > 0)
        ReceiptAdjustment(ReceiptAdjustmentType.discount, discountAmount),
      if (deliveryCharge > 0)
        ReceiptAdjustment(ReceiptAdjustmentType.delivery, deliveryCharge),
      if (otherCharge > 0)
        ReceiptAdjustment(ReceiptAdjustmentType.otherCharge, otherCharge),
      if (taxAmount > 0)
        ReceiptAdjustment(ReceiptAdjustmentType.tax, taxAmount),
    ];
```

Every renderer just does `for (final adj in receipt.adjustments)` — none of
them contain an `if (tax > 0)` check themselves. That's the payoff: fix the
rule once, every output obeys it.

**3. Whether this receipt needs Khmer-safe rendering at all** — computed
once, used by the printing layer to pick a strategy (Lesson 6):

```dart
// receipt_view_model.dart:119-120
bool get containsKhmer =>
    language.isKhmer || _khmerPattern.hasMatch(_allText);
```

### Designing your own print view model

1. **Make it flat.** Nested optionality (`r?.customer?.name`) belongs in the
   factory that builds the model, not in every place that reads it.
2. **Put computed/derived display logic on the model as getters**
   (`adjustments`, `containsKhmer`, `showExchangeRate`), not duplicated in
   each renderer.
3. **Never let it hold a reference back to the raw API type.** If a renderer
   needs one more field from `ReceiptResponse`, add that field to the view
   model explicitly — don't hand the renderer the raw response "just in
   case."
4. **One factory per legitimate data source**, not one factory with a dozen
   optional parameters trying to serve every caller.

### Simplified example (yours will have far more fields)

```dart
class ReceiptViewModel {
  const ReceiptViewModel({
    required this.invoiceNumber,
    required this.lines,
    required this.subtotal,
    this.taxAmount = 0,
    this.discountAmount = 0,
    required this.total,
  });

  final String invoiceNumber;
  final List<ReceiptLineViewModel> lines;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double total;

  // Derived, computed once, used everywhere:
  List<ReceiptAdjustment> get adjustments => [
        if (discountAmount > 0) ReceiptAdjustment('Discount', -discountAmount),
        if (taxAmount > 0) ReceiptAdjustment('Tax', taxAmount),
      ];

  factory ReceiptViewModel.fromApi(SaleReceiptDto r) => ReceiptViewModel(
        invoiceNumber: r.invoiceNumber,
        lines: r.lines.map(ReceiptLineViewModel.fromApi).toList(),
        subtotal: r.subtotal,
        taxAmount: r.taxAmount,
        discountAmount: r.discountAmount,
        total: r.total,
      );
}
```

## Exercise

`ReceiptViewModel.fromReceiptResponse` and `.fromCart` both end up setting
`paidAmount`/`changeAmount`. Look at `receipt_view_model.dart:282-283`
(`fromCart`) — its `paidAmount`/`changeAmount` are plain required
parameters, computed by the *caller* (`ReceiptPreviewScreen._buildViewModel`),
not derived inside the factory. Why is that the right call here, given what
you know about `_chargeCash()` capping the applied amount at the total (from
the earlier payment-flow fix)? What would go wrong if `fromCart` tried to
compute `changeAmount` itself from `subtotal`/`total` alone?

---

# Lesson 3 — The 58mm PDF

## Concept

A thermal receipt printer's paper isn't a "page size" in the way A4 is — it's
a **fixed width, unbounded length** roll. `PrinterPaperSize.pdfPageFormat`
(`printer_pdf_format.dart`) encodes exactly that:

```dart
const PdfPageFormat _mm58Format = PdfPageFormat(
  57 * PdfPageFormat.mm,     // width — fixed
  double.infinity,           // height — the page just grows as content needs
  marginLeft: 4.5 * PdfPageFormat.mm,
  marginRight: 4.5 * PdfPageFormat.mm,
  marginTop: 5 * PdfPageFormat.mm,
  marginBottom: 5 * PdfPageFormat.mm,
);
```

Two numbers worth understanding, not memorizing:

- **57mm, not 58mm.** "58mm paper" is nominal — the actual roll width is
  commonly ~57mm. Getting this from `pdf`'s own `roll57` constant (rather
  than typing `58`) is the kind of detail that only comes from testing
  against real hardware.
- **4.5mm margins are not arbitrary** — they're derived from the *other*
  printing path (raw ESC/POS), not chosen independently. The comment in the
  file explains why:

```dart
/// - "58mm" stock: printable width 384 dots ÷ 8 dots/mm = 48mm →
///   4.5mm margin each side.
```

This is the important idea: **the PDF path's margins are computed backward
from the ESC/POS path's dot width**, so a receipt printed via PDF/driver and
one printed via raw thermal bytes have the *same usable content width* —
57mm page − 9mm margins = 48mm content, matching 384 dots ÷ 8 dots/mm
exactly. If you picked PDF margins independently of the ESC/POS geometry,
the two outputs would silently drift apart (text wrapping differently, items
fitting on one path and not the other).

### Typography for 58mm

`receipt_layout_spec.dart` defines a **named type scale**, not raw numbers
scattered through the PDF builder:

```dart
static const mm58 = ReceiptTypography(
  businessTitle: 16,   // mm80 is 22
  itemName: 8,          // mm80 is 9
  totalValue: 13,        // mm80 is 16
  // ...
);
```

The file's own comment states the design rule explicitly: mm58 is "a
deliberately-chosen compact scale (~70%), never below 7pt — Khmer's stacked
marks need more room than Latin at the same size." That floor (7pt) is a
real constraint discovered from testing Khmer rendering, not a guess.

## Exercise

Given `_mm58Format`'s printable width is 48mm and the typography's
`itemName` is 8pt — if you were adding a new "Discount %" column to the
line-item row, what two things would you have to check before deciding it
fits, and where in this project would you find the numbers to check them
against? *(Hint: one is in `printer_pdf_format.dart`, the other is the
column-width numbers actually used inside `PrintService`'s line-item row
builder — not covered yet, coming in Lesson 5.)*

---

# Lesson 4 — The 80mm PDF (and why it's "the same code")

## Concept

There is no separate `buildReceiptPdf80mm` function. `PrintService.buildReceiptPdf`
takes `paperSize` as a parameter and asks two extension getters for
everything width/typography-related:

```dart
final t = paperSize.receiptTypography;      // receipt_layout_spec.dart
// ...
doc.addPage(pw.Page(
  pageFormat: paperSize.pdfPageFormat,       // printer_pdf_format.dart
  build: (context) => _receiptPageContent(r, paperSize),
));
```

This is the payoff of Lesson 3's design: **80mm isn't a different code
path, it's a different value flowing through the same code path.** The
`ReceiptTypography.mm80` constant is literally the on-screen preview's own
sizes (per the file's own comment: "mm80 values ARE the on-screen sizes"),
while mm58 is derived from it. If you ever add a third paper size, you
extend the same two lookup tables — you never touch `buildReceiptPdf`
itself.

**The lesson here isn't about 80mm specifically — it's about eliminating a
whole category of bug (mm58 and mm80 outputs silently diverging) by
construction:** there's no *place* for them to diverge, because there's only
one PDF-building function, parameterized by paper size, not two
independently-maintained ones.

## Exercise

Suppose a printer manufacturer ships a 112mm-wide industrial kitchen-order
printer. List, in order, every file from Lessons 3–4 you'd touch to add
support for it, and what you'd add to each — without writing any code, just
the plan. *(This is deliberately the same exercise shape as a real feature
request you'll eventually get.)*

---

# Lesson 5 — PrintService.buildReceiptPdf, Section by Section

## Concept

`print_service.dart`'s `buildReceiptPdf` (and its sibling `buildReceiptsPdf`
for batches, Lesson 8) build a `pw.Document` — `package:pdf`'s equivalent of
a `Document` object you keep adding pages to. One receipt is one `pw.Page`;
inside it, everything is `pw.Column`/`pw.Row`/`pw.Text`, the same mental
model as Flutter's own `Column`/`Row`/`Text`, but for a completely different
rendering target (PDF drawing commands, not pixels on a device).

Walking the real structure, section by section (`_receiptPageContent`):

```dart
pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,   // ① full page width
  children: [
    // ── Header ── business name, address, phone — centered
    // ── Invoice metadata ── Invoice No. / Date / Time / Cashier — label:value rows
    // ── Items header ── "Item / Qty / Total" column titles
    // ── Line items ── one row per ReceiptLineViewModel
    // ── Totals ── Subtotal, then receipt.adjustments (Lesson 2), then Total
    // ── Payment ── Paid, Cash Received + Change (only if changeAmount > 0)
    // ── Exchange rate ── only if showExchangeRate
    // ── Footer ── thank-you line, website, "Powered by"
  ],
)
```

**① `crossAxisAlignment: stretch`** is why every row spans the full receipt
width instead of shrink-wrapping its content — a deliberate choice so
dividers and label:value rows line up visually.

### Why these specific widgets

- **`pw.Column`** — vertical stack, one per receipt "section." Chosen over
  manually positioning things because receipt height is unbounded (it grows
  with item count) — a column just keeps adding height, no math required.
- **`pw.Row` + `pw.Expanded`** — every label:value line
  (`_metadataRow`, `_summaryRow`, `_itemRow`'s name/qty/price) is a `Row`
  where the label/name is wrapped in `pw.Expanded` and the value has a fixed
  `pw.SizedBox(width: ...)`. This is the PDF equivalent of "grow to fill,
  except this one column which is a fixed width" — exactly the same reason
  you'd reach for `Expanded` in a normal Flutter layout: the item name can be
  any length, but the price column needs to stay aligned.
- **`_clipped()` (a small wrapper around `pw.Text`)** — sets
  `overflow: pw.TextOverflow.clip` instead of `package:pdf`'s default
  (`visible`). The reason is Khmer-specific and worth remembering: `pdf`
  only knows how to wrap text on whitespace, but Khmer is traditionally
  written without spaces between words — an unbroken long Khmer name has no
  internal wrap point, so without an explicit clip it would render past the
  receipt's content width instead of staying inside it.
- **Margins** come from `paperSize.pdfPageFormat` (Lesson 3), never
  hardcoded per-section — one more place `buildReceiptPdf` stays paper-size
  agnostic.

### Font embedding — one call, used everywhere

```dart
final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());
```

Every PDF document in this app — receipt, A4 report, even the developer test
screen — gets its font theme from this single function. That's Lesson 2's
principle applied to fonts: one place decides "how do we draw text," every
consumer just uses it. Full Khmer mechanics are Lesson 6.

## Exercise

`_summaryRow('Paid', r.fmt(r.paidAmount), t, bold: true)` — no `if` guard,
it always renders. But `_summaryRow('Change', ...)` is wrapped in
`if (r.changeAmount > 0)`. Given what `paidAmount` means in this codebase
(Lesson-adjacent: "amount applied," from the payment-flow work earlier),
explain in one sentence why "Paid" never needs a zero-guard but "Change"
does.

---

# Lesson 6 — Bluetooth/ESC-POS and the Khmer Bitmap Strategy

## Concept: what ESC/POS actually is

PDF is a *document format* — a whole page description language with fonts,
vector graphics, and a renderer (the OS, a PDF viewer) that interprets it.
**ESC/POS is a *command protocol*** — a stream of raw bytes where certain
byte sequences mean "start bold," "cut the paper," "print this raster
image." There is no document, no pages — just a printer executing commands
as it reads them, like a very old-school terminal. That's the fundamental
reason it's a different code path entirely, not just "PDF but smaller."

### containsKhmer: the decision point

```dart
// escpos_receipt_builder.dart:37-42
if (receipt.containsKhmer) {
  final image = await bitmapRenderer.render(context, receipt, paperSize);
  bytes += generator.imageRaster(image, align: PosAlign.center);
} else {
  bytes += _buildLatinText(generator, receipt);
}
```

Two completely different strategies, chosen once per receipt:

- **Pure Latin → native ESC/POS text commands** (`_buildLatinText`) — fast,
  small byte count, the printer's own firmware renders the characters.
- **Any Khmer present → render the WHOLE receipt to a bitmap image, then
  send that as a raster image command** (`generator.imageRaster`).

### Why not just send Khmer Unicode bytes to the printer?

The class doc says it directly:

```dart
/// Reliability strategy: thermal printer firmware support for Khmer is
/// inconsistent, so mixing native ESC/POS text commands with per-line font
/// switches is fragile. Instead: pure-Latin receipts print as fast native
/// ESC/POS text; any receipt containing Khmer prints as a single rasterized
/// bitmap of the whole receipt — one simple, reliable rule instead of a
/// hybrid per-glyph fallback.
```

Unpacked: a thermal printer's Khmer support (if it has any at all) lives in
its firmware's built-in code page tables — different printer brands, even
different firmware versions of the *same* brand, implement this differently
or not at all. Trying to detect and switch code pages per character is
fragile and brand-specific. **Rendering to a bitmap sidesteps the printer's
font support entirely** — the printer doesn't need to know what Khmer is,
it's just printing a picture. `ReceiptBitmapRenderer` does this by actually
mounting a real (off-screen) Flutter widget tree and using
`RenderRepaintBoundary.toImage()` — i.e., it reuses **Flutter's own text
shaping engine** (which already correctly handles Khmer glyph selection,
reordering, and stacking) instead of reimplementing font rendering:

```dart
/// The trick: build the receipt as an ordinary Flutter widget tree (using
/// the bundled NotoSansKhmer font), mount it off-screen via a real
/// OverlayEntry positioned far outside the viewport, and rasterize it with
/// RenderRepaintBoundary.toImage. Because it's a real, attached widget
/// subtree, Flutter's own text shaping engine does the hard part.
```

This is why this is "safer across printer brands": the printer's Khmer
support quality becomes irrelevant. Trade-off: it's slower (rendering a
widget tree + rasterizing takes real time) and the output is a fixed-size
image, not selectable/searchable text — an acceptable trade for a printed
paper receipt.

### The five Khmer problems, mapped to this project's actual fixes

| Problem | Where it showed up here | Fix |
|---|---|---|
| Missing font | Using `NotoSansKhmer` as the *only* PDF font | `khmer_pdf_font.dart` uses NotoSans as primary, Khmer only as `fontFallback` |
| Missing glyph | The bundled `NotoSansKhmer-*.ttf` is a Khmer-only subset — zero Latin coverage | Verified by direct cmap-table inspection (see the file's own comment), not assumed |
| Incorrect fallback direction | Khmer font as primary broke every plain-English receipt | Swapped: Latin primary, Khmer fallback-only |
| Complex Khmer shaping | Raw ESC/POS text can't shape stacked Khmer marks at all | Bitmap rendering via real Flutter text layout (`ReceiptBitmapRenderer`) |
| Printer firmware inconsistency | Different thermal printer brands support Khmer differently or not at all | Bitmap sidesteps firmware font support entirely |

### Direct thermal printing, traced

```
ThermalPrinterService.printReceipt(context, receipt, config)
        │
        ▼
  _transportFor(config)  →  BluetoothPrinterTransport / UsbPrinterTransport / NetworkPrinterTransport
        │
        ▼
  transport.connect()
        │
        ▼
  EscPosReceiptBuilder.build(context, receipt, paperSize)  →  List<int> bytes
        │  (reset → text-or-bitmap → feed(2) → cut)
        ▼
  transport.write(bytes)
        │
        ▼
  transport.disconnect()   (in a `finally` — always runs, even on error)
```

`PrinterTransport` (`printer_transport.dart`) is a tiny interface — probably
under 15 lines — with exactly `connect()`, `write(bytes)`, `disconnect()`.
Three implementations (`bluetooth_`, `usb_`, `network_printer_transport.dart`)
satisfy it. **`ThermalPrinterService`, `EscPosReceiptBuilder`, and
`ReceiptViewModel` never import any of the three transport files** — they
only know the interface. This is Lesson 5 from Part 3 (the swappable seam)
made concrete: adding a fourth transport later means writing one new file
implementing `PrinterTransport`, and touching nothing else.

## Exercise

If a receipt has a Khmer customer name but every product name, cashier name,
and footer are plain English, does `containsKhmer` return true or false?
Look at `receipt_view_model.dart:122-128` (`_allText`) to answer precisely,
then explain why checking the *whole* receipt's text (rather than per-line)
is the right granularity given how `imageRaster` works (one image for the
*entire* receipt, not per-line).

---

# Lesson 7 — Print One (in ReceiptsScreen)

## Concept

Trace what happens when a cashier taps the print icon on one row in the
Receipts list:

```
row tap → sale.id
    │
    ▼
SaleService.getReceipt(sale.id)     ← fetch FULL detail first, separately
    │  (its own try/catch → distinct "Unable to load receipt" message)
    ▼
PrintService.printReceipt(context, sale.id)
    │  (fetches AGAIN internally, builds ReceiptViewModel, resolves
    │   PrinterConfig, dispatches PDF vs thermal — all in one reusable call)
    ▼
printed / thrown → caught → "Unable to print receipt" message
```

### Summary row vs. full detail — the concept that matters here

The Receipts list is populated from `SaleResponse` — confirmed by direct
inspection earlier this session to contain only: id, invoiceNumber, status,
grandTotal, paidAmount, customerName, cashierName, createdAt, currency,
payments. **No line items, no tax/discount/delivery breakdown.** That's a
deliberate, reasonable choice — a list of 50 receipts shouldn't each carry
their full itemized detail over the wire just to render a summary row.

But that means **the row you tap is never enough data to print from.**
Printing needs the full `ReceiptResponse` (Lesson 1) — hence the fetch
before printing. This is a completely general pattern worth naming:

> **A list/summary model exists to make the *list* cheap. A detail/document
> model exists to make *one item, fully*, correct. Never assume the summary
> model secretly has everything — check, the way this project's `SaleResponse`
> genuinely doesn't.**

### Why the double-fetch, instead of reusing one call

Looking at the real code: `_printOne` fetches `getReceipt(sale.id)` once
(to produce a load-specific error message if it fails), then calls
`PrintService.printReceipt(context, sale.id)`, which fetches `/receipt`
*again* internally. That's a deliberate trade-off recorded in this
project's own history: it costs one extra small GET request, in exchange for
not having to touch `PrintService.printReceipt`'s existing contract (used
elsewhere, e.g. the auto-print-after-payment call) just to get a more
specific error message in one call site. **Not every inefficiency is a bug —
this one was a conscious "reuse existing, proven code over introducing a new
method with a slightly different contract" decision.**

## Exercise

If you were designing this from scratch and DID want to avoid the double
fetch, what would you change about `PrintService.printReceipt`'s return type
(currently `Future<bool>`) to let a caller distinguish "failed to load" from
"failed to print," without needing a second, separate fetch? Sketch the
type, don't implement it.

---

# Lesson 8 — Print All

## Concept

Print All has to solve a harder problem than Print One: get full detail for
*N* receipts, without doing anything foolish like firing 64 simultaneous
HTTP requests or blocking the UI for a minute.

### Step by step, matching the real implementation (`receipts_screen.dart`)

```
1. sales = state.filteredSales     ← already the FULL filtered set (Lesson 15)
2. confirm dialog: "Print all N receipts?"
3. ids = {for (s in sales) s.id}.toList()   ← dedupe by id, defensively
4. mapBounded(ids, fetchDetailFn, concurrency: 5, onProgress: ...)
       → List<ReceiptViewModel>, failures collected separately
5. if PDF/driver:  buildReceiptsPdf(viewModels, paperSize)  → ONE PDF, N pages
   if thermal:     ThermalPrinterService.printReceipts(...)  → ONE connection, N receipts
6. summary snackbar: "Printed X of N receipts." (+ failure count if any)
```

### mapBounded — the concurrency-cap pattern

The naive version (`Future.wait(ids.map(fetchDetail))`) fires *every* request
at once. For 5 receipts that's fine; for 64 it can overwhelm the backend or
the device's own connection pool, and if one request is slow, you have no
visibility into partial progress. `mapBounded` (`bounded_concurrency.dart`)
solves this with a classic **worker pool**:

```dart
Future<void> worker() async {
  while (isCancelled?.call() != true) {
    final i = nextIndex;
    if (i >= items.length) return;      // no more work — this worker exits
    nextIndex++;                         // claim the next item
    try {
      results[i] = BoundedResult.ok(items[i], await fn(items[i]));
    } catch (e) {
      results[i] = BoundedResult.failed(items[i], e);   // isolated — doesn't stop the others
    }
    onProgress?.call(++done, items.length);
  }
}
final workerCount = concurrency.clamp(1, items.length);
await Future.wait(List.generate(workerCount, (_) => worker()));
```

**Walk through 64 receipts, concurrency = 5, by hand:**

```
Start: 5 workers spawned, each grabs the next unclaimed index.

worker 1 → item 0     worker 2 → item 1     worker 3 → item 2
worker 4 → item 3      worker 5 → item 4

worker 1 finishes item 0 first → immediately grabs item 5 (not "wait for round 2")
worker 3 is slow on item 2 → keeps working on it while others race ahead

...this continues until index reaches 64. At most 5 requests are ever
in flight at once, but no worker sits idle waiting for a "batch" to finish —
whichever worker finishes first immediately claims the next unclaimed item.
```

This is the key property that makes it better than naive batching (fetch 5,
wait for ALL 5, fetch next 5, ...): a naive batch-of-5 approach wastes time
whenever one item in a batch is slow — the other 4 workers sit idle waiting
for it. The worker-pool pattern above keeps all 5 slots continuously busy
until there's truly no work left.

### Why a per-item failure doesn't kill the batch

`BoundedResult.failed(items[i], e)` is stored, not thrown further up. One bad
receipt (network hiccup, malformed data) becomes one entry in a failure list
— the other 63 still print. This is the same "isolate failure at the
boundary" idea from Lesson 4's summary (`receipt_image_decoder.dart`),
applied to a batch instead of a single field.

### PDF batch vs. thermal batch — different reasons for "one job"

- **PDF**: `buildReceiptsPdf` builds ONE `pw.Document` with N `pw.Page`s (one
  per receipt), then ONE `Printing.layoutPdf` call. Without this, N separate
  PDF jobs would mean N separate OS print dialogs popping up — unusable.
- **Thermal**: `ThermalPrinterService.printReceipts` connects **once**, loops
  writing each receipt's bytes (each already ends in its own `feed`+`cut`),
  disconnects once. Reconnecting per receipt is genuinely expensive for
  Bluetooth specifically — the connection handshake (pairing/socket
  negotiation) can take a meaningful fraction of a second, which multiplied
  by 64 receipts becomes a real, user-visible delay, not just "less
  efficient" in the abstract.

## Exercise

`mapBounded`'s `concurrency` parameter defaults to `5`. If you were printing
via Bluetooth (not fetching HTTP data), would you reuse `mapBounded` for
"connect once, write N times"? Why or why not — think about what
`mapBounded` fundamentally assumes about the units of work it's
parallelizing.

---

# Lesson 9 — A4 Invoice: Frontend and Backend, Two Real Systems

## Concept

This is the one area where "invoice" genuinely means two different pipelines
in this codebase — worth being precise about, since it's easy to conflate
them.

### There is no separate backend "Invoice" entity

Verified fresh this session: no `Invoice.java` domain entity exists for
sales. `Sale` is the one entity. `SaleService.generateStandardInvoiceHtml()`
picks the *title* at render time based on payment status:

```java
boolean saleReceipt = paid.compareTo(BigDecimal.ZERO) > 0
                       && paid.compareTo(total) >= 0;
String documentTitle = saleReceipt ? "SALE RECEIPT" : "INVOICE";
```

Fully paid → prints "SALE RECEIPT". Still owing → prints "INVOICE". Same
method, same entity, same PDF pipeline — just a different heading and,
implicitly, a different real-world meaning (a receipt proves payment
happened; an invoice requests payment). If you're designing a mobile app
from scratch, this is worth deciding deliberately: do you want one document
type with a computed title (this project's choice), or genuinely separate
document types? Both are valid; know which one you're building.

### Two independent PDF systems, on purpose

| | Frontend (`package:pdf`) | Backend (`PdfService.java`) |
|---|---|---|
| Input | `ReceiptViewModel` (typed Dart object) | HTML string |
| Library | `package:pdf` — pure-Dart PDF widget tree | OpenHTMLtoPDF (verified via `pom.xml`) — HTML/CSS → PDF |
| Used for | Receipts (58/80mm), A4 reports | `/invoice.pdf` (A4), estimates, the one Z-report PDF |
| Trigger | User taps Print in the app | `GET /invoice.pdf`, or emailing |
| Khmer font | `assets/fonts/NotoSansKhmer-*.ttf` (Flutter bundle) | `src/main/resources/fonts/NotoSansKhmer-*.ttf` (JVM classpath) — a **separate copy** |

### Why frontend and backend can safely coexist without sharing code

They render *different documents for different purposes* — the frontend
system is for what a cashier prints immediately, at the register, on
receipt-sized paper, needing to work offline-tolerant and match exactly what
was previewed on screen. The backend system is for on-demand A4
document downloads and email attachments, triggered from anywhere with
network access, where HTML+CSS is a faster way to lay out a full A4 page
with a company letterhead than hand-building `pw.Row`/`pw.Column` trees.
Neither one needs to know the other exists.

**Why they should NOT share font files or runtime assumptions**, even though
both need Khmer support: they run in genuinely different runtimes (Dart/
Flutter vs. JVM) with different font-loading APIs
(`pw.Font.ttf(await rootBundle.load(...))` vs. OpenHTMLtoPDF's
`builder.useFont(File, ...)`, which specifically needs a `File`, not a
stream — that's *why* the backend copies its classpath font to a JVM temp
file, per `PdfService.java`'s own logic). A shared font *file* (literally the
same `.ttf` bytes shipped to both) is fine and arguably good practice; a
shared font *loading mechanism* is impossible across these two runtimes, and
trying to force one would be fighting the platform for no benefit.

### Email invoice: same PDF code, different destination

```
POST /api/pos/sales/{id}/email
        │
        ▼
SaleController.emailInvoice
        │
        ▼
saleService.invoicePdf(id, thermal=false)   ← SAME method the download endpoint calls
        │
        ▼
byte[] pdfBytes
        │
        ▼
EmailService.sendReceipt(..., pdfBytes)     ← attaches, sends via Spring Mail/SMTP
```

Verified: there is no separate "build a PDF for email" code path. The
lesson: **once you have a function that reliably produces `byte[]` bytes,
"download it" and "email it as an attachment" are two thin, separate
consumers of the same output — don't duplicate the generation logic for each
destination.**

## Exercise

If you wanted to add a "Print" button on the frontend for the backend-
generated A4 invoice (not the frontend's own receipt PDF), what would the
frontend need to do differently compared to `print_service.dart`'s current
`buildReceiptPdf` → `Printing.layoutPdf` flow? *(Hint: think about where the
PDF bytes originate — locally built vs. fetched from an HTTP endpoint — and
what that changes about error handling.)*

---

# Lesson 10 — The A4 Report

## Concept

`A4ReportPdf.build()` (`lib/core/services/printing/a4_report_pdf.dart`) is a
**generic** report PDF builder — it takes columns/rows/summary as plain
data, with zero knowledge of "sales" or "inventory." Every report screen
(Sales Summary, Sales by Item, etc.) calls the same function with different
data.

### Traced

```
report screen filters (date range, cashier, ...)
        │
        ▼
ReportService — fetchAllPages()  (Lesson 15 — walks EVERY backend page,
        │                          not just what's on screen)
        ▼
report rows (plain List<List<String>> after formatting)
        │
        ▼
A4ReportPdf.build(columns, rows, summary, landscape: bool)
        │
        ▼
pw.MultiPage(pageFormat: A4 or A4.landscape, header: ..., footer: ..., 
             build: (context) => [pw.TableHelper.fromTextArray(...), summaryBlock])
        │
        ▼
Printing.layoutPdf(...)
```

### Why `pw.MultiPage`, not `pw.Page`

A receipt (Lesson 5) uses `pw.Page` — one page, unbounded height, because
receipt "paper" is a roll. A report is the opposite: **fixed page size (A4),
unbounded row count.** `pw.MultiPage` is `package:pdf`'s tool for exactly
that — give it content that might not fit on one page, and it automatically
flows the overflow onto additional pages, repeating the `header:`/`footer:`
widget on every page it creates. That's how you get:

- **Repeated table headers** — `pw.TableHelper.fromTextArray`'s header row,
  used as a flowing top-level widget inside `MultiPage.build`, repeats
  automatically on every new page it spills onto.
- **Page numbers** — the `footer:` callback receives a `context` with
  `context.pageNumber` / `context.pagesCount`, so "Page 3 / 8" is computed
  by the library, not hand-tracked.
- **Portrait vs. landscape** — one parameter:
  `pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4`.
  Nothing else in the builder changes; the table just gets more/less
  horizontal room.

### Summary placement

The summary block (grand totals) is just the *last* widget in the `build:`
list, after the table. `MultiPage` doesn't treat it specially — if the table
fills the last page exactly, the summary naturally flows onto a fresh page
rather than overlapping. This is a case where doing *nothing* special was
the correct design — trying to hand-place "summary always on the last page
no matter what" would fight the library's own flowing layout for no benefit.

### Why report printing must not reuse receipt paper settings

`printer_pdf_format.dart`'s own header comment states this as a rule:

```dart
/// A4 report printing (see a4_report_pdf.dart) does NOT import this file
/// and has no reference to [PrinterPaperSize] — A4 page geometry is fixed
/// and must never be influenced by the receipt printer's configured paper
/// size.
```

The reasoning: a store's receipt printer might be configured for 58mm or
80mm roll paper — that setting is about a *different physical device* than
whatever prints an A4 report (often a regular office printer, or the same
thermal printer in a completely different mode most stores don't even use
for reports). Coupling them means changing your receipt paper width could
silently corrupt your report layout, for no functional reason — they're
unrelated settings that happen to live in the same Settings screen.

## Exercise

If a report has zero rows matching the filter, does `A4ReportPdf.build`
crash, produce a blank page, or something else? Reason through it from what
you now know about `pw.MultiPage` and `pw.TableHelper.fromTextArray` — you
don't need to open the file to answer this one.

---

# Bonus — Pagination vs. Printing (the bug, generalized)

## The bug we had

A report screen loaded 20 rows at a time (on-screen pagination) but showed a
count of 64 total matching rows. The **Print** button used to print only
what was currently loaded in `state` — 20 rows — while the visible summary
said 64. The PDF silently under-reported.

## The concept

Two genuinely different questions look similar but aren't:

- **"What should the screen render right now?"** — answer: whatever's
  cheap and fits the viewport. Pagination/lazy-loading exists to answer
  *this* question efficiently.
- **"What should Print/Export produce?"** — answer: everything matching the
  active filter, full stop. The user's mental model of "print this report"
  does not include "...but only the part I happened to have scrolled to."

## The reusable rule

> **Never let a print/export/batch action read directly from the same state
> variable a paginated UI list reads from.** Give it its own fetch path that
> walks pages until there are none left (`fetchAllPages`/`mapBounded` in this
> project), driven by the *same filters* as the screen, but not by the
> *same loaded subset*. If the UI list and the print/export path share one
> variable, you will eventually print exactly what's on screen instead of
> what's real — and it will look correct in casual testing (small datasets
> fit on one page, so the bug is invisible until real data volume hits it).

Note this project's Receipts screen turned out to have **no pagination bug
at all** — its `SaleService.listSales`/`getActiveShiftSales` endpoints are
fully unbounded (confirmed by direct inspection), so `state.filteredSales`
already *is* every matching row. The lesson isn't "always add a fetch-all
step" — it's "verify whether your data source is actually paginated before
assuming you need one." Adding an unnecessary page-walking loop where the
backend already returns everything would be needless complexity.

---

# Bonus — Payment/Total Flow: the Authoritative Total

## Concept

Trace one example end to end:

```
Subtotal = 10.00
Discount = 2.00
Tax      = 0.80
Delivery = 1.00
Total    = 9.80
```

```
① Cart (client, provisional)
   CartState.taxAmount = (subtotal - itemDiscounts) * taxRate
   CartState.finalTotal = subtotal - discount - loyalty + tax
        │  sent as: taxRate, invoiceDiscount, line items — NOT a pre-computed total
        ▼
② Backend (authoritative, final)
   SaleService.createSale():
     taxable   = subtotal - invoiceDiscount
     taxAmount = taxable * taxRate
     grandTotal = taxable + taxAmount + deliveryCharge + otherCharge
        │  persisted on the Sale row — this is now THE number
        ▼
③ ReceiptResponse (fetched back)
   subtotal=10.00, discountAmount=2.00, taxAmount=0.80,
   deliveryCharge=1.00, total=9.80
        │
        ▼
④ ReceiptViewModel.fromReceiptResponse
   same numbers, copied field-for-field — total is NEVER recomputed here
        │
        ▼
⑤ Every renderer (preview/PDF/ESC-POS)
   displays receipt.total directly; adjustments list is built FROM the
   already-known discountAmount/taxAmount/deliveryCharge, purely for
   display ordering — none of it feeds back into computing Total
```

## Where calculations SHOULD happen

**Exactly once, at step ②, server-side, at the moment a sale is finalized.**
Everything before that (①) is a *preview* — allowed to be provisional,
allowed to be slightly wrong for a frame while the cashier is still adding
items. Everything after (③④⑤) is *display* — required to be exactly right,
because money has already changed hands.

## Why the PDF must not independently calculate tax

Two reasons, one practical and one architectural:

- **Practical**: if `print_service.dart` computed
  `tax = subtotal * someRate`, it would need to know the tax rate that was
  *actually applied to this specific sale* — which can change over time in
  Settings. Get that wrong and old receipts silently start showing a
  different tax than what the customer actually paid.
- **Architectural**: this is Lesson 5's "authoritative total" concept —
  once step ② has computed and persisted the real number, every downstream
  consumer's only correct job is to *display* it unchanged. A PDF builder
  that recomputes anything is really a second, competing implementation of
  business logic that now has to be kept in sync with the backend forever.
  This project's own `ReceiptViewModel` docs this explicitly:

```dart
/// [Total] itself still comes straight from [total], never derived from
/// this list.
```

That one sentence is worth remembering as a design rule on its own.

---

# Bonus — Code Organization, and a Proposal for Mobile

## Why this project separates `models/` / `services/` / `printing/` / `screens/` / `widgets/`

| Folder | What lives there | Why separate |
|---|---|---|
| `models/` | Typed API shapes (`ReceiptResponse`) | Changes only when the backend contract changes |
| `services/` | HTTP calls, business orchestration (`SaleService`, `PrintService`) | Changes when *behavior* changes, independent of UI |
| `services/printing/` | The entire print pipeline (view model, layout spec, transports, ESC/POS) | Big enough, cohesive enough, and reused by enough different screens (preview, reprint, batch) to deserve its own namespace *inside* services |
| `screens/` | Full-page widgets tied to a route | Changes when navigation/page structure changes |
| `widgets/` | Reusable, smaller UI pieces (`ReceiptPreviewScreen` is arguably screen-sized but lives here — a minor inconsistency worth noting, not copying) | Changes when visual presentation changes |

**What worked well**: the `printing/` sub-namespace. Every file in it has one
clear job (transport, one builder, one config model), and nothing outside
`printing/` reaches into its internals except through `PrintService` and
`ThermalPrinterService` — those two are the public API of the whole
subsystem.

**What worked less well, worth avoiding in a fresh project**:
`ReceiptPreviewScreen` living in `widgets/` while functioning as a full
navigable screen (it has its own `Scaffold`+`AppBar`, pushed via
`Navigator.push`) is a minor folder-placement inconsistency. Not a real bug,
just a reminder that "screens/" vs "widgets/" needs a clear rule (e.g. "has
its own Scaffold+AppBar → screens/, regardless of who navigates to it")
decided up front, or it drifts.

## A proposal for a fresh Flutter mobile POS

```
features/pos/
  models/
    sale_response.dart
    receipt_response.dart
  services/
    sale_service.dart          ← HTTP: createSale, paySale, getReceipt
    print_service.dart         ← picks PDF vs thermal, owns buildReceiptPdf
    printing/
      receipt_view_model.dart
      receipt_layout_spec.dart
      printer_profile.dart     ← PrinterConfig, PaperSize, TransportType
      printer_pdf_format.dart
      khmer_pdf_font.dart      ← or your own script's font strategy
      thermal_printer_service.dart
      escpos_receipt_builder.dart
      receipt_bitmap_renderer.dart
      transports/
        printer_transport.dart      ← interface
        bluetooth_printer_transport.dart
        usb_printer_transport.dart
        network_printer_transport.dart
  screens/
    payment_screen.dart
    receipts_screen.dart
    receipt_preview_screen.dart      ← moved here, it's a screen
```

This is your existing project's structure, essentially unchanged — because
it's already a good structure. The only real change: put
`receipt_preview_screen.dart` under `screens/` instead of `widgets/`, and
put the transport implementations in their own `transports/` folder since
mobile will likely add more of them (Lesson 18, next).

---

# Bonus — Debugging Flow

A troubleshooting decision tree, in the order to actually check things:

```
Wrong total?
  → inspect payment/domain data (backend Sale computation, or what was
    sent in the create-sale request) — NOT the receipt/PDF code

Correct total on screen but wrong on the printed receipt?
  → inspect ReceiptViewModel construction (which factory, which source
    data) — the PDF/ESC-POS template is very unlikely to be the bug,
    since both renderers share one model

PDF looks correct in preview but physical print is wrong (cut off,
wrong scale, wrong paper)?
  → inspect the printer driver / OS paper settings — Flutter cannot
    control this (Lesson 9's PDF/driver boundary)

Boxes/tofu characters instead of Khmer?
  → font/glyph coverage issue — check which font is primary vs fallback
    (khmer_pdf_font.dart) and verify with an actual cmap inspection,
    don't assume a font "has" a language just because it's named for one

Khmer letters present but visually jumbled/wrong order?
  → shaping issue, not a font issue — on the ESC/POS path this means the
    bitmap-rendering fallback isn't being used (check `containsKhmer`
    detection); on the PDF path check whether text is going through a
    renderer that does NOT do complex script shaping

Print All missing some receipts?
  → data-fetching/filter/pagination issue — check whether the source list
    is genuinely unbounded or secretly paginated (Bonus: Pagination vs
    Printing), and check mapBounded's failure list, not the batch PDF code

"Unable to guess the image type" / decode crash?
  → invalid image bytes reaching a decoder with no validation — check the
    boundary where a raw string/bytes becomes an image object, not the
    printing template around it
```

The one-sentence version of all of the above: **figure out which of the 8
layers (Part 1's table) the wrong data or wrong behavior first appears in,
then look only at that layer and the one immediately before it.** Every bug
this project actually had lived at a boundary between two layers, not deep
inside a single one — so once you've localized "it's correct going into
layer N, wrong coming out," you've found the bug's home.
