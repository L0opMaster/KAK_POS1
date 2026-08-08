# Printing setup

How receipt and report printing work in this app, what the app controls
versus what Chrome/Windows/the printer driver controls, and how to test and
diagnose printing problems on a new machine.

## Architecture

Two independent PDF pipelines, both using `package:pdf` (a pure-Dart PDF
builder — no HTML, no CSS, no `window.print()`, no `dart:html`) plus
`package:printing` to hand the finished PDF to the OS print dialog:

```
Receipt (thermal, 58mm/80mm)          Report/Inventory (A4)
  ReceiptViewModel                      table data (columns/rows)
        |                                       |
        v                                       v
  PrintService.buildReceiptPdf            A4ReportPdf.build
  (or receipt_preview_screen's                  |
   lightweight post-sale fallback)              |
        |                                       |
        +-------------------+-------------------+
                            |
                 pageFormat: PdfPageFormat
                 (roll57/roll80-shaped for
                  receipts, A4/A4.landscape
                  for reports — NEVER shared)
                            |
                            v
                  Printing.layoutPdf(...)
                            |
                            v
              Chrome print dialog (Flutter Web)
             / OS print dialog (desktop/mobile)
```

A third path exists only for receipts: if the configured printer transport
is Bluetooth/USB/Network (not "PDF/Driver"), `ThermalPrinterService` builds
raw ESC/POS bytes and writes them straight to the printer — Chrome's print
dialog is never involved for that path.

**Why not print the live Flutter page / use CSS `@media print`?** This app's
`web/index.html` has no printable DOM — the whole UI paints into a
canvas/WebGL surface via the Flutter engine. There is nothing for a CSS
print stylesheet to select. Every "print" action in this codebase builds a
real, self-contained PDF file in Dart first, then hands that file (not the
live page) to the browser/OS print system. This sidesteps the entire class
of "Flutter widget doesn't respond to `@page`/`@media print`" problems.

## Receipt paper size — single source of truth

`lib/features/pos/services/printing/printer_pdf_format.dart` is the *only*
place that maps `PrinterPaperSize` (`mm58`/`mm80`, Settings → Printers) to a
`PdfPageFormat`. Both receipt-PDF builders read it:

- `PrintService.buildReceiptPdf` (full itemized receipt — actual reprints)
- `receipt_preview_screen.dart`'s `_buildSimplePdf` (lightweight immediate
  post-sale preview/print, before the backend receipt has loaded)

Neither hardcodes a page format anymore. If you need to change receipt page
geometry, change it in `printer_pdf_format.dart` — never inline in a print
call site — so preview and actual print can never drift apart again.

### Exact dimensions

| Paper | Page width | Page height | Margins (L/R) | Content width | Matches ESC/POS |
|---|---|---|---|---|---|
| `mm58` | 57mm | auto (roll) | 4.5mm each | **48mm** | 384 dots ÷ 8 dots/mm = 48mm |
| `mm80` | 80mm | auto (roll) | 4mm each | **72mm** | 576 dots ÷ 8 dots/mm = 72mm |

Top/bottom margin is 5mm on both (paper feed, unrelated to head width).

These are **not** `package:pdf`'s built-in `PdfPageFormat.roll57`/`roll80`
constants — those default to a flat 5mm margin on every side (48mm/70mm
content width). We deliberately derive the *left/right* margins from this
app's own ESC/POS dot widths instead, so a receipt printed via the
PDF/driver transport and the same receipt printed via direct thermal use
the same usable content width — not two subtly different ones. There is no
double margin: `pw.Page`/`pw.MultiPage` only apply an explicit `margin:` if
you pass one, and neither receipt builder does — they let the page format's
own margins apply, which is the only margin source in play.

A4 reports (`lib/core/services/printing/a4_report_pdf.dart`) never import
`printer_pdf_format.dart` and have no reference to `PrinterPaperSize` at
all — `PdfPageFormat.a4` / `PdfPageFormat.a4.landscape` are used directly
and unconditionally. Changing the receipt paper size in Settings has zero
effect on report output, and cannot.

### Responsive receipt layout

58mm's ~48mm content width is meaningfully narrower than 80mm's ~72mm, so
`PrintService.buildReceiptPdf` uses a smaller font-size scale for `mm58`
(business name 15pt vs 20pt, line items 9pt vs 13pt, grand total 12pt vs
16pt, etc. — see `_ReceiptTextSizes` in `print_service.dart`) rather than
shrinking the 80mm layout proportionally, which would make item names and
totals unreadable. Column layout (item name / qty×price / line total) is
unchanged between the two — only the font scale and the page's own content
width change.

## Khmer Unicode

Khmer text is never left to the browser, OS, or printer to render — the
glyphs are drawn (PDF) or rasterized (thermal) by this app before the job
ever reaches a printer:

- **PDF paths** — `KhmerPdfFont.loadTheme()` (shared by both PDF builders)
  loads `assets/fonts/NotoSansKhmer-Regular.ttf`/`-Bold.ttf` and embeds them
  directly into the generated PDF via `pw.ThemeData.withFont`. The glyph
  outlines live inside the PDF file itself — nothing about print time (which
  Windows machine, which printer, whether Khmer fonts are installed
  anywhere) matters once the PDF exists.
- **Direct thermal (raw ESC/POS)** — `EscPosReceiptBuilder` checks
  `ReceiptViewModel.containsKhmer`. Pure-Latin receipts print as fast native
  ESC/POS text (works with any printer's built-in font). Any receipt
  containing Khmer is instead rendered as a single bitmap image by
  `ReceiptBitmapRenderer` (a real off-screen Flutter widget using
  `fontFamilyFallback: ['NotoSansKhmer']`, i.e. the exact same font asset)
  and sent via `generator.imageRaster(...)`. The thermal printer's firmware
  never needs to understand Khmer at all.

**Historical bug, already fixed in this codebase:** the bundled
`NotoSansKhmer-*.ttf` files were at one point not actually Khmer fonts (a
21KB file with only 209 Latin-range codepoints and zero glyphs in the Khmer
Unicode block, despite the correct filename) — this produced missing-glyph
boxes for any Khmer text, independent of any of the printing code. They
have been replaced with genuine Noto Sans Khmer fonts (verified via direct
`cmap` table inspection: 114 Khmer-block glyphs including U+17DB, the Riel
sign, in both weights). If Khmer boxes ever reappear, check the font asset
first (Print Test Suite's "Khmer font" debug row) before suspecting the
print pipeline.

## Windows client setup

**What this app controls:** the generated PDF's page dimensions
(58mm/80mm/A4/A4-landscape), receipt/report content and layout, font
embedding, Khmer glyph rendering. All of this is identical on Ubuntu and
Windows — it's pure Dart, computed before anything reaches Chrome or a
printer driver.

**What Chrome/Windows controls:** which printer is selected, that printer's
driver, what paper is physically loaded, the driver's configured default
paper size, and (for some drivers) print scaling/margins.

**What the printer hardware controls:** actual printable area, cutter
behavior, DPI, firmware quirks.

The app can build a perfectly-sized 80mm PDF and Chrome will still let the
selected printer's driver scale or crop it onto whatever paper size that
driver is configured for. **This is a real, unavoidable OS/driver-level
constraint — no web technology can silently override a Windows printer
driver's paper configuration.** The driver must be told about the roll
paper once, per machine:

### Thermal printer (80mm)

1. Install the printer manufacturer's Windows driver.
2. Open **Devices and Printers → (the printer) → Printing Preferences**.
3. Choose a **Receipt / Roll / 80mm** paper size if the driver lists one.
   If not, create a **custom paper size** (~80mm × continuous/long, e.g.
   80mm × 297mm as a practical continuous-feed stand-in).
4. Do **not** leave it on A4/Letter.
5. When printing, use **Actual size / 100%** rather than "Fit to page" —
   fit-to-page will scale the correctly-sized PDF up to whatever paper the
   driver thinks is loaded.
6. Minimize driver-level margins where the driver exposes that option (the
   PDF's own margins are already tuned — see the table above).

### Thermal printer (58mm)

Same steps, using a 58mm (or the driver's nearest, e.g. 57mm/50mm) roll/receipt
paper size.

### A4 printer (reports)

Select the printer's normal A4 paper size; portrait or landscape is chosen
automatically by the report code (`A4ReportPdf.build(..., landscape: true)`)
based on which report button is used, not by the driver.

### "Save as PDF" first

To separate *this app's* PDF geometry from a specific driver's behavior:
Chrome's print dialog → **Destination: Save as PDF** → open the saved file.
If the saved PDF is the right physical width (58mm/80mm/A4), the app is
correct and any remaining problem is the physical printer's driver
configuration — not this codebase.

## Testing

### Ubuntu (development)

1. `flutter run -d chrome` and log in.
2. Settings → Printers → set Connection type to **PDF / Driver printer**,
   set paper size, Save.
3. Settings → Printers → **Print test suite** (debug builds only) → run the
   58mm/80mm × English/Khmer/Mixed buttons and the long-receipt buttons.
4. In Chrome's print dialog, **Destination: Save as PDF**, open the file,
   and check:
   - 58mm PDF is ~57mm wide, 80mm PDF is ~80mm wide (not A4).
   - Khmer glyphs render (no boxes) in the Khmer/Mixed tests.
   - The A4 report buttons produce true A4 pages, portrait and landscape.
5. Check the debug info panel on the test screen for the computed PDF
   widths/margins and "Khmer font: loaded ok".

### Windows (client)

1. Same app, same login, on the target Windows machine + Chrome.
2. Configure the printer driver first (see above).
3. Settings → Printers → Print test suite → run the same buttons.
4. Test both **Save as PDF** (isolates app correctness) and an **actual
   physical print** (isolates driver/paper configuration).
5. Checklist:
   - [ ] Chrome print dialog opens and shows the correct printer
   - [ ] 58mm thermal: physical printout width matches 58mm stock, no
         clipping, no huge blank margins
   - [ ] 80mm thermal: same, for 80mm stock
   - [ ] A4 printer: normal A4 printout, correct portrait/landscape
   - [ ] Khmer receipt: no missing-glyph boxes
   - [ ] Mixed English/Khmer receipt: no missing-glyph boxes, correct
         alignment
   - [ ] Direct thermal (Bluetooth/USB/Network, if applicable): test print
         from the test screen produces correct output without going through
         Chrome's print dialog at all

## Known limitations (not fixable from this codebase)

- Windows printer drivers, not this app, own the physical paper-size
  default. A correctly-sized PDF can still be scaled/cropped by a driver
  configured for A4/Letter — the driver must be configured once per
  machine (see above).
- Some thermal printer drivers apply their own minimum margins regardless
  of what the PDF requests; if printouts are clipped despite a correctly
  sized PDF, check the driver's margin settings.
- Different printer brands/models vary in printable width even within
  "58mm"/"80mm" nominal paper — the dimensions in this document match this
  app's own ESC/POS dot-width assumptions (384/576 dots), which are typical
  but not universal. If a specific model's printable area differs, adjust
  `printer_pdf_format.dart`'s margins (single source of truth — this is the
  only file that should change).
