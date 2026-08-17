import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../widgets/report_list_config.dart';
import 'mobile_report_list_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// sales_by_modifier_screen.dart` via `MobileReportListScreen`. Bar chart
/// (labeled `"$groupName: $optionName"`) and the cashier filter are both
/// wired in via the shared config.
class MobileSalesByModifierScreen extends ConsumerWidget {
  const MobileSalesByModifierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);
    final service = ref.read(reportServiceProvider);

    return MobileReportListScreen<ModifierPerformance>(
      config: ReportListConfig<ModifierPerformance>(
        title: l10n.reportsSalesByModifier,
        columns: [
          ReportColumn(
            header: l10n.salesByModifierPdfColGroup,
            cell: (r) => r.groupName,
          ),
          ReportColumn(
            header: l10n.salesByModifierPdfColOption,
            cell: (r) => r.optionName,
          ),
          ReportColumn(
            header: l10n.cartQty,
            cell: (r) => r.quantity.toStringAsFixed(0),
            numeric: true,
          ),
          ReportColumn(
            header: l10n.reportsRevenue,
            cell: (r) => formatAmount(r.revenue, cur),
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
            }) => service.salesByModifier(
              from: from,
              to: to,
              fromHour: fromHour,
              toHour: toHour,
              employeeId: employeeId,
              page: page,
              size: size,
            ),
        summaryBuilder: (rows) => [
          MapEntry(
            l10n.reportsRevenue,
            formatAmount(rows.fold<double>(0, (s, r) => s + r.revenue), cur),
          ),
        ],
        pdfExport: ReportPdfConfig(
          pdfTitle: l10n.salesByModifierTopOptionsTitle,
        ),
        showEmployeeFilter: true,
        chartKind: ChartKind.bar,
        chartValueFormatter: (v) => formatAmount(v, cur),
        chartBuilder: (rows) => [
          for (final r in rows)
            (label: '${r.groupName}: ${r.optionName}', value: r.revenue),
        ],
      ),
    );
  }
}
