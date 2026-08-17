import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../widgets/report_list_config.dart';
import 'mobile_report_list_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// category_performance_screen.dart` via `MobileReportListScreen`. Bar
/// chart (revenue per category) and the cashier filter are both wired in
/// via the shared config. Category name falls back to
/// `categoryPerformanceFallbackName('#id')`, matching source, for rows
/// whose category was deleted after the sale — same fallback used for the
/// chart's bar labels as for the table column.
class MobileCategoryPerformanceScreen extends ConsumerWidget {
  const MobileCategoryPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final cur = watchCurrency(ref);
    final service = ref.read(reportServiceProvider);

    String categoryLabel(CategoryPerformance r) => r.categoryNameEn != null
        ? resolveBilingual(
            en: r.categoryNameEn!,
            km: r.categoryNameKm,
            language: language,
          )
        : l10n.categoryPerformanceFallbackName('${r.categoryId}');

    return MobileReportListScreen<CategoryPerformance>(
      config: ReportListConfig<CategoryPerformance>(
        title: l10n.reportsSalesByCategory,
        columns: [
          ReportColumn(header: l10n.formCategory, cell: categoryLabel),
          ReportColumn(
            header: l10n.cartQty,
            cell: (r) => r.quantity.toStringAsFixed(0),
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
              employeeId,
              required page,
              required size,
            }) => service.categoryPerformance(
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
            l10n.receiptTotal,
            formatAmount(rows.fold<double>(0, (s, r) => s + r.total), cur),
          ),
        ],
        pdfExport: ReportPdfConfig(pdfTitle: l10n.reportsSalesByCategory),
        showEmployeeFilter: true,
        chartKind: ChartKind.bar,
        chartValueFormatter: (v) => formatAmount(v, cur),
        chartBuilder: (rows) => [
          for (final r in rows) (label: categoryLabel(r), value: r.total),
        ],
      ),
    );
  }
}
