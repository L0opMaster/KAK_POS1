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

/// Sales by Payment Type — revenue breakdown by payment method.
class PaymentMixScreen extends ConsumerStatefulWidget {
  const PaymentMixScreen({super.key});

  @override
  ConsumerState<PaymentMixScreen> createState() => _PaymentMixScreenState();
}

class _PaymentMixScreenState extends ConsumerState<PaymentMixScreen> {
  ReportFilterState _filter = ReportFilterState.initial().copyWith(
    period: ReportPeriod.thisMonth,
    from: DateTime.now().subtract(const Duration(days: 30)),
    to: DateTime.now(),
  );
  int _page = 0;
  static const _pageSize = 20;
  List<PaymentBreakdown> _rows = [];
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
      final data = await svc.paymentMix(
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
      final allRows = await fetchAllPages<PaymentBreakdown>(
        fetchPage: (page) async {
          final pageData = await svc.paymentMix(
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
          .map((p) => [
                p.method,
                '${p.count}',
                '$cur${_fmtNum(p.total)}',
              ])
          .toList();

      final totalCount = allRows.fold(0, (s, p) => s + p.count);
      final grandTotal = allRows.fold(0.0, (s, p) => s + p.total);

      final pdfBytes = await A4ReportPdf.build(
        title: l10n.reportsSalesByPaymentType,
        subtitle: '${_filter.fromStr} — ${_filter.toStr}',
        businessName: '${company['businessName'] ?? ''}',
        businessAddress: '${company['address'] ?? ''}',
        businessPhone: '${company['phone'] ?? ''}',
        columns: [
          l10n.receiptPaymentMethod,
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
          MapEntry(l10n.receiptTotal, '$cur${_fmtNum(grandTotal)}'),
        ],
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'sales_by_payment_type_report',
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
        title: Text(context.l10n.reportsSalesByPaymentType),
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

  Widget _buildContent() {
    final total = _rows.fold<double>(0, (s, p) => s + p.total);
    final chartData =
        _rows.map((p) => (label: p.method, value: p.total)).toList();

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
          Text(context.l10n.paymentMixShareByMethod,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ReportPieChart(data: chartData, valuePrefix: '\$'),
          const SizedBox(height: 16),
          ..._rows.map((p) {
            final pct = total > 0 ? p.total / total * 100 : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: PosTheme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _pmColor(p.method).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_pmIcon(p.method),
                          color: _pmColor(p.method), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.method,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: PosTheme.textPrimary)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: PosTheme.dividerColor,
                              color: _pmColor(p.method),
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$${_fmtNum(p.total)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: PosTheme.textPrimary)),
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
          const SizedBox(height: 8),
          Center(
            child: Text(
                '${context.l10n.paymentMixTotalLabel} \$${_fmtNum(total)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: PosTheme.textPrimary)),
          ),
          const SizedBox(height: 8),
          ReportPaginationBar(meta: _meta, onPageChange: _changePage),
        ],
      ],
    );
  }

  IconData _pmIcon(String m) {
    switch (m.toLowerCase()) {
      case 'cash':
        return Icons.money_rounded;
      case 'card':
      case 'credit_card':
      case 'debit_card':
        return Icons.credit_card_rounded;
      case 'aba':
      case 'khqr':
      case 'qr':
        return Icons.qr_code_rounded;
      case 'credit':
        return Icons.account_balance_rounded;
      case 'transfer':
      case 'bank_transfer':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Color _pmColor(String m) {
    switch (m.toLowerCase()) {
      case 'cash':
        return const Color(0xFF2E7D32);
      case 'card':
      case 'credit_card':
      case 'debit_card':
        return const Color(0xFF1565C0);
      case 'aba':
      case 'khqr':
      case 'qr':
        return const Color(0xFF6A1B9A);
      case 'credit':
        return const Color(0xFFE65100);
      case 'transfer':
      case 'bank_transfer':
        return const Color(0xFF00838F);
      default:
        return const Color(0xFF546E7A);
    }
  }

  String _fmtNum(double v) => v.toStringAsFixed(2);
}
