import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/providers/language_provider.dart';
import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/services/print_service.dart';
import 'package:frontend_flutter_mobile/features/pos/services/printing/printer_profile.dart';
import 'package:frontend_flutter_mobile/features/pos/services/printing/receipt_view_model.dart';

/// `PrintService.buildReceiptPdf` doesn't need a real `ApiService`/`Ref`
/// (only `printReceipt` does) — capturing a `Ref` from a throwaway
/// provider read is the simplest way to construct one outside a widget
/// tree.
PrintService _service() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  late Ref capturedRef;
  final dummy = Provider<void>((ref) => capturedRef = ref);
  container.read(dummy);
  return PrintService(ApiService(), capturedRef);
}

const _englishReceipt = ReceiptViewModel(
  language: AppLanguage.en,
  businessName: 'Acme Cafe',
  invoiceNumber: 'INV-0001',
  date: '01/01/2026',
  time: '12:00:00',
  lines: [
    ReceiptLineViewModel(name: 'Coffee', qty: 2, unitPrice: 2.5, lineTotal: 5),
  ],
  subtotal: 5,
  taxAmount: 0.5,
  total: 5.5,
  paidAmount: 5.5,
  footer: 'Thank you!',
  currencyCode: 'USD',
);

const _khmerReceipt = ReceiptViewModel(
  language: AppLanguage.km,
  businessName: 'ហាងកាហ្វេ',
  invoiceNumber: 'INV-0002',
  date: '01/01/2026',
  time: '12:00:00',
  lines: [
    ReceiptLineViewModel(
      name: 'កាហ្វេ',
      qty: 1,
      unitPrice: 2.5,
      lineTotal: 2.5,
    ),
  ],
  subtotal: 2.5,
  total: 2.5,
  paidAmount: 2.5,
  footer: 'អរគុណ!',
  currencyCode: 'USD',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrintService.buildReceiptPdf', () {
    test('produces non-empty, valid-looking PDF bytes for an English '
        'receipt', () async {
      final bytes = await _service().buildReceiptPdf(
        _englishReceipt,
        PrinterPaperSize.mm80,
      );
      expect(bytes, isNotEmpty);
      // Every PDF file starts with this magic header.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('a Khmer receipt still renders — via the font-fallback pw.Text '
        'path (the bitmap path is Day 14 scope, see this class\'s doc '
        'comment) — rather than failing to produce a PDF at all', () async {
      final bytes = await _service().buildReceiptPdf(
        _khmerReceipt,
        PrinterPaperSize.mm80,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('both mm58 and mm80 paper sizes produce a valid PDF (page-format '
        'selection itself is covered by printer_profile_test.dart\'s '
        'pdfPageFormat test)', () async {
      final mm58Bytes = await _service().buildReceiptPdf(
        _englishReceipt,
        PrinterPaperSize.mm58,
      );
      final mm80Bytes = await _service().buildReceiptPdf(
        _englishReceipt,
        PrinterPaperSize.mm80,
      );
      expect(String.fromCharCodes(mm58Bytes.take(5)), '%PDF-');
      expect(String.fromCharCodes(mm80Bytes.take(5)), '%PDF-');
    });

    test('an empty cart (no lines) still produces a PDF rather than '
        'crashing', () async {
      const empty = ReceiptViewModel(
        language: AppLanguage.en,
        businessName: 'Acme',
        invoiceNumber: 'INV-0003',
        date: '',
        time: '',
        lines: [],
        subtotal: 0,
        total: 0,
        footer: 'Thanks',
      );
      final bytes = await _service().buildReceiptPdf(
        empty,
        PrinterPaperSize.mm80,
      );
      expect(bytes, isNotEmpty);
    });
  });
}
