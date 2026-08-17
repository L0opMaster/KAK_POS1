// Developer-only print regression screen (debug builds only). Exercises the
// real printing pipelines — PrintService.buildReceiptPdf (PDF/driver
// receipts), ThermalPrinterService (raw ESC/POS), A4ReportPdf (reports) —
// with synthetic English/Khmer/mixed data, so paper-size and Khmer-glyph
// regressions can be caught without a real sale or a real printer.
//
// Ported from `frontend-flutter-pos/lib/features/pos/screens/
// print_test_screen.dart` — COPY/ADAPT NEARLY EXACTLY, same test actions/
// layout, import paths adapted to this port's file locations. Nothing on
// this screen prints automatically; every job is a manual button press.
//
// Only ever reachable via the `if (kDebugMode)` gated entry point in
// `mobile_printer_settings_screen.dart`; the `if (!kDebugMode)` guard in
// [build] below is a defensive second layer, not the primary gate.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../pos/services/print_service.dart';
import '../../pos/services/printing/khmer_pdf_font.dart';
import '../../pos/services/printing/printer_pdf_format.dart';
import '../../pos/services/printing/printer_profile.dart';
import '../../pos/services/printing/receipt_bitmap_renderer.dart';
import '../../pos/services/printing/receipt_view_model.dart';
import '../../pos/services/printing/thermal_printer_service.dart';

enum _ReceiptContent { english, khmer, mixed }

class MobilePrintTestScreen extends ConsumerStatefulWidget {
  const MobilePrintTestScreen({super.key});

  @override
  ConsumerState<MobilePrintTestScreen> createState() =>
      _MobilePrintTestScreenState();
}

class _MobilePrintTestScreenState
    extends ConsumerState<MobilePrintTestScreen> {
  String _log = '';
  bool _busy = false;
  PrinterConfig? _config;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await ref.read(thermalPrinterServiceProvider).loadConfig();
    if (mounted) setState(() => _config = config);
  }

  void _appendLog(String line) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() => _log = '[$stamp] $line\n$_log');
    debugPrint('[PrintTest] $line');
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    _appendLog('$label — starting');
    final stopwatch = Stopwatch()..start();
    try {
      await action();
      _appendLog('$label — done (${stopwatch.elapsedMilliseconds}ms)');
    } catch (e, st) {
      _appendLog('$label — FAILED: $e');
      debugPrint('$st');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Receipt fixtures ──────────────────────────────────────────────────

  ReceiptViewModel _receiptFixture({
    required _ReceiptContent content,
    required int itemCount,
    bool includeLongName = false,
  }) {
    final lines = <ReceiptLineViewModel>[];
    for (var i = 0; i < itemCount; i++) {
      final n = i + 1;
      final String name;
      switch (content) {
        case _ReceiptContent.english:
          name = 'Iced Coffee #$n';
        case _ReceiptContent.khmer:
          name = 'ទឹកក្រឡុកកាហ្វេទឹកកក #$n';
        case _ReceiptContent.mixed:
          name = 'Smoothie ទឹកក្រឡុក #$n';
      }
      final qty = (n % 3) + 1;
      final unitPrice = 1.25 + (n % 5) * 0.75;
      lines.add(ReceiptLineViewModel(
        name: name,
        qty: qty.toDouble(),
        unitPrice: unitPrice,
        lineTotal: unitPrice * qty,
      ));
    }
    if (includeLongName) {
      lines.add(const ReceiptLineViewModel(
        name:
            'Extra Large Iced Blended Caramel Smoothie ភេសជ្ជៈកាហ្វេទឹកកកមួយធុងធំបំផុត',
        qty: 1,
        unitPrice: 4.5,
        lineTotal: 4.5,
      ));
    }
    final subtotal = lines.fold(0.0, (s, l) => s + l.lineTotal);
    const taxRate = 0.10;
    final tax = subtotal * taxRate;
    final total = subtotal + tax;

    return ReceiptViewModel(
      language:
          content == _ReceiptContent.khmer ? AppLanguage.km : AppLanguage.en,
      businessName: 'KAKNNEA POS System',
      address: 'Phnom Penh, Cambodia',
      phone: '+855 23 123 456',
      invoiceNumber: 'TEST-${itemCount.toString().padLeft(3, '0')}',
      date: '2026-08-17',
      time: '14:30:00',
      cashierName: 'Test Cashier',
      lines: lines,
      subtotal: subtotal,
      taxAmount: tax,
      total: total,
      paidAmount: total,
      currencyCode: 'KHR',
      exchangeRateKhr: 4100,
      footer: 'Thank you for your purchase! អរគុណ',
    );
  }

  Future<Uint8List> _buildReceiptBytes(
    PrinterPaperSize paperSize,
    _ReceiptContent content, {
    int itemCount = 12,
    bool longName = false,
  }) async {
    final receipt = _receiptFixture(
      content: content,
      itemCount: itemCount,
      includeLongName: longName,
    );
    final bytes = await ref
        .read(printServiceProvider)
        .buildReceiptPdf(receipt, paperSize, context: context);
    _appendLog('  page: ${paperSize.name}, PDF bytes: ${bytes.length}, '
        'width: ${(paperSize.pdfPageFormat.width / PdfPageFormat.mm).toStringAsFixed(1)}mm, '
        'content width: ${(paperSize.pdfPageFormat.availableWidth / PdfPageFormat.mm).toStringAsFixed(1)}mm, '
        'containsKhmer: ${receipt.containsKhmer}');
    return bytes;
  }

  Future<void> _printReceipt(
    String label,
    PrinterPaperSize paperSize,
    _ReceiptContent content, {
    int itemCount = 12,
    bool longName = false,
  }) {
    return _run(label, () async {
      final bytes = await _buildReceiptBytes(paperSize, content,
          itemCount: itemCount, longName: longName);
      await Printing.layoutPdf(onLayout: (_) => bytes, name: label);
    });
  }

  /// Downloads the PDF directly (`Printing.sharePdf`) instead of opening the
  /// OS print/share dialog (`Printing.layoutPdf`). Lets you inspect the
  /// generated file's actual page size/content directly — e.g. in a PDF
  /// viewer that reports page dimensions — with zero involvement from a
  /// printer driver.
  Future<void> _saveReceiptPdf(
    String label,
    PrinterPaperSize paperSize,
    _ReceiptContent content,
  ) {
    return _run('Save PDF — $label', () async {
      final bytes = await _buildReceiptBytes(paperSize, content);
      await Printing.sharePdf(bytes: bytes, filename: '$label.pdf');
    });
  }

  /// Dumps the exact pre-PDF Khmer raster [ReceiptBitmapRenderer] produces
  /// — i.e. the same [img.Image] `PrintService`'s Khmer PDF path embeds —
  /// so it can be inspected directly against the on-screen preview and the
  /// final PDF page: if this raster already looks wrong, the bug is in
  /// [ReceiptBitmapRenderer]; if this looks right but the final PDF doesn't,
  /// the bug is in PDF embedding. Wrapping it in a throwaway 1:1 single-
  /// image PDF is only so this reuses the same `Printing.sharePdf` download
  /// path as every other debug export on this screen — this PNG encode is a
  /// debug-only diagnostic, not a change to the production path.
  Future<void> _saveRawRaster(
    String label,
    PrinterPaperSize paperSize,
    _ReceiptContent content,
  ) {
    return _run('Save raw raster — $label', () async {
      final receipt = _receiptFixture(content: content, itemCount: 12);
      final image = await const ReceiptBitmapRenderer()
          .renderImage(context, receipt, paperSize);
      _appendLog('  raster: ${image.width}x${image.height}px '
          '(paper: ${paperSize.name}, dotWidth: ${paperSize.dotWidth})');
      final doc = pw.Document();
      final pngBytes = img.encodePng(image);
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(
            image.width.toDouble(), image.height.toDouble(),
            marginAll: 0),
        build: (_) => pw.Image(pw.MemoryImage(pngBytes)),
      ));
      await Printing.sharePdf(
          bytes: await doc.save(), filename: '${label}_raster.pdf');
    });
  }

  // ── Direct thermal test ──────────────────────────────────────────────

  Future<void> _printThermalTest() {
    return _run('Direct thermal test print', () async {
      final config = _config;
      if (config == null ||
          config.transportType == PrinterTransportType.pdfDriver) {
        throw StateError(
            'Configured transport is not a direct thermal transport '
            '(Settings → Printers → Connection type)');
      }
      final receipt = _receiptFixture(
        content: _ReceiptContent.mixed,
        itemCount: 5,
      );
      await ref
          .read(thermalPrinterServiceProvider)
          .printReceipt(context, receipt, config);
    });
  }

  // ── A4 fixtures ────────────────────────────────────────────────────────

  Future<Uint8List> _buildA4Bytes({
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
    bool landscape = false,
  }) async {
    final bytes = await A4ReportPdf.build(
      title: title,
      subtitle: 'Developer print test — ${rows.length} rows',
      businessName: 'KAKNNEA POS System',
      businessAddress: 'Phnom Penh, Cambodia',
      businessPhone: '+855 23 123 456',
      columns: columns,
      rows: rows,
      columnAlignments: {2: pw.Alignment.centerRight},
      summary: [MapEntry('Rows', '${rows.length}')],
      generatedAt: DateTime.now(),
      generatedLabel: 'Generated',
      pageLabel: 'Page',
      landscape: landscape,
    );
    _appendLog('  PDF bytes: ${bytes.length}, landscape: $landscape');
    return bytes;
  }

  Future<void> _printA4({
    required String label,
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
    bool landscape = false,
  }) {
    return _run(label, () async {
      final bytes = await _buildA4Bytes(
          title: title, columns: columns, rows: rows, landscape: landscape);
      await Printing.layoutPdf(onLayout: (_) => bytes, name: label);
    });
  }

  Future<void> _saveA4Pdf(String label, String title, List<String> columns,
      List<List<String>> rows) {
    return _run('Save PDF — $label', () async {
      final bytes =
          await _buildA4Bytes(title: title, columns: columns, rows: rows);
      await Printing.sharePdf(bytes: bytes, filename: '$label.pdf');
    });
  }

  List<List<String>> _a4Rows(int count,
      {bool khmer = false, bool mixed = false}) {
    return List.generate(count, (i) {
      final n = i + 1;
      final name = mixed
          ? 'Product ផលិតផល #$n'
          : khmer
              ? 'ផលិតផលលេខ #$n'
              : 'Product #$n';
      return [
        name,
        'SKU-$n',
        '${(n % 20) + 1}',
        formatAmount(n * 1.5, readCurrency(ref)),
      ];
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
            child:
                Text('Print test screen is only available in debug builds.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Print Test Suite')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _debugInfoCard(),
          const SizedBox(height: 16),
          _sectionHeader('Receipt PDF tests (PDF/driver transport)'),
          _buttonGrid([
            _TestButton(
                '58mm English',
                () => _printReceipt('58mm English', PrinterPaperSize.mm58,
                    _ReceiptContent.english)),
            _TestButton(
                '58mm Khmer',
                () => _printReceipt('58mm Khmer', PrinterPaperSize.mm58,
                    _ReceiptContent.khmer)),
            _TestButton(
                '58mm Mixed',
                () => _printReceipt('58mm Mixed', PrinterPaperSize.mm58,
                    _ReceiptContent.mixed)),
            _TestButton(
                '80mm English',
                () => _printReceipt('80mm English', PrinterPaperSize.mm80,
                    _ReceiptContent.english)),
            _TestButton(
                '80mm Khmer',
                () => _printReceipt('80mm Khmer', PrinterPaperSize.mm80,
                    _ReceiptContent.khmer)),
            _TestButton(
                '80mm Mixed',
                () => _printReceipt('80mm Mixed', PrinterPaperSize.mm80,
                    _ReceiptContent.mixed)),
            _TestButton(
                '58mm Long Receipt (50+)',
                () => _printReceipt('58mm Long Receipt', PrinterPaperSize.mm58,
                    _ReceiptContent.mixed,
                    itemCount: 55, longName: true)),
            _TestButton(
                '80mm Long Receipt (50+)',
                () => _printReceipt('80mm Long Receipt', PrinterPaperSize.mm80,
                    _ReceiptContent.mixed,
                    itemCount: 55, longName: true)),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Direct thermal test (Bluetooth/USB/Network)'),
          Text(
            _config == null
                ? 'Loading configured printer…'
                : _config!.transportType == PrinterTransportType.pdfDriver
                    ? 'Configured transport is PDF/Driver — switch Settings → '
                        'Printers → Connection type to Bluetooth/USB/Network to '
                        'enable this test.'
                    : 'Configured transport: ${_config!.transportType.name}, '
                        'paper: ${_config!.paperSize.name}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          _buttonGrid([
            _TestButton(
              'Send direct thermal test print',
              _printThermalTest,
              enabled: _config != null &&
                  _config!.transportType != PrinterTransportType.pdfDriver,
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('A4 report tests'),
          _buttonGrid([
            _TestButton(
                'A4 Portrait (English)',
                () => _printA4(
                    label: 'a4_portrait_en',
                    title: 'Inventory Report',
                    columns: const ['Product', 'SKU', 'Qty', 'Value'],
                    rows: _a4Rows(10))),
            _TestButton(
                'A4 Landscape',
                () => _printA4(
                    label: 'a4_landscape',
                    title: 'Inventory Report (Landscape)',
                    columns: const ['Product', 'SKU', 'Qty', 'Value'],
                    rows: _a4Rows(10),
                    landscape: true)),
            _TestButton(
                'A4 Khmer',
                () => _printA4(
                    label: 'a4_khmer',
                    title: 'របាយការណ៍ស្តុក',
                    columns: const ['ផលិតផល', 'SKU', 'ចំនួន', 'តម្លៃ'],
                    rows: _a4Rows(10, khmer: true))),
            _TestButton(
                'A4 Mixed',
                () => _printA4(
                    label: 'a4_mixed',
                    title: 'Inventory Report ស្តុក',
                    columns: const ['Product ផលិតផល', 'SKU', 'Qty', 'Value'],
                    rows: _a4Rows(10, mixed: true))),
            _TestButton(
                'A4 Multi-page (80 rows)',
                () => _printA4(
                    label: 'a4_multipage',
                    title: 'Inventory Report — Multi-page',
                    columns: const ['Product', 'SKU', 'Qty', 'Value'],
                    rows: _a4Rows(80))),
          ]),
          const SizedBox(height: 24),
          _sectionHeader(
              'Save PDF (isolate PDF generation from printer drivers)'),
          const Text(
            'Downloads the raw PDF instead of opening the print/share dialog. '
            'Open it in a PDF viewer that reports page size to confirm this '
            'app generated the correct physical dimensions — independently '
            'of whichever printer/driver you print to.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buttonGrid([
            _TestButton(
                'Save 58mm receipt PDF',
                () => _saveReceiptPdf('receipt_58mm', PrinterPaperSize.mm58,
                    _ReceiptContent.mixed)),
            _TestButton(
                'Save 80mm receipt PDF',
                () => _saveReceiptPdf('receipt_80mm', PrinterPaperSize.mm80,
                    _ReceiptContent.mixed)),
            _TestButton(
                'Save A4 report PDF',
                () => _saveA4Pdf(
                    'a4_report',
                    'Inventory Report',
                    const ['Product', 'SKU', 'Qty', 'Value'],
                    _a4Rows(10, mixed: true))),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Save raw Khmer raster (preview/raster/PDF parity)'),
          const Text(
            'Downloads the exact pre-PDF bitmap ReceiptBitmapRenderer '
            'produces for a Khmer receipt (wrapped 1:1 in a throwaway PDF '
            'page purely so it can be downloaded/opened). Compare it '
            'against the on-screen preview and "Save Khmer receipt PDF" '
            'above — if this raster already looks wrong, the bug is in '
            'ReceiptBitmapRenderer/ReceiptContent; if this looks right but '
            'the final PDF above doesn\'t, the bug is in PDF embedding.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buttonGrid([
            _TestButton(
                'Save 58mm Khmer raster',
                () => _saveRawRaster('khmer_58mm', PrinterPaperSize.mm58,
                    _ReceiptContent.khmer)),
            _TestButton(
                'Save 80mm Khmer raster',
                () => _saveRawRaster('khmer_80mm', PrinterPaperSize.mm80,
                    _ReceiptContent.khmer)),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Log'),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 320),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _log.isEmpty ? 'No test runs yet.' : _log,
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );

  Widget _buttonGrid(List<_TestButton> buttons) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons
          .map((b) => OutlinedButton(
                onPressed: (_busy || !b.enabled) ? null : b.onPressed,
                child: Text(b.label),
              ))
          .toList(),
    );
  }

  Widget _debugInfoCard() {
    final config = _config;
    // Sanity-check ReceiptViewModel.containsKhmer itself, independent of
    // whichever test button (if any) has been pressed — always visible.
    final khmerSample =
        _receiptFixture(content: _ReceiptContent.khmer, itemCount: 1);
    final englishSample =
        _receiptFixture(content: _ReceiptContent.english, itemCount: 1);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Print diagnostics',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _infoRow(
                'Transport type', config?.transportType.name ?? 'loading…'),
            _infoRow('Configured receipt paper',
                config?.paperSize.name ?? 'loading…'),
            _infoRow(
                'Platform',
                kIsWeb
                    ? 'Web (${defaultTargetPlatform.name})'
                    : defaultTargetPlatform.name),
            _infoRow(
                'Currency symbol (live)', currencySymbol(watchCurrency(ref))),
            FutureBuilder<pw.ThemeData>(
              future: KhmerPdfFont.loadTheme(),
              builder: (context, snapshot) {
                final status = snapshot.connectionState != ConnectionState.done
                    ? 'loading…'
                    : snapshot.hasError
                        ? 'FAILED: ${snapshot.error}'
                        : 'loaded ok';
                return _infoRow('Khmer font', status);
              },
            ),
            _infoRow('containsKhmer — Khmer sample (expect true)',
                '${khmerSample.containsKhmer}'),
            _infoRow('containsKhmer — English sample (expect false)',
                '${englishSample.containsKhmer}'),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _paperFormatTable(),
          ],
        ),
      ),
    );
  }

  Widget _paperFormatTable() {
    Widget headerCell(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        );
    Widget cell(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text, style: const TextStyle(fontSize: 11)),
        );
    TableRow row(PrinterPaperSize size) {
      final format = size.pdfPageFormat;
      final widthMm = format.width / PdfPageFormat.mm;
      final marginMm = format.marginLeft / PdfPageFormat.mm;
      final contentMm = format.availableWidth / PdfPageFormat.mm;
      return TableRow(children: [
        cell(size.name),
        cell('${widthMm.toStringAsFixed(1)}mm'),
        cell('${marginMm.toStringAsFixed(1)}mm'),
        cell('${contentMm.toStringAsFixed(1)}mm'),
        cell('${size.dotWidth} dots'),
      ]);
    }

    // FlexColumnWidth (not a fixed-px Table) so this reflows within
    // whatever width the phone screen gives it instead of forcing a
    // horizontal scroll.
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(1.3),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.3),
        4: FlexColumnWidth(1.2),
      },
      border: TableBorder.all(color: Colors.black12, width: 0.5),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [
            headerCell('Paper'),
            headerCell('Width'),
            headerCell('Margin'),
            headerCell('Content'),
            headerCell('Raster'),
          ],
        ),
        row(PrinterPaperSize.mm58),
        row(PrinterPaperSize.mm80),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}

class _TestButton {
  const _TestButton(this.label, this.onPressed, {this.enabled = true});
  final String label;
  final Future<void> Function() onPressed;
  final bool enabled;
}
