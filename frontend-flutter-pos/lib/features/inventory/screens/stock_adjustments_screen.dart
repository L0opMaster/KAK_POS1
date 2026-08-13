import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';
import '../../pos/services/settings_service.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';
import '../services/inventory_service.dart' show defaultInventoryStoreId;

const List<String> _adjustmentReasons = [
  'Received',
  'Damaged',
  'Lost',
  'Found',
  'Returned',
  'Manual Count',
  'Other',
];

String _reasonLabel(BuildContext context, String reason) {
  switch (reason) {
    case 'Received':
      return context.l10n.stockAdjustmentReasonReceived;
    case 'Damaged':
      return context.l10n.stockAdjustmentReasonDamaged;
    case 'Lost':
      return context.l10n.stockAdjustmentReasonLost;
    case 'Found':
      return context.l10n.stockAdjustmentReasonFound;
    case 'Returned':
      return context.l10n.stockAdjustmentReasonReturned;
    case 'Manual Count':
      return context.l10n.stockAdjustmentReasonManualCount;
    case 'Other':
      return context.l10n.stockAdjustmentReasonOther;
    default:
      return reason;
  }
}

class StockAdjustmentsScreen extends ConsumerStatefulWidget {
  const StockAdjustmentsScreen({super.key});

  @override
  ConsumerState<StockAdjustmentsScreen> createState() =>
      _StockAdjustmentsScreenState();
}

class _StockAdjustmentsScreenState
    extends ConsumerState<StockAdjustmentsScreen> {
  static const int _pageSize = 8;

  final TextEditingController _searchCtl = TextEditingController();
  int _currentPage = 0;
  bool _hasLoadedOnce = false;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(movementsProvider.notifier).load();
      if (mounted) setState(() => _hasLoadedOnce = true);
    });
    Future.microtask(() => ref.read(productsProvider.notifier).loadProducts());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<StockMovementEntry> _filtered(List<StockMovementEntry> movements) {
    final needle = _searchCtl.text.trim().toLowerCase();
    if (needle.isEmpty) return movements;
    return movements
        .where((m) =>
            m.productName.toLowerCase().contains(needle) ||
            (m.reason ?? '').toLowerCase().contains(needle))
        .toList();
  }

  /// Reports every movement entry (there's no adjustment reference/batch id
  /// in the backend data — see StockMovementEntry — so this is a filtered
  /// log, not a single bundled "adjustment document"), over the FULL
  /// dataset already loaded in movementsProvider with the same search
  /// filter applied on screen.
  Future<Uint8List?> _buildPdfBytes() async {
    final movements = ref.read(movementsProvider).value;
    if (movements == null) return null;
    final l10n = context.l10n;
    final sorted = [...movements]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final filtered = _filtered(sorted);
    final company = await ref.read(settingsServiceProvider).getCompanyProfile();
    final query = _searchCtl.text.trim();

    final rows = filtered
        .map((m) => [
              _fmtDate(m.createdAt),
              m.productName,
              m.movementType.replaceAll('_', ' '),
              m.quantity.toStringAsFixed(
                  m.quantity.truncateToDouble() == m.quantity ? 0 : 2),
              m.reason ?? '',
              m.storeName ?? '',
              m.createdBy ?? '',
            ])
        .toList();

    return A4ReportPdf.build(
      title: l10n.stockAdjustmentsTitle,
      subtitle:
          query.isNotEmpty ? l10n.stockAdjustmentsPdfFilterQuery(query) : null,
      businessName: '${company['businessName'] ?? ''}',
      businessAddress: '${company['address'] ?? ''}',
      businessPhone: '${company['phone'] ?? ''}',
      columns: [
        l10n.receiptDate,
        l10n.receiptItem,
        l10n.stockMovementPdfColType,
        l10n.receiptQty,
        l10n.shiftScreenReasonLabel,
        l10n.commonLocation,
        l10n.commonUser,
      ],
      rows: rows,
      columnAlignments: const {3: pw.Alignment.centerRight},
      summary: [
        MapEntry(l10n.stockMovementPdfMovementsLabel, '${filtered.length}'),
      ],
      generatedAt: DateTime.now(),
      generatedLabel: l10n.reportPdfGeneratedLabel,
      pageLabel: l10n.reportPdfPageLabel,
      landscape: true,
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _printReport() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildPdfBytes();
      if (bytes == null) return;
      await Printing.layoutPdf(onLayout: (_) => bytes, name: 'stock_adjustments');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.l10n.printerPrintFailed}: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _savePdf() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildPdfBytes();
      if (bytes == null) return;
      await Printing.sharePdf(bytes: bytes, filename: 'stock_adjustments.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.l10n.printerPrintFailed}: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _openNewAdjustmentDialog() async {
    final products = ref.read(productsProvider).products;
    final language = ref.read(appLanguageProvider);
    Product? selectedProduct;
    final qtyCtl = TextEditingController();
    String reason = _adjustmentReasons.first;
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final qty = double.tryParse(qtyCtl.text.trim());
              if (selectedProduct == null || qty == null || qty == 0) {
                setDialogState(() =>
                    error = context.l10n.stockAdjustmentsPickProductError);
                return;
              }
              setDialogState(() {
                saving = true;
                error = null;
              });
              try {
                await ref.read(movementsProvider.notifier).createAdjustment(
                      StockAdjustmentRequest(
                        productId: selectedProduct!.id,
                        quantity: qty,
                        storeId: defaultInventoryStoreId,
                        reason: reason,
                      ),
                    );
                if (context.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() {
                  saving = false;
                  error = context.l10n.inventoryFailedToSave('$e');
                });
              }
            }

            return AlertDialog(
              title: Text(context.l10n.stockAdjustmentsNewTitle),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<Product>(
                        initialValue: selectedProduct,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.stockAdjustmentsProductLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: products
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p.localizedName(language),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedProduct = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qtyCtl,
                        decoration: InputDecoration(
                          labelText: context.l10n.stockAdjustmentsQuantityChangeLabel,
                          hintText: context.l10n.stockAdjustmentsQuantityHint,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(signed: true, decimal: true),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: reason,
                        decoration: InputDecoration(
                          labelText: context.l10n.stockAdjustmentsReasonLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: _adjustmentReasons
                            .map((r) => DropdownMenuItem(
                                value: r, child: Text(_reasonLabel(context, r))))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setDialogState(() => reason = value);
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: PosTheme.errorRed)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonCancel.toUpperCase()),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(context.l10n.commonSave.toUpperCase()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.stockAdjustmentsTitle),
        elevation: 0.5,
        actions: [
          if (_generatingPdf)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: context.l10n.commonPrint,
              onPressed: state.value == null ? null : _printReport,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: context.l10n.commonSavePdf,
              onPressed: state.value == null ? null : _savePdf,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: () => ref.read(movementsProvider.notifier).load(),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (movements) {
            final isSearching = _searchCtl.text.trim().isNotEmpty;
            if (!isSearching && movements.isEmpty && _hasLoadedOnce) {
              return _buildEmptyState();
            }
            return _buildList(movements, loading: false);
          },
          loading: () {
            if (!_hasLoadedOnce) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildList(const [], loading: true);
          },
          error: (e, _) => _buildErrorState('$e'),
        ),
      ),
    );
  }

  Widget _buildList(List<StockMovementEntry> allMovements, {required bool loading}) {
    final sorted = [...allMovements]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final filtered = _filtered(sorted);
    final totalItems = filtered.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);
    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageMovements = filtered.sublist(startIndex, endIndex);

    return RefreshIndicator(
      onRefresh: () => ref.read(movementsProvider.notifier).load(),
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
                        onPressed: _openNewAdjustmentDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(190, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          context.l10n.stockAdjustmentsNewButton,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: (_) => setState(() => _currentPage = 0),
                          decoration: InputDecoration(
                            hintText: context.l10n.stockAdjustmentsSearchHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchCtl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtl.clear();
                                      setState(() => _currentPage = 0);
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: PosTheme.backgroundPage,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(context.l10n.stockAdjustmentsMovementsHeader,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                      ),
                      Text(
                          context.l10n.inventoryShowingCount(
                              '${pageMovements.length}', '$totalItems'),
                          style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageMovements.isEmpty)
                  _buildNoResults(loading: loading)
                else
                  ...pageMovements.map(_buildRow),
                if (pageMovements.isNotEmpty)
                  _buildPagination(
                    currentPage: safeCurrentPage,
                    totalPages: totalPages,
                    totalItems: totalItems,
                  ),
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
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchCtl.text.trim().isEmpty
                  ? context.l10n.stockAdjustmentsNoMovements
                  : context.l10n.stockAdjustmentsNoMatchingMovements,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(StockMovementEntry movement) {
    final isPositive = movement.quantity >= 0;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: isPositive
                ? PosTheme.successGreen.withValues(alpha: 0.15)
                : PosTheme.errorRed.withValues(alpha: 0.15),
            child: Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              color: isPositive ? PosTheme.successGreen : PosTheme.errorRed,
            ),
          ),
          title: Text(movement.productName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              movement.movementType.replaceAll('_', ' '),
              if (movement.reason != null && movement.reason!.isNotEmpty) movement.reason!,
              if (movement.createdBy != null) movement.createdBy!,
            ].join(' • '),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          trailing: Text(
            '${isPositive ? '+' : ''}${movement.quantity.toStringAsFixed(movement.quantity.truncateToDouble() == movement.quantity ? 0 : 2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isPositive ? PosTheme.successGreen : PosTheme.errorRed,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildPagination({
    required int currentPage,
    required int totalPages,
    required int totalItems,
  }) {
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
            tooltip: context.l10n.inventoryFirstPageTooltip,
            onPressed: currentPage == 0 ? null : () => setState(() => _currentPage = 0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: context.l10n.inventoryPreviousPageTooltip,
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
            tooltip: context.l10n.inventoryNextPageTooltip,
            onPressed:
                currentPage >= totalPages - 1 ? null : () => setState(() => _currentPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: context.l10n.inventoryLastPageTooltip,
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
                    child: const Icon(Icons.tune, size: 52, color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  Text(context.l10n.stockAdjustmentsTitle,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.stockAdjustmentsEmptySubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _openNewAdjustmentDialog,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(190, 54),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.stockAdjustmentsNewButton,
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
              onPressed: () => ref.read(movementsProvider.notifier).load(),
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
