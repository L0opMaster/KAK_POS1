import '../../../../core/config/currency_utils.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/utils/bilingual.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../models/cart_models.dart';
import '../../models/receipt_models.dart';

/// One printable line item, already localized and formatted — the on-screen
/// preview, the PDF builder and the ESC/POS/bitmap builder all read from
/// this instead of each re-deriving it from raw data.
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

/// A fully localized, formatted, print-ready receipt.
///
/// This is the single source of truth for receipt content — the on-screen
/// preview ([ReceiptPreviewScreen]), the PDF pipeline ([PrintService]) and
/// the thermal ESC/POS + bitmap pipeline ([EscPosReceiptBuilder]) all render
/// from the *same* [ReceiptViewModel] instead of three independently
/// formatted copies of the same receipt, so they can never drift apart.
class ReceiptViewModel {
  const ReceiptViewModel({
    required this.language,
    required this.businessName,
    this.address,
    this.phone,
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
  });

  final AppLanguage language;
  final String businessName;
  final String? address;
  final String? phone;
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

  /// Whether this receipt has any Khmer text in it (Khmer UI language, or a
  /// Khmer-only line/customer/business name) — the printing pipeline uses
  /// this to decide whether to fall back to bitmap rendering (see
  /// [EscPosReceiptBuilder]).
  bool get containsKhmer =>
      language.isKhmer || _khmerPattern.hasMatch(_allText);

  String get _allText => [
        businessName,
        customerName,
        cashierName,
        footer,
        ...lines.map((l) => l.name),
      ].whereType<String>().join();

  static final RegExp _khmerPattern = RegExp(r'[ក-៿]');

  bool get showExchangeRate =>
      (exchangeRateKhr ?? 0) > 0 && currencyCode?.toUpperCase() != 'KHR';

  double get khrTotal => total * (exchangeRateKhr ?? 0);

  String fmt(double amount) => formatAmount(amount, currencyCode);

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
  /// (`GET /api/pos/sales/{id}/receipt`), used for reprints from
  /// [ReceiptsScreen] and [PrintService].
  factory ReceiptViewModel.fromReceiptResponse(
    ReceiptResponse r,
    AppLanguage language,
    AppLocalizations l10n,
  ) {
    final createdAt = r.createdAt ?? '';
    return ReceiptViewModel(
      language: language,
      businessName: r.businessName ?? r.storeName ?? l10n.appName,
      address: r.address,
      phone: r.phone,
      invoiceNumber: r.saleNumber ?? '#${r.saleId}',
      date: createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
      time: createdAt.length >= 19 ? createdAt.substring(11, 19) : '',
      cashierName: r.cashierName,
      customerName: r.customerName,
      tableNumber: r.tableNumber,
      lines: r.lines
          .map((line) => ReceiptLineViewModel(
                name: line.localizedName(language),
                qty: line.qty,
                unitPrice: line.unitPrice,
                lineTotal: line.lineTotal,
                basePrice: line.basePrice,
                modifierAmount: line.modifierAmount,
                modifierSummary: line.modifierSummary,
              ))
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
      paymentMethodLabel:
          r.payments.isNotEmpty ? r.payments.first.method : null,
    );
  }

  /// Builds a [ReceiptViewModel] straight from the in-progress cart, used by
  /// [ReceiptPreviewScreen] for the immediate post-sale preview/print,
  /// before the backend receipt has necessarily been fetched.
  factory ReceiptViewModel.fromCart({
    required AppLanguage language,
    required AppLocalizations l10n,
    required double total,
    double subtotal = 0,
    required List<CartItem> items,
    required double paidAmount,
    double changeAmount = 0,
    String? invoiceNumber,
    String cashierName = '',
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? currency,
    String? footer,
    String? saleDate,
    String? saleTime,
    String? tableNumber,
    String? qrImageData,
    double? exchangeRateKhr,
    String? paymentMethodLabel,
  }) {
    final computedSubtotal =
        subtotal > 0 ? subtotal : items.fold(0.0, (s, i) => s + i.lineTotal);
    return ReceiptViewModel(
      language: language,
      businessName: businessName ?? l10n.appName,
      address: businessAddress,
      phone: businessPhone,
      invoiceNumber: invoiceNumber ?? 'N/A',
      date: saleDate ?? '',
      time: saleTime ?? '',
      cashierName: cashierName.isNotEmpty ? cashierName : null,
      tableNumber: tableNumber,
      lines: items
          .map((item) => ReceiptLineViewModel(
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
              ))
          .toList(),
      subtotal: computedSubtotal,
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
    );
  }
}
