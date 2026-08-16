import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../widgets/report_list_config.dart';
import 'mobile_report_list_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// payment_mix_screen.dart` via `MobileReportListScreen`. Pie chart +
/// per-row share bar dropped (see `report_list_config.dart`'s doc
/// comment) — the underlying total/count columns are unchanged.
class MobilePaymentMixScreen extends ConsumerWidget {
  const MobilePaymentMixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);
    final service = ref.read(reportServiceProvider);

    return MobileReportListScreen<PaymentBreakdown>(
      config: ReportListConfig<PaymentBreakdown>(
        title: l10n.reportsSalesByPaymentType,
        columns: [
          ReportColumn(header: l10n.receiptPaymentMethod, cell: (r) => r.method),
          ReportColumn(
            header: l10n.reportsTransactions,
            cell: (r) => '${r.count}',
            numeric: true,
          ),
          ReportColumn(
            header: l10n.receiptTotal,
            cell: (r) => formatAmount(r.total, cur),
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
            }) => service.paymentMix(
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
            '${rows.fold<int>(0, (s, r) => s + r.count)}',
          ),
          MapEntry(
            l10n.receiptTotal,
            formatAmount(rows.fold<double>(0, (s, r) => s + r.total), cur),
          ),
        ],
        pdfExport: ReportPdfConfig(pdfTitle: l10n.reportsSalesByPaymentType),
      ),
    );
  }
}
