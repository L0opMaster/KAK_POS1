import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/config/currency_utils.dart';
import '../models/receipt_models.dart';
import '../providers/receipt_provider.dart';
import '../services/sale_service.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/providers/language_provider.dart';

class ReceiptsScreen extends ConsumerStatefulWidget {
  final int? initialSaleId;
  final int? initialCustomerId;
  final String? initialCustomerName;
  const ReceiptsScreen({
    super.key,
    this.initialSaleId,
    this.initialCustomerId,
    this.initialCustomerName,
  });
  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  bool _showAllSales = false;
  static const List<String?> _statusFilters = [
    null,
    'PAID',
    'PENDING',
    'REFUNDED'
  ];
  final ScrollController _listScrollCtl = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(receiptProvider.notifier).loadActiveShiftSales();
      if (widget.initialSaleId != null) {
        ref.read(receiptProvider.notifier).loadReceipt(widget.initialSaleId!);
      }
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _listScrollCtl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receiptProvider);
    final displaySales = state.filteredSales;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(context.l10n.navReceipts),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndToggle(state),
          _buildStatusFilterChips(state),
          _buildErrorAndCount(state, displaySales),
          Expanded(child: _buildReceiptListOrDetail(state, displaySales)),
        ],
      ),
    );
  }

  void _refresh() {
    if (_showAllSales) {
      ref
          .read(receiptProvider.notifier)
          .loadAllSales(status: ref.read(receiptProvider).statusFilter);
    } else {
      ref.read(receiptProvider.notifier).loadActiveShiftSales();
    }
  }

  // ─────────────────────────────────────────────
  // SEARCH + TOGGLE
  // ─────────────────────────────────────────────

  Widget _buildSearchAndToggle(ReceiptState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: context.l10n.receiptsScreenSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtl.clear();

                          ref.read(receiptProvider.notifier).setSearchQuery('');

                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: PosTheme.backgroundPage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    PosTheme.radiusMedium,
                  ),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                ),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (value) {
                ref.read(receiptProvider.notifier).setSearchQuery(value);

                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(context.l10n.receiptsScreenShiftSegment),
              ),
              ButtonSegment(
                value: true,
                label: Text(context.l10n.commonAll),
              ),
            ],
            selected: {_showAllSales},
            onSelectionChanged: (v) {
              setState(() => _showAllSales = v.first);
              if (v.first) {
                ref
                    .read(receiptProvider.notifier)
                    .loadAllSales(status: state.statusFilter);
              } else {
                ref.read(receiptProvider.notifier).loadActiveShiftSales();
              }
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STATUS FILTER CHIPS
  // ─────────────────────────────────────────────

  Widget _buildStatusFilterChips(ReceiptState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statusFilters.map((status) {
            final selected = state.statusFilter == status;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(
                  status ?? context.l10n.commonAll,
                  style: TextStyle(
                      fontSize: 12, color: selected ? Colors.white : null),
                ),
                selected: selected,
                onSelected: (_) =>
                    ref.read(receiptProvider.notifier).setStatusFilter(status),
                selectedColor: PosTheme.primaryGreen,
                checkmarkColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ERROR + COUNT
  // ─────────────────────────────────────────────

  Widget _buildErrorAndCount(
      ReceiptState state, List<SaleResponse> displaySales) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(state.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        if (!state.loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              context.l10n.receiptsScreenReceiptCount(
                displaySales.length.toString(),
              ),
              style: TextStyle(fontSize: 12, color: PosTheme.textSecondary),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // RECEIPT LIST + DETAIL SPLIT VIEW
  // ─────────────────────────────────────────────

  Widget _buildReceiptListOrDetail(
      ReceiptState state, List<SaleResponse> displaySales) {
    if (state.loading && state.sales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final listPane = RefreshIndicator(
          onRefresh: () async {
            if (_showAllSales) {
              await ref
                  .read(receiptProvider.notifier)
                  .loadAllSales(status: state.statusFilter);
            } else {
              await ref.read(receiptProvider.notifier).loadActiveShiftSales();
            }
          },
          child: displaySales.isEmpty
              ? ListView(children: [_buildEmptyState()])
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _listScrollCtl,
                  itemCount: displaySales.length,
                  itemBuilder: (_, i) => _buildSaleCard(displaySales[i]),
                ),
        );
        final detailPane = state.selectedReceipt == null
            ? _buildSelectHint()
            : _buildReceiptView(state.selectedReceipt!);
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              Expanded(flex: 4, child: listPane),
              Container(height: 1, color: PosTheme.dividerColor),
              Expanded(flex: 5, child: detailPane),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 4, child: listPane),
            Container(width: 1, color: PosTheme.dividerColor),
            Expanded(flex: 5, child: detailPane),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────

  Widget _buildEmptyState() {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(context.l10n.receiptsScreenEmptyTitle,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500])),
            const SizedBox(height: 6),
            Text(context.l10n.receiptsScreenEmptySubtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(context.l10n.receiptsScreenSelectHint,
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SALE LIST CARD
  // ─────────────────────────────────────────────

  Widget _buildSaleCard(SaleResponse sale) {
    final isPaid = sale.status == 'PAID' || sale.status == 'COMPLETED';
    final fmt = (double v) => formatAmount(v, sale.currency);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: PosTheme.dividerColor.withOpacity(0.8)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => ref.read(receiptProvider.notifier).loadReceipt(sale.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Left: status icon + info
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPaid
                            ? Icons.check_circle_rounded
                            : Icons.access_time_rounded,
                        size: 18,
                        color: isPaid ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.invoiceNumber ??
                              context.l10n.receiptsScreenSaleFallback(
                                sale.id.toString(),
                              ),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              sale.customerName ??
                                  context.l10n.receiptsScreenWalkIn,
                              style: TextStyle(
                                  fontSize: 12, color: PosTheme.textSecondary),
                            ),
                            if (sale.createdAt != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(sale.createdAt!),
                                style: TextStyle(
                                    fontSize: 11, color: PosTheme.textHint),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Right: total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt(sale.grandTotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sale.status,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isPaid ? Colors.green : Colors.orange),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return context.l10n.receiptsScreenJustNow;
      if (diff.inHours < 1) {
        return context.l10n.receiptsScreenMinutesAgo(
          diff.inMinutes.toString(),
        );
      }
      if (diff.inHours < 24) {
        return context.l10n.receiptsScreenHoursAgo(diff.inHours.toString());
      }
      if (diff.inDays < 7) {
        return context.l10n.receiptsScreenDaysAgo(diff.inDays.toString());
      }
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return iso;
    }
  }

  // ─────────────────────────────────────────────
  // RECEIPT DETAIL VIEW
  // ─────────────────────────────────────────────

  Widget _buildReceiptView(ReceiptResponse receipt) {
    String _fmt(double v) => formatAmount(v, receipt.currency);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ═══ HEADER ═══
              Center(
                  child: Text(context.l10n.appName,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.0))),
              const SizedBox(height: 4),
              if (receipt.businessName != null)
                Center(
                    child: Text(receipt.businessName!,
                        style:
                            TextStyle(fontSize: 9, color: Colors.grey[500]))),
              if (receipt.address != null)
                Center(
                    child: Text(receipt.address!,
                        style:
                            TextStyle(fontSize: 9, color: Colors.grey[500]))),
              if (receipt.phone != null)
                Center(
                    child: Text(
                        context.l10n.receiptsScreenTelLabel(receipt.phone!),
                        style:
                            TextStyle(fontSize: 9, color: Colors.grey[500]))),
              const SizedBox(height: 14),
              _miniDivider,
              const SizedBox(height: 14),

              // ═══ INFO ═══
              _infoLine(context.l10n.receiptsScreenReceiptNoLabel,
                  receipt.saleNumber ?? '#${receipt.saleId}'),
              if (receipt.createdAt != null)
                _infoLine(context.l10n.receiptDate, receipt.createdAt!),
              if (receipt.cashierName != null)
                _infoLine(context.l10n.receiptCashier, receipt.cashierName!),
              if (receipt.customerName != null)
                _infoLine(
                    context.l10n.receiptCustomer, receipt.customerName!),
              if (receipt.orderMode != null)
                _infoLine(
                    context.l10n.receiptsScreenModeLabel, receipt.orderMode!),
              if (receipt.tableNumber != null && receipt.tableNumber!.isNotEmpty)
                _infoLine(context.l10n.receiptTable, receipt.tableNumber!),
              const SizedBox(height: 14),
              _miniDivider,
              const SizedBox(height: 14),

              // ═══ ITEMS ═══
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(context.l10n.receiptsScreenDescriptionHeader,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700])),
                  const Spacer(),
                  SizedBox(
                      width: 30,
                      child: Text(context.l10n.receiptQty,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[700]))),
                  SizedBox(
                      width: 58,
                      child: Text(context.l10n.receiptTotal,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[700]))),
                ],
              ),
              const SizedBox(height: 4),
              _miniDivider,
              const SizedBox(height: 8),
              if (receipt.lines.isNotEmpty)
                ...receipt.lines
                    .map((l) => _buildLineItem(l, receipt.currency)),
              const SizedBox(height: 14),
              _miniDivider,
              const SizedBox(height: 14),

              // ═══ TOTALS ═══
              _buildTotals(receipt, receipt.currency),
              const SizedBox(height: 14),
              _miniDivider,
              const SizedBox(height: 14),

              // ═══ PAYMENTS ═══
              if (receipt.payments.isNotEmpty) ...[
                ...receipt.payments.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                p.method ??
                                    context.l10n.receiptsScreenPaymentFallback,
                                style: const TextStyle(fontSize: 12)),
                            Text(_fmt(p.amount),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                    )),
                const SizedBox(height: 14),
                _miniDivider,
                const SizedBox(height: 14),
              ],

              // ═══ STATUS ═══
              if (receipt.status != null)
                Center(
                  child: Text(
                    receipt.status!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: (receipt.status == 'PAID' ||
                              receipt.status == 'COMPLETED')
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // ═══ THREE-DOT MENU + ACTIONS ═══
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (receipt.status == 'PAID' || receipt.status == 'COMPLETED')
                    TextButton.icon(
                      onPressed: () => _showRefundDialog(context, receipt),
                      icon: const Icon(Icons.replay, size: 16),
                      label: Text(context.l10n.receiptsScreenRefund,
                          style: const TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'print') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  context.l10n.receiptsScreenPrintNotConnected)),
                        );
                      } else if (value == 'email') {
                        _showEmailDialog(context, receipt);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'print',
                          child: ListTile(
                              leading: const Icon(Icons.print, size: 20),
                              title:
                                  Text(context.l10n.receiptsScreenPrintReceipt),
                              dense: true,
                              contentPadding: EdgeInsets.zero)),
                      PopupMenuItem(
                          value: 'email',
                          child: ListTile(
                              leading: const Icon(Icons.email, size: 20),
                              title: Text(
                                  context.l10n.receiptsScreenSendByEmail),
                              dense: true,
                              contentPadding: EdgeInsets.zero)),
                    ],
                  ),
                ],
              ),

              // ═══ FOOTER ═══
              const SizedBox(height: 16),
              if (receipt.footer != null)
                Center(
                    child: Text(receipt.footer!,
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[500])))
              else ...[
                Center(
                    child: Text(context.l10n.receiptsScreenThankYouFooter,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700))),
                const SizedBox(height: 4),
                Center(
                    child: Text('www.kaknnea.com',
                        style:
                            TextStyle(fontSize: 8, color: Colors.grey[500]))),
                const SizedBox(height: 2),
                Center(
                    child: Text(context.l10n.receiptsScreenPoweredBy,
                        style:
                            TextStyle(fontSize: 7, color: Colors.grey[500]))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget get _miniDivider => Container(height: 1, color: Colors.grey[200]);

  IconData _paymentIcon(String? method) {
    switch (method?.toUpperCase()) {
      case 'CASH':
        return Icons.money;
      case 'CARD':
      case 'CREDIT_CARD':
      case 'VISA':
      case 'MASTERCARD':
        return Icons.credit_card;
      case 'QR':
      case 'QR_CODE':
        return Icons.qr_code;
      case 'MOBILE':
      case 'WALLET':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }

  void _showEmailDialog(BuildContext context, ReceiptResponse receipt) {
    final emailCtl = TextEditingController(text: receipt.customerPhone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.receiptsScreenEmailDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.receiptsScreenEmailDialogBody),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtl,
              decoration: InputDecoration(
                hintText: context.l10n.receiptsScreenEmailHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.receiptsScreenReceiptSentTo(emailCtl.text),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(context.l10n.receiptsScreenSendButton),
          ),
        ],
      ),
    );
  }

  void _showRefundDialog(BuildContext context, ReceiptResponse receipt) {
    final remaining = receipt.total - receipt.refundedAmount;
    final reasonCtl = TextEditingController();
    final managerEmailCtl = TextEditingController();
    final managerPasswordCtl = TextEditingController();
    bool submitting = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            setDialogState(() {
              submitting = true;
              error = null;
            });
            try {
              await ref.read(saleServiceProvider).refundSale(
                    receipt.saleId,
                    amount: remaining,
                    method: 'CASH',
                    reason: reasonCtl.text.trim(),
                    managerEmail: managerEmailCtl.text.trim(),
                    managerPassword: managerPasswordCtl.text,
                  );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await ref
                  .read(receiptProvider.notifier)
                  .loadReceipt(receipt.saleId);
              _refresh();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.receiptsScreenRefundSubmitted),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              setDialogState(() {
                submitting = false;
                error = e.toString();
              });
            }
          }

          return AlertDialog(
            title: Text(context.l10n.receiptsScreenRefund),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.l10n.receiptsScreenRefundConfirmPrefix(receipt.saleNumber ?? context.l10n.receiptsScreenRefundReceiptFallback(receipt.saleId.toString()))}\n\n'
                    '${context.l10n.receiptsScreenRefundTotalLine('\$${receipt.total.toStringAsFixed(2)}')}'
                    '${receipt.refundedAmount > 0 ? '\n${context.l10n.receiptsScreenRefundAlreadyRefundedLine('\$${receipt.refundedAmount.toStringAsFixed(2)}')}' : ''}'
                    '\n${context.l10n.receiptsScreenRefundAmountLine('\$${remaining.toStringAsFixed(2)}')}',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtl,
                    enabled: !submitting,
                    decoration: InputDecoration(
                        labelText: context.l10n.receiptsScreenReasonOptionalLabel,
                        isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: managerEmailCtl,
                    enabled: !submitting,
                    decoration: InputDecoration(
                        labelText: context.l10n.receiptsScreenManagerEmailLabel,
                        isDense: true),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: managerPasswordCtl,
                    enabled: !submitting,
                    decoration: InputDecoration(
                        labelText:
                            context.l10n.receiptsScreenManagerPasswordLabel,
                        isDense: true),
                    obscureText: true,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: Text(context.l10n.commonCancel),
              ),
              ElevatedButton(
                onPressed: submitting || remaining <= 0 ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosTheme.errorRed,
                  foregroundColor: Colors.white,
                ),
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(context.l10n.receiptsScreenConfirmRefundButton),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INFO LINE
  // ─────────────────────────────────────────────

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LINE ITEM
  // ─────────────────────────────────────────────

  Widget _buildLineItem(ReceiptLine line, String? currency) {
    final fmt = (double v) => formatAmount(v, currency);
    final lang = ref.watch(appLanguageProvider);
    final localizedLineName = line.localizedName(lang);
    final unitFallback = context.l10n.receiptsScreenEachUnitFallback;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Qty badge
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosTheme.backgroundPage,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: PosTheme.dividerColor),
            ),
            child: Text(
              line.qty.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedLineName.isEmpty
                      ? context.l10n.receiptsScreenItemFallback
                      : localizedLineName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  line.modifierAmount != 0
                      ? '${context.l10n.receiptsScreenBaseWithUnit(fmt(line.basePrice), line.unitSymbol ?? unitFallback)}'
                          ' + ${context.l10n.receiptsScreenModifiersWithUnit(fmt(line.modifierAmount), line.unitSymbol ?? unitFallback)}'
                      : fmt(line.unitPrice) +
                          (line.unitSymbol != null
                              ? ' /${line.unitSymbol}'
                              : ''),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                if (line.modifierSummary != null &&
                    line.modifierSummary!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    line.modifierSummary!,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmt(line.lineTotal),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TOTALS
  // ─────────────────────────────────────────────

  Widget _buildTotals(ReceiptResponse r, String? currency) {
    final fmt = (double v) => formatAmount(v, currency);
    return Column(
      children: [
        _totalRow(context.l10n.receiptSubtotal, fmt(r.subtotal)),
        if (r.discountAmount > 0)
          _totalRow(context.l10n.receiptDiscount, '-${fmt(r.discountAmount)}'),
        if (r.taxAmount > 0) _totalRow(context.l10n.receiptTax, fmt(r.taxAmount)),
        if (r.deliveryCharge > 0)
          _totalRow(
              context.l10n.receiptsScreenDeliveryLabel, fmt(r.deliveryCharge)),
        if (r.otherCharge > 0)
          _totalRow(context.l10n.receiptsScreenOtherLabel, fmt(r.otherCharge)),
        const Divider(height: 16),
        _totalRow(context.l10n.receiptTotal, fmt(r.total),
            bold: true, large: true),
        if (r.paidAmount > 0 && r.paidAmount != r.total)
          _totalRow(context.l10n.receiptPaid, fmt(r.paidAmount)),
        if (r.changeAmount > 0)
          _totalRow(context.l10n.receiptChange, fmt(r.changeAmount)),
        // Riel conversion, using the rate frozen onto this sale at the time
        // it was made — never the live Settings rate — so an old receipt
        // keeps showing the rate that was actually in effect back then.
        if ((r.exchangeRateKhr ?? 0) > 0 &&
            currency?.toUpperCase() != 'KHR') ...[
          const Divider(height: 16),
          _totalRow(
              context.l10n.receiptExchangeRate,
              context.l10n.receiptsScreenExchangeRateValue(
                  _khrGroup(r.exchangeRateKhr!))),
          _totalRow(context.l10n.receiptsScreenTotalRielLabel,
              '${_khrGroup(r.total * r.exchangeRateKhr!)} ៛',
              bold: true),
        ],
      ],
    );
  }

  /// Groups a riel amount with thousands separators and no decimals
  /// (e.g. 82000 -> "82,000"), since riel is never quoted in cents.
  String _khrGroup(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _totalRow(String label, String value,
      {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: large ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 18 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
