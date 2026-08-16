import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../widgets/report_list_config.dart';
import 'mobile_report_list_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// cashier_performance_screen.dart` via `MobileReportListScreen`. Bar
/// chart dropped (see `report_list_config.dart`'s doc comment).
class MobileCashierPerformanceScreen extends ConsumerWidget {
  const MobileCashierPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);
    final service = ref.read(reportServiceProvider);

    return MobileReportListScreen<CashierPerformance>(
      config: ReportListConfig<CashierPerformance>(
        title: l10n.cashierPerformanceTitle,
        columns: [
          ReportColumn(header: l10n.receiptCashier, cell: (r) => r.cashierName),
          ReportColumn(
            header: l10n.reportsTransactions,
            cell: (r) => '${r.salesCount}',
            numeric: true,
          ),
          ReportColumn(
            header: l10n.receiptTotal,
            cell: (r) => formatAmount(r.salesTotal, cur),
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
            }) => service.cashierPerformance(
              from: from,
              to: to,
              fromHour: fromHour,
              toHour: toHour,
              page: page,
              size: size,
            ),
        summaryBuilder: (rows) => [
          MapEntry(
            l10n.reportsTransactions,
            '${rows.fold<int>(0, (s, r) => s + r.salesCount)}',
          ),
          MapEntry(
            l10n.receiptTotal,
            formatAmount(rows.fold<double>(0, (s, r) => s + r.salesTotal), cur),
          ),
        ],
        pdfExport: ReportPdfConfig(pdfTitle: l10n.cashierPerformanceTitle),
      ),
    );
  }
}
