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

/// Sales by Modifier — paginated breakdown of modifier option performance.
class SalesByModifierScreen extends ConsumerStatefulWidget {
  const SalesByModifierScreen({super.key});

  @override
  ConsumerState<SalesByModifierScreen> createState() =>
      _SalesByModifierScreenState();
}

class _SalesByModifierScreenState extends ConsumerState<SalesByModifierScreen> {
  ReportFilterState _filter = ReportFilterState.initial().copyWith(
    period: ReportPeriod.thisWeek,
    from: DateTime.now().subtract(const Duration(days: 7)),
    to: DateTime.now(),
  );
  int _page = 0;
  static const _pageSize = 20;
  PagedResult<ModifierPerformance>? _data;
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
      final data = await svc.salesByModifier(
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
    if (_data == null) return;
    final l10n = context.l10n;
    try {
      final company =
          await ref.read(settingsServiceProvider).getCompanyProfile();
      final cur = currencySymbol(readCurrency(ref));

      final svc = ref.read(reportServiceProvider);
      final allRows = await fetchAllPages<ModifierPerformance>(
        fetchPage: (page) async {
          final pageData = await svc.salesByModifier(
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
          .map((m) => [
                m.groupName,
                m.optionName,
                _fmtNum(m.quantity),
                '$cur${_fmtNum(m.revenue)}',
              ])
          .toList();

      final totalQty = allRows.fold(0.0, (s, m) => s + m.quantity);
      final totalRevenue = allRows.fold(0.0, (s, m) => s + m.revenue);

      final pdfBytes = await A4ReportPdf.build(
        title: l10n.reportsSalesByModifier,
        subtitle: '${_filter.fromStr} — ${_filter.toStr}',
        businessName: '${company['businessName'] ?? ''}',
        businessAddress: '${company['address'] ?? ''}',
        businessPhone: '${company['phone'] ?? ''}',
        columns: [
          l10n.salesByModifierPdfColGroup,
          l10n.salesByModifierPdfColOption,
          l10n.cartQty,
          l10n.reportsRevenue,
        ],
        rows: rows,
        columnAlignments: const {
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        summary: [
          MapEntry(l10n.cartQty, _fmtNum(totalQty)),
          MapEntry(l10n.reportsRevenue, '$cur${_fmtNum(totalRevenue)}'),
        ],
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'sales_by_modifier_report',
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
        title: Text(context.l10n.reportsSalesByModifier),
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
    if (data == null || data.content.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.l10n.reportsNoDataForPeriod,
              style: const TextStyle(color: PosTheme.textHint)),
        ),
      );
    }
    final content = data.content;
    final chartData = content
        .map(
            (m) => (label: '${m.groupName}: ${m.optionName}', value: m.revenue))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.salesByModifierTopOptionsTitle,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: PosTheme.textPrimary,
                fontSize: 15)),
        const SizedBox(height: 8),
        ReportBarChart(data: chartData, valuePrefix: '\$'),
        const SizedBox(height: 16),
        ...content.map((m) => Card(
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
                    Text('${m.groupName}: ${m.optionName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: PosTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _chip(context.l10n.cartQty, _fmtNum(m.quantity)),
                        const SizedBox(width: 8),
                        _chip(context.l10n.reportsRevenue,
                            '\$${_fmtNum(m.revenue)}',
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

  String _fmtNum(double v) => v.toStringAsFixed(2);
}
