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

/// Sales by Cashier — sales totals & transaction counts per cashier.
class CashierPerformanceScreen extends ConsumerStatefulWidget {
  const CashierPerformanceScreen({super.key});

  @override
  ConsumerState<CashierPerformanceScreen> createState() =>
      _CashierPerformanceScreenState();
}

class _CashierPerformanceScreenState
    extends ConsumerState<CashierPerformanceScreen> {
  ReportFilterState _filter = ReportFilterState.initial();
  int _page = 0;
  static const _pageSize = 20;
  List<CashierPerformance> _rows = [];
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
      final data = await svc.cashierPerformance(
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
    try {
      final company =
          await ref.read(settingsServiceProvider).getCompanyProfile();
      final cur = currencySymbol(readCurrency(ref));

      final svc = ref.read(reportServiceProvider);
      final allRows = await fetchAllPages<CashierPerformance>(
        fetchPage: (page) async {
          final pageData = await svc.cashierPerformance(
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

      final rows = allRows
          .map((c) => [
                c.cashierName,
                '${c.salesCount}',
                '$cur${_fmtNum(c.salesTotal)}',
              ])
          .toList();

      final totalCount = allRows.fold(0, (s, c) => s + c.salesCount);
      final totalSales = allRows.fold(0.0, (s, c) => s + c.salesTotal);

      final pdfBytes = await A4ReportPdf.build(
        title: l10n.cashierPerformanceTitle,
        subtitle: '${_filter.fromStr} — ${_filter.toStr}',
        businessName: '${company['businessName'] ?? ''}',
        businessAddress: '${company['address'] ?? ''}',
        businessPhone: '${company['phone'] ?? ''}',
        columns: [
          l10n.receiptCashier,
          l10n.reportsTransactions,
          l10n.receiptTotal
        ],
        rows: rows,
        columnAlignments: const {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
        },
        summary: [
          MapEntry(l10n.reportsTransactions, '$totalCount'),
          MapEntry(l10n.receiptTotal, '$cur${_fmtNum(totalSales)}'),
        ],
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'sales_by_cashier_report',
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
        title: Text(context.l10n.cashierPerformanceTitle),
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
            // Note: cashier dropdown here filters by the same cashier
            // this report already breaks down by — kept for consistency
            // with the shared filter bar used on every report screen.
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

  Widget _buildContent() {
    final maxSales =
        _rows.fold<double>(0, (m, c) => m > c.salesTotal ? m : c.salesTotal);
    final chartData =
        _rows.map((c) => (label: c.cashierName, value: c.salesTotal)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_rows.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.l10n.reportsNoDataForPeriod,
                  style: const TextStyle(color: PosTheme.textHint)),
            ),
          )
        else ...[
          Text(context.l10n.cashierPerformanceTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ReportBarChart(data: chartData, valuePrefix: '\$'),
          const SizedBox(height: 16),
          ..._rows.map((c) {
            final bar = maxSales > 0 ? c.salesTotal / maxSales : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: PosTheme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: PosTheme.backgroundPage,
                          child: Icon(Icons.person_rounded,
                              color: PosTheme.primaryGreen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(c.cashierName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: PosTheme.textPrimary)),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('\$${_fmtNum(c.salesTotal)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: PosTheme.primaryGreen,
                                    fontSize: 15)),
                            Text(
                                context.l10n
                                    .reportsTxCount(c.salesCount.toString()),
                                style: const TextStyle(
                                    fontSize: 12, color: PosTheme.textHint)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bar,
                        backgroundColor: PosTheme.dividerColor,
                        color: PosTheme.primaryGreen,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          ReportPaginationBar(meta: _meta, onPageChange: _changePage),
        ],
      ],
    );
  }

  String _fmtNum(double v) => v.toStringAsFixed(2);
}
