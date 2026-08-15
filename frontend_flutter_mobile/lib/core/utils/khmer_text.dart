/// Ported from `frontend-flutter-pos/lib/core/utils/khmer_text.dart` —
/// COPY/ADAPT NEARLY EXACTLY. Single source of truth for "does this string
/// need Khmer-safe rendering" — used by `ReceiptViewModel.containsKhmer`.
/// Day 14's bitmap/ESC-POS Khmer rendering pipeline (not built yet) will
/// read from the same function once it exists, rather than checking Khmer
/// presence a second, different way.
final RegExp _khmerPattern = RegExp(r'[ក-៿]');

bool containsKhmerText(String text) => _khmerPattern.hasMatch(text);
