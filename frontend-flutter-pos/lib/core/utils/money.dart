/// Money math helpers that work in integer *minor units* (e.g. cents) to avoid
/// floating-point rounding errors when summing carts and applying discounts.
///
/// Prices enter the app as `double` (from the API/JSON), so this class converts
/// to integer minor units for arithmetic and back to `double` only for display.
/// A scale of 100 covers 2-decimal currencies (USD) and is lossless for
/// 0-decimal currencies (KHR), whose amounts are already whole numbers.
class Money {
  const Money._();

  /// Number of minor units per major unit (2 decimal places).
  static const int scale = 100;

  /// Convert a major-unit amount (e.g. 12.34) to minor units (1234).
  static int toMinor(final double major) => (major * scale).round();

  /// Convert minor units (1234) back to a major-unit amount (12.34).
  static double toMajor(final int minor) => minor / scale;

  /// Exact line total in minor units for [unitPrice] x [qty].
  /// Rounds the unit price to the nearest minor unit first, then multiplies by
  /// the integer quantity so no float error accumulates across lines.
  static int lineTotalMinor(final double unitPrice, final int qty) =>
      toMinor(unitPrice) * qty;

  /// [percent] of an amount already expressed in minor units, rounded to the
  /// nearest minor unit. e.g. percentOfMinor(1000, 10) == 100.
  static int percentOfMinor(final int minor, final double percent) =>
      (minor * percent / 100).round();
}
