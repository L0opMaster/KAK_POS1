import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/receipt_models.dart';
import '../providers/receipt_provider.dart';
import '../services/print_service.dart';
import '../services/printing/receipt_view_model.dart';
import '../services/printing/thermal_printer_service.dart';
import '../services/sale_service.dart';
import '../widgets/receipt_paper_view.dart';

/// MOBILE UI REIMPLEMENT of `frontend-flutter-pos/lib/features/pos/
/// screens/receipts_screen.dart`. Source is a responsive split-pane
/// (list | detail, side-by-side above a 900px width breakpoint, stacked
/// below it) with no push navigation for the detail at all — on a phone
/// that breakpoint is never crossed, so this port replaces the stacked
/// pane with a real push: tapping a sale card navigates to a full-screen
/// `_ReceiptDetailScreen` instead of squeezing the receipt into half the
/// remaining vertical space beneath the list.
///
/// Search/status-filter/shift-vs-all-sales toggle, `saleMatchesStatusFilter`
/// / `backendStatusQueryFor`, the status color/icon/label mapping, and the
/// Refund button's exact status gating (`PAID`/`PARTIALLY_REFUNDED` only)
/// are all COPY/ADAPT NEARLY EXACTLY.
///
/// Print One / Save PDF added Day 13, once `print_service.dart` existed —
/// `_printOne` mirrors source's fetch-then-print split (a load failure
/// gets its own message, distinct from a printer failure) and `_savePdf`
/// mirrors source's `buildReceiptPdf` + `Printing.sharePdf` exactly. Still
/// DROPPED: **Print All** (needs `buildReceiptsPdf`/bounded-concurrency
/// batching — a bigger feature than "Day 13: print button", not core to
/// this day's scope) and **Send by Email** (source's own version is a
/// non-functional stub — no real email API call is wired up there either
/// — reproducing a fake "sent" toast has no value). Refund never depended
/// on printing (a plain `SaleService.refundSale` call, ported Day 11).
class ReceiptsScreen extends ConsumerStatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  bool _showAllSales = false;
  static const List<String?> _statusFilters = [
    null,
    'PAID',
    'VOID',
    'REFUNDED',
  ];

  /// Sale ids with an in-flight "Print One" — disables that row's button
  /// and prevents a repeated tap from firing a second print job.
  final Set<int> _printingIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(receiptProvider.notifier).loadActiveShiftSales(),
    );
  }

  /// Reuses `PrintService.printReceipt(context, saleId)` unchanged — same
  /// call the post-checkout print button uses — so this screen never grows
  /// a second receipt-printing pipeline. Fetches the receipt first, on its
  /// own, so a load failure gets its own message — `PrintService
  /// .printReceipt` bundles "couldn't fetch the receipt" and "couldn't
  /// reach the printer" into a single bool and can't tell them apart.
  Future<void> _printOne(SaleResponse sale) async {
    if (_printingIds.contains(sale.id)) return;
    setState(() => _printingIds.add(sale.id));
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final label = sale.invoiceNumber ?? '#${sale.id}';
    try {
      try {
        await ref.read(saleServiceProvider).getReceipt(sale.id);
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.receiptsScreenLoadReceiptFailed(label)),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      final ok = await ref
          .read(printServiceProvider)
          .printReceipt(context, sale.id);
      if (!ok && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.receiptsScreenPrintReceiptFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _printingIds.remove(sale.id));
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _refresh() {
    if (_showAllSales) {
      ref
          .read(receiptProvider.notifier)
          .loadAllSales(
            status: backendStatusQueryFor(
              ref.read(receiptProvider).statusFilter,
            ),
          );
    } else {
      ref.read(receiptProvider.notifier).loadActiveShiftSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receiptProvider);
    final displaySales = state.filteredSales;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navReceipts),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndToggle(state),
          _buildStatusFilterChips(state),
          _buildErrorAndCount(state, displaySales),
          Expanded(child: _buildBody(state, displaySales)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SEARCH + SHIFT/ALL TOGGLE
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
                filled: true,
                fillColor: PosTheme.backgroundPageOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (value) =>
                  ref.read(receiptProvider.notifier).setSearchQuery(value),
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(context.l10n.receiptsScreenShiftSegment),
              ),
              ButtonSegment(value: true, label: Text(context.l10n.commonAll)),
            ],
            selected: {_showAllSales},
            onSelectionChanged: (v) {
              setState(() => _showAllSales = v.first);
              if (v.first) {
                ref
                    .read(receiptProvider.notifier)
                    .loadAllSales(
                      status: backendStatusQueryFor(state.statusFilter),
                    );
              } else {
                ref.read(receiptProvider.notifier).loadActiveShiftSales();
              }
            },
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
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
                  _statusFilterLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : null,
                  ),
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

  /// Label for a filter chip's own key — `null` is "All", 'REFUNDED' here
  /// means the whole refund family (see `saleMatchesStatusFilter`), not
  /// just the literal REFUNDED status.
  String _statusFilterLabel(String? filterStatus) {
    switch (filterStatus) {
      case 'PAID':
        return context.l10n.receiptPaid;
      case 'VOID':
        return context.l10n.receiptsScreenStatusVoid;
      case 'REFUNDED':
        return context.l10n.receiptsScreenStatusRefunded;
      default:
        return context.l10n.commonAll;
    }
  }

  // ─────────────────────────────────────────────
  // ERROR + COUNT
  // ─────────────────────────────────────────────

  Widget _buildErrorAndCount(
    ReceiptState state,
    List<SaleResponse> displaySales,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              state.error!,
              style: const TextStyle(color: PosTheme.errorRed, fontSize: 12),
            ),
          ),
        if (!state.loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              context.l10n.receiptsScreenReceiptCount(
                displaySales.length.toString(),
              ),
              style: TextStyle(
                fontSize: 12,
                color: PosTheme.textSecondaryOf(context),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // LIST
  // ─────────────────────────────────────────────

  Widget _buildBody(ReceiptState state, List<SaleResponse> displaySales) {
    if (state.loading && state.sales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: displaySales.isEmpty
          ? ListView(children: [_buildEmptyState()])
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: displaySales.length,
              itemBuilder: (_, i) => _buildSaleCard(displaySales[i]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: PosTheme.textHintOf(context),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            Text(
              context.l10n.receiptsScreenEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PosTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.receiptsScreenEmptySubtitle,
              style: TextStyle(
                fontSize: 13,
                color: PosTheme.textHintOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SALE LIST CARD
  // ─────────────────────────────────────────────

  Widget _buildSaleCard(SaleResponse sale) {
    final statusColor = statusColorFor(sale.status);
    final fmt = (double v) => formatAmount(v, sale.currency);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: PosTheme.dividerColorOf(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await ref.read(receiptProvider.notifier).loadReceipt(sale.id);
          if (!mounted) return;
          final receipt = ref.read(receiptProvider).selectedReceipt;
          if (receipt == null) return;
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  _ReceiptDetailScreen(receipt: receipt, onRefunded: _refresh),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        statusIconFor(sale.status),
                        size: 18,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.invoiceNumber ??
                                context.l10n.receiptsScreenSaleFallback(
                                  sale.id.toString(),
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  sale.customerName ??
                                      context.l10n.receiptsScreenWalkIn,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: PosTheme.textSecondaryOf(context),
                                  ),
                                ),
                              ),
                              if (sale.createdAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(sale.createdAt!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: PosTheme.textHintOf(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt(sale.grandTotal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusBadgeLabel(context, sale.status),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _printingIds.contains(sale.id)
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.print_outlined, size: 18),
                      tooltip: context.l10n.receiptsScreenPrintReceipt,
                      color: PosTheme.textHintOf(context),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _printOne(sale),
                    ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: PosTheme.textHintOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      // .difference() is correct either way (subtracts absolute instants),
      // but the 'M/D' fallback reads local calendar fields directly —
      // those must be converted from the raw UTC value first, or a receipt
      // from just after local midnight can show the previous UTC day.
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return context.l10n.receiptsScreenJustNow;
      if (diff.inHours < 1) {
        return context.l10n.receiptsScreenMinutesAgo(diff.inMinutes.toString());
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
}

// ═══════════════════════════════════════════════════════════════════
// Status label/color/icon mapping — shared by the list card and the
// detail screen below, top-level so both can reach it without a
// BuildContext-bearing State object.
// ═══════════════════════════════════════════════════════════════════

/// Readable label for an actual sale's status (badges) — every real
/// backend status gets a distinct label; anything unmapped falls back to
/// its raw value rather than showing blank.
String statusBadgeLabel(BuildContext context, String status) {
  switch (status) {
    case 'PAID':
      return context.l10n.receiptPaid;
    case 'VOID':
      return context.l10n.receiptsScreenStatusVoid;
    case 'REFUNDED':
      return context.l10n.receiptsScreenStatusRefunded;
    case 'PARTIALLY_REFUNDED':
      return context.l10n.receiptsScreenStatusPartiallyRefunded;
    case 'CREDIT':
      return context.l10n.receiptsScreenStatusCredit;
    case 'DRAFT':
      return context.l10n.receiptsScreenStatusDraft;
    case 'HOLD':
      return context.l10n.receiptsScreenStatusHold;
    default:
      return status;
  }
}

/// Distinct color per status family so VOID/REFUNDED/etc. don't all
/// collapse into the same "not paid" orange.
Color statusColorFor(String status) {
  switch (status) {
    case 'PAID':
      return PosTheme.primaryGreen;
    case 'VOID':
      return PosTheme.errorRed;
    case 'REFUNDED':
    case 'PARTIALLY_REFUNDED':
      return PosTheme.warningAmber;
    default:
      return PosTheme.textSecondary;
  }
}

/// A clock/"pending" icon for VOID (a cancelled ticket) reads as "still
/// waiting", which is wrong — this maps each status to a fitting icon
/// instead of a binary paid/not-paid check.
IconData statusIconFor(String status) {
  switch (status) {
    case 'PAID':
      return Icons.check_circle_rounded;
    case 'VOID':
      return Icons.block_rounded;
    case 'REFUNDED':
    case 'PARTIALLY_REFUNDED':
      return Icons.replay_rounded;
    default:
      return Icons.access_time_rounded;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Detail screen — pushed from a sale card. Mobile's push-navigation
// replacement for source's inline split-pane detail (see this file's
// header comment).
// ═══════════════════════════════════════════════════════════════════

class _ReceiptDetailScreen extends ConsumerStatefulWidget {
  const _ReceiptDetailScreen({required this.receipt, required this.onRefunded});

  final ReceiptResponse receipt;

  /// Called after a successful refund so the caller's list re-fetches —
  /// this screen only reloads its own single receipt.
  final VoidCallback onRefunded;

  @override
  ConsumerState<_ReceiptDetailScreen> createState() =>
      _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends ConsumerState<_ReceiptDetailScreen> {
  bool _printing = false;
  bool _savingPdf = false;

  ReceiptResponse get receipt => widget.receipt;

  /// Same as `_ReceiptsScreenState._printOne` — reuses
  /// `PrintService.printReceipt` unchanged.
  Future<void> _print() async {
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await ref
          .read(printServiceProvider)
          .printReceipt(context, receipt.saleId);
      if (!ok && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.receiptsScreenPrintReceiptFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  /// Exports the receipt to a shareable PDF file via the exact same
  /// `PrintService.buildReceiptPdf` the print pipeline uses — no second
  /// PDF template.
  Future<void> _savePdf(ReceiptViewModel vm) async {
    setState(() => _savingPdf = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final config = await ref.read(thermalPrinterServiceProvider).loadConfig();
      if (!mounted) return;
      final bytes = await ref
          .read(printServiceProvider)
          .buildReceiptPdf(vm, config.paperSize, context: context);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${vm.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.receiptsScreenPrintReceiptFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    final vm = ReceiptViewModel.fromReceiptResponse(
      receipt,
      language,
      context.l10n,
    );
    final canRefund =
        receipt.status == 'PAID' || receipt.status == 'PARTIALLY_REFUNDED';

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.invoiceNumber),
        actions: [
          IconButton(
            icon: _savingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: context.l10n.receiptsScreenSavePdf,
            onPressed: _savingPdf ? null : () => _savePdf(vm),
          ),
          IconButton(
            icon: _printing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: context.l10n.receiptsScreenPrintReceipt,
            onPressed: _printing ? null : _print,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Cap at kReceiptContentWidth (the paper-size default) on wide
          // screens, but shrink to fit narrow phones instead of overflowing
          // past the edge — a fixed 380px never fit a 320-360px phone with
          // this padding, and SingleChildScrollView only scrolls vertically.
          const horizontalPadding = 20.0 * 2;
          final receiptWidth = (constraints.maxWidth - horizontalPadding)
              .clamp(0.0, kReceiptContentWidth);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: receiptWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReceiptPaperView(receipt: vm, width: receiptWidth),
                    const SizedBox(height: 14),
                    if (receipt.status != null)
                      Center(
                        child: Text(
                          statusBadgeLabel(context, receipt.status!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: statusColorFor(receipt.status!),
                          ),
                        ),
                      ),
                    if (canRefund) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _showRefundDialog(context, ref),
                          icon: const Icon(Icons.replay, size: 16),
                          label: Text(context.l10n.receiptsScreenRefund),
                          style: TextButton.styleFrom(
                            foregroundColor: PosTheme.errorRed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRefundDialog(BuildContext context, WidgetRef ref) {
    final remaining = receipt.total - receipt.refundedAmount;
    final cur = readCurrency(ref);
    final reasonCtl = TextEditingController();
    final managerEmailCtl = TextEditingController();
    final managerPasswordCtl = TextEditingController();
    bool submitting = false;
    String? error;

    showDialog<void>(
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
              await ref
                  .read(saleServiceProvider)
                  .refundSale(
                    receipt.saleId,
                    amount: remaining,
                    method: 'CASH',
                    reason: reasonCtl.text.trim(),
                    managerEmail: managerEmailCtl.text.trim(),
                    managerPassword: managerPasswordCtl.text,
                  );
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              widget.onRefunded();
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.receiptsScreenRefundSubmitted),
                    backgroundColor: PosTheme.primaryGreen,
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
                    '${context.l10n.receiptsScreenRefundTotalLine(formatAmount(receipt.total, cur))}'
                    '${receipt.refundedAmount > 0 ? '\n${context.l10n.receiptsScreenRefundAlreadyRefundedLine(formatAmount(receipt.refundedAmount, cur))}' : ''}'
                    '\n${context.l10n.receiptsScreenRefundAmountLine(formatAmount(remaining, cur))}',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtl,
                    enabled: !submitting,
                    decoration: InputDecoration(
                      labelText: context.l10n.receiptsScreenReasonOptionalLabel,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: managerEmailCtl,
                    enabled: !submitting,
                    decoration: InputDecoration(
                      labelText: context.l10n.receiptsScreenManagerEmailLabel,
                      isDense: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: managerPasswordCtl,
                    enabled: !submitting,
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.receiptsScreenManagerPasswordLabel,
                      isDense: true,
                    ),
                    obscureText: true,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: PosTheme.errorRed,
                        fontSize: 12,
                      ),
                    ),
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(context.l10n.receiptsScreenConfirmRefundButton),
              ),
            ],
          );
        },
      ),
    );
  }
}
