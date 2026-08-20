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
    required this.dueDate,
    required this.remaining,
    required this.creditStatus,
    required this.ticket,
    required this.billHeaderTitle,
    required this.paymentStatus,
    required this.unpaid,
    required this.billDisclaimer,
    required this.billCashierNotice,
    required this.dineIn,
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
        dueDate: l10n.paymentScreenCreditDueLabel,
        remaining: l10n.creditRepaymentRemainingLabel,
        creditStatus: l10n.paymentScreenCreditStatusLabel,
        ticket: l10n.receiptTicketNumber,
        billHeaderTitle: l10n.receiptBillHeaderTitle,
        paymentStatus: l10n.receiptPaymentStatus,
        unpaid: l10n.receiptUnpaid,
        billDisclaimer: l10n.receiptBillDisclaimer,
        billCashierNotice: l10n.receiptBillCashierNotice,
        dineIn: l10n.receiptDineIn,
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

  /// Credit sale section — only rendered when [ReceiptViewModel.creditStatus]
  /// is non-null (see `print_service.dart`/`escpos_receipt_builder.dart`).
  final String dueDate;
  final String remaining;
  final String creditStatus;

  /// "Ticket" — used in place of [invoiceNumber] on a pre-payment bill
  /// (see [ReceiptViewModel.isBill]), since a held ticket isn't an invoice
  /// yet.
  final String ticket;

  /// "BILL / CHECK" — the document-type banner shown at the very top of a
  /// pre-payment bill, above the business name, so it can never be mistaken
  /// for a paid receipt at a glance.
  final String billHeaderTitle;

  /// "Payment Status" — label above [unpaid] on a pre-payment bill.
  final String paymentStatus;

  /// "UNPAID" — replaces the Paid/Cash Received/Change section entirely on
  /// a pre-payment bill (see [ReceiptViewModel.isBill]).
  final String unpaid;

  /// "This is a bill for payment. It is NOT a payment receipt." — printed
  /// under [unpaid] on a pre-payment bill.
  final String billDisclaimer;

  /// "Please present this bill at the cashier." — printed under
  /// [billDisclaimer] on a pre-payment bill.
  final String billCashierNotice;

  /// "Dine In" — shown alongside the table number on a pre-payment bill
  /// when [ReceiptViewModel.orderModeLabel] is set.
  final String dineIn;

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
    dueDate: 'Due',
    remaining: 'Remaining Balance',
    ticket: 'Ticket',
    billHeaderTitle: 'BILL / CHECK',
    paymentStatus: 'Payment Status',
    unpaid: 'UNPAID',
    billDisclaimer: 'This is a bill for payment. It is NOT a payment receipt.',
    billCashierNotice: 'Please present this bill at the cashier.',
    dineIn: 'Dine In',
    creditStatus: 'Status',
  );

  static String _fallbackTel(Object phone) => 'Tel: $phone';
  static String _fallbackRate(Object rate) => '1 USD = $rate KHR';
}
