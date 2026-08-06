import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../services/report_service.dart';
import '../models/report_models.dart';
import '../widgets/report_filter_bar.dart';
import '../widgets/report_pagination_bar.dart';
import '../widgets/report_charts.dart';

/// Discounts — discount transactions with totals, filters and pagination.
class DiscountsScreen extends ConsumerStatefulWidget {
  const DiscountsScreen({super.key});

  @override
  ConsumerState<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends ConsumerState<DiscountsScreen> {
  ReportFilterState _filter = ReportFilterState.initial().copyWith(
    period: ReportPeriod.thisWeek,
    from: DateTime.now().subtract(const Duration(days: 7)),
    to: DateTime.now(),
  );
  int _page = 0;
  static const _pageSize = 20;
  DiscountsResponse? _data;
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
      final data = await svc.discounts(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reportsDiscounts),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
    if (data == null) return const SizedBox();
    final chartData = data.rows
        .take(15)
        .map((r) => (
              label: r.date ?? (r.saleNumber ?? '#${r.saleId}'),
              value: r.amount,
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Totals card ──
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
                Text(context.l10n.discountsScreenSummary,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _sRow(context.l10n.discountsScreenDiscountsGiven,
                    '${data.totals.count}'),
                _sRow(context.l10n.discountsScreenTotalDiscountAmount,
                    '\$${_fmtNum(data.totals.totalAmount)}',
                    bold: true, color: PosTheme.accentBlue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (data.rows.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.l10n.discountsScreenNoData,
                  style: const TextStyle(color: PosTheme.textHint)),
            ),
          )
        else ...[
          Text(context.l10n.discountsScreenChartTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ReportBarChart(data: chartData, valuePrefix: '\$'),
          const SizedBox(height: 16),
          Text(context.l10n.discountsScreenTransactionsTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ...data.rows.map(_rowCard),
          ReportPaginationBar(meta: data.meta, onPageChange: _changePage),
        ],
      ],
    );
  }

  Widget _rowCard(DiscountRow r) {
    final hasReason = r.reason != null && r.reason!.isNotEmpty;
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
            Row(
              children: [
                Expanded(
                  child: Text(r.saleNumber ?? '#${r.saleId}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: PosTheme.textPrimary)),
                ),
                Text('-\$${_fmtNum(r.amount)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: PosTheme.accentBlue,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (r.date != null) r.date!,
                if (r.employeeName != null) r.employeeName!,
                if (r.discountType != null) r.discountType!,
              ].join('  ·  '),
              style: const TextStyle(fontSize: 12, color: PosTheme.textHint),
            ),
            if (hasReason) ...[
              const SizedBox(height: 4),
              Text(r.reason!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: PosTheme.textSecondary,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: bold ? PosTheme.textPrimary : PosTheme.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  String _fmtNum(double v) => v.toStringAsFixed(2);
}
