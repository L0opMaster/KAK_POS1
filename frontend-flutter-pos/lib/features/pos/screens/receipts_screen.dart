import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/bounded_concurrency.dart';
import '../../../core/config/currency_utils.dart';
import '../models/receipt_models.dart';
import '../providers/receipt_provider.dart';
import '../services/print_service.dart';
import '../services/printing/printer_profile.dart';
import '../services/printing/receipt_bitmap_renderer.dart';
import '../services/printing/receipt_view_model.dart';
import '../services/printing/thermal_printer_service.dart';
import '../services/sale_service.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/providers/language_provider.dart';
import '../utils/credit_status.dart';
import '../widgets/credit_repayment_dialog.dart';
import '../widgets/receipt_paper_view.dart';

/// Progress shown while "Print All" is preparing (fetching full receipt
/// detail per sale) or printing (building/emitting the batch print job).
class _PrintAllProgress {
  const _PrintAllProgress(this.done, this.total, this.stage);
  final int done;
  final int total;
  final String stage;
}

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
    'CREDIT',
    'VOID',
    'REFUNDED'
  ];
  final ScrollController _listScrollCtl = ScrollController();

  /// Sale ids with an in-flight "Print One" — disables that row's button
  /// and prevents a repeated tap from firing a second print job.
  final Set<int> _printingIds = {};

  /// True while "Print All" is running (fetching details, building the
  /// batch job, or printing) — disables the Print All button itself.
  bool _printAllRunning = false;

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
            icon: _printAllRunning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: context.l10n.receiptsScreenPrintAllTooltip,
            onPressed: displaySales.isEmpty || _printAllRunning
                ? null
                : () => _printAllReceipts(displaySales),
          ),
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
      ref.read(receiptProvider.notifier).loadAllSales(
          status:
              backendStatusQueryFor(ref.read(receiptProvider).statusFilter));
    } else {
      ref.read(receiptProvider.notifier).loadActiveShiftSales();
    }
  }

  // ─────────────────────────────────────────────
  // PRINT ONE — reuses PrintService.printReceipt(context, saleId)
  // unchanged (same call the post-checkout auto-print uses), so this
  // screen never grows a second receipt-printing pipeline.
  // ─────────────────────────────────────────────

  Future<void> _printOne(SaleResponse sale) async {
    if (_printingIds.contains(sale.id)) return; // guard double-tap
    setState(() => _printingIds.add(sale.id));
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final label = sale.invoiceNumber ?? '#${sale.id}';
    try {
      // Fetch first, on its own, so a load failure gets its own message —
      // PrintService.printReceipt bundles "couldn't fetch the receipt" and
      // "couldn't reach the printer" into a single bool and can't tell
      // them apart from the caller's side.
      try {
        await ref.read(saleServiceProvider).getReceipt(sale.id);
      } catch (e) {
        debugPrint('Print One: failed to load receipt $label: $e');
        if (mounted) {
          messenger.showSnackBar(SnackBar(
              content: Text(l10n.receiptsScreenLoadReceiptFailed(label))));
        }
        return;
      }
      if (!mounted) return;
      final ok =
          await ref.read(printServiceProvider).printReceipt(context, sale.id);
      if (!ok && mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.receiptsScreenPrintReceiptFailed)));
      }
    } finally {
      if (mounted) setState(() => _printingIds.remove(sale.id));
    }
  }

  /// Exports a single receipt to a shareable PDF file, via the exact same
  /// [PrintService.buildReceiptPdf] the print pipelines use — no second PDF
  /// template.
  Future<void> _savePdf(ReceiptResponse receipt) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final language = ref.read(appLanguageProvider);
      final viewModel =
          ReceiptViewModel.fromReceiptResponse(receipt, language, l10n);
      final config = await ref.read(thermalPrinterServiceProvider).loadConfig();
      final bytes = await ref
          .read(printServiceProvider)
          .buildReceiptPdf(viewModel, config.paperSize, context: context);
      await Printing.sharePdf(
          bytes: bytes, filename: '${viewModel.invoiceNumber}.pdf');
    } catch (e) {
      debugPrint('Save PDF failed: $e');
      if (mounted) {
        final message = e is ReceiptRenderException
            ? e.message
            : l10n.receiptsScreenPrintReceiptFailed;
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  // ─────────────────────────────────────────────
  // PRINT ALL — every sale matching the screen's CURRENT filters
  // (state.filteredSales, already unbounded — see receipt_provider.dart,
  // this screen's list endpoints have no pagination to walk), not just
  // what's on screen. Fetches full detail per sale (bounded concurrency),
  // then emits ONE PDF job (driver) or ONE connect/print/disconnect batch
  // (thermal) — never one job/connection per receipt.
  // ─────────────────────────────────────────────

  Future<void> _printAllReceipts(List<SaleResponse> sales) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.receiptsScreenPrintAllConfirmTitle),
        content: Text(l10n.receiptsScreenPrintAllConfirmBody(sales.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.receiptsScreenPrintAll),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Defensive de-dupe by id: this screen's sale list has no pagination to
    // overlap, but keeping the guarantee explicit costs nothing and avoids
    // silently trusting that invariant forever.
    final ids = {for (final s in sales) s.id}.toList();

    setState(() => _printAllRunning = true);
    final progress = ValueNotifier(
        _PrintAllProgress(0, ids.length, l10n.receiptsScreenPreparingReceipts));
    var cancelled = false;

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: ValueListenableBuilder<_PrintAllProgress>(
          valueListenable: progress,
          builder: (ctx, p, __) => AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.stage),
                      const SizedBox(height: 4),
                      Text(
                        l10n.receiptsScreenPrintAllProgress(p.done, p.total),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: p.stage == l10n.receiptsScreenPreparingReceipts
                ? [
                    TextButton(
                      onPressed: () => cancelled = true,
                      child: Text(l10n.commonCancel),
                    ),
                  ]
                : const [],
          ),
        ),
      ),
    ));

    final failedLabels = <String>[];
    final viewModels = <ReceiptViewModel>[];
    var printJobFailed = false;
    String? printJobFailureMessage;
    final language = ref.read(appLanguageProvider);
    final saleService = ref.read(saleServiceProvider);

    try {
      // ── Prepare: full detail per sale, bounded concurrency (Step 14) ──
      final results = await mapBounded<int, ReceiptViewModel>(
        ids,
        (id) async {
          final raw = await saleService.getReceipt(id);
          final receipt = ReceiptResponse.fromJson(raw);
          return ReceiptViewModel.fromReceiptResponse(receipt, language, l10n);
        },
        isCancelled: () => cancelled,
        onProgress: (done, total) => progress.value = _PrintAllProgress(
            done, total, l10n.receiptsScreenPreparingReceipts),
      );

      if (cancelled) return;
      for (final r in results) {
        if (r.isOk) {
          viewModels.add(r.value!);
        } else {
          debugPrint(
              'Print All: failed to load receipt id=${r.item}: ${r.error}');
          failedLabels.add('#${r.item}');
        }
      }
      if (viewModels.isEmpty) return;

      // ── Print: one PDF job, or one connect/disconnect thermal batch ──
      progress.value = _PrintAllProgress(
          0, viewModels.length, l10n.receiptsScreenPrintingReceipts);
      final config = await ref.read(thermalPrinterServiceProvider).loadConfig();
      if (!mounted) return;

      if (config.transportType == PrinterTransportType.pdfDriver) {
        final bytes = await ref
            .read(printServiceProvider)
            .buildReceiptsPdf(viewModels, config.paperSize, context: context);
        progress.value = _PrintAllProgress(viewModels.length, viewModels.length,
            l10n.receiptsScreenPrintingReceipts);
        await Printing.layoutPdf(
            onLayout: (_) => bytes, name: 'receipts_batch');
      } else {
        if (!mounted) return;
        await ref.read(thermalPrinterServiceProvider).printReceipts(
              context,
              viewModels,
              config,
              onProgress: (d, t) => progress.value =
                  _PrintAllProgress(d, t, l10n.receiptsScreenPrintingReceipts),
            );
      }
    } catch (e) {
      debugPrint('Print All failed: $e');
      printJobFailed = true;
      if (e is ReceiptRenderException) printJobFailureMessage = e.message;
    } finally {
      navigator.pop(); // close the progress dialog
      progress.dispose();
      if (mounted) setState(() => _printAllRunning = false);
    }

    if (!mounted || cancelled) return;
    if (printJobFailed) {
      messenger.showSnackBar(SnackBar(
          content: Text(printJobFailureMessage ??
              l10n.receiptsScreenPrintReceiptFailed)));
      return;
    }
    if (viewModels.isEmpty) {
      messenger.showSnackBar(SnackBar(
          content:
              Text(l10n.receiptsScreenPrintAllPartialFailure(ids.length))));
      return;
    }
    messenger.showSnackBar(SnackBar(
        content: Text(
            l10n.receiptsScreenPrintAllDone(viewModels.length, ids.length))));
    if (failedLabels.isNotEmpty) {
      messenger.showSnackBar(SnackBar(
          content: Text(
              l10n.receiptsScreenPrintAllPartialFailure(failedLabels.length))));
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
                ref.read(receiptProvider.notifier).loadAllSales(
                    status: backendStatusQueryFor(state.statusFilter));
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
                  _statusFilterLabel(context, status),
                  style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : Colors.black),
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
  /// means the whole refund family (see saleMatchesStatusFilter), not just
  /// the literal REFUNDED status.
  String _statusFilterLabel(BuildContext context, String? filterStatus) {
    switch (filterStatus) {
      case 'PAID':
        return context.l10n.receiptPaid;
      case 'CREDIT':
        return context.l10n.receiptsScreenStatusCredit;
      case 'VOID':
        return context.l10n.receiptsScreenStatusVoid;
      case 'REFUNDED':
        return context.l10n.receiptsScreenStatusRefunded;
      default:
        return context.l10n.commonAll;
    }
  }

  /// Readable label for an actual sale's status (badges) — every real
  /// backend status (see SaleService) gets a distinct label; anything
  /// unmapped falls back to its raw value rather than showing blank.
  /// [creditStatus] (OPEN/PARTIALLY_PAID/PAID/OVERDUE/EXPIRED/CANCELLED —
  /// see `SaleResponse.creditStatus`/`ReceiptResponse.creditStatus`) refines
  /// the generic 'CREDIT' [status] into the finer label a credit sale
  /// actually needs (e.g. "Overdue" instead of just "Credit"). Falls back to
  /// the plain CREDIT label when it isn't available yet (still loading).
  String _statusBadgeLabel(BuildContext context, String status,
      {String? creditStatus}) {
    if (status == 'CREDIT' && creditStatus != null) {
      return creditStatusLabel(context.l10n, creditStatus);
    }
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
  /// collapse into the same "not paid" orange. A CREDIT sale defers to
  /// [creditStatusColor] (red once overdue/expired) instead of the flat grey
  /// every other unmapped status gets.
  Color _statusColor(String status, {String? creditStatus}) {
    if (status == 'CREDIT') return creditStatusColor(creditStatus);
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'VOID':
        return Colors.red;
      case 'REFUNDED':
      case 'PARTIALLY_REFUNDED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// A clock/"pending" icon for VOID (a cancelled ticket) reads as "still
  /// waiting", which is wrong — this maps each status to a fitting icon
  /// instead of the old binary paid/not-paid check.
  IconData _statusIcon(String status) {
    switch (status) {
      case 'PAID':
        return Icons.check_circle_rounded;
      case 'CREDIT':
        return Icons.schedule_rounded;
      case 'VOID':
        return Icons.block_rounded;
      case 'REFUNDED':
      case 'PARTIALLY_REFUNDED':
        return Icons.replay_rounded;
      default:
        return Icons.access_time_rounded;
    }
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
              await ref.read(receiptProvider.notifier).loadAllSales(
                  status: backendStatusQueryFor(state.statusFilter));
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
    final statusColor =
        _statusColor(sale.status, creditStatus: sale.creditStatus);
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
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _statusIcon(sale.status),
                        size: 18,
                        color: statusColor,
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _statusBadgeLabel(context, sale.status,
                          creditStatus: sale.creditStatus),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
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
                      color: Colors.grey[500],
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _printOne(sale),
                    ),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      // .difference() below is correct either way (it subtracts absolute
      // instants), but the '${dt.month}/${dt.day}' fallback reads local
      // calendar fields directly — those must be converted from the raw
      // UTC (Instant.toString()) value first, or a receipt from just after
      // local midnight can show the previous UTC day.
      final dt = DateTime.parse(iso).toLocal();
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
    final language = ref.watch(appLanguageProvider);
    final vm =
        ReceiptViewModel.fromReceiptResponse(receipt, language, context.l10n);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ═══ RECEIPT — same design as the printed/on-screen preview ═══
              ReceiptPaperView(receipt: vm, width: 380),
              const SizedBox(height: 14),

              // ═══ STATUS ═══
              if (receipt.status != null)
                Center(
                  child: Text(
                    _statusBadgeLabel(context, receipt.status!,
                        creditStatus: receipt.creditStatus),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: _statusColor(receipt.status!,
                          creditStatus: receipt.creditStatus),
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // ═══ THREE-DOT MENU + ACTIONS ═══
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // PARTIALLY_REFUNDED can still be refunded further — the
                  // backend's refund() explicitly allows either PAID or
                  // PARTIALLY_REFUNDED as a starting state (see
                  // SaleService.refund's guard) — this used to only show
                  // for PAID (or the dead 'COMPLETED' status), which hid a
                  // real, already-supported action.
                  if (receipt.status == 'PAID' ||
                      receipt.status == 'PARTIALLY_REFUNDED')
                    TextButton.icon(
                      onPressed: () => _showRefundDialog(context, receipt),
                      icon: const Icon(Icons.replay, size: 16),
                      label: Text(context.l10n.receiptsScreenRefund,
                          style: const TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent),
                    ),
                  if (receipt.status == 'CREDIT' &&
                      (receipt.remainingBalance ?? 0) > 0)
                    TextButton.icon(
                      onPressed: () => _recordCreditPayment(receipt),
                      icon: const Icon(Icons.payments_outlined, size: 16),
                      label: Text(context.l10n.receiptsScreenRecordPaymentAction,
                          style: const TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                          foregroundColor: PosTheme.primaryGreen),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                    onSelected: (value) async {
                      if (value == 'print') {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await ref
                            .read(printServiceProvider)
                            .printReceipt(context, receipt.saleId);
                        if (!ok && mounted) {
                          messenger.showSnackBar(SnackBar(
                              content: Text(context
                                  .l10n.receiptsScreenPrintReceiptFailed)));
                        }
                      } else if (value == 'savePdf') {
                        await _savePdf(receipt);
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
                          value: 'savePdf',
                          child: ListTile(
                              leading:
                                  const Icon(Icons.picture_as_pdf, size: 20),
                              title: Text(context.l10n.receiptsScreenSavePdf),
                              dense: true,
                              contentPadding: EdgeInsets.zero)),
                      PopupMenuItem(
                          value: 'email',
                          child: ListTile(
                              leading: const Icon(Icons.email, size: 20),
                              title:
                                  Text(context.l10n.receiptsScreenSendByEmail),
                              dense: true,
                              contentPadding: EdgeInsets.zero)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the shared credit-repayment dialog (same one the Customer Credit
  /// Detail screen uses — see `credit_repayment_dialog.dart`) for the sale
  /// currently shown in the receipt detail view. [ReceiptResponse] doesn't
  /// carry every [SaleResponse] field, but it has everything the dialog
  /// actually needs (id/invoiceNumber/total/paidAmount/customerName/credit
  /// fields), so it's translated into one here rather than issuing a second
  /// `getSale` fetch just to get the same data in a different shape.
  Future<void> _recordCreditPayment(ReceiptResponse receipt) async {
    final sale = SaleResponse(
      id: receipt.saleId,
      invoiceNumber: receipt.saleNumber,
      status: receipt.status ?? 'CREDIT',
      grandTotal: receipt.total,
      paidAmount: receipt.paidAmount,
      customerName: receipt.customerName,
      currency: receipt.currency,
      creditDueAt: receipt.creditDueAt,
      creditExpiresAt: receipt.creditExpiresAt,
      creditStatus: receipt.creditStatus,
    );
    final updated = await showCreditRepaymentDialog(context, ref, sale: sale);
    if (updated == null || !mounted) return;
    await ref.read(receiptProvider.notifier).loadReceipt(receipt.saleId);
    _refresh();
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
    final cur = readCurrency(ref);
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
                    '${context.l10n.receiptsScreenRefundTotalLine(formatAmount(receipt.total, cur))}'
                    '${receipt.refundedAmount > 0 ? '\n${context.l10n.receiptsScreenRefundAlreadyRefundedLine(formatAmount(receipt.refundedAmount, cur))}' : ''}'
                    '\n${context.l10n.receiptsScreenRefundAmountLine(formatAmount(remaining, cur))}',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtl,
                    enabled: !submitting,
                    decoration: InputDecoration(
                        labelText:
                            context.l10n.receiptsScreenReasonOptionalLabel,
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
}
