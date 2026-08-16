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
/// chart dropped (see `report_list_config.dart`'s doc comment). Category
/// name falls back to `categoryPerformanceFallbackName('#id')`, matching
/// source, for rows whose category was deleted after the sale.
class MobileCategoryPerformanceScreen extends ConsumerWidget {
  const MobileCategoryPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final cur = watchCurrency(ref);
    final service = ref.read(reportServiceProvider);

    return MobileReportListScreen<CategoryPerformance>(
      config: ReportListConfig<CategoryPerformance>(
        title: l10n.reportsSalesByCategory,
        columns: [
          ReportColumn(
            header: l10n.formCategory,
            cell: (r) => r.categoryNameEn != null
                ? resolveBilingual(
                    en: r.categoryNameEn!,
                    km: r.categoryNameKm,
                    language: language,
                  )
                : l10n.categoryPerformanceFallbackName('${r.categoryId}'),
          ),
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
              required page,
              required size,
            }) => service.categoryPerformance(
              from: from,
              to: to,
              fromHour: fromHour,
              toHour: toHour,
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
      ),
    );
  }
}
