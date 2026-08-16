import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';

const _pageSize = 20;

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// sales_report_screen.dart` ("Receipts" in the hub) — COPY/ADAPT NEARLY
/// EXACTLY for the per-sale `ExpansionTile` card (source's own layout is
/// already phone-shaped: a card that expands to show gross/discount/tax/
/// paid/balance/credit-sale badge and nested line items). Filter/
/// pagination follow this port's established date-range pattern (see
/// `MobileReportListScreen`) rather than source's `ReportFilterBar` — the
/// employee/cashier filter is dropped for the same reason noted in
/// `report_list_config.dart`. PDF business header (company name/address/
/// phone) reads from Day 19's `companyProfileProvider`.
class MobileSalesReportScreen extends ConsumerStatefulWidget {
  const MobileSalesReportScreen({super.key});

  @override
  ConsumerState<MobileSalesReportScreen> createState() =>
      _MobileSalesReportScreenState();
}

class _MobileSalesReportScreenState
    extends ConsumerState<MobileSalesReportScreen> {
  late DateTime _from;
  late DateTime _to;
  int _page = 0;
  SalesReportResponse? _data;
  bool _loading = false;
  bool _exporting = false;
  Object? _error;

  static String _iso(DateTime d) => d.toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _to = DateTime(today.year, today.month, today.day);
    _from = _to.subtract(const Duration(days: 6));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(reportServiceProvider)
          .salesReport(
            from: _iso(_from),
            to: _iso(_to),
            page: _page,
            size: _pageSize,
          );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
      _page = 0;
    });
    _load();
  }

  Future<void> _exportPdf() async {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);
    setState(() => _exporting = true);
    try {
      final allSales = await fetchAllPages<SalesDetail>(
        fetchPage: (page) async {
          final pageData = await ref
              .read(reportServiceProvider)
              .salesReport(
                from: _iso(_from),
                to: _iso(_to),
                page: page,
                size: reportPrintPageSize,
              );
          return (pageData.sales, pageData.salesMeta);
        },
      );
      final company = ref.read(companyProfileProvider).valueOrNull;
      final pdfBytes = await A4ReportPdf.build(
        title: l10n.navReceipts,
        subtitle: '${_iso(_from)} — ${_iso(_to)}',
        businessName: company?['businessName'] as String?,
        businessAddress: company?['address'] as String?,
        businessPhone: company?['phone'] as String?,
        columns: [
          l10n.salesReportPdfColReceiptNo,
          l10n.receiptDate,
          l10n.receiptCashier,
          l10n.salesReportPdfColPayment,
          l10n.reportsGross,
          l10n.cartDiscount,
          l10n.cartTax,
          l10n.reportsNet,
        ],
        rows: [
          for (final sale in allSales)
            [
              sale.saleNumber ?? '#${sale.saleId}',
              sale.saleDate ?? '',
              sale.cashierName ?? '',
              sale.paymentMethod ?? '',
              formatAmount(sale.grossAmount, cur),
              formatAmount(sale.discountAmount, cur),
              formatAmount(sale.taxAmount, cur),
              formatAmount(sale.netAmount, cur),
            ],
        ],
        landscape: true,
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );
      await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'receipts.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.printerPrintFailed}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navReceipts),
        actions: [
          IconButton(
            tooltip: l10n.reportsDateRange,
            icon: const Icon(Icons.date_range_outlined),
            onPressed: _pickRange,
          ),
          IconButton(
            tooltip: l10n.commonPrint,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting ? null : _exportPdf,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_error'),
                  const SizedBox(height: PosTheme.spacingSm),
                  OutlinedButton(
                    onPressed: _load,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            )
          : (_data?.sales.isEmpty ?? true)
          ? Center(child: Text(l10n.reportsNoReceiptsForPeriod))
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  if (_data!.summary != null)
                    Padding(
                      padding: const EdgeInsets.all(PosTheme.spacingMd),
                      child: Wrap(
                        spacing: PosTheme.spacingMd,
                        runSpacing: PosTheme.spacingXs,
                        children: [
                          Text(
                            '${l10n.reportsGross}: '
                            '${formatAmount(_data!.summary!.totalGrossSales, cur)}',
                          ),
                          Text(
                            '${l10n.reportsNet}: '
                            '${formatAmount(_data!.summary!.totalNetSales, cur)}',
                          ),
                          Text(
                            l10n.reportsTransactionsCount(
                              _data!.summary!.totalSalesCount,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PosTheme.spacingMd,
                      ),
                      itemCount: _data!.sales.length,
                      itemBuilder: (context, i) =>
                          _SaleCard(sale: _data!.sales[i], cur: cur),
                    ),
                  ),
                  if (_data!.salesMeta.totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.all(PosTheme.spacingSm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _page > 0
                                ? () {
                                    setState(() => _page--);
                                    _load();
                                  }
                                : null,
                          ),
                          Text(
                            l10n.reportPaginationPageInfo(
                              '${_page + 1}',
                              '${_data!.salesMeta.totalPages}',
                              '${_data!.salesMeta.totalElements}',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _page + 1 < _data!.salesMeta.totalPages
                                ? () {
                                    setState(() => _page++);
                                    _load();
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SaleCard extends ConsumerWidget {
  const _SaleCard({required this.sale, required this.cur});

  final SalesDetail sale;
  final String? cur;

  Widget _detail(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: PosTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(color: PosTheme.borderColorOf(context)),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                sale.saleNumber ?? '#${sale.saleId}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              formatAmount(sale.netAmount, cur),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: PosTheme.primaryGreen,
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            sale.saleDate ?? '',
            sale.cashierName ?? '',
            sale.paymentMethod ?? '',
            if ((sale.tableNumber ?? '').isNotEmpty)
              '${l10n.posTable} ${sale.tableNumber}',
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: PosTheme.textHintOf(context)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((sale.tableNumber ?? '').isNotEmpty)
                  _detail(l10n.posTable, sale.tableNumber!),
                if (sale.customerName != null)
                  _detail(l10n.posCustomer, sale.customerName!),
                _detail(l10n.reportsGross, formatAmount(sale.grossAmount, cur)),
                _detail(l10n.cartDiscount, formatAmount(sale.discountAmount, cur)),
                _detail(l10n.cartTax, formatAmount(sale.taxAmount, cur)),
                _detail(l10n.receiptPaid, formatAmount(sale.paidAmount, cur)),
                if (sale.balance > 0)
                  _detail(
                    l10n.reportsBalance,
                    formatAmount(sale.balance, cur),
                    color: PosTheme.errorRed,
                  ),
                if (sale.creditSale)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: PosTheme.warningAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          PosTheme.radiusPill,
                        ),
                      ),
                      child: Text(
                        l10n.reportsCreditSale,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PosTheme.warningAmber,
                        ),
                      ),
                    ),
                  ),
                if (sale.items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.navItems,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final item in sale.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              resolveBilingual(
                                en: item.productNameEn,
                                km: item.productNameKm,
                                language: language,
                              ),
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'x${item.quantity.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: PosTheme.textHintOf(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatAmount(item.totalPrice, cur),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
