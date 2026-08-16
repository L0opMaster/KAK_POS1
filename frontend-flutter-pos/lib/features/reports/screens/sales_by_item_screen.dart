import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';
import '../services/report_service.dart';
import '../models/report_models.dart';
import '../widgets/report_filter_bar.dart';
import '../widgets/report_pagination_bar.dart';
import '../widgets/report_charts.dart';

/// Sales by Item — paginated per-product breakdown with a qty/revenue sort
/// toggle and a top-10 bar chart.
class SalesByItemScreen extends ConsumerStatefulWidget {
  const SalesByItemScreen({super.key});

  @override
  ConsumerState<SalesByItemScreen> createState() => _SalesByItemScreenState();
}

class _SalesByItemScreenState extends ConsumerState<SalesByItemScreen> {
  ReportFilterState _filter = ReportFilterState.initial().copyWith(
    period: ReportPeriod.thisWeek,
    from: DateTime.now().subtract(const Duration(days: 7)),
    to: DateTime.now(),
  );
  int _page = 0;
  static const _pageSize = 20;
  String _sort = 'revenue';
  PagedResult<SalesByItemRow>? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(reportServiceProvider);
      final data = await svc.salesByItem(
        from: _filter.fromStr,
        to: _filter.toStr,
        fromHour: _filter.fromHour == 0 ? null : _filter.fromHour,
        toHour: _filter.toHour == 23 ? null : _filter.toHour,
        employeeId: _filter.employeeId,
        page: _page,
        size: _pageSize,
        sort: _sort,
      );
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter(ReportFilterState filter) {
    setState(() {
      _filter = filter;
      _page = 0;
    });
    _load();
  }

  void _changePage(int page) {
    setState(() => _page = page);
    _load();
  }

  void _setSort(String sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _page = 0;
    });
    _load();
  }

  Future<void> _printReport() async {
    if (_data == null) return;
    final l10n = context.l10n;
    final language = ref.read(appLanguageProvider);
    try {
      final company =
          await ref.read(settingsServiceProvider).getCompanyProfile();
      final curCode = readCurrency(ref);

      // Print/export must include every item matching the active filters,
      // not just the ~20 currently loaded for on-screen pagination — walk
      // every backend page (same filters, same query, same sort).
      final svc = ref.read(reportServiceProvider);
      final allRows = await fetchAllPages<SalesByItemRow>(
        fetchPage: (page) async {
          final pageData = await svc.salesByItem(
            from: _filter.fromStr,
            to: _filter.toStr,
            fromHour: _filter.fromHour == 0 ? null : _filter.fromHour,
            toHour: _filter.toHour == 23 ? null : _filter.toHour,
            employeeId: _filter.employeeId,
            page: page,
            size: reportPrintPageSize,
            sort: _sort,
          );
          return (pageData.content, pageData.meta);
        },
      );

      if (kDebugMode) {
        debugPrint('[ReportPrint] rowsFetched=${allRows.length}');
      }

      final rows = allRows
          .map((r) => [
                resolveBilingual(
                    en: r.nameEn, km: r.nameKm, language: language),
                r.sku ?? '',
                _fmtNum(r.quantitySold),
                formatAmount(r.grossSales, curCode),
                formatAmount(r.discount, curCode),
                formatAmount(r.netSales, curCode),
              ])
          .toList();

      final totalQty = allRows.fold(0.0, (s, r) => s + r.quantitySold);
      final totalGross = allRows.fold(0.0, (s, r) => s + r.grossSales);
      final totalDiscount = allRows.fold(0.0, (s, r) => s + r.discount);
      final totalNet = allRows.fold(0.0, (s, r) => s + r.netSales);

      final pdfBytes = await A4ReportPdf.build(
        title: l10n.reportsSalesByItem,
        subtitle: '${_filter.fromStr} — ${_filter.toStr}',
        businessName: '${company['businessName'] ?? ''}',
        businessAddress: '${company['address'] ?? ''}',
        businessPhone: '${company['phone'] ?? ''}',
        columns: [
          l10n.receiptItem,
          l10n.formSku,
          l10n.cartQty,
          l10n.salesByItemGrossLabel,
          l10n.cartDiscount,
          l10n.salesByItemNetLabel,
        ],
        rows: rows,
        columnAlignments: const {
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        summary: [
          MapEntry(l10n.salesSummaryPdfItemsSoldLabel, _fmtNum(totalQty)),
          MapEntry(l10n.salesByItemGrossLabel, formatAmount(totalGross, curCode)),
          MapEntry(l10n.cartDiscount, formatAmount(totalDiscount, curCode)),
          MapEntry(l10n.salesByItemNetLabel, formatAmount(totalNet, curCode)),
        ],
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'sales_by_item_report',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.printerPrintFailed}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reportsSalesByItem),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: _data == null ? null : _printReport,
              tooltip: context.l10n.commonPrint),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: context.l10n.commonRefresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ReportFilterBar(value: _filter, onChanged: _applyFilter),
            Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  label: Text(context.l10n.salesByItemSortByRevenue),
                  selected: _sort == 'revenue',
                  onSelected: (_) => _setSort('revenue'),
                  selectedColor: PosTheme.primaryGreenLight,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _sort == 'revenue'
                        ? PosTheme.primaryGreenDark
                        : PosTheme.textSecondary,
                  ),
                ),
                ChoiceChip(
                  label: Text(context.l10n.salesByItemSortByQuantity),
                  selected: _sort == 'quantity',
                  onSelected: (_) => _setSort('quantity'),
                  selectedColor: PosTheme.primaryGreenLight,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _sort == 'quantity'
                        ? PosTheme.primaryGreenDark
                        : PosTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorView()
            else
              _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _errorView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: PosTheme.errorRed),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: PosTheme.errorRed)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _load, child: Text(context.l10n.commonRetry)),
          ],
        ),
      );

  /// Resolves the display name for a sold-item row, switching between the
  /// bilingual DB name's English/Khmer values with the current app language.
  String _itemLabel(SalesByItemRow r) {
    final lang = ref.watch(appLanguageProvider);
    return resolveBilingual(en: r.nameEn, km: r.nameKm, language: lang);
  }

  Widget _buildContent() {
    final data = _data;
    if (data == null || data.content.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.l10n.reportsNoDataForPeriod,
              style: const TextStyle(color: PosTheme.textHint)),
        ),
      );
    }
    final curCode = watchCurrency(ref);
    final content = data.content;
    final chartData = content
        .take(10)
        .map((r) => (
              label: _itemLabel(r),
              value: _sort == 'revenue' ? r.netSales : r.quantitySold,
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.salesByItemTopItems,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: PosTheme.textPrimary,
                fontSize: 15)),
        const SizedBox(height: 8),
        ReportBarChart(
          data: chartData,
          valueFormatter: _sort == 'revenue'
              ? (v) => formatAmount(v, curCode)
              : (v) => _fmtNum(v),
        ),
        const SizedBox(height: 16),
        ...content.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: PosTheme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_itemLabel(r),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: PosTheme.textPrimary)),
                    if ((r.sku ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                            '${context.l10n.salesByItemSkuLabel} ${r.sku}',
                            style: const TextStyle(
                                fontSize: 11, color: PosTheme.textHint)),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _chip(context.l10n.cartQty, _fmtNum(r.quantitySold)),
                        const SizedBox(width: 8),
                        _chip(context.l10n.salesByItemGrossLabel,
                            formatAmount(r.grossSales, curCode)),
                        const SizedBox(width: 8),
                        _chip(context.l10n.cartDiscount,
                            formatAmount(r.discount, curCode)),
                        const SizedBox(width: 8),
                        _chip(context.l10n.salesByItemNetLabel,
                            formatAmount(r.netSales, curCode),
                            bold: true),
                      ],
                    ),
                  ],
                ),
              ),
            )),
        ReportPaginationBar(meta: data.meta, onPageChange: _changePage),
      ],
    );
  }

  Widget _chip(String label, String value, {bool bold = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: PosTheme.backgroundPage,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
            Text(label,
                style: const TextStyle(fontSize: 9, color: PosTheme.textHint)),
          ],
        ),
      ),
    );
  }

  String _fmtNum(double v) => v.toStringAsFixed(2);
}
