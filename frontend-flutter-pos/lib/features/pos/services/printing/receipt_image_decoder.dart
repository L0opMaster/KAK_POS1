import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Decodes an inline receipt image field (currently just `qrImageData` —
/// the backend generates a fresh per-sale QR PNG on every `/receipt` fetch,
/// see `SaleService.buildQrImageData` server-side) into validated raster
/// bytes, safe to hand to `pw.MemoryImage` or `Image.memory`.
///
/// Handles two things every call site got wrong before this existed:
///  1. The backend sends a `data:image/png;base64,<data>` URI, not bare
///     base64 — this strips that prefix before decoding, instead of
///     base64-decoding (or worse, `.codeUnits`-ing) the whole string
///     including the non-base64 `data:image/png;base64,` header.
///  2. It verifies the decoded bytes actually start with a recognized
///     raster image signature (PNG/JPEG/GIF/WebP) before returning them —
///     an HTML error page, a JSON error body, an empty string, or a
///     truncated/corrupt payload all fail this check and return null
///     instead of reaching an image decoder that will throw.
///
/// A QR/logo is decorative, not part of the receipt's financial record —
/// [decode] never throws; a bad image is logged once and skipped so it
/// can't take down an otherwise-good receipt (or, worse, an entire
/// "Print All" batch) over a missing picture.
class ReceiptImageDecoder {
  ReceiptImageDecoder._();

  /// Returns the decoded, signature-validated image bytes for [raw], or
  /// null if [raw] is empty, isn't valid base64, or doesn't decode to a
  /// recognized image format. [label] is only used in the debug log line
  /// (e.g. the invoice number) to make a real failure easy to trace.
  static Uint8List? decode(String? raw, {required String label}) {
    if (raw == null || raw.isEmpty) return null;

    final commaIndex = raw.indexOf(',');
    final base64Part = raw.startsWith('data:') && commaIndex != -1
        ? raw.substring(commaIndex + 1)
        : raw;

    final Uint8List bytes;
    try {
      bytes = base64Decode(base64Part);
    } catch (e) {
      debugPrint('[ReceiptImage] $label: not valid base64 '
          '(${base64Part.length} chars) — $e');
      return null;
    }

    if (!_hasKnownImageSignature(bytes)) {
      final header = bytes
          .take(16)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      debugPrint('[ReceiptImage] $label: ${bytes.length} decoded bytes do '
          'not match a known image signature (header: $header) — skipping');
      return null;
    }
    return bytes;
  }

  /// PNG/JPEG/GIF/WebP magic-byte sniffing — deliberately not
  /// filename-extension or Content-Type based (neither is available or
  /// trustworthy for an inline base64 field), per the same signatures
  /// every image format documents for its own header.
  static bool _hasKnownImageSignature(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // GIF: "GIF8"
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }
    // WebP: "RIFF"...."WEBP"
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }
}
