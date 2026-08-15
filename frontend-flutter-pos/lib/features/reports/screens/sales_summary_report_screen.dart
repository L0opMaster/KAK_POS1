import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';
import '../services/report_service.dart';
import '../models/report_models.dart';
import '../widgets/report_filter_bar.dart';
import '../widgets/report_pagination_bar.dart';
import '../widgets/report_charts.dart';

/// Sales Summary Report — daily breakdown with filters (like Loyverse).
class SalesSummaryReportScreen extends ConsumerStatefulWidget {
  const SalesSummaryReportScreen({super.key});

  @override
  ConsumerState<SalesSummaryReportScreen> createState() =>
      _SalesSummaryReportScreenState();
}

class _SalesSummaryReportScreenState
    extends ConsumerState<SalesSummaryReportScreen> {
  ReportFilterState _filter = ReportFilterState.initial().copyWith(
    period: ReportPeriod.thisWeek,
    from: DateTime.now().subtract(const Duration(days: 7)),
    to: DateTime.now(),
  );
  int _page = 0;
  static const _pageSize = 20;
  SalesSummaryReportResponse? _data;
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
      final data = await svc.salesSummary(
        from: _filter.fromStr,
        to: _filter.toStr,
        fromHour: _filter.fromHour == 0 ? null : _filter.fromHour,
        toHour: _filter.toHour == 23 ? null : _filter.toHour,
        employeeId: _filter.employeeId,
        page: _page,
        size: _pageSize,
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

  Future<void> _printReport() async {
    final data = _data;
    if (data == null) return;
    final l10n = context.l10n;
    try {
      final company =
          await ref.read(settingsServiceProvider).getCompanyProfile();
      final cur = currencySymbol(readCurrency(ref));
      final totals = data.totals;

      // Print/export must include every daily row matching the active
      // filters, not just the ~20 currently loaded for on-screen pagination
      // — walk every backend page (same filters, same query). `totals` is
      // already authoritative (the backend computes it from the full
      // filtered set before paginating `rows`), so it doubles as the check
      // for whether every row made it into the PDF.
      final svc = ref.read(reportServiceProvider);
      final allRows = await fetchAllPages<SalesSummaryRow>(
        fetchPage: (page) async {
          final pageData = await svc.salesSummary(
            from: _filter.fromStr,
            to: _filter.toStr,
            fromHour: _filter.fromHour == 0 ? null : _filter.fromHour,
            toHour: _filter.toHour == 23 ? null : _filter.toHour,
            employeeId: _filter.employeeId,
            page: page,
            size: reportPrintPageSize,
          );
          return (pageData.rows, pageData.rowsMeta);
        },
      );

      if (kDebugMode) {
        debugPrint('[ReportPrint] summaryTransactionCount=${totals?.orders} '
            'rowsFetched=${allRows.length} rowsPassedToPdf=${allRows.length}');
      }

      final rows = allRows
          .map((r) => [
                r.date,
                '${r.orders}',
                _fmtNum(r.quantity),
                '$cur${_fmtNum(r.gross)}',
                '$cur${_fmtNum(r.discount)}',
                '$cur${_fmtNum(r.tax)}',
                '$cur${_fmtNum(r.net)}',
              ])
          .toList();

      final pdfBytes = await A4ReportPdf.build(
        title: l10n.salesSummaryPdfTitle,
        subtitle: '${_filter.fromStr} — ${_filter.toStr}',
        businessName: '${company['businessName'] ?? ''}',
        businessAddress: '${company['address'] ?? ''}',
        businessPhone: '${company['phone'] ?? ''}',
        columns: [
          l10n.salesSummaryPdfColDate,
          l10n.salesSummaryPdfColOrders,
          l10n.salesSummaryPdfColQty,
          l10n.salesSummaryPdfColGross,
          l10n.salesSummaryPdfColDiscount,
          l10n.salesSummaryPdfColTax,
          l10n.salesSummaryPdfColNet,
        ],
        rows: rows,
        columnAlignments: const {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
          6: pw.Alignment.centerRight,
        },
        summary: totals == null
            ? const []
            : [
                MapEntry(l10n.salesSummaryPdfGrossSalesLabel,
                    '$cur${_fmtNum(totals.gross)}'),
                MapEntry(l10n.salesSummaryPdfDiscountsLabel,
                    '$cur${_fmtNum(totals.discount)}'),
                MapEntry(
                    l10n.salesSummaryPdfColTax, '$cur${_fmtNum(totals.tax)}'),
                MapEntry(l10n.salesSummaryPdfNetSalesLabel,
                    '$cur${_fmtNum(totals.net)}'),
                MapEntry(l10n.salesSummaryPdfTransactionsLabel,
                    '${totals.orders}'),
                MapEntry(l10n.salesSummaryPdfItemsSoldLabel,
                    _fmtNum(totals.quantity)),
              ],
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'sales_summary_report',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${l10n.printerPrintFailed}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reportsSalesSummary),
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
            ReportFilterBar(
              value: _filter,
              employees: _data?.cashiers ?? const [],
              onChanged: _applyFilter,
            ),
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

  Widget _buildContent() {
    final data = _data;
    if (data == null) return const SizedBox();
    final totals = data.totals;
    final chartData =
        data.rows.map((r) => (label: r.date, value: r.net)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Totals card ──
        if (totals != null)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: PosTheme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(context.l10n.reportsSummary,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _totRow(context.l10n.reportsGrossSales, totals.gross),
                  _totRow(context.l10n.reportsDiscounts, totals.discount,
                      color: PosTheme.errorRed),
                  _totRow(context.l10n.cartTax, totals.tax),
                  const Divider(),
                  _totRow(context.l10n.reportsNetSales, totals.net,
                      bold: true, color: PosTheme.primaryGreen),
                  const Divider(),
                  _totRow(
                      context.l10n.reportsTransactions, totals.orders.toDouble(),
                      isInt: true),
                  _totRow(context.l10n.reportsItemsSold,
                      totals.quantity.toDouble(),
                      isInt: true),
                  if (totals.orders > 0)
                    _totRow(
                        context.l10n.reportsAvgPerSale,
                        totals.net / totals.orders,
                        prefix: '\$'),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // ── Net sales trend ──
        if (data.rows.isNotEmpty) ...[
          Text(context.l10n.reportsNetSalesPerDay,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ReportLineChart(data: chartData, valuePrefix: '\$'),
          const SizedBox(height: 16),
        ],

        // ── Per-cashier breakdown ──
        if (data.cashierBreakdown.isNotEmpty) ...[
          Text(context.l10n.reportsSalesByCashier,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ...data.cashierBreakdown.map((c) => _cashierCard(c)),
          const SizedBox(height: 16),
        ],

        // ── Daily rows table ──
        if (data.rows.isNotEmpty) ...[
          Text(context.l10n.reportsDailyBreakdown,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ...data.rows.map((r) => _rowCard(r)),
          ReportPaginationBar(meta: data.rowsMeta, onPageChange: _changePage),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.l10n.reportsNoDataForPeriod,
                  style: const TextStyle(color: PosTheme.textHint)),
            ),
          ),
      ],
    );
  }

  Widget _totRow(String label, double value,
      {bool bold = false,
      bool isInt = false,
      String prefix = '',
      Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: bold ? PosTheme.textPrimary : PosTheme.textSecondary)),
          Text(
            '$prefix${isInt ? value.toInt().toString() : '\$${_fmtNum(value)}'}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color),
          ),
        ],
      ),
    );
  }

  Widget _rowCard(SalesSummaryRow r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: PosTheme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.date,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: PosTheme.textPrimary)),
            const SizedBox(height: 6),
            Row(
              children: [
                _chip(context.l10n.reportsOrders, '${r.orders}'),
                const SizedBox(width: 8),
                _chip(context.l10n.reportsGross, '\$${_fmtNum(r.gross)}'),
                const SizedBox(width: 8),
                _chip(context.l10n.reportsNet, '\$${_fmtNum(r.net)}',
                    bold: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, {bool bold = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: PosTheme.backgroundPage,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: PosTheme.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _cashierCard(CashierPerformance c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: PosTheme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: PosTheme.backgroundPage,
              child: Icon(Icons.person_rounded,
                  size: 16, color: PosTheme.primaryGreen),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(c.cashierName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: PosTheme.textPrimary)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${_fmtNum(c.salesTotal)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: PosTheme.primaryGreen)),
                Text(
                    c.salesCount == 1
                        ? context.l10n.reportsSalesCountSingular(c.salesCount)
                        : context.l10n.reportsSalesCountPlural(c.salesCount),
                    style: const TextStyle(
                        fontSize: 11, color: PosTheme.textHint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(double v) => v.toStringAsFixed(2);
}
