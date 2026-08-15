/// Ported from `frontend-flutter-pos/lib/core/utils/money.dart` —
/// COPY/ADAPT NEARLY EXACTLY (byte-identical logic, no platform
/// dependency).
///
/// Money math helpers that work in integer *minor units* (e.g. cents) to
/// avoid floating-point rounding errors when summing carts and applying
/// discounts.
class Money {
  const Money._();

  static const int scale = 100;

  static int toMinor(final double major) => (major * scale).round();

  static double toMajor(final int minor) => minor / scale;

  static int lineTotalMinor(final double unitPrice, final int qty) =>
      toMinor(unitPrice) * qty;

  static int percentOfMinor(final int minor, final double percent) =>
      (minor * percent / 100).round();
}
