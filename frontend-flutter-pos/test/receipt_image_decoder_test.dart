// Regression test for the "Unable to guess the image type 474 bytes"
// crash: PrintService's QR embedding used to do
// `Uint8List.fromList(r.qrImageData!.codeUnits)` — treating the receipt's
// `data:image/png;base64,<...>` string as if its characters WERE the raw
// image bytes, instead of base64-decoding it. package:pdf's format sniffer
// correctly rejected the resulting garbage. ReceiptImageDecoder.decode is
// the fix: strip a data-URI prefix if present, base64-decode, then verify
// the result actually starts with a recognized image signature before
// anything downstream (pw.MemoryImage / Image.memory) ever sees it.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_image_decoder.dart';

/// The smallest possible valid PNG: a 1x1 transparent pixel (67 bytes).
/// Used as a real, fully-decodable image fixture — not just a signature —
/// so tests can also prove a valid image survives end to end.
const _tinyPngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
];

void main() {
  group('ReceiptImageDecoder.decode — accepts real images', () {
    test('bare base64 PNG (no data: prefix) -> decoded bytes returned', () {
      final b64 = base64Encode(_tinyPngBytes);
      final decoded = ReceiptImageDecoder.decode(b64, label: 't');
      expect(decoded, isNotNull);
      expect(decoded, _tinyPngBytes);
    });

    test('data:image/png;base64,<...> URI -> prefix stripped, decoded', () {
      final b64 = base64Encode(_tinyPngBytes);
      final dataUri = 'data:image/png;base64,$b64';
      final decoded = ReceiptImageDecoder.decode(dataUri, label: 't');
      expect(decoded, isNotNull);
      expect(decoded, _tinyPngBytes,
          reason: 'the exact reported bug: a data URI must be stripped, '
              'not treated as raw bytes');
    });

    test('JPEG signature (FF D8 FF) -> accepted', () {
      final jpegish = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 1, 2, 3, 4];
      final decoded =
          ReceiptImageDecoder.decode(base64Encode(jpegish), label: 't');
      expect(decoded, isNotNull);
    });
  });

  group(
      'ReceiptImageDecoder.decode — rejects everything else, never '
      'throws', () {
    test('null -> null', () {
      expect(ReceiptImageDecoder.decode(null, label: 't'), isNull);
    });

    test('empty string -> null', () {
      expect(ReceiptImageDecoder.decode('', label: 't'), isNull);
    });

    test('HTML error page bytes -> null, not passed through', () {
      const html = '<!DOCTYPE html><html><body>404</body></html>';
      final decoded = ReceiptImageDecoder.decode(
          base64Encode(utf8.encode(html)),
          label: 't');
      expect(decoded, isNull);
    });

    test('JSON error body bytes -> null, not passed through', () {
      const json = '{"error":"not found","status":404}';
      final decoded = ReceiptImageDecoder.decode(
          base64Encode(utf8.encode(json)),
          label: 't');
      expect(decoded, isNull);
    });

    test('invalid base64 characters -> null, does not throw', () {
      expect(
          () =>
              ReceiptImageDecoder.decode('not-@@@-valid-base64!!!', label: 't'),
          returnsNormally);
      expect(ReceiptImageDecoder.decode('not-@@@-valid-base64!!!', label: 't'),
          isNull);
    });

    test(
        'the exact reported bug scenario: a data-URI string reinterpreted '
        'as raw code units (the old, broken behavior) is NOT what reaches '
        'the decoder — decode() only ever receives the original string and '
        'safely rejects garbage without throwing', () {
      // Simulates what the OLD buggy code effectively handed to
      // pw.MemoryImage: the *codeUnits* of a real data URI, base64-encoded
      // as if it were legitimate image data (so it still parses as valid
      // base64 — the bug was never in the base64 layer, it was in never
      // decoding at all). This must not match any image signature.
      final b64 = base64Encode(utf8.encode('data:image/png;base64,iVBORw0K'));
      final decoded = ReceiptImageDecoder.decode(b64, label: 't');
      expect(decoded, isNull);
    });

    test('corrupt/truncated payload shorter than any signature -> null', () {
      final decoded =
          ReceiptImageDecoder.decode(base64Encode([1, 2]), label: 't');
      expect(decoded, isNull);
    });
  });
}
