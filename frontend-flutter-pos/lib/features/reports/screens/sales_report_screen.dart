import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../services/report_service.dart';
import '../models/report_models.dart';
import '../widgets/report_filter_bar.dart';
import '../widgets/report_pagination_bar.dart';

/// Receipts — individual sales with items, customers, payments.
class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  ReportFilterState _filter = ReportFilterState.initial().copyWith(
    period: ReportPeriod.thisWeek,
    from: DateTime.now().subtract(const Duration(days: 7)),
    to: DateTime.now(),
  );
  int _page = 0;
  static const _pageSize = 20;
  SalesReportResponse? _data;
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
      final data = await svc.salesReport(
        from: _filter.fromStr,
        to: _filter.toStr,
        cashierId: _filter.employeeId,
        fromHour: _filter.fromHour == 0 ? null : _filter.fromHour,
        toHour: _filter.toHour == 23 ? null : _filter.toHour,
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
        title: Text(context.l10n.navReceipts),
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
    final s = data.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary ──
        if (s != null)
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
                  const SizedBox(height: 12),
                  _sRow(context.l10n.reportsGrossSales,
                      '\$${_fmtNum(s.totalGrossSales)}'),
                  _sRow(context.l10n.reportsNetSales,
                      '\$${_fmtNum(s.totalNetSales)}',
                      bold: true, color: PosTheme.primaryGreen),
                  _sRow(context.l10n.reportsDiscounts,
                      '\$${_fmtNum(s.totalDiscount)}'),
                  _sRow(context.l10n.cartTax, '\$${_fmtNum(s.totalTax)}'),
                  const Divider(),
                  _sRow(context.l10n.reportsSalesCountLabel,
                      '${s.totalSalesCount}'),
                  _sRow(context.l10n.reportsItemsSold, '${s.totalItemsSold}'),
                  _sRow(context.l10n.reportsAvgSale,
                      '\$${_fmtNum(s.averageSaleAmount)}'),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // ── Payment breakdown ──
        if (data.paymentBreakdown.isNotEmpty) ...[
          Text(context.l10n.reportsPaymentMethods,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ...data.paymentBreakdown.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: PosTheme.dividerColor),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(p.method),
                  trailing: Text('\$${_fmtNum(p.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle:
                      Text(context.l10n.reportsTransactionsCount(p.count)),
                ),
              )),
          const SizedBox(height: 16),
        ],

        // ── Individual sales (receipts) ──
        if (data.sales.isNotEmpty) ...[
          Text(context.l10n.navReceipts,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ...data.sales.map((sale) => _saleCard(sale)),
          ReportPaginationBar(meta: data.salesMeta, onPageChange: _changePage),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.l10n.reportsNoReceiptsForPeriod,
                  style: const TextStyle(color: PosTheme.textHint)),
            ),
          ),
      ],
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

  Widget _saleCard(SalesDetail sale) {
    final lang = ref.watch(appLanguageProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: PosTheme.dividerColor),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(sale.saleNumber ?? '#${sale.saleId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: PosTheme.textPrimary)),
            ),
            Text('\$${_fmtNum(sale.netAmount)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: PosTheme.primaryGreen)),
          ],
        ),
        subtitle: Text(
          [
            sale.saleDate ?? '',
            sale.cashierName ?? '',
            sale.paymentMethod ?? '',
            if (sale.tableNumber != null && sale.tableNumber!.isNotEmpty)
              '${context.l10n.posTable} ${sale.tableNumber}',
          ].join('  ·  '),
          style: const TextStyle(fontSize: 12, color: PosTheme.textHint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          if (sale.tableNumber != null && sale.tableNumber!.isNotEmpty)
            _detail(context.l10n.posTable, sale.tableNumber!),
          if (sale.customerName != null)
            _detail(context.l10n.posCustomer, sale.customerName!),
          _detail(context.l10n.reportsGross, '\$${_fmtNum(sale.grossAmount)}'),
          _detail(
              context.l10n.cartDiscount, '\$${_fmtNum(sale.discountAmount)}'),
          _detail(context.l10n.cartTax, '\$${_fmtNum(sale.taxAmount)}'),
          _detail(context.l10n.receiptPaid, '\$${_fmtNum(sale.paidAmount)}'),
          if (sale.balance > 0)
            _detail(context.l10n.reportsBalance, '\$${_fmtNum(sale.balance)}',
                color: PosTheme.errorRed),
          if (sale.creditSale)
            _Badge(context.l10n.reportsCreditSale, PosTheme.warningAmber),
          if (sale.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(context.l10n.navItems,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            ...sale.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            resolveBilingual(
                                en: item.productNameEn,
                                km: item.productNameKm,
                                language: lang),
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('x${_fmtNum(item.quantity)}',
                          style: const TextStyle(
                              fontSize: 12, color: PosTheme.textHint)),
                      const SizedBox(width: 8),
                      Text('\$${_fmtNum(item.totalPrice)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: PosTheme.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  String _fmtNum(double v) => v.toStringAsFixed(2);
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
