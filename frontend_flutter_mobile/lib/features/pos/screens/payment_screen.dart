import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/currency_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';
import '../providers/held_ticket_provider.dart';
import '../services/sale_service.dart';
import 'receipt_preview_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// Enums — ported from `frontend-flutter-pos/lib/features/pos/screens/
// payment_screen.dart` verbatim (PaymentMethod, SplitRow/SplitStatus,
// paymentRequestEntry).
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
  other,
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
/// [split.amount] is the amount APPLIED to the sale — for cash it's capped
/// at the total (see `_chargeCash`) so it never overshoots on screen. For a
/// cash split, [cashReceived] is what the customer actually tendered; when
/// that's more than what was applied, this sends the tendered amount
/// instead, so the backend's own `appliedAmount = min(requestTotal,
/// remaining)` / `changeAmount = requestTotal - appliedAmount` computes the
/// customer's real change.
Map<String, dynamic> paymentRequestEntry(SplitRow split, double? cashReceived) {
  final tendered = split.method == PaymentMethod.cash ? cashReceived : null;
  final amount = (tendered != null && tendered > split.amount)
      ? tendered
      : split.amount;
  return {'method': split.method.code, 'amount': amount};
}

// ═══════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════

/// ADAPTED from `frontend-flutter-pos/lib/features/pos/screens/
/// payment_screen.dart` — the enums above, split arithmetic
/// (`_rebalance`/`_increaseSplits`/`_decreaseSplits`), the `_clientRef`
/// idempotency pattern, dual-currency cash tender (`_convert`/`_rates`/
/// `_changeDue`/`_amountShort`), and `_submitSaleToBackend`'s core sequence
/// are all COPY/ADAPT NEARLY EXACTLY. The 2-column desktop `Row` (cart
/// items | payment panel) is MOBILE UI REIMPLEMENT'd as a single vertical
/// `Column`/`ListView`.
///
/// Three things source's screen does that this one deliberately doesn't,
/// none of them silent — see `_submitSaleToBackend`'s doc comment for why:
/// the waiting-tickets queue board save (dropped, Day 9), the paired
/// customer-facing display broadcast (`customerDisplayProvider` — a
/// desktop-companion-screen feature with no mobile equivalent, never in
/// this task's scope), and the receipt fetch / auto-print (Day 12/13
/// scope, not built yet).
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

  SaleResponse? _completedSale;
  bool _isSubmitting = false;
  String _currency = 'KHR';

  // Snapshot of the cart's items/subtotal/discount/tax right before it's
  // cleared on successful payment — the completed screen's "View Receipt"
  // button needs these for `ReceiptViewModel.fromCart` after the cart
  // itself has already emptied out.
  List<CartItem> _savedSaleItems = [];
  double _savedSubtotal = 0;
  double _savedDiscountAmount = 0;
  double _savedTaxAmount = 0;

  // Cash tendered by the customer for a full-amount cash payment, converted
  // into the store's currency (`_currency`). `widget.total` already
  // reflects discounts and modifier price deltas, so change is simply
  // tendered - total.
  double? _cashReceived;

  // The currency the customer is actually handing over (e.g. paying in
  // Riel even though prices are quoted in USD) and the raw number entered
  // in that currency, before conversion.
  String _tenderCurrency = 'KHR';
  double? _cashReceivedRaw;
  final _cashReceivedCtl = TextEditingController();

  // Exchange rates for currencies a customer can pay cash in, each
  // "units of that currency per 1 USD". Seeded with the standard USD/KHR
  // pairing so the screen works before the backend value loads.
  Map<String, TenderCurrency> _rates = const {
    'USD': TenderCurrency(code: 'USD', symbol: r'$', ratePerUsd: 1),
    'KHR': TenderCurrency(code: 'KHR', symbol: '៛', ratePerUsd: 4100),
  };

  double _convert(double amount, String fromCode, String toCode) {
    final fromRate = _rates[fromCode]?.ratePerUsd ?? 1;
    final toRate = _rates[toCode]?.ratePerUsd ?? 1;
    return amount / fromRate * toRate;
  }

  /// Renders [amountInStoreCurrency] as both a dollar and a riel figure
  /// stacked, since change is handed back in whichever bills the drawer
  /// has regardless of what the customer paid with.
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
          color: color,
        ),
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
            color: color,
          ),
        ),
        Text(
          '${_currency == 'KHR' ? '' : '≈ '}${formatAmount(khr, 'KHR')}',
          style: TextStyle(
            fontSize: secondaryFontSize,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // Stable idempotency key for this checkout, generated once so a retry
  // after a timeout/network error reuses the same key — the backend
  // dedupes on `clientRef` and returns the existing sale instead of
  // creating a duplicate.
  final String _clientRef = const Uuid().v4();

  String _getOrderModeFromCart() {
    switch (ref.read(cartProvider).orderMode) {
      case OrderMode.dineIn:
        return 'DINE_IN';
      case OrderMode.takeaway:
        return 'TAKEAWAY';
      case OrderMode.delivery:
        return 'DELIVERY';
    }
  }

  List<double> _quickCashAmounts() {
    if (_tenderCurrency == 'KHR') {
      return [1000, 5000, 10000, 20000, 50000, 100000];
    }
    return [1, 5, 10, 20, 50, 100];
  }

  void _setTenderCurrency(String code) {
    if (code == _tenderCurrency) return;
    setState(() {
      _tenderCurrency = code;
      _cashReceivedRaw = null;
      _cashReceived = null;
      _cashReceivedCtl.clear();
    });
  }

  void _onCashReceivedChanged(String text) {
    final raw = double.tryParse(text);
    setState(() {
      _cashReceivedRaw = raw;
      _cashReceived = raw == null
          ? null
          : _convert(raw, _tenderCurrency, _currency);
    });
  }

  double get _totalPaid => _splits
      .where((s) => s.status == SplitStatus.authorized)
      .fold(0.0, (sum, s) => sum + s.amount);

  bool get _allPaid =>
      _splits.isNotEmpty &&
      _splits.every((s) => s.status == SplitStatus.authorized);

  double get _changeDue {
    final received = _cashReceived;
    if (received == null) return 0;
    final diff = received - widget.total;
    return diff > 0 ? diff : 0;
  }

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
    try {
      final cur = readCurrency(ref);
      if (cur.isNotEmpty) _currency = cur;
    } catch (_) {}
    _tenderCurrency = _currency;

    ref
        .read(tenderCurrenciesProvider.future)
        .then((rates) {
          if (mounted && rates.isNotEmpty) setState(() => _rates = rates);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
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

  /// Distribute [widget.total] across all rows equally. Last row absorbs
  /// the cent remainder.
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
  }

  void _payFullAmount() {
    _cashReceived = null;
    _cashReceivedRaw = null;
    _splits = [SplitRow(id: 0)];
    _splits[0].amount = widget.total;
    _splits[0].status = SplitStatus.authorized;
    _submitSaleToBackend();
  }

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

  /// Submit the sale and all payments to the backend API. Adapted from
  /// source's 6-step `_submitSaleToBackend`: steps 1-3 (create, pay,
  /// release the resumed held ticket) and the final cart clear are ported
  /// as-is; steps 4 (waiting-tickets queue board save) and 6 (receipt
  /// fetch/auto-print) are out of this port's scope (see this class's doc
  /// comment). One deliberate adaptation to step 5's `clear()` call:
  /// source passes `releaseWaitingNumber: false` because its queue board
  /// (dropped here) is what releases the number later, when the customer
  /// presses "Collected". Without that screen, `false` here would leak the
  /// waiting number forever (never released) — so this port releases it
  /// immediately on successful payment instead (the default `clear()`
  /// behavior), which is the correct equivalent for a device with no
  /// separate "order collected" step.
  Future<void> _submitSaleToBackend() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final CartState cartSnapshot = ref.read(cartProvider);
      final saleService = ref.read(saleServiceProvider);

      // Snapshot before the cart clears below — the completed screen's
      // "View Receipt" button needs these once the cart is empty again.
      _savedSaleItems = List<CartItem>.from(cartSnapshot.items);
      _savedSubtotal = cartSnapshot.total;
      _savedDiscountAmount = cartSnapshot.discountAmount;
      _savedTaxAmount = cartSnapshot.taxAmount;

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
        // The backend recomputes tax/discount/total server-side from
        // these — omitting them is exactly why a sale would otherwise
        // record zero tax.
        'taxRate': cartSnapshot.taxRate,
        if (cartSnapshot.discountAmount > 0)
          'invoiceDiscount': cartSnapshot.discountAmount,
      };

      // 1. CREATE (DRAFT, no money moved, no stock deducted yet)
      final saleResponse = await saleService.createSale(request);
      final saleId = saleResponse.id;

      SaleResponse? payResponse;
      // 2. PAY — only if authorized splits exist; else the sale is
      // created but never actually paid.
      if (payments.isNotEmpty) {
        payResponse = await saleService.paySale(saleId, payments);
      } else {
        payResponse = saleResponse;
      }

      if (!mounted) return;

      // 3. release held ticket — fire-and-forget, non-fatal (see
      // HeldTicketNotifier.releaseTicketById's own doc comment).
      if (widget.heldTicketId != null) {
        unawaited(
          ref
              .read(heldTicketProvider.notifier)
              .releaseTicketById(widget.heldTicketId!),
        );
      }

      // 4. clear cart — releases the waiting number immediately (see this
      // method's doc comment for why that differs from source).
      await ref.read(cartProvider.notifier).clear();

      if (mounted) {
        setState(() {
          _completedSale = payResponse;
          _paymentState = PaymentState.completed;
          _isSubmitting = false;
        });
      }
    } catch (e) {
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

  void _newSale() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _showAmountEditor(int index) async {
    final split = _splits[index];
    final ctl = TextEditingController(text: split.amount.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ctx.l10n.paymentScreenSplitAmountTitle((index + 1).toString()),
        ),
        content: TextField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            prefixText: '${currencySymbol(_currency)} ',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
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
        return _buildIdle();
      case PaymentState.splitting:
        return _buildSplitting();
      case PaymentState.completed:
        return _buildCompleted();
      case PaymentState.failed:
        return _buildFailed();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // IDLE — total, cash-received calculator, action buttons
  // ═══════════════════════════════════════════════════════════════
  Widget _buildIdle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PosTheme.spacingLg),
      child: Column(
        children: [
          Text(
            formatAmount(widget.total, _currency),
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: PosTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.paymentScreenTotalDue,
            style: TextStyle(
              fontSize: 14,
              color: PosTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: PosTheme.spacingXl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  context.l10n.paymentScreenCashReceived,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PosTheme.textSecondaryOf(context),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    (_rates.keys.toList()
                          ..sort((a, b) => a == _currency ? -1 : 1))
                        .map((code) {
                          final selected = code == _tenderCurrency;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: GestureDetector(
                              onTap: () => _setTenderCurrency(code),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? PosTheme.primaryGreen
                                      : PosTheme.backgroundCardOf(context),
                                  borderRadius: BorderRadius.circular(
                                    PosTheme.radiusPill,
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? PosTheme.primaryGreen
                                        : PosTheme.borderColorOf(context),
                                  ),
                                ),
                                child: Text(
                                  '${_rates[code]?.symbol ?? code} $code',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : PosTheme.textSecondaryOf(context),
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),
              ),
            ],
          ),
          const SizedBox(height: PosTheme.spacingSm),
          TextField(
            controller: _cashReceivedCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                _tenderCurrency == 'KHR'
                    ? RegExp(r'^\d*')
                    : RegExp(r'^\d*\.?\d{0,2}'),
              ),
            ],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              prefixText:
                  _rates[_tenderCurrency]?.symbol ??
                  currencySymbol(_tenderCurrency),
              hintText: _tenderCurrency == 'KHR' ? '0' : '0.00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
              ),
            ),
            onChanged: _onCashReceivedChanged,
          ),
          const SizedBox(height: PosTheme.spacingSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _quickCashAmounts().map((amount) {
              final totalInTender = _convert(
                widget.total,
                _currency,
                _tenderCurrency,
              );
              final tolerance = _tenderCurrency == 'KHR' ? 50 : 0.01;
              final isExact = (amount - totalInTender).abs() < tolerance;
              return SizedBox(
                width: 82,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => _selectCashReceived(amount.toDouble()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExact
                        ? PosTheme.primaryGreen
                        : PosTheme.backgroundCardOf(context),
                    foregroundColor: isExact
                        ? Colors.white
                        : PosTheme.textPrimaryOf(context),
                    side: BorderSide(
                      color: isExact
                          ? PosTheme.primaryGreen
                          : PosTheme.borderColorOf(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
                    ),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                  ),
                  child: Text(
                    isExact
                        ? context.l10n.paymentScreenExact
                        : formatAmount(amount, _tenderCurrency),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_cashReceived != null) ...[
            const SizedBox(height: PosTheme.spacingMd),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    (_amountShort > 0
                            ? PosTheme.warningAmber
                            : PosTheme.primaryGreen)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
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
                            : PosTheme.primaryGreen,
                      ),
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
          const SizedBox(height: PosTheme.spacingXl),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.money, size: 22),
              label: Text(
                context.l10n.paymentScreenChargeCash,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isSubmitting ? null : _chargeCash,
              style: ElevatedButton.styleFrom(
                backgroundColor: PosTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.call_split, size: 22),
              label: Text(
                context.l10n.paymentScreenSplitPayment,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isSubmitting ? null : _enterSplitMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: PosTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.payment, size: 22),
              label: Text(
                context.l10n.paymentScreenPayFullAmount,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isSubmitting ? null : _payFullAmount,
              style: ElevatedButton.styleFrom(
                backgroundColor: PosTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SPLITTING
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSplitting() {
    final remaining = widget.total - _totalPaid;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PosTheme.spacingLg,
            vertical: PosTheme.spacingMd,
          ),
          color: PosTheme.backgroundCardOf(context),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.paymentScreenTotalLabel(
                        formatAmount(widget.total, _currency),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      remaining > 0
                          ? context.l10n.paymentScreenRemainingLabel(
                              formatAmount(remaining, _currency),
                            )
                          : context.l10n.paymentScreenAllPaid,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: remaining > 0
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: remaining > 0
                            ? PosTheme.warningAmber
                            : PosTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: PosTheme.borderColorOf(context)),
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _splits.length > 1 ? _decreaseSplits : null,
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${_splits.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _splits.length < 6 ? _increaseSplits : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _splits.length,
            itemBuilder: (ctx, i) => _splitRow(i),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PosTheme.spacingLg,
            vertical: PosTheme.spacingMd,
          ),
          color: PosTheme.backgroundCardOf(context),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: _allPaid
                  ? ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, size: 22),
                      label: Text(
                        context.l10n.commonDone,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _submitSaleToBackend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PosTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PosTheme.radiusMedium,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                context.l10n.paymentScreenRemaining,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: PosTheme.textSecondaryOf(context),
                                ),
                              ),
                              Text(
                                formatAmount(remaining, _currency),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            context.l10n.paymentScreenOfAmount(
                              formatAmount(widget.total, _currency),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: PosTheme.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
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
          width: paid || processing ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: paid
                    ? PosTheme.primaryGreen
                    : sp.method.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: paid
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: sp.method.color,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  paid
                      ? Row(
                          children: [
                            Icon(
                              sp.method.icon,
                              size: 14,
                              color: PosTheme.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                sp.method.label(context.l10n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: PosTheme.primaryGreen,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.check_circle,
                              size: 13,
                              color: PosTheme.primaryGreen,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              context.l10n.receiptPaid,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: PosTheme.primaryGreen,
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          height: 30,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<PaymentMethod>(
                              value: sp.method,
                              isExpanded: true,
                              items: PaymentMethod.values
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Row(
                                        children: [
                                          Icon(
                                            m.icon,
                                            size: 14,
                                            color: m.color,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            m.label(context.l10n),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) _updateSplitMethod(index, v);
                              },
                            ),
                          ),
                        ),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: paid ? null : () => _showAmountEditor(index),
                    child: Text(
                      formatAmount(sp.amount, _currency),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: paid
                            ? PosTheme.primaryGreen
                            : PosTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!paid)
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: canCharge ? () => _chargeSplit(index) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCharge
                        ? sp.method.color
                        : sp.method.color.withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    elevation: 0,
                  ),
                  child: processing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.l10n.paymentScreenCharge,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPLETED — simplified from source: no print/email (Day 12/13 scope,
  // not built yet). Just a summary and a way back to the register.
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCompleted() {
    final sale = _completedSale;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PosTheme.spacingLg),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.check_circle, size: 72, color: PosTheme.primaryGreen),
          const SizedBox(height: 16),
          Text(
            context.l10n.paymentScreenPaymentComplete,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          if (sale?.invoiceNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.paymentScreenInvoiceNumber('${sale!.invoiceNumber}'),
              style: TextStyle(
                fontSize: 16,
                color: PosTheme.textSecondaryOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: PosTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: PosTheme.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              context.l10n.paymentScreenWaitingNumber(
                widget.waitingNumber.toString().padLeft(3, '0'),
              ),
              style: TextStyle(
                color: PosTheme.primaryGreen,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
              side: BorderSide(color: PosTheme.borderColorOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _receiptRow(
                    context.l10n.cartTotal,
                    formatAmount(widget.total, _currency),
                    bold: true,
                    large: true,
                  ),
                  const SizedBox(height: 12),
                  Divider(color: PosTheme.dividerColorOf(context)),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.paymentScreenPayments,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PosTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._splits
                      .where((s) => s.status == SplitStatus.authorized)
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _receiptRow(
                            s.method.label(context.l10n),
                            formatAmount(s.amount, _currency),
                            valueColor: s.method.color,
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                  Divider(color: PosTheme.dividerColorOf(context)),
                  const SizedBox(height: 8),
                  _receiptRow(
                    context.l10n.receiptPaid,
                    formatAmount(_totalPaid, _currency),
                    bold: true,
                  ),
                  if (_cashReceived != null) ...[
                    const SizedBox(height: 6),
                    _receiptRow(
                      context.l10n.paymentScreenCashReceived,
                      formatAmount(
                        _cashReceivedRaw ?? _cashReceived!,
                        _tenderCurrency,
                      ),
                    ),
                  ],
                  if (_cashReceived != null && _changeDue > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.receiptChange,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: PosTheme.textSecondaryOf(context),
                          ),
                        ),
                        _dualCurrencyAmount(
                          _changeDue,
                          color: PosTheme.primaryGreen,
                          primaryFontSize: 15,
                          secondaryFontSize: 12,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long_outlined, size: 20),
              label: Text(context.l10n.receiptsScreenPrintReceipt),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReceiptPreviewScreen(
                    total: widget.total,
                    subtotal: _savedSubtotal,
                    discountAmount: _savedDiscountAmount,
                    taxAmount: _savedTaxAmount,
                    splits: _splits
                        .where((s) => s.status == SplitStatus.authorized)
                        .map(
                          (s) => SplitRowReceipt(
                            methodLabel: s.method.label(context.l10n),
                            amount: s.amount,
                          ),
                        )
                        .toList(),
                    invoiceNumber: _completedSale?.invoiceNumber,
                    cashierName: _completedSale?.cashierName ?? '',
                    saleItems: _savedSaleItems,
                    currency: _currency,
                    // No human-readable table name available here — only
                    // `widget.tableId` (a raw backend id), and
                    // `tableSelectionProvider`'s selection has already
                    // moved on by the time payment completes. Showing the
                    // raw id would read as a typo, not a table number.
                    paidAmountOverride: _completedSale?.paidAmount,
                    changeAmountOverride: _changeDue,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 22),
              label: Text(
                context.l10n.paymentScreenNewSale,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
        ],
      ),
    );
  }

  Widget _receiptRow(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
    bool large = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: large ? 16 : 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: PosTheme.textSecondaryOf(context),
            ),
          ),
        ),
        const SizedBox(width: PosTheme.spacingSm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: large ? 20 : 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? PosTheme.textPrimaryOf(context),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FAILED
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFailed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 72, color: PosTheme.errorRed),
          const SizedBox(height: 16),
          Text(
            context.l10n.paymentScreenPaymentFailed,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _resetSplits,
            child: Text(context.l10n.paymentScreenTryAgain),
          ),
        ],
      ),
    );
  }
}
