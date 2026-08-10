/// Shared `dd/MM/yyyy` / `HH:mm:ss` formatting for receipts — used wherever
/// a [DateTime] needs to become the date/time pair shown on a receipt
/// (payment_screen.dart's print button, receipt_preview_screen.dart's
/// "no backend receipt yet" fallback), so the two never drift into
/// different formats.
String formatReceiptDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

String formatReceiptTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
