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

/// Sales by Category — revenue & quantity per category (like Loyverse).
class CategoryPerformanceScreen extends ConsumerStatefulWidget {
  const CategoryPerformanceScreen({super.key});

  @override
  ConsumerState<CategoryPerformanceScreen> createState() =>
      _CategoryPerformanceScreenState();
}

class _CategoryPerformanceScreenState
    extends ConsumerState<CategoryPerformanceScreen> {
  ReportFilterState _filter = ReportFilterState.initial().copyWith(
    period: ReportPeriod.thisMonth,
    from: DateTime.now().subtract(const Duration(days: 30)),
    to: DateTime.now(),
  );
  int _page = 0;
  static const _pageSize = 20;
  List<CategoryPerformance> _rows = [];
  PageMeta _meta = PageMeta.empty;
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
      final data = await svc.categoryPerformance(
        from: _filter.fromStr,
        to: _filter.toStr,
        fromHour: _filter.fromHour == 0 ? null : _filter.fromHour,
        toHour: _filter.toHour == 23 ? null : _filter.toHour,
        employeeId: _filter.employeeId,
        page: _page,
        size: _pageSize,
      );
      setState(() {
        _rows = data.content;
        _meta = data.meta;
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

  Future<void> _printReport() async {
    if (_rows.isEmpty) return;
    final l10n = context.l10n;
    final language = ref.read(appLanguageProvider);
    try {
      final company =
          await ref.read(settingsServiceProvider).getCompanyProfile();
      final cur = currencySymbol(readCurrency(ref));

      final svc = ref.read(reportServiceProvider);
      final allRows = await fetchAllPages<CategoryPerformance>(
        fetchPage: (page) async {
          final pageData = await svc.categoryPerformance(
            from: _filter.fromStr,
            to: _filter.toStr,
            fromHour: _filter.fromHour == 0 ? null : _filter.fromHour,
            toHour: _filter.toHour == 23 ? null : _filter.toHour,
            employeeId: _filter.employeeId,
            page: page,
            size: reportPrintPageSize,
          );
          return (pageData.content, pageData.meta);
        },
      );

      if (kDebugMode) {
        debugPrint('[ReportPrint] rowsFetched=${allRows.length}');
      }

      String label(CategoryPerformance c) {
        final name = resolveBilingual(
            en: c.categoryNameEn ?? '',
            km: c.categoryNameKm,
            language: language);
        return name.isNotEmpty
            ? name
            : l10n.categoryPerformanceFallbackName(c.categoryId.toString());
      }

      final rows = allRows
          .map((c) => [
                label(c),
                _fmtNum(c.quantity),
                '$cur${_fmtNum(c.total)}',
              ])
          .toList();

      final totalQty = allRows.fold(0.0, (s, c) => s + c.quantity);
      final grandTotal = allRows.fold(0.0, (s, c) => s + c.total);

      final pdfBytes = await A4ReportPdf.build(
        title: l10n.reportsSalesByCategory,
        subtitle: '${_filter.fromStr} — ${_filter.toStr}',
        businessName: '${company['businessName'] ?? ''}',
        businessAddress: '${company['address'] ?? ''}',
        businessPhone: '${company['phone'] ?? ''}',
        columns: [l10n.formCategory, l10n.cartQty, l10n.receiptTotal],
        rows: rows,
        columnAlignments: const {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
        },
        summary: [
          MapEntry(l10n.cartQty, _fmtNum(totalQty)),
          MapEntry(l10n.receiptTotal, '$cur${_fmtNum(grandTotal)}'),
        ],
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'sales_by_category_report',
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
        title: Text(context.l10n.reportsSalesByCategory),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: _rows.isEmpty ? null : _printReport,
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

  /// Resolves the display name for a category row: prefers the
  /// bilingual DB name (switching with the current app language), falling
  /// back to a generic "Category #id" placeholder when no name was set.
  String _categoryLabel(CategoryPerformance c) {
    final lang = ref.watch(appLanguageProvider);
    final name = resolveBilingual(
      en: c.categoryNameEn ?? '',
      km: c.categoryNameKm,
      language: lang,
    );
    return name.isNotEmpty
        ? name
        : context.l10n.categoryPerformanceFallbackName(c.categoryId.toString());
  }

  Widget _buildContent() {
    final totalRev = _rows.fold(0.0, (sum, c) => sum + c.total);
    final chartData = _rows
        .map((c) => (
              label: _categoryLabel(c),
              value: c.total,
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_rows.isNotEmpty) ...[
          Text(context.l10n.categoryPerformanceTopByRevenue,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ReportBarChart(data: chartData, valuePrefix: '\$'),
          const SizedBox(height: 16),
        ],
        if (_rows.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.l10n.reportsNoDataForPeriod,
                  style: const TextStyle(color: PosTheme.textHint)),
            ),
          )
        else
          ..._rows.map((c) {
            final pct = totalRev > 0 ? (c.total / totalRev * 100) : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: PosTheme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_categoryLabel(c),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: PosTheme.textPrimary)),
                        ),
                        Text('\$${_fmtNum(c.total)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: PosTheme.primaryGreen,
                                fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: PosTheme.dividerColor,
                        color: PosTheme.primaryGreen,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                            context.l10n.categoryPerformanceItemsSoldCount(
                                _fmtNum(c.quantity)),
                            style: const TextStyle(
                                fontSize: 12, color: PosTheme.textHint)),
                        const Spacer(),
                        Text('${pct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize: 12, color: PosTheme.textHint)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        if (_rows.isNotEmpty)
          ReportPaginationBar(meta: _meta, onPageChange: _changePage),
      ],
    );
  }

  String _fmtNum(double v) => v.toStringAsFixed(2);
}
