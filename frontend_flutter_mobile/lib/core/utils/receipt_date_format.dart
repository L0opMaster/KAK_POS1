/// Ported from `frontend-flutter-pos/lib/core/utils/receipt_date_format.dart`
/// — COPY/ADAPT NEARLY EXACTLY. Needed starting Day 10 for `Shift`'s
/// `startTime`/`closedAt` (backend `Instant` timestamps), same UTC-to-local
/// conversion bug class this already fixes in source for receipts.
String formatReceiptDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

String formatReceiptTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

/// Parses a backend timestamp (`java.time.Instant`, serialized via
/// `Instant.toString()` — always UTC with a trailing `Z`) and converts it to
/// the device's local time zone. `DateTime.parse` alone marks the result
/// `isUtc == true` but does NOT convert the field values (`.hour`, `.day`,
/// ...) to local time — reading those directly silently displays the UTC
/// clock/calendar values mislabeled as local time. Returns `null` if [raw]
/// is null, empty, or unparsable, so callers can fall back to their own
/// default instead of showing a malformed value.
DateTime? parseBackendTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw).toLocal();
  } on FormatException {
    return null;
  }
}
