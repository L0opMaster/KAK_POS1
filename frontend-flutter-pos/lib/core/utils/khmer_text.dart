/// Whether [text] contains any Khmer-script character.
///
/// Single source of truth for "does this string need Khmer-safe rendering"
/// — used by [ReceiptViewModel.containsKhmer] (decides thermal
/// text-vs-bitmap and PDF text-vs-bitmap for receipts) and
/// [KhmerTextRasterizer] (decides per-cell text-vs-bitmap for A4 reports),
/// so both never drift into checking Khmer presence two different ways.
final RegExp _khmerPattern = RegExp(r'[ក-៿]');

bool containsKhmerText(String text) => _khmerPattern.hasMatch(text);
