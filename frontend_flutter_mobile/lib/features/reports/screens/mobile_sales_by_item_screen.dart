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
/// sales_by_item_screen.dart` via `MobileReportListScreen`. Source's
/// Revenue/Quantity `ChoiceChip` sort toggle (server-side `sort` param,
/// not client sort) is kept — it's the one report-specific control this
/// screen adds on top of the shared config, via a Riverpod-free local
/// `ValueNotifier` swapped into `fetchPage`'s closure. Top-10 bar chart
/// dropped (see `report_list_config.dart`'s doc comment).
class MobileSalesByItemScreen extends ConsumerStatefulWidget {
  const MobileSalesByItemScreen({super.key});

  @override
  ConsumerState<MobileSalesByItemScreen> createState() =>
      _MobileSalesByItemScreenState();
}

class _MobileSalesByItemScreenState
    extends ConsumerState<MobileSalesByItemScreen> {
  String _sort = 'revenue';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final cur = watchCurrency(ref);
    final service = ref.read(reportServiceProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ChoiceChip(
                label: Text(l10n.salesByItemSortByRevenue),
                selected: _sort == 'revenue',
                onSelected: (_) => setState(() => _sort = 'revenue'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(l10n.salesByItemSortByQuantity),
                selected: _sort == 'quantity',
                onSelected: (_) => setState(() => _sort = 'quantity'),
              ),
            ],
          ),
        ),
        Expanded(
          child: MobileReportListScreen<SalesByItemRow>(
            key: ValueKey(_sort),
            config: ReportListConfig<SalesByItemRow>(
              title: l10n.reportsSalesByItem,
              columns: [
                ReportColumn(
                  header: l10n.formSku,
                  cell: (r) => r.sku ?? '',
                ),
                ReportColumn(
                  header: l10n.reportsSalesByItem,
                  cell: (r) =>
                      resolveBilingual(en: r.nameEn, km: r.nameKm, language: language),
                ),
                ReportColumn(
                  header: l10n.cartQty,
                  cell: (r) => r.quantitySold.toStringAsFixed(0),
                  numeric: true,
                ),
                ReportColumn(
                  header: l10n.salesByItemGrossLabel,
                  cell: (r) => formatAmount(r.grossSales, cur),
                  numeric: true,
                ),
                ReportColumn(
                  header: l10n.cartDiscount,
                  cell: (r) => formatAmount(r.discount, cur),
                  numeric: true,
                ),
                ReportColumn(
                  header: l10n.salesByItemNetLabel,
                  cell: (r) => formatAmount(r.netSales, cur),
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
                    final resp = await service.salesByItem(
                      from: from,
                      to: to,
                      fromHour: fromHour,
                      toHour: toHour,
                      page: page,
                      size: size,
                      sort: _sort,
                    );
                    return resp;
                  },
              pdfExport: ReportPdfConfig(
                pdfTitle: l10n.salesByItemTopItems,
                landscape: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
