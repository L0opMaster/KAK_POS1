import '../../../../core/config/currency_utils.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/utils/bilingual.dart';
import '../../../../core/utils/khmer_text.dart';
import '../../../../core/utils/receipt_date_format.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../models/cart_models.dart';
import '../../models/receipt_models.dart';
import 'receipt_labels.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// receipt_view_model.dart` — COPY/ADAPT NEARLY EXACTLY, full file. This is
/// the single source of truth for receipt content: the on-screen preview
/// (`ReceiptPreviewScreen`/`ReceiptsScreen`) reads from this same model
/// Day 13/14/15's PDF/ESC-POS/bitmap pipelines will too, once they exist —
/// never a separately-formatted copy of the same receipt.
class ReceiptLineViewModel {
  const ReceiptLineViewModel({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.basePrice = 0,
    this.modifierAmount = 0,
    this.modifierSummary,
    this.note,
  });

  final String name;
  final double qty;
  final double unitPrice;
  final double lineTotal;
  final double basePrice;
  final double modifierAmount;
  final String? modifierSummary;
  final String? note;
}

enum ReceiptAdjustmentType { discount, delivery, otherCharge, tax }

extension ReceiptAdjustmentTypeLabel on ReceiptAdjustmentType {
  String labelFrom(ReceiptLabels labels) {
    switch (this) {
      case ReceiptAdjustmentType.discount:
        return labels.discount;
      case ReceiptAdjustmentType.delivery:
        return labels.delivery;
      case ReceiptAdjustmentType.otherCharge:
        return labels.otherCharge;
      case ReceiptAdjustmentType.tax:
        return labels.tax;
    }
  }
}

/// One non-zero row to show between Subtotal and Total. See
/// [ReceiptViewModel.adjustments].
class ReceiptAdjustment {
  const ReceiptAdjustment(this.type, this.amount);

  final ReceiptAdjustmentType type;

  /// Always the positive magnitude — [isSubtraction] says how to sign it.
  final double amount;

  bool get isSubtraction => type == ReceiptAdjustmentType.discount;
}

/// A fully localized, formatted, print-ready receipt.
class ReceiptViewModel {
  const ReceiptViewModel({
    required this.language,
    required this.businessName,
    this.address,
    this.phone,
    this.website,
    required this.invoiceNumber,
    required this.date,
    required this.time,
    this.cashierName,
    this.customerName,
    this.tableNumber,
    required this.lines,
    required this.subtotal,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.deliveryCharge = 0,
    this.otherCharge = 0,
    required this.total,
    this.paidAmount = 0,
    this.changeAmount = 0,
    this.currencyCode,
    this.exchangeRateKhr,
    this.qrImageData,
    this.logoUrl,
    required this.footer,
    this.paymentMethodLabel,
    this.labels = ReceiptLabels.fallback,
    this.isBill = false,
    this.isDineIn = false,
  });

  final AppLanguage language;
  final String businessName;
  final String? address;
  final String? phone;

  /// Never rendered at all when null/empty — not defaulted to a hardcoded
  /// placeholder.
  final String? website;
  final String invoiceNumber;
  final String date;
  final String time;
  final String? cashierName;
  final String? customerName;
  final String? tableNumber;
  final List<ReceiptLineViewModel> lines;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double deliveryCharge;
  final double otherCharge;
  final double total;
  final double paidAmount;
  final double changeAmount;
  final String? currencyCode;
  final double? exchangeRateKhr;
  final String? qrImageData;
  final String? logoUrl;
  final String footer;
  final String? paymentMethodLabel;
  final ReceiptLabels labels;

  /// True for a pre-payment "bill/check" printed from a held ticket before
  /// any payment exists (see `held_tickets_screen.dart`'s `_buildBillReceipt`)
  /// — false (the default) for every other receipt, including the actual
  /// paid receipt for the same sale once it's charged. Every renderer
  /// (on-screen preview, PDF, ESC/POS, Khmer bitmap) reads this to replace
  /// the Paid/Cash Received/Change section with an explicit "UNPAID" notice
  /// instead of printing e.g. "Paid: $0", which reads as if $0 was already
  /// settled rather than nothing having been paid at all.
  final bool isBill;

  /// True when this order has a table (dine-in) — used on a pre-payment
  /// bill ([isBill]) to show a prominent "TABLE T05 / DINE IN" block so the
  /// cashier can identify the order at a glance. Not rendered on a normal
  /// paid receipt, whose existing (smaller) table row is unchanged.
  final bool isDineIn;

  /// Whether this receipt has any Khmer text in it (Khmer UI language, or a
  /// Khmer-only line/customer/business name) — used by Day 14's printing
  /// pipeline to decide whether to fall back to bitmap rendering.
  bool get containsKhmer => language.isKhmer || containsKhmerText(_allText);

  String get _allText => [
    businessName,
    customerName,
    cashierName,
    footer,
    ...lines.map((l) => l.name),
  ].whereType<String>().join();

  bool get showExchangeRate =>
      (exchangeRateKhr ?? 0) > 0 && currencyCode?.toUpperCase() != 'KHR';

  double get khrTotal => total * (exchangeRateKhr ?? 0);

  String fmt(double amount) => formatAmount(amount, currencyCode);

  /// Non-zero financial adjustment rows to show between Subtotal and
  /// Total, in display order (discount, delivery, other/service charge,
  /// tax) — the single source of truth for "which rows, in what order,
  /// hidden when zero".
  List<ReceiptAdjustment> get adjustments => [
    if (discountAmount > 0)
      ReceiptAdjustment(ReceiptAdjustmentType.discount, discountAmount),
    if (deliveryCharge > 0)
      ReceiptAdjustment(ReceiptAdjustmentType.delivery, deliveryCharge),
    if (otherCharge > 0)
      ReceiptAdjustment(ReceiptAdjustmentType.otherCharge, otherCharge),
    if (taxAmount > 0) ReceiptAdjustment(ReceiptAdjustmentType.tax, taxAmount),
  ];

  /// Formats [adjustment]'s amount with the correct sign placement — a
  /// discount renders as e.g. "-$1.00" (minus before the currency symbol).
  String fmtAdjustment(ReceiptAdjustment adjustment) => adjustment.isSubtraction
      ? '-${fmt(adjustment.amount)}'
      : fmt(adjustment.amount);

  /// Groups a riel amount with thousands separators and no decimals
  /// (e.g. 82000 -> "82,000"), since riel is never quoted in cents.
  static String khrGroup(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// Builds a [ReceiptViewModel] from the backend's persisted receipt
  /// (`GET /api/pos/sales/{id}/receipt`), used for `ReceiptsScreen`.
  factory ReceiptViewModel.fromReceiptResponse(
    ReceiptResponse r,
    AppLanguage language,
    AppLocalizations l10n,
  ) {
    // r.createdAt is an Instant serialized via Instant.toString() — always
    // UTC with a trailing 'Z'. parseBackendTimestamp converts to local
    // time exactly once; slicing the raw string's characters would display
    // UTC calendar/clock values mislabeled as local time.
    final createdAtLocal = parseBackendTimestamp(r.createdAt);
    return ReceiptViewModel(
      language: language,
      businessName: r.businessName ?? r.storeName ?? l10n.appName,
      address: r.address,
      phone: r.phone,
      website: r.website,
      invoiceNumber: r.saleNumber ?? '#${r.saleId}',
      date: createdAtLocal != null
          ? formatReceiptDate(createdAtLocal)
          : (r.createdAt ?? ''),
      time: createdAtLocal != null ? formatReceiptTime(createdAtLocal) : '',
      cashierName: r.cashierName,
      customerName: r.customerName,
      tableNumber: r.tableNumber,
      lines: r.lines
          .map(
            (line) => ReceiptLineViewModel(
              name: line.localizedName(language),
              qty: line.qty,
              unitPrice: line.unitPrice,
              lineTotal: line.lineTotal,
              basePrice: line.basePrice,
              modifierAmount: line.modifierAmount,
              modifierSummary: line.modifierSummary,
            ),
          )
          .toList(),
      subtotal: r.subtotal,
      discountAmount: r.discountAmount,
      taxAmount: r.taxAmount,
      deliveryCharge: r.deliveryCharge,
      otherCharge: r.otherCharge,
      total: r.total,
      paidAmount: r.paidAmount,
      changeAmount: r.changeAmount,
      currencyCode: r.currency,
      exchangeRateKhr: r.exchangeRateKhr,
      qrImageData: r.qrImageData,
      logoUrl: r.logoUrl,
      footer: (r.footer != null && r.footer!.isNotEmpty)
          ? r.footer!
          : l10n.receiptThankYou,
      paymentMethodLabel: r.payments.isNotEmpty
          ? r.payments.first.method
          : null,
      labels: ReceiptLabels.fromL10n(l10n),
    );
  }

  /// Builds a [ReceiptViewModel] straight from the in-progress cart, used
  /// by `ReceiptPreviewScreen` for the immediate post-sale preview, before
  /// the backend receipt has necessarily been fetched.
  factory ReceiptViewModel.fromCart({
    required AppLanguage language,
    required AppLocalizations l10n,
    required double total,
    double subtotal = 0,
    double discountAmount = 0,
    double taxAmount = 0,
    double deliveryCharge = 0,
    double otherCharge = 0,
    required List<CartItem> items,
    required double paidAmount,
    double changeAmount = 0,
    String? invoiceNumber,
    String cashierName = '',
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? website,
    String? currency,
    String? footer,
    String? saleDate,
    String? saleTime,
    String? tableNumber,
    String? qrImageData,
    double? exchangeRateKhr,
    String? paymentMethodLabel,
    bool isBill = false,
    bool isDineIn = false,
  }) {
    final computedSubtotal = subtotal > 0
        ? subtotal
        : items.fold(0.0, (s, i) => s + i.lineTotal);
    return ReceiptViewModel(
      language: language,
      businessName: businessName ?? l10n.appName,
      address: businessAddress,
      phone: businessPhone,
      website: website,
      invoiceNumber: invoiceNumber ?? 'N/A',
      isBill: isBill,
      isDineIn: isDineIn,
      date: saleDate ?? '',
      time: saleTime ?? '',
      cashierName: cashierName.isNotEmpty ? cashierName : null,
      tableNumber: tableNumber,
      lines: items
          .map(
            (item) => ReceiptLineViewModel(
              name: item.product.localizedName(language),
              qty: item.qty.toDouble(),
              unitPrice: item.product.price,
              lineTotal: item.lineTotal,
              basePrice: item.product.price,
              modifierAmount: item.modifierPriceDelta,
              modifierSummary: item.modifierSummaryText.isEmpty
                  ? null
                  : item.modifierSummaryText,
              note: item.note,
            ),
          )
          .toList(),
      subtotal: computedSubtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      deliveryCharge: deliveryCharge,
      otherCharge: otherCharge,
      total: total,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      currencyCode: currency,
      exchangeRateKhr: exchangeRateKhr,
      qrImageData: qrImageData,
      footer: (footer != null && footer.isNotEmpty)
          ? footer
          : l10n.receiptThankYou,
      paymentMethodLabel: paymentMethodLabel,
      labels: ReceiptLabels.fromL10n(l10n),
    );
  }
}
