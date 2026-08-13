/// Shared `dd/MM/yyyy` / `HH:mm:ss` formatting for receipts — used wherever
/// a [DateTime] needs to become the date/time pair shown on a receipt
/// (payment_screen.dart's print button, receipt_preview_screen.dart's
/// "no backend receipt yet" fallback), so the two never drift into
/// different formats.
String formatReceiptDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

String formatReceiptTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

/// Parses a backend sale timestamp (`Sale.createdAt` is `java.time.Instant`
/// — see backend-spring-boot's `BaseEntity`/`SaleService` — serialized via
/// `Instant.toString()`, which is always UTC with a trailing `Z`, e.g.
/// `"2026-08-11T03:21:00.123456Z"`) and converts it to the device's local
/// time zone — the *one* place this conversion happens for receipt display,
/// so it's never done twice and never skipped. `DateTime.parse` alone marks
/// the result `isUtc == true` but does NOT convert the field values
/// (`.hour`, `.day`, ...) to local time — reading those directly, or slicing
/// the raw string's characters, silently displays the UTC clock/calendar
/// values mislabeled as local time (this was the receipt-timestamp bug:
/// `.toLocal()` was missing here). Returns `null` if [raw] is null, empty,
/// or unparsable, so callers can fall back to their own default instead of
/// showing a malformed value.
DateTime? parseBackendTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw).toLocal();
  } on FormatException {
    return null;
  }
}
