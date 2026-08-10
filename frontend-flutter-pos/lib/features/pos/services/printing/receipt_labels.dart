import '../../../../l10n/generated/app_localizations.dart';

/// Every field-label string a printed receipt needs, resolved once from
/// [AppLocalizations] and carried on [ReceiptViewModel] from then on.
///
/// Why this exists: `print_service.dart` (PDF), `EscPosReceiptBuilder`
/// (thermal text) and `ReceiptBitmapRenderer` (Khmer bitmap) have no
/// `BuildContext` of their own to call `AppLocalizations.of(context)` —
/// only the screen that kicks off printing does. Building the labels once,
/// at the same moment `ReceiptViewModel` itself is built (both of
/// `ReceiptViewModel`'s factories already take an `AppLocalizations l10n`
/// parameter), means every renderer reads `receipt.labels.xxx` instead of
/// each one hardcoding its own English string — which is exactly how the
/// PDF/ESC-POS/bitmap paths ended up printing "Subtotal"/"Paid"/"Change" in
/// English even when the app itself was switched to Khmer: none of those
/// three files had any localization mechanism at all before this.
///
/// Deliberately NOT a dependency of [ReceiptLayout]/typography — labels are
/// *content* (what word appears), typography is *presentation* (how big,
/// how spaced). Keeping them separate means switching language never has
/// to touch `receipt_layout_spec.dart`, and changing paper size never has
/// to touch this file.
class ReceiptLabels {
  const ReceiptLabels({
    required this.invoiceNumber,
    required this.date,
    required this.time,
    required this.cashier,
    required this.customer,
    required this.table,
    required this.item,
    required this.qty,
    required this.subtotal,
    required this.discount,
    required this.delivery,
    required this.otherCharge,
    required this.tax,
    required this.total,
    required this.paid,
    required this.cashReceived,
    required this.change,
    required this.paymentMethod,
    required this.exchangeRate,
    required this.totalRiel,
    required this.poweredBy,
    required this.thankYou,
    required this.emptyCart,
    required this.telFormat,
    required this.exchangeRateValueFormat,
  });

  factory ReceiptLabels.fromL10n(AppLocalizations l10n) => ReceiptLabels(
        invoiceNumber: l10n.receiptInvoiceNumber,
        date: l10n.receiptDate,
        time: l10n.receiptTime,
        cashier: l10n.receiptCashier,
        customer: l10n.receiptCustomer,
        table: l10n.receiptTable,
        item: l10n.receiptItem,
        qty: l10n.receiptQty,
        subtotal: l10n.receiptSubtotal,
        discount: l10n.receiptDiscount,
        delivery: l10n.receiptDelivery,
        otherCharge: l10n.receiptOtherCharge,
        tax: l10n.receiptTax,
        total: l10n.receiptTotal,
        paid: l10n.receiptPaid,
        cashReceived: l10n.paymentScreenCashReceived,
        change: l10n.receiptChange,
        paymentMethod: l10n.receiptPaymentMethod,
        exchangeRate: l10n.receiptExchangeRate,
        totalRiel: l10n.receiptsScreenTotalRielLabel,
        poweredBy: l10n.receiptsScreenPoweredBy,
        thankYou: l10n.receiptThankYou,
        emptyCart: l10n.posEmptyCart,
        telFormat: l10n.receiptsScreenTelLabel,
        exchangeRateValueFormat: l10n.receiptsScreenExchangeRateValue,
      );

  final String invoiceNumber;
  final String date;
  final String time;
  final String cashier;
  final String customer;
  final String table;
  final String item;
  final String qty;
  final String subtotal;
  final String discount;
  final String delivery;
  final String otherCharge;
  final String tax;
  final String total;
  final String paid;
  final String cashReceived;
  final String change;
  final String paymentMethod;
  final String exchangeRate;
  final String totalRiel;
  final String poweredBy;
  final String thankYou;
  final String emptyCart;

  /// e.g. "Tel: {phone}" — needs the actual phone number, so it stays a
  /// function rather than a precomputed string.
  final String Function(Object phone) telFormat;

  /// e.g. "1 USD = {rate} KHR" — needs the actual formatted rate.
  final String Function(Object rate) exchangeRateValueFormat;

  /// English fallback — used only where no [AppLocalizations] is available
  /// at all (there is currently no such call site in production code; this
  /// exists so a future test fixture or offline code path never crashes
  /// for want of a `BuildContext`, instead of every field needing its own
  /// `?? 'hardcoded fallback'` at every call site).
  static const ReceiptLabels fallback = ReceiptLabels(
    invoiceNumber: 'Invoice No.',
    date: 'Date',
    time: 'Time',
    cashier: 'Cashier',
    customer: 'Customer',
    table: 'Table',
    item: 'Item',
    qty: 'Qty',
    subtotal: 'Subtotal',
    discount: 'Discount',
    delivery: 'Delivery',
    otherCharge: 'Other Charge',
    tax: 'Tax',
    total: 'Total',
    paid: 'Paid',
    cashReceived: 'Cash Received',
    change: 'Change',
    paymentMethod: 'Payment Method',
    exchangeRate: 'Exchange rate',
    totalRiel: 'Total (Riel)',
    poweredBy: 'Powered by KAKNNEA',
    thankYou: 'Thank you for your purchase!',
    emptyCart: 'Cart is empty',
    telFormat: _fallbackTel,
    exchangeRateValueFormat: _fallbackRate,
  );

  static String _fallbackTel(Object phone) => 'Tel: $phone';
  static String _fallbackRate(Object rate) => '1 USD = $rate KHR';
}
