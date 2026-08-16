import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../widgets/report_list_config.dart';
import 'mobile_report_list_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// sales_summary_report_screen.dart` via the shared
/// `MobileReportListScreen` (see `report_list_config.dart`). Dropped: the
/// per-cashier breakdown section and the net-sales/day line chart — both
/// genuinely secondary to the daily table itself, which carries every
/// column and the PDF export. `reports_hub_screen.dart`'s subtitle key
/// (`reportsHubSalesSummarySubtitle`) is reused here rather than
/// duplicated.
class MobileSalesSummaryScreen extends ConsumerWidget {
  const MobileSalesSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);
    final service = ref.read(reportServiceProvider);

    return MobileReportListScreen<SalesSummaryRow>(
      config: ReportListConfig<SalesSummaryRow>(
        title: l10n.reportsSalesSummary,
        columns: [
          ReportColumn(header: l10n.salesSummaryPdfColDate, cell: (r) => r.date),
          ReportColumn(
            header: l10n.salesSummaryPdfColOrders,
            cell: (r) => '${r.orders}',
            numeric: true,
          ),
          ReportColumn(
            header: l10n.salesSummaryPdfColQty,
            cell: (r) => r.quantity.toStringAsFixed(0),
            numeric: true,
          ),
          ReportColumn(
            header: l10n.salesSummaryPdfColGross,
            cell: (r) => formatAmount(r.gross, cur),
            numeric: true,
          ),
          ReportColumn(
            header: l10n.salesSummaryPdfColDiscount,
            cell: (r) => formatAmount(r.discount, cur),
            numeric: true,
          ),
          ReportColumn(
            header: l10n.salesSummaryPdfColTax,
            cell: (r) => formatAmount(r.tax, cur),
            numeric: true,
          ),
          ReportColumn(
            header: l10n.salesSummaryPdfColNet,
            cell: (r) => formatAmount(r.net, cur),
            numeric: true,
          ),
        ],
        fetchPage:
            ({
              required from,
              required to,
              fromHour,
              toHour,
              required page,
              required size,
            }) async {
              final resp = await service.salesSummary(
                from: from,
                to: to,
                fromHour: fromHour,
                toHour: toHour,
                page: page,
                size: size,
              );
              return PagedResult(content: resp.rows, meta: resp.rowsMeta);
            },
        summaryBuilder: (rows) {
          final gross = rows.fold<double>(0, (s, r) => s + r.gross);
          final discount = rows.fold<double>(0, (s, r) => s + r.discount);
          final net = rows.fold<double>(0, (s, r) => s + r.net);
          final orders = rows.fold<int>(0, (s, r) => s + r.orders);
          return [
            MapEntry(l10n.salesSummaryPdfTransactionsLabel, '$orders'),
            MapEntry(l10n.salesSummaryPdfGrossSalesLabel, formatAmount(gross, cur)),
            MapEntry(l10n.salesSummaryPdfDiscountsLabel, formatAmount(discount, cur)),
            MapEntry(l10n.salesSummaryPdfNetSalesLabel, formatAmount(net, cur)),
          ];
        },
        pdfExport: ReportPdfConfig(pdfTitle: l10n.salesSummaryPdfTitle),
      ),
    );
  }
}
