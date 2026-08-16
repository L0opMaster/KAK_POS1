import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';
import 'create_purchase_order.dart';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// PO status transitions this screen can reach (see
/// PurchasingWorkflowService.transitionPurchaseOrder): DRAFT --submit-->
/// SUBMITTED --approve--> APPROVED, any of SUBMITTED/APPROVED --send--> (sets
/// sentAt, status unchanged), anything not RECEIVED/PARTIALLY_RECEIVED/
/// CLOSED/CANCELLED --cancel--> CANCELLED. RECEIVED/PARTIALLY_RECEIVED only
/// happen via the separate Goods Receipt flow, not built here.
List<String> _actionsFor(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
      return ['submit', 'cancel'];
    case 'SUBMITTED':
      return ['approve', 'send', 'cancel'];
    case 'APPROVED':
      return ['send', 'cancel'];
    case 'RECEIVED':
    case 'PARTIALLY_RECEIVED':
      return ['send', 'close'];
    default:
      return [];
  }
}

String _actionLabel(BuildContext context, String action) {
  switch (action) {
    case 'submit':
      return context.l10n.commonSubmit;
    case 'approve':
      return context.l10n.purchaseOrdersActionApprove;
    case 'send':
      return context.l10n.purchaseOrdersActionSendToSupplier;
    case 'close':
      return context.l10n.commonClose;
    case 'cancel':
      return context.l10n.commonCancel;
    default:
      return action;
  }
}

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  static const int _pageSize = 8;
  int _currentPage = 0;
  bool _hasLoadedOnce = false;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(purchaseOrdersProvider.notifier).loadOrders();
      if (mounted) setState(() => _hasLoadedOnce = true);
    });
  }

  Future<void> _openCreate() async {
    final result = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CreatePurchaseOrder()));
    if (result == true && mounted) setState(() => _currentPage = 0);
  }

  Future<void> _runAction(PurchaseOrder order, String action) async {
    if (action == 'cancel') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.purchaseOrdersCancelTitle),
          content: Text(context.l10n
              .purchaseOrdersCancelConfirm(order.referenceNumber ?? '#${order.id}')),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.l10n.inventoryKeepButton)),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.inventoryCancelOrderButton,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref.read(purchaseOrdersProvider.notifier).transition(order.id!, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n
                  .purchaseOrdersActionDoneSnackbar(_actionLabel(context, action))),
              backgroundColor: PosTheme.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.inventoryActionFailed('$e')),
              backgroundColor: PosTheme.errorRed),
        );
      }
    }
  }

  /// `order.lines` is already fully populated in the list response (see
  /// PurchaseOrder.fromJson) — there's no separate detail-fetch endpoint in
  /// use anywhere in the app, so this builds straight from the row's own
  /// object.
  Future<Uint8List> _buildOrderPdf(PurchaseOrder order) async {
    final l10n = context.l10n;
    final company = await ref.read(settingsServiceProvider).getCompanyProfile();
    final currencyCode = readCurrency(ref);

    final details = <MapEntry<String, String>>[
      MapEntry(l10n.purchaseOrderPdfNumberLabel,
          order.referenceNumber ?? l10n.purchaseOrdersPoFallback('${order.id}')),
      MapEntry(l10n.commonStatus, order.status),
      MapEntry(l10n.formSupplier,
          order.supplierName ?? l10n.purchaseOrdersSupplierFallback('${order.supplierId}')),
      if (order.storeName != null)
        MapEntry(l10n.createPurchaseOrderDeliverToStore, order.storeName!),
      if (order.orderDeadline != null)
        MapEntry(l10n.createPurchaseOrderOrderDeadline, _fmtDate(order.orderDeadline!)),
      if (order.expectedArrival != null)
        MapEntry(l10n.createPurchaseOrderExpectedArrival, _fmtDate(order.expectedArrival!)),
      if (order.notes != null && order.notes!.isNotEmpty)
        MapEntry(l10n.inventoryNotesLabel, order.notes!),
    ];

    final rows = order.lines
        .map((line) => [
              line.productNameEn ?? l10n.reportsProductFallback('${line.productId}'),
              line.quantity.toStringAsFixed(
                  line.quantity.truncateToDouble() == line.quantity ? 0 : 2),
              formatAmount(line.unitCost, currencyCode),
              formatAmount(
                  line.lineTotal ?? line.quantity * line.unitCost, currencyCode),
            ])
        .toList();

    final summary = <MapEntry<String, String>>[
      if (order.subtotal != null)
        MapEntry(l10n.cartSubtotal, formatAmount(order.subtotal!, currencyCode)),
      if (order.taxAmount != null)
        MapEntry(l10n.cartTax, formatAmount(order.taxAmount!, currencyCode)),
      if (order.totalAmount != null)
        MapEntry(l10n.cartTotal, formatAmount(order.totalAmount!, currencyCode)),
    ];

    return A4ReportPdf.build(
      title: l10n.purchaseOrderPdfTitle,
      businessName: '${company['businessName'] ?? ''}',
      businessAddress: '${company['address'] ?? ''}',
      businessPhone: '${company['phone'] ?? ''}',
      details: details,
      columns: [
        l10n.inventoryProductLabel,
        l10n.cartQty,
        l10n.createPurchaseOrderUnitCost,
        l10n.purchaseOrderPdfLineTotalLabel,
      ],
      rows: rows,
      columnAlignments: const {
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      summary: summary,
      generatedAt: DateTime.now(),
      generatedLabel: l10n.reportPdfGeneratedLabel,
      pageLabel: l10n.reportPdfPageLabel,
    );
  }

  Future<void> _printOrder(PurchaseOrder order) async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildOrderPdf(order);
      await Printing.layoutPdf(
          onLayout: (_) => bytes, name: order.referenceNumber ?? 'purchase_order');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.l10n.printerPrintFailed}: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _saveOrderPdf(PurchaseOrder order) async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildOrderPdf(order);
      await Printing.sharePdf(
          bytes: bytes, filename: '${order.referenceNumber ?? 'purchase_order'}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.l10n.printerPrintFailed}: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.purchaseOrdersTitle),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: () => ref.read(purchaseOrdersProvider.notifier).loadOrders(),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (orders) {
            if (orders.isEmpty && _hasLoadedOnce) return _buildEmptyState();
            return _buildList(orders, loading: false);
          },
          loading: () {
            if (!_hasLoadedOnce) return const Center(child: CircularProgressIndicator());
            return _buildList(const [], loading: true);
          },
          error: (e, _) => _buildErrorState('$e'),
        ),
      ),
    );
  }

  Widget _buildList(List<PurchaseOrder> allOrders, {required bool loading}) {
    final totalItems = allOrders.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);
    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageOrders = allOrders.sublist(startIndex, endIndex);

    return RefreshIndicator(
      onRefresh: () => ref.read(purchaseOrdersProvider.notifier).loadOrders(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          Card(
            color: Colors.white,
            elevation: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 22),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openCreate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(210, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.purchaseOrdersNewButton,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(context.l10n.inventoryOrderCount('${allOrders.length}'),
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageOrders.isEmpty)
                  _buildNoResults(loading: loading)
                else
                  ...pageOrders.map(_buildRow),
                if (pageOrders.isNotEmpty)
                  _buildPagination(currentPage: safeCurrentPage, totalPages: totalPages, totalItems: totalItems),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults({required bool loading}) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(context.l10n.purchaseOrdersNoOrdersFound,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(PurchaseOrder order) {
    final currencyCode = watchCurrency(ref);
    final status = order.status.toUpperCase();
    final actions = order.id == null ? const <String>[] : _actionsFor(status);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF99D267),
                child: Icon(Icons.shopping_cart, color: Colors.white),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        order.referenceNumber ??
                            context.l10n.purchaseOrdersPoFallback('${order.id}'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${order.supplierName ?? context.l10n.purchaseOrdersSupplierFallback('${order.supplierId}')} • '
                      '${context.l10n.inventoryLineCount('${order.totalItems}')}',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (order.totalAmount != null) ...[
                Text(formatAmount(order.totalAmount!, currencyCode),
                    style: TextStyle(fontWeight: FontWeight.bold, color: PosTheme.primaryGreen)),
                const SizedBox(width: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status))),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: context.l10n.inventoryDocumentActionsTooltip,
                enabled: !_generatingPdf,
                onSelected: (action) => action == 'print'
                    ? _printOrder(order)
                    : _saveOrderPdf(order),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'print', child: Text(context.l10n.commonPrint)),
                  PopupMenuItem(value: 'save', child: Text(context.l10n.commonSavePdf)),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (action) => _runAction(order, action),
                  itemBuilder: (context) => actions
                      .map((a) => PopupMenuItem(value: a, child: Text(_actionLabel(context, a))))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
      case 'RECEIVED':
      case 'CLOSED':
        return PosTheme.successGreen;
      case 'CANCELLED':
        return PosTheme.errorRed;
      case 'SUBMITTED':
      case 'PARTIALLY_RECEIVED':
        return PosTheme.warningAmber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPagination({required int currentPage, required int totalPages, required int totalItems}) {
    final firstItem = totalItems == 0 ? 0 : currentPage * _pageSize + 1;
    final lastItem = math.min((currentPage + 1) * _pageSize, totalItems);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
              context.l10n
                  .inventoryPaginationRange('$firstItem', '$lastItem', '$totalItems'),
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 20),
          IconButton(
            onPressed: currentPage == 0 ? null : () => setState(() => _currentPage = 0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            onPressed: currentPage == 0 ? null : () => setState(() => _currentPage = currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 100),
            alignment: Alignment.center,
            child: Text(
                context.l10n.inventoryPaginationPage('${currentPage + 1}', '$totalPages'),
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          IconButton(
            onPressed: currentPage >= totalPages - 1 ? null : () => setState(() => _currentPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            onPressed: currentPage >= totalPages - 1 ? null : () => setState(() => _currentPage = totalPages - 1),
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Card(
            color: Colors.white,
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 45),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                    child: const Icon(Icons.shopping_cart_outlined, size: 52, color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  Text(context.l10n.purchaseOrdersTitle,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 18),
                  Text(context.l10n.purchaseOrdersEmptySubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.black54)),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _openCreate,
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(210, 54)),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.purchaseOrdersNewButton,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref.read(purchaseOrdersProvider.notifier).loadOrders(),
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
