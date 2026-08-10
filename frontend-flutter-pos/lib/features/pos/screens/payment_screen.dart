import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/providers/currency_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/receipt_date_format.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../services/sale_service.dart';
import '../services/settings_service.dart';
import '../services/print_service.dart';
import '../providers/cart_provider.dart';
import '../providers/held_ticket_provider.dart';
import '../providers/waiting_ticket_provider.dart' as waiting;
import '../models/cart_models.dart';
import '../models/receipt_models.dart';
import '../widgets/receipt_preview_screen.dart';
import '../providers/customer_display_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// Enums
// ═══════════════════════════════════════════════════════════════════
enum PaymentState { idle, splitting, completed, failed }

enum PaymentMethod {
  cash,
  card,
  aba,
  khqr,
  bankTransfer,
  wing,
  acleda,
  check,
  other
}

extension PaymentMethodX on PaymentMethod {
  String label(AppLocalizations l10n) {
    switch (this) {
      case PaymentMethod.cash:
        return l10n.cartCash;
      case PaymentMethod.card:
        return l10n.cartCard;
      case PaymentMethod.aba:
        return l10n.paymentScreenMethodAba;
      case PaymentMethod.khqr:
        return l10n.cartKhqr;
      case PaymentMethod.bankTransfer:
        return l10n.paymentScreenMethodBankTransfer;
      case PaymentMethod.wing:
        return l10n.paymentScreenMethodWing;
      case PaymentMethod.acleda:
        return l10n.paymentScreenMethodAcleda;
      case PaymentMethod.check:
        return l10n.paymentScreenMethodCheck;
      case PaymentMethod.other:
        return l10n.paymentScreenMethodOther;
    }
  }

  String get code {
    switch (this) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.card:
        return 'CARD';
      case PaymentMethod.aba:
        return 'ABA';
      case PaymentMethod.khqr:
        return 'KHQR';
      case PaymentMethod.bankTransfer:
        return 'BANK_TRANSFER';
      case PaymentMethod.wing:
        return 'WING';
      case PaymentMethod.acleda:
        return 'ACLEDA';
      case PaymentMethod.check:
        return 'CHECK';
      case PaymentMethod.other:
        return 'OTHER';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.aba:
        return Icons.phone_android;
      case PaymentMethod.khqr:
        return Icons.qr_code;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
      case PaymentMethod.wing:
        return Icons.phone_iphone;
      case PaymentMethod.acleda:
        return Icons.account_balance;
      case PaymentMethod.check:
        return Icons.receipt;
      case PaymentMethod.other:
        return Icons.payment;
    }
  }

  Color get color {
    switch (this) {
      case PaymentMethod.cash:
        return const Color(0xFF4CAF50);
      case PaymentMethod.card:
        return const Color(0xFF2196F3);
      case PaymentMethod.aba:
        return const Color(0xFFE91E63);
      case PaymentMethod.khqr:
        return const Color(0xFF9C27B0);
      case PaymentMethod.bankTransfer:
        return const Color(0xFF607D8B);
      case PaymentMethod.wing:
        return const Color(0xFFFF5722);
      case PaymentMethod.acleda:
        return const Color(0xFF795548);
      case PaymentMethod.check:
        return const Color(0xFFFF9800);
      case PaymentMethod.other:
        return const Color(0xFF9E9E9E);
    }
  }

  static PaymentMethod fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'CASH':
        return PaymentMethod.cash;
      case 'CARD':
        return PaymentMethod.card;
      case 'ABA':
        return PaymentMethod.aba;
      case 'KHQR':
        return PaymentMethod.khqr;
      case 'BANK_TRANSFER':
        return PaymentMethod.bankTransfer;
      case 'WING':
        return PaymentMethod.wing;
      case 'ACLEDA':
        return PaymentMethod.acleda;
      case 'CHECK':
        return PaymentMethod.check;
      default:
        return PaymentMethod.other;
    }
  }
}

enum SplitStatus { pending, authorizing, authorized, failed }

/// A single split row in the payment workflow.
class SplitRow {
  int id;
  PaymentMethod method;
  double amount;
  SplitStatus status;

  SplitRow({
    required this.id,
    this.method = PaymentMethod.cash,
    this.amount = 0,
    this.status = SplitStatus.pending,
  });
}

/// Amount to actually send to the backend for one authorized payment split.
///
/// [split.amount] is the amount APPLIED to the sale — for cash it's
/// capped at the total (see `_chargeCash`) so it never overshoots on
/// screen. For a cash split, [cashReceived] is what the customer actually
/// tendered; when that's more than what was applied, this sends the
/// tendered amount instead, so the backend's own
/// `appliedAmount = min(requestTotal, remaining)` /
/// `changeAmount = requestTotal - appliedAmount` (see `SaleService.pay`)
/// computes the customer's real change — sending the pre-capped amount
/// made the backend see exactly the total every time, so change was
/// always recorded as zero regardless of what was handed over.
Map<String, dynamic> paymentRequestEntry(SplitRow split, double? cashReceived) {
  final tendered = split.method == PaymentMethod.cash ? cashReceived : null;
  final amount =
      (tendered != null && tendered > split.amount) ? tendered : split.amount;
  return {'method': split.method.code, 'amount': amount};
}

// ═══════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════
class PaymentScreen extends ConsumerStatefulWidget {
  final double total;
  final List<Map<String, dynamic>>? saleLines;
  final int? customerId;
  final int? tableId;
  final int waitingNumber;

  /// Backend id of the held ticket this cart was resumed from, if any —
  /// once payment succeeds, that ticket is released (see
  /// `_submitSaleToBackend`) so it doesn't linger as a phantom
  /// in-progress entry that can never be resumed again.
  final int? heldTicketId;

  const PaymentScreen({
    super.key,
    required this.total,
    this.saleLines,
    this.customerId,
    this.tableId,
    required this.waitingNumber,
    this.heldTicketId,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentState _paymentState = PaymentState.idle;

  List<SplitRow> _splits = [];
  int _splitCount = 1;
  int _processingIndex = -1;

  final _emailCtl = TextEditingController();

  // Holds the completed sale response from backend
  SaleResponse? _completedSale;
  ReceiptResponse? _completedReceipt;

  /// True only while the Print button is waiting on [_ensureCompletedReceipt]
  /// — normally near-instant since the background fetch usually already
  /// finished by the time the cashier taps Print.
  bool _preparingPrint = false;
  List<CartItem> _savedSaleItems = [];
  bool _isSubmitting = false;
  String _currency = 'USD';

  // Cash tendered by the customer for a full-amount cash payment, converted
  // into the store's currency (`_currency`). `widget.total` already
  // reflects discounts and modifier price deltas (see CartState.finalTotal
  // / CartItem.unitPrice), so change is simply tendered - total.
  double? _cashReceived;

  // The currency the customer is actually handing over (e.g. they're
  // paying in Riel even though prices are quoted in USD) and the raw
  // number they/the cashier entered in that currency, before conversion.
  String _tenderCurrency = 'USD';
  double? _cashReceivedRaw;
  final _cashReceivedCtl = TextEditingController();

  // Exchange rates for the currencies a customer can pay cash in, each
  // expressed as "units of that currency per 1 USD". Seeded with the
  // standard USD/KHR pairing so the screen works before the backend
  // value loads; refreshed from Settings in initState.
  Map<String, TenderCurrency> _rates = const {
    'USD': TenderCurrency(code: 'USD', symbol: r'$', ratePerUsd: 1),
    'KHR': TenderCurrency(code: 'KHR', symbol: '៛', ratePerUsd: 4100),
  };

  double _convert(double amount, String fromCode, String toCode) {
    final fromRate = _rates[fromCode]?.ratePerUsd ?? 1;
    final toRate = _rates[toCode]?.ratePerUsd ?? 1;
    return amount / fromRate * toRate;
  }

  /// Renders [amountInStoreCurrency] (already in `_currency`) as both a
  /// dollar and a riel figure stacked, since change is handed back in
  /// whichever bills the drawer has regardless of what the customer paid
  /// with. Whichever of the two isn't the store's own currency is a
  /// converted ("≈") figure; falls back to a single line if USD/KHR
  /// aren't both configured as active currencies.
  Widget _dualCurrencyAmount(
    double amountInStoreCurrency, {
    required Color color,
    double primaryFontSize = 18,
    double secondaryFontSize = 13,
  }) {
    if (!(_rates.containsKey('USD') && _rates.containsKey('KHR'))) {
      return Text(
        formatAmount(amountInStoreCurrency, _currency),
        style: TextStyle(
            fontSize: primaryFontSize,
            fontWeight: FontWeight.w800,
            color: color),
      );
    }
    final usd = _currency == 'USD'
        ? amountInStoreCurrency
        : _convert(amountInStoreCurrency, _currency, 'USD');
    final khr = _currency == 'KHR'
        ? amountInStoreCurrency
        : _convert(amountInStoreCurrency, _currency, 'KHR');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_currency == 'USD' ? '' : '≈ '}${formatAmount(usd, 'USD')}',
          style: TextStyle(
              fontSize: primaryFontSize,
              fontWeight: FontWeight.w800,
              color: color),
        ),
        Text(
          '${_currency == 'KHR' ? '' : '≈ '}${formatAmount(khr, 'KHR')}',
          style: TextStyle(
              fontSize: secondaryFontSize,
              fontWeight: FontWeight.w700,
              color: color),
        ),
      ],
    );
  }

  // Stable idempotency key for this checkout. Generated once so that a retry
  // after a timeout/network error reuses the same key; the backend dedupes on
  // `clientRef` (SaleService.findByClientRef) and returns the existing sale
  // instead of creating a duplicate.
  final String _clientRef = const Uuid().v4();

  /// Get the order mode string from the current cart state.
  String _getOrderModeFromCart() {
    try {
      final mode = ref.read(cartProvider).orderMode;
      switch (mode) {
        case OrderMode.dineIn:
          return 'DINE_IN';
        case OrderMode.takeaway:
          return 'TAKEAWAY';
        case OrderMode.delivery:
          return 'DELIVERY';
      }
    } catch (_) {}
    return 'DINE_IN';
  }

  /// Quick-cash presets, sized to the currently selected tender currency
  /// (small dollar bills vs. the riel note denominations in circulation).
  List<double> _quickCashAmounts() {
    if (_tenderCurrency == 'KHR') {
      return [1000, 5000, 10000, 20000, 50000, 100000];
    }
    return [1, 5, 10, 20, 50, 100];
  }

  /// Switch which currency the customer is handing over cash in. Clears
  /// any amount already entered rather than reinterpreting those digits
  /// in the new currency, since that would silently change the value.
  void _setTenderCurrency(String code) {
    if (code == _tenderCurrency) return;
    setState(() {
      _tenderCurrency = code;
      _cashReceivedRaw = null;
      _cashReceived = null;
      _cashReceivedCtl.clear();
    });
  }

  /// Parse the raw amount typed in the tender currency and convert it into
  /// the store's currency, which is what the change math is done in.
  void _onCashReceivedChanged(String text) {
    final raw = double.tryParse(text);
    setState(() {
      _cashReceivedRaw = raw;
      _cashReceived =
          raw == null ? null : _convert(raw, _tenderCurrency, _currency);
    });
  }

  double get _totalPaid => _splits
      .where((s) => s.status == SplitStatus.authorized)
      .fold(0.0, (sum, s) => sum + s.amount);

  bool get _allPaid =>
      _splits.isNotEmpty &&
      _splits.every((s) => s.status == SplitStatus.authorized);

  /// Change owed back to the customer: cash handed over minus the total
  /// (which already has discounts and modifier prices baked in). Zero
  /// while nothing has been tendered yet, or if the tender is short.
  double get _changeDue {
    final received = _cashReceived;
    if (received == null) return 0;
    final diff = received - widget.total;
    return diff > 0 ? diff : 0;
  }

  /// How much more cash is still owed after the tendered amount, or zero
  /// once enough (or more) has been handed over.
  double get _amountShort {
    final received = _cashReceived;
    if (received == null) return widget.total;
    final diff = widget.total - received;
    return diff > 0 ? diff : 0;
  }

  @override
  void initState() {
    super.initState();
    _resetSplits();
    // Read currency from settings
    try {
      final cur = readCurrency(ref);
      if (cur.isNotEmpty) _currency = cur;
    } catch (_) {}
    _tenderCurrency = _currency;

    // Refresh exchange rates from Settings (falls back to the seeded
    // USD/KHR default above if this fails or the app is offline).
    ref.read(tenderCurrenciesProvider.future).then((rates) {
      if (mounted && rates.isNotEmpty) setState(() => _rates = rates);
    }).catchError((_) {});

    ref.read(customerDisplayProvider.notifier).broadcastPaymentPending(
          widget.total,
          currencySymbol: currencySymbol(_currency),
        );
  }

  /// Mirrors the current split rows to the paired customer display.
  void _broadcastSplitUpdate() {
    ref.read(customerDisplayProvider.notifier).broadcastPaymentSplitUpdate(
          splits: _splits
              .where((s) => s.status == SplitStatus.authorized)
              .map((s) => <String, dynamic>{
                    'method': s.method.code,
                    'amount': s.amount,
                  })
              .toList(),
          remaining: widget.total - _totalPaid,
          currencySymbol: currencySymbol(_currency),
        );
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _cashReceivedCtl.dispose();
    super.dispose();
  }

  // ── Split arithmetic ──

  void _resetSplits() {
    _splitCount = 1;
    _splits = [SplitRow(id: 0)];
    _rebalance();
    _paymentState = PaymentState.idle;
    _processingIndex = -1;
    setState(() {});
  }

  /// Distribute [widget.total] across all rows equally.
  /// Last row absorbs the cent remainder.
  void _rebalance() {
    if (_splits.isEmpty) return;
    final total = widget.total;
    final count = _splits.length;
    final floorCents = (total * 100 / count).floor();
    final remainder = (total * 100).round() - floorCents * count;
    for (int i = 0; i < count; i++) {
      final cents = (i < count - 1) ? floorCents : floorCents + remainder;
      _splits[i].amount = cents / 100.0;
    }
    _broadcastSplitUpdate();
  }

  void _increaseSplits() {
    if (_splitCount >= 6) return;
    _splitCount++;
    _splits.add(SplitRow(id: _splits.length));
    _rebalance();
    setState(() {});
  }

  void _decreaseSplits() {
    if (_splitCount <= 1) return;
    _splitCount--;
    _splits.removeLast();
    _rebalance();
    setState(() {});
  }

  void _updateSplitMethod(int index, PaymentMethod method) {
    setState(() => _splits[index].method = method);
  }

  void _updateSplitAmount(int index, double amount) {
    setState(() {
      _splits[index].amount = amount.clamp(0, widget.total);
    });
  }

  // ── State machine transitions ──

  void _enterSplitMode() {
    _paymentState = PaymentState.splitting;
    _processingIndex = -1;
    _rebalance();
    setState(() {});
  }

  /// Process a single split row (individual Charge button).
  Future<void> _chargeSplit(int index) async {
    if (_processingIndex >= 0) return;
    setState(() {
      _processingIndex = index;
      _splits[index].status = SplitStatus.authorizing;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _splits[index].status = SplitStatus.authorized;
      _processingIndex = -1;
    });
    _broadcastSplitUpdate();
  }

  void _payFullAmount() {
    _cashReceived = null;
    _cashReceivedRaw = null;
    _splits = [SplitRow(id: 0)];
    _splits[0].amount = widget.total;
    _splits[0].status = SplitStatus.authorized;
    _submitSaleToBackend();
  }

  /// Set the cash amount the customer handed over from a quick-cash preset
  /// (in whichever currency is currently selected as the tender currency),
  /// so the change/short indicator updates. Does not submit the sale —
  /// the cashier confirms with the "Charge Cash" button once the tendered
  /// amount is right, which is what actually records the payment.
  void _selectCashReceived(double rawAmount) {
    setState(() {
      _cashReceivedRaw = rawAmount;
      _cashReceivedCtl.text = _tenderCurrency == 'KHR'
          ? rawAmount.toStringAsFixed(0)
          : rawAmount.toStringAsFixed(2);
      _cashReceived = _convert(rawAmount, _tenderCurrency, _currency);
    });
  }

  /// Confirm the cash payment: charge the amount owed (never more, even if
  /// more was tendered) and keep `_cashReceived` around so the completed
  /// screen can show the actual change due back to the customer.
  void _chargeCash() {
    final received = _cashReceived ?? widget.total;
    final amount = received > widget.total ? widget.total : received;
    _splits = [SplitRow(id: 0)];
    _splits[0].amount = amount;
    _splits[0].method = PaymentMethod.cash;
    _splits[0].status = SplitStatus.authorized;
    _submitSaleToBackend();
  }

  /// Submit the sale and all payments to the backend API.
  Future<void> _submitSaleToBackend() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      // Keep a snapshot because the cart is cleared after payment succeeds.
      final CartState cartSnapshot = ref.read(cartProvider);
      final List<CartItem> saleItems = List<CartItem>.from(cartSnapshot.items);
      final OrderMode saleOrderMode = cartSnapshot.orderMode;

      final saleService = ref.read(saleServiceProvider);

      // Build sale request from splits — see paymentRequestEntry for why a
      // cash split sends the tendered amount, not the amount applied.
      final payments = _splits
          .where((s) => s.status == SplitStatus.authorized)
          .map((s) => paymentRequestEntry(s, _cashReceived))
          .toList();

      final request = <String, dynamic>{
        'lines': widget.saleLines ?? [],
        'clientRef': _clientRef,
        if (widget.customerId != null) 'customerId': widget.customerId,
        if (widget.tableId != null) 'tableId': widget.tableId,
        'orderMode': _getOrderModeFromCart(),
        if (payments.isNotEmpty) 'payments': payments,
        // The backend recomputes tax/discount/total server-side from these
        // — see SaleService.createSale (taxable = subtotal - discount,
        // taxAmount = taxable * taxRate) — but only if it's told the rate
        // and discount actually applied on this cart; omitting them here is
        // exactly why every finalized sale used to record zero tax.
        'taxRate': cartSnapshot.taxRate,
        if (cartSnapshot.discountAmount > 0)
          'invoiceDiscount': cartSnapshot.discountAmount,
      };

      // Create sale
      final saleResponse = await saleService.createSale(request);
      final saleId = saleResponse.id;

      // Save cart items before clearing (for receipt preview).
      _savedSaleItems = saleItems;

      SaleResponse? payResponse;

      // Process payments if any.
      if (payments.isNotEmpty) {
        payResponse = await saleService.paySale(saleId, payments);
      } else {
        payResponse = saleResponse;
      }

      if (!mounted) return;

      // This cart came from a held ticket and just became a real sale —
      // release the original ticket so it doesn't linger as a phantom
      // in-progress entry that can never be resumed again.
      if (widget.heldTicketId != null) {
        unawaited(
          ref
              .read(heldTicketProvider.notifier)
              .releaseTicketById(widget.heldTicketId!),
        );
      }

      // Add the paid order to the local waiting-number list.
      // The backend currently does not store waiting numbers.
      try {
        await ref.read(waiting.waitingNumberServiceProvider).saveWaitingTicket(
              waitingNumber: widget.waitingNumber,
              items: saleItems,
              orderMode: saleOrderMode,
              status: WaitingTicketStatus.paid,
              total: widget.total,
              orderId: saleId,
            );

        // Refresh the dialog opened by clicking "Ticket".
        ref.invalidate(waitingTicketsProvider);
      } catch (e) {
        // Payment already succeeded, so a local queue-storage failure must not
        // change the sale to a failed payment.
        debugPrint('Waiting ticket save failed (non-fatal): $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(context.l10n.paymentScreenWaitingTicketSaveFailed('$e')),
              backgroundColor: PosTheme.warningAmber,
            ),
          );
        }
      }

      // Clear the sold cart but keep its waiting number reserved.
      // It is released only when the customer presses "Collected".
      await ref.read(cartProvider.notifier).clear(
            releaseWaitingNumber: false,
          );

      // Update UI to completed state
      if (mounted) {
        setState(() {
          _completedSale = payResponse;
          _paymentState = PaymentState.completed;
          _isSubmitting = false;
        });
      }

      ref.read(customerDisplayProvider.notifier).broadcastPaymentCompleted(
            receiptNumber: payResponse.invoiceNumber ?? 'Sale #$saleId',
            total: payResponse.grandTotal,
            amountPaid: payResponse.paidAmount,
            change: _changeDue,
            currencySymbol: currencySymbol(_currency),
          );

      // Fetch receipt data (non-blocking — UI already shows success). This
      // is the authoritative source for the printed receipt's financial
      // breakdown (subtotal/tax/discount/paid/change) — see
      // _ensureCompletedReceipt, used by the Print button below.
      unawaited(_fetchCompletedReceipt(saleId));

      // Auto-print only when Settings → POS → "Auto-print after payment"
      // is actually turned on (off by default) — this used to fire
      // unconditionally on every sale regardless of the setting.
      if (mounted) {
        unawaited(_autoPrintIfEnabled(context, saleId));
      }
    } catch (e) {
      debugPrint('Sale submission failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.paymentScreenSaleFailed('$e')),
            backgroundColor: PosTheme.errorRed,
            action: SnackBarAction(
              label: context.l10n.commonRetry,
              textColor: Colors.white,
              onPressed: _submitSaleToBackend,
            ),
          ),
        );
        setState(() {
          _paymentState = PaymentState.failed;
          _isSubmitting = false;
        });
      }
    }
  }

  void _done() {
    // The cart was already cleared after the sale was submitted successfully.
    ref.read(customerDisplayProvider.notifier).broadcastIdle();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _newSale() {
    // Return to the POS. The completed sale's waiting number remains active.
    ref.read(customerDisplayProvider.notifier).broadcastIdle();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Fetches the finalized sale's full receipt (subtotal/tax/discount/
  /// paid/change, all computed server-side) and stores it in
  /// [_completedReceipt]. This is the single source of truth the printed
  /// receipt must use — never re-derived from the cart or from
  /// [widget.total] alone, which is only ever the tax-inclusive grand
  /// total and carries no tax/discount breakdown of its own.
  Future<ReceiptResponse?> _fetchCompletedReceipt(int saleId) async {
    try {
      final raw = await ref.read(saleServiceProvider).getReceipt(saleId);
      final receipt = ReceiptResponse.fromJson(raw);
      if (mounted) setState(() => _completedReceipt = receipt);
      return receipt;
    } catch (e) {
      debugPrint('Receipt fetch failed (non-fatal): $e');
      return null;
    }
  }

  /// Returns [_completedReceipt] if it already loaded (the common case —
  /// the background fetch kicked off right after payment success usually
  /// finishes well before the cashier taps Print), otherwise fetches it
  /// fresh rather than letting the receipt print with cart-derived
  /// placeholder values.
  Future<ReceiptResponse?> _ensureCompletedReceipt() async {
    final existing = _completedReceipt;
    if (existing != null) return existing;
    final saleId = _completedSale?.id;
    if (saleId == null) return null;
    return _fetchCompletedReceipt(saleId);
  }

  /// Prints [saleId]'s receipt automatically, but only when Settings → POS
  /// → "Auto-print after payment" (`BusinessSettings.autoPrintReceipt`,
  /// off by default) is actually enabled — this used to call
  /// `printService.printReceipt` unconditionally on every completed sale.
  Future<void> _autoPrintIfEnabled(BuildContext context, int saleId) async {
    bool enabled;
    try {
      final pos = await ref.read(settingsServiceProvider).getPosSettings();
      enabled = pos['autoPrintReceipt'] as bool? ?? false;
    } catch (e) {
      debugPrint('Auto-print setting check failed (non-fatal): $e');
      return;
    }
    if (!enabled || !mounted) return;
    await ref.read(printServiceProvider).printReceipt(context, saleId);
  }

  /// Show dialog to edit a split's amount.
  Future<void> _showAmountEditor(int index) async {
    final split = _splits[index];
    final ctl = TextEditingController(text: split.amount.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            ctx.l10n.paymentScreenSplitAmountTitle((index + 1).toString())),
        content: TextField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
          ],
          decoration: const InputDecoration(
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.commonCancel)),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(ctl.text) ?? 0;
              Navigator.pop(ctx, amt);
            },
            child: Text(ctx.l10n.commonApply),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      _updateSplitAmount(index, result.clamp(0, widget.total));
    }
    ctl.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosTheme.backgroundPageOf(context),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String title;
    switch (_paymentState) {
      case PaymentState.idle:
        title = context.l10n.posCheckout;
        break;
      case PaymentState.splitting:
        title = context.l10n.paymentScreenSplitPayment;
        break;
      case PaymentState.completed:
        title = context.l10n.paymentScreenPaymentComplete;
        break;
      case PaymentState.failed:
        title = context.l10n.paymentScreenPaymentFailed;
        break;
    }
    return AppBar(
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (_paymentState == PaymentState.completed) {
            Navigator.of(context).popUntil((r) => r.isFirst);
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      // No backgroundColor/foregroundColor override here — this bar uses
      // the shared branded-green AppBarTheme (see PosTheme.lightTheme /
      // darkTheme) so it stays consistent with the rest of the app.
      elevation: 0.5,
      actions: [
        if (_paymentState == PaymentState.splitting && _splits.length > 1)
          TextButton(
            onPressed: _resetSplits,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(context.l10n.commonReset),
          ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_paymentState) {
      case PaymentState.idle:
      case PaymentState.splitting:
        return _buildTwoColumn();
      case PaymentState.completed:
        return _buildCompleted();
      case PaymentState.failed:
        return _buildFailed();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 2-COLUMN: Left = Cart Items , Right = Payment / Splits
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTwoColumn() {
    final cart = ref.watch(cartProvider);
    final isIdle = _paymentState == PaymentState.idle;

    return Row(
      children: [
        // ─── LEFT: Cart items ───
        Expanded(
          flex: 5,
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: PosTheme.dividerColorOf(context)))),
                  child: Row(children: [
                    Icon(Icons.shopping_cart,
                        size: 18, color: PosTheme.textSecondaryOf(context)),
                    const SizedBox(width: 8),
                    Text(
                        context.l10n.paymentScreenCartCount(
                            cart.items.length.toString()),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                ),
                Expanded(
                  child: cart.items.isEmpty
                      ? Center(
                          child: Text(context.l10n.posEmptyCart,
                              style: TextStyle(
                                  color: PosTheme.textHintOf(context))))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: cart.items.length,
                          itemBuilder: (ctx, i) => _cartItemRow(cart.items[i]),
                        ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: PosTheme.dividerColorOf(context)))),
                  child: Column(children: [
                    _calcRow(context.l10n.cartSubtotal,
                        formatAmount(cart.total, _currency)),
                    if (cart.discountAmount > 0)
                      _calcRow(context.l10n.cartDiscount,
                          '-${formatAmount(cart.discountAmount, _currency)}',
                          valueColor: PosTheme.errorRed),
                    const Divider(height: 16),
                    _calcRow(context.l10n.cartTotal,
                        formatAmount(widget.total, _currency),
                        bold: true, large: true),
                  ]),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: PosTheme.dividerColorOf(context)),
        // ─── RIGHT: Payment panel ───
        Expanded(
          flex: 5,
          child: isIdle ? _rightIdle() : _rightSplitPanel(),
        ),
      ],
    );
  }

  Widget _cartItemRow(CartItem item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: PosTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text('${item.qty}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: PosTheme.primaryGreen)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.localizedName(ref.watch(appLanguageProvider)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                // Show the modifier's own price before the combined
                // (base + modifier) total on the right, so the cashier can
                // see what the modifier actually added.
                if (item.modifierPriceDelta != 0)
                  Text(
                    context.l10n.paymentScreenBaseModifierLine(
                      formatAmount(item.product.price, _currency),
                      formatAmount(item.modifierPriceDelta, _currency),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: PosTheme.textHintOf(context)),
                  ),
                if (item.modifierSummaryText.isNotEmpty)
                  Text(
                    item.modifierSummaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: PosTheme.textHintOf(context),
                        fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatAmount(item.lineTotal, _currency),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _calcRow(String label, String value,
          {Color? valueColor, bool bold = false, bool large = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  fontSize: large ? 15 : 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: PosTheme.textSecondaryOf(context))),
          Text(value,
              style: TextStyle(
                  fontSize: large ? 20 : 14,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? PosTheme.textPrimaryOf(context))),
        ]),
      );

  // ═══════════════════════════════════════════════════════════════
  // RIGHT PANEL: IDLE
  // ═══════════════════════════════════════════════════════════════
  Widget _rightIdle() => Container(
        color: PosTheme.backgroundPageOf(context),
        child: Column(children: [
          const Spacer(flex: 1),
          // ── Large total ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              Text(formatAmount(widget.total, _currency),
                  style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: PosTheme.textPrimaryOf(context))),
              const SizedBox(height: 6),
              Text(context.l10n.paymentScreenTotalDue,
                  style: TextStyle(
                      fontSize: 14, color: PosTheme.textSecondaryOf(context))),
            ]),
          ),
          const Spacer(flex: 1),
          // ── Cash received + change calculator ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n.paymentScreenCashReceived,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PosTheme.textSecondaryOf(context))),
                    // Paid in $ or paid in ៛ — whichever the customer
                    // actually handed over.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: (_rates.keys.toList()
                            ..sort((a, b) => a == _currency ? -1 : 1))
                          .map((code) {
                        final selected = code == _tenderCurrency;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () => _setTenderCurrency(code),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected
                                    ? PosTheme.primaryGreen
                                    : Colors.white,
                                borderRadius:
                                    BorderRadius.circular(PosTheme.radiusPill),
                                border: Border.all(
                                    color: selected
                                        ? PosTheme.primaryGreen
                                        : PosTheme.borderColorOf(context)),
                              ),
                              child: Text(
                                '${_rates[code]?.symbol ?? code} $code',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : PosTheme.textSecondaryOf(context)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cashReceivedCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(_tenderCurrency == 'KHR'
                        ? RegExp(r'^\d*')
                        : RegExp(r'^\d*\.?\d{0,2}'))
                  ],
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: _rates[_tenderCurrency]?.symbol ??
                        currencySymbol(_tenderCurrency),
                    hintText: _tenderCurrency == 'KHR' ? '0' : '0.00',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(PosTheme.radiusMedium),
                    ),
                  ),
                  onChanged: _onCashReceivedChanged,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickCashAmounts().map((amount) {
                    final totalInTender =
                        _convert(widget.total, _currency, _tenderCurrency);
                    final tolerance = _tenderCurrency == 'KHR' ? 50 : 0.01;
                    final isExact = (amount - totalInTender).abs() < tolerance;
                    return SizedBox(
                      width: 82,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => _selectCashReceived(amount.toDouble()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isExact ? PosTheme.primaryGreen : Colors.white,
                          foregroundColor: isExact
                              ? Colors.white
                              : PosTheme.textPrimaryOf(context),
                          side: BorderSide(
                              color: isExact
                                  ? PosTheme.primaryGreen
                                  : PosTheme.borderColorOf(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(PosTheme.radiusSmall),
                          ),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: Text(
                          isExact
                              ? context.l10n.paymentScreenExact
                              : formatAmount(amount, _tenderCurrency),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_cashReceived != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: (_amountShort > 0
                              ? PosTheme.warningAmber
                              : PosTheme.primaryGreen)
                          .withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(PosTheme.radiusMedium),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _amountShort > 0
                                ? context.l10n.paymentScreenShort
                                : context.l10n.receiptChange,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _amountShort > 0
                                    ? PosTheme.warningAmber
                                    : PosTheme.primaryGreen),
                          ),
                        ),
                        _dualCurrencyAmount(
                          _amountShort > 0 ? _amountShort : _changeDue,
                          color: _amountShort > 0
                              ? PosTheme.warningAmber
                              : PosTheme.primaryGreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.money, size: 22),
                label: Text(context.l10n.paymentScreenChargeCash,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                onPressed: _chargeCash,
                style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium))),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.call_split, size: 22),
                label: Text(context.l10n.paymentScreenSplitPayment,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                onPressed: _enterSplitMode,
                style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium))),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment, size: 22),
                label: Text(context.l10n.paymentScreenPayFullAmount,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                onPressed: _payFullAmount,
                style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium))),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ]),
      );

  // ═══════════════════════════════════════════════════════════════
  // RIGHT PANEL: SPLITTING
  // ═══════════════════════════════════════════════════════════════
  Widget _rightSplitPanel() {
    final remaining = widget.total - _totalPaid;
    return Container(
      color: PosTheme.backgroundPageOf(context),
      child: Column(children: [
        // Header: total + counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Colors.white,
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      context.l10n.paymentScreenTotalLabel(
                          formatAmount(widget.total, _currency)),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                  Text(
                      remaining > 0
                          ? context.l10n.paymentScreenRemainingLabel(
                              formatAmount(remaining, _currency))
                          : context.l10n.paymentScreenAllPaid,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              remaining > 0 ? FontWeight.w500 : FontWeight.w700,
                          color: remaining > 0
                              ? PosTheme.warningAmber
                              : PosTheme.primaryGreen)),
                ])),
            // +/- counter
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: PosTheme.borderColorOf(context)),
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: _splits.length > 1 ? _decreaseSplits : null),
                SizedBox(
                    width: 36,
                    child: Text('${_splits.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15))),
                IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: _splits.length < 6 ? _increaseSplits : null),
              ]),
            ),
          ]),
        ),
        const Divider(height: 1),
        // Split rows
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _splits.length,
          itemBuilder: (ctx, i) => _splitRow(i),
        )),
        // Bottom bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: SafeArea(
              child: SizedBox(
            width: double.infinity,
            height: 50,
            child: _allPaid
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, size: 22),
                    label: Text(context.l10n.commonDone,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    onPressed: _submitSaleToBackend,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: PosTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(PosTheme.radiusMedium))),
                  )
                : Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Text(context.l10n.paymentScreenRemaining,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: PosTheme.textSecondaryOf(context))),
                          Text(formatAmount(remaining, _currency),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                        ])),
                    Text(
                        context.l10n.paymentScreenOfAmount(
                            formatAmount(widget.total, _currency)),
                        style: TextStyle(
                            fontSize: 13,
                            color: PosTheme.textSecondaryOf(context))),
                  ]),
          )),
        ),
      ]),
    );
  }

  Widget _splitRow(int index) {
    final sp = _splits[index];
    final processing = index == _processingIndex;
    final paid = sp.status == SplitStatus.authorized;
    final canCharge = !paid && _processingIndex < 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: paid
                ? PosTheme.primaryGreen
                : (processing
                    ? sp.method.color
                    : PosTheme.borderColorOf(context)),
            width: paid || processing ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: paid
                    ? PosTheme.primaryGreen
                    : sp.method.color.withOpacity(0.1),
                shape: BoxShape.circle),
            alignment: Alignment.center,
            child: paid
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text('${index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: sp.method.color)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                paid
                    ? Row(children: [
                        Icon(sp.method.icon,
                            size: 14, color: PosTheme.primaryGreen),
                        const SizedBox(width: 4),
                        Text(sp.method.label(context.l10n),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: PosTheme.primaryGreen)),
                        const Spacer(),
                        const Icon(Icons.check_circle,
                            size: 13, color: PosTheme.primaryGreen),
                        const SizedBox(width: 3),
                        Text(context.l10n.receiptPaid,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: PosTheme.primaryGreen)),
                      ])
                    : SizedBox(
                        height: 30,
                        child: DropdownButtonHideUnderline(
                            child: DropdownButton<PaymentMethod>(
                          value: sp.method,
                          isExpanded: true,
                          items: PaymentMethod.values
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Row(children: [
                                      Icon(m.icon, size: 14, color: m.color),
                                      const SizedBox(width: 5),
                                      Text(m.label(context.l10n),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600))
                                    ]),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) _updateSplitMethod(index, v);
                          },
                        ))),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: paid ? null : () => _showAmountEditor(index),
                  child: Text(formatAmount(sp.amount, _currency),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: paid
                              ? PosTheme.primaryGreen
                              : PosTheme.textPrimaryOf(context))),
                ),
              ])),
          if (!paid)
            SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: canCharge ? () => _chargeSplit(index) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCharge
                        ? sp.method.color
                        : sp.method.color.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    elevation: 0,
                  ),
                  child: processing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(context.l10n.paymentScreenCharge,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                )),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STATE: COMPLETED
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCompleted() {
    final sale = _completedSale;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(
            _isSubmitting ? Icons.hourglass_top : Icons.check_circle,
            size: 72,
            color:
                _isSubmitting ? PosTheme.warningAmber : PosTheme.primaryGreen,
          ),
          const SizedBox(height: 16),
          Text(
            _isSubmitting
                ? context.l10n.paymentScreenSubmitting
                : context.l10n.paymentScreenPaymentComplete,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          if (sale?.invoiceNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.paymentScreenInvoiceNumber('${sale!.invoiceNumber}'),
              style: TextStyle(
                  fontSize: 16,
                  color: PosTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: PosTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: PosTheme.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: Text(
              context.l10n.paymentScreenWaitingNumber(
                  widget.waitingNumber.toString().padLeft(3, '0')),
              style: const TextStyle(
                color: PosTheme.primaryGreen,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Receipt card — single receipt with multiple payment types
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
              side: BorderSide(color: PosTheme.borderColorOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt header
                  Center(
                    child: Text(context.l10n.paymentScreenReceiptHeader,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 2)),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      DateTime.now().toString().substring(0, 19),
                      style: TextStyle(
                          fontSize: 11, color: PosTheme.textHintOf(context)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: PosTheme.dividerColorOf(context)),
                  const SizedBox(height: 8),

                  // Total
                  _receiptRow(context.l10n.cartTotal,
                      formatAmount(widget.total, _currency),
                      bold: true, large: true),
                  const SizedBox(height: 12),
                  Divider(color: PosTheme.dividerColorOf(context)),
                  const SizedBox(height: 8),

                  // Payment breakdown
                  Text(context.l10n.paymentScreenPayments,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PosTheme.textSecondaryOf(context))),
                  const SizedBox(height: 8),
                  ..._splits
                      .where((s) => s.status == SplitStatus.authorized)
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _receiptRow(s.method.label(context.l10n),
                                formatAmount(s.amount, _currency),
                                valueColor: s.method.color),
                          )),
                  const SizedBox(height: 8),
                  Divider(color: PosTheme.dividerColorOf(context)),
                  const SizedBox(height: 8),
                  _receiptRow(context.l10n.receiptPaid,
                      formatAmount(_totalPaid, _currency),
                      bold: true),
                  if (_cashReceived != null) ...[
                    _receiptRow(
                        context.l10n.paymentScreenCashReceived,
                        formatAmount(_cashReceivedRaw ?? _cashReceived!,
                            _tenderCurrency)),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.receiptChange,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: PosTheme.textSecondaryOf(context))),
                          _dualCurrencyAmount(
                            _changeDue,
                            color: PosTheme.primaryGreen,
                            primaryFontSize: 15,
                            secondaryFontSize: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons row
          if (!_isSubmitting) ...[
            // Print receipt button
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _preparingPrint
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print, size: 20),
                label: Text(context.l10n.paymentScreenPrintReceipt,
                    style: const TextStyle(fontSize: 16)),
                onPressed: _preparingPrint
                    ? null
                    : () async {
                        setState(() => _preparingPrint = true);
                        // Block on the authoritative receipt rather than
                        // printing from cart-derived guesses — this is
                        // what actually carries tax/discount/paid/change,
                        // and normally resolves instantly since the
                        // background fetch already started at payment
                        // success.
                        final r = await _ensureCompletedReceipt();
                        if (!mounted) return;
                        setState(() => _preparingPrint = false);

                        String? saleDate;
                        String? saleTime;
                        if (r?.createdAt != null) {
                          try {
                            final dt = DateTime.parse(r!.createdAt!);
                            saleDate = formatReceiptDate(dt);
                            saleTime = formatReceiptTime(dt);
                          } catch (_) {}
                        }
                        if (!mounted) return;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ReceiptPreviewScreen(
                            total: r?.total ?? widget.total,
                            subtotal: r?.subtotal ?? widget.total,
                            discountAmount: r?.discountAmount ?? 0,
                            taxAmount: r?.taxAmount ?? 0,
                            deliveryCharge: r?.deliveryCharge ?? 0,
                            otherCharge: r?.otherCharge ?? 0,
                            splits: _splits
                                .where(
                                    (s) => s.status == SplitStatus.authorized)
                                .map((s) => SplitRowReceipt(
                                    methodLabel: s.method.label(context.l10n),
                                    amount: s.amount))
                                .toList(),
                            paidAmountOverride: r?.paidAmount,
                            changeAmountOverride: r?.changeAmount,
                            invoiceNumber: _completedSale?.invoiceNumber,
                            cashierName: _completedSale?.cashierName ?? '',
                            saleItems: _savedSaleItems,
                            businessName: r?.businessName,
                            businessAddress: r?.address,
                            businessPhone: r?.phone,
                            currency: r?.currency,
                            footer: r?.footer,
                            saleDate: saleDate,
                            saleTime: saleTime,
                            tableNumber: r?.tableNumber,
                            // Prefer the rate frozen onto the sale itself;
                            // only fall back to the live Settings rate if
                            // the receipt fetch failed outright.
                            exchangeRateKhr:
                                r?.exchangeRateKhr ?? _rates['KHR']?.ratePerUsd,
                          ),
                        ));
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: PosTheme.textPrimaryOf(context),
                  side: BorderSide(color: PosTheme.borderColorOf(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Email receipt
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                side: BorderSide(color: PosTheme.borderColorOf(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.email_outlined,
                            size: 20, color: PosTheme.textSecondaryOf(context)),
                        const SizedBox(width: 8),
                        Text(context.l10n.paymentScreenEmailReceipt,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'customer@example.com',
                        suffixIcon: Icon(Icons.send, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // New Sale button
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: Text(context.l10n.paymentScreenNewSale,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                onPressed: _newSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                  ),
                ),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(color: PosTheme.primaryGreen),
            ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value,
      {Color? valueColor, bool bold = false, bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: large ? 16 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: PosTheme.textSecondaryOf(context))),
        Text(value,
            style: TextStyle(
                fontSize: large ? 20 : 15,
                fontWeight: FontWeight.w800,
                color: valueColor ?? PosTheme.textPrimaryOf(context))),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STATE: FAILED
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFailed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 72, color: PosTheme.errorRed),
          const SizedBox(height: 16),
          Text(context.l10n.paymentScreenPaymentFailed,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 32),
          ElevatedButton(
              onPressed: _resetSplits,
              child: Text(context.l10n.paymentScreenTryAgain)),
        ],
      ),
    );
  }
}
