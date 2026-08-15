import '../../../../l10n/generated/app_localizations.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// receipt_labels.dart` — COPY/ADAPT NEARLY EXACTLY. Every field-label
/// string a printed/previewed receipt needs, resolved once from
/// [AppLocalizations] and carried on `ReceiptViewModel` from then on, so
/// every renderer reads `receipt.labels.xxx` instead of hardcoding English.
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

  /// e.g. "Tel: {phone}" — needs the actual phone number.
  final String Function(Object phone) telFormat;

  /// e.g. "1 USD = {rate} KHR" — needs the actual formatted rate.
  final String Function(Object rate) exchangeRateValueFormat;

  /// English fallback — used only where no [AppLocalizations] is available.
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
