import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../widgets/report_list_config.dart';
import 'mobile_report_list_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// discounts_screen.dart` via `MobileReportListScreen`. Bar chart (top 15
/// by amount) dropped (see `report_list_config.dart`'s doc comment); the
/// totals card is kept as the PDF's summary section, computed from the
/// full (all-pages) row set rather than the backend's own `totals` field
/// — same numbers either way, just derived client-side to fit the shared
/// config's `summaryBuilder` shape.
class MobileDiscountsScreen extends ConsumerWidget {
  const MobileDiscountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);
    final service = ref.read(reportServiceProvider);

    return MobileReportListScreen<DiscountRow>(
      config: ReportListConfig<DiscountRow>(
        title: l10n.reportsDiscounts,
        columns: [
          ReportColumn(
            header: l10n.salesReportPdfColReceiptNo,
            cell: (r) => r.saleNumber ?? '#${r.saleId}',
          ),
          ReportColumn(header: l10n.receiptDate, cell: (r) => r.date ?? ''),
          ReportColumn(
            header: l10n.receiptCashier,
            cell: (r) => r.employeeName ?? '',
          ),
          ReportColumn(
            header: l10n.stockMovementPdfColType,
            cell: (r) => r.discountType ?? '',
          ),
          ReportColumn(
            header: l10n.receiptAmount,
            cell: (r) => formatAmount(r.amount, cur),
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
              final resp = await service.discounts(
                from: from,
                to: to,
                fromHour: fromHour,
                toHour: toHour,
                page: page,
                size: size,
              );
              return PagedResult(content: resp.rows, meta: resp.meta);
            },
        summaryBuilder: (rows) => [
          MapEntry(l10n.discountsScreenDiscountsGiven, '${rows.length}'),
          MapEntry(
            l10n.discountsScreenTotalDiscountAmount,
            formatAmount(rows.fold<double>(0, (s, r) => s + r.amount), cur),
          ),
        ],
        pdfExport: ReportPdfConfig(pdfTitle: l10n.reportsDiscounts),
      ),
    );
  }
}
