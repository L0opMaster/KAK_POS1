import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../widgets/report_list_config.dart';
import 'mobile_report_list_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// taxes_screen.dart` via `MobileReportListScreen`. `pdfExport: null` —
/// matching source exactly, this is one of the 3 report screens that
/// never had a print/PDF action (see `report_list_config.dart`'s doc
/// comment). Line chart (taxCollected/day) and the cashier filter are
/// both wired in via the shared config.
class MobileTaxesScreen extends ConsumerWidget {
  const MobileTaxesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);
    final service = ref.read(reportServiceProvider);

    return MobileReportListScreen<TaxReportRow>(
      config: ReportListConfig<TaxReportRow>(
        title: l10n.reportsTaxes,
        columns: [
          ReportColumn(header: l10n.receiptDate, cell: (r) => r.date),
          ReportColumn(
            header: l10n.reportsTaxableSales,
            cell: (r) => formatAmount(r.taxableSales, cur),
            numeric: true,
          ),
          ReportColumn(
            header: l10n.reportsTaxCollected,
            cell: (r) => formatAmount(r.taxCollected, cur),
            numeric: true,
          ),
          ReportColumn(
            header: l10n.reportsSalesLabel,
            cell: (r) => '${r.salesCount}',
            numeric: true,
          ),
        ],
        fetchPage:
            ({
              required from,
              required to,
              fromHour,
              toHour,
              employeeId,
              required page,
              required size,
            }) async {
              final resp = await service.taxRangeReport(
                from: from,
                to: to,
                fromHour: fromHour,
                toHour: toHour,
                employeeId: employeeId,
                page: page,
                size: size,
              );
              return PagedResult(content: resp.rows, meta: resp.meta);
            },
        showEmployeeFilter: true,
        chartKind: ChartKind.line,
        chartValueFormatter: (v) => formatAmount(v, cur),
        chartBuilder: (rows) => [
          for (final r in rows) (label: r.date, value: r.taxCollected),
        ],
      ),
    );
  }
}
