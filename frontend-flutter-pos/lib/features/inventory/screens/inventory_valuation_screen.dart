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

/// Read-only report: current stock-on-hand value per product, plus a
/// grand total — mirrors InventoryDtos.StockValuationResponse exactly
/// (cost-based valuation, not sale price).
class InventoryValuationScreen extends ConsumerStatefulWidget {
  const InventoryValuationScreen({super.key});

  @override
  ConsumerState<InventoryValuationScreen> createState() =>
      _InventoryValuationScreenState();
}

class _InventoryValuationScreenState
    extends ConsumerState<InventoryValuationScreen> {
  static const int _pageSize = 10;

  final TextEditingController _searchCtl = TextEditingController();
  int _currentPage = 0;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(inventoryValuationProvider.notifier).loadReport());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<InventoryValuationItem> _filtered(List<InventoryValuationItem> items) {
    final needle = _searchCtl.text.trim().toLowerCase();
    if (needle.isEmpty) return items;
    return items
        .where((i) =>
            i.productName.toLowerCase().contains(needle) ||
            i.sku.toLowerCase().contains(needle))
        .toList();
  }

  Future<Uint8List?> _buildPdfBytes() async {
    final report = ref.read(inventoryValuationProvider).value;
    if (report == null) return null;
    final l10n = context.l10n;
    final company = await ref.read(settingsServiceProvider).getCompanyProfile();
    final cur = currencySymbol(readCurrency(ref));
    final items = _filtered(report.items);

    final rows = items
        .map((i) => [
              i.productName,
              i.sku,
              i.stock.toStringAsFixed(
                  i.stock.truncateToDouble() == i.stock ? 0 : 2),
              '$cur${i.cost.toStringAsFixed(2)}',
              '$cur${i.totalValue.toStringAsFixed(2)}',
            ])
        .toList();

    return A4ReportPdf.build(
      title: l10n.inventoryValuationTitle,
      subtitle: report.valuedAt != null
          ? l10n.inventoryValuationAsOf('${report.valuedAt}')
          : null,
      businessName: '${company['businessName'] ?? ''}',
      businessAddress: '${company['address'] ?? ''}',
      businessPhone: '${company['phone'] ?? ''}',
      columns: [
        l10n.inventoryValuationColProduct,
        l10n.formSku,
        l10n.inventoryValuationColStock,
        l10n.formCost,
        l10n.inventoryValuationColValue,
      ],
      rows: rows,
      columnAlignments: const {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      summary: [
        MapEntry(l10n.inventoryValuationProductsLabel, '${items.length}'),
        MapEntry(l10n.inventoryValuationPdfTotalValueLabel,
            '$cur${report.totalValue.toStringAsFixed(2)}'),
      ],
      generatedAt: DateTime.now(),
      generatedLabel: l10n.reportPdfGeneratedLabel,
      pageLabel: l10n.reportPdfPageLabel,
    );
  }

  Future<void> _printReport() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildPdfBytes();
      if (bytes == null) return;
      await Printing.layoutPdf(onLayout: (_) => bytes, name: 'inventory_valuation');
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
      await Printing.sharePdf(bytes: bytes, filename: 'inventory_valuation.pdf');
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
    final state = ref.watch(inventoryValuationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.inventoryValuationTitle),
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
            onPressed: () =>
                ref.read(inventoryValuationProvider.notifier).loadReport(),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (report) {
            if (report == null)
              return const Center(child: CircularProgressIndicator());
            return _buildContent(report);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildErrorState('$e'),
        ),
      ),
    );
  }

  Widget _buildContent(InventoryValuationReport report) {
    final filtered = _filtered(report.items);
    final totalItems = filtered.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);
    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageItems = filtered.sublist(startIndex, endIndex);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(inventoryValuationProvider.notifier).loadReport(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          Card(
            elevation: 0,
            color: PosTheme.primaryGreen,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.inventoryValuationTotalValue,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text('\$${report.totalValue.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold)),
                        if (report.valuedAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                              context.l10n
                                  .inventoryValuationAsOf('${report.valuedAt}'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${report.totalProducts}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text(context.l10n.inventoryValuationProductsLabel,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            elevation: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 24, 30, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            context.l10n.inventoryValuationStockByProduct,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: (_) => setState(() => _currentPage = 0),
                          decoration: InputDecoration(
                            hintText: context.l10n.posSearchHint,
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
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusMedium),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 0, horizontal: 12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(context.l10n.inventoryValuationColProduct,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54))),
                      SizedBox(
                          width: 70,
                          child: Text(context.l10n.inventoryValuationColStock,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54))),
                      SizedBox(
                          width: 90,
                          child: Text(context.l10n.formCost,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54))),
                      SizedBox(
                          width: 100,
                          child: Text(context.l10n.inventoryValuationColValue,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54))),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(context.l10n.inventoryNoProductsFound,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54)),
                        ],
                      ),
                    ),
                  )
                else
                  ...pageItems.map(_buildRow),
                if (pageItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          context.l10n.inventoryPaginationRange(
                              '${startIndex + 1}', '$endIndex', '$totalItems'),
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          onPressed: safeCurrentPage == 0
                              ? null
                              : () => setState(() => _currentPage = 0),
                          icon: const Icon(Icons.first_page),
                        ),
                        IconButton(
                          onPressed: safeCurrentPage == 0
                              ? null
                              : () => setState(
                                  () => _currentPage = safeCurrentPage - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 100),
                          alignment: Alignment.center,
                          child: Text(
                              context.l10n.inventoryPaginationPage(
                                  '${safeCurrentPage + 1}', '$totalPages'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        IconButton(
                          onPressed: safeCurrentPage >= totalPages - 1
                              ? null
                              : () => setState(
                                  () => _currentPage = safeCurrentPage + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                        IconButton(
                          onPressed: safeCurrentPage >= totalPages - 1
                              ? null
                              : () =>
                                  setState(() => _currentPage = totalPages - 1),
                          icon: const Icon(Icons.last_page),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(InventoryValuationItem item) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    if (item.sku.isNotEmpty)
                      Text('${context.l10n.formSku}: ${item.sku}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                    item.stock.toStringAsFixed(
                        item.stock.truncateToDouble() == item.stock ? 0 : 2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13)),
              ),
              SizedBox(
                width: 90,
                child: Text('\$${item.cost.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13)),
              ),
              SizedBox(
                width: 100,
                child: Text('\$${item.totalValue.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PosTheme.primaryGreen)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
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
              onPressed: () =>
                  ref.read(inventoryValuationProvider.notifier).loadReport(),
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
