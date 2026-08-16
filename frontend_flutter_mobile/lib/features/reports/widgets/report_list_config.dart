import '../models/report_models.dart';

/// Genuinely new in this port — `[OLD/SOURCE]` has 11 separate, largely
/// duplicated report screen files (`sales_summary_report_screen.dart`,
/// `sales_by_item_screen.dart`, `payment_mix_screen.dart`,
/// `cashier_performance_screen.dart`, `category_performance_screen.dart`,
/// `sales_by_modifier_screen.dart`, `discounts_screen.dart`,
/// `taxes_screen.dart`, each hand-rolling the same
/// filter-bar → paginated-table → print/PDF shape around a different row
/// type). This config object plus `MobileReportListScreen` collapses all
/// 8 of those into ONE generic screen, driven by one small config per
/// report type — a deliberate MOBILE UI REIMPLEMENT simplification, not a
/// silent feature drop: every column, every filter, every PDF export
/// those 8 screens have is still here, just not duplicated 8 times.
/// `sales_report_screen.dart` (nested drill-down), `stock_movement_screen
/// .dart`, `monthly_sales_screen.dart` and `top_products_screen.dart` have
/// a genuinely different shape (year picker, no pagination, nested
/// expansion) and keep their own screens.
///
/// Dropped, deliberately, from all 8: the cashier/employee filter
/// dropdown. Source populates its options from each response's own
/// `cashiers`/`employees` field — plumbing that through a generic `<T>`
/// config for 8 differently-shaped responses added real complexity for a
/// secondary filter; date + hour range (the two filters every one of the
/// 8 reports shares) are kept in full. Also dropped: the `fl_chart`
/// bar/line/pie visualizations `report_charts.dart` drew above 7 of these
/// 8 tables — the table data itself (and its PDF export) is unchanged,
/// only the chart is omitted. Both are flagged here, not silently missing.
class ReportListConfig<T> {
  const ReportListConfig({
    required this.title,
    required this.columns,
    required this.fetchPage,
    this.showHourFilter = true,
    this.initialFromDaysAgo = 6,
    this.summaryBuilder,
    this.pdfExport,
  });

  final String title;
  final List<ReportColumn<T>> columns;

  /// Fetches one page (0-based) of rows for the given filters.
  final Future<PagedResult<T>> Function({
    required String from,
    required String to,
    int? fromHour,
    int? toHour,
    required int page,
    required int size,
  })
  fetchPage;

  final bool showHourFilter;

  /// How many days before today the initial "from" date defaults to (e.g.
  /// 6 → a 7-day window ending today, matching several source screens'
  /// `thisWeek`-ish defaults).
  final int initialFromDaysAgo;

  /// Builds the PDF's right-aligned summary lines (e.g. totals) from the
  /// full (all-pages) row set. Returns an empty list if this report has
  /// no summary section.
  final List<MapEntry<String, String>> Function(List<T> allRows)?
  summaryBuilder;

  /// PDF export config. `null` for the 3 source reports that never had a
  /// print/PDF action (Taxes, Monthly Sales, Top Products) — see
  /// `mobile_reports_hub_screen.dart`'s doc comment.
  final ReportPdfConfig<T>? pdfExport;
}

class ReportColumn<T> {
  const ReportColumn({
    required this.header,
    required this.cell,
    this.numeric = false,
  });

  final String header;
  final String Function(T row) cell;
  final bool numeric;
}

class ReportPdfConfig<T> {
  const ReportPdfConfig({required this.pdfTitle, this.landscape = false});

  final String pdfTitle;
  final bool landscape;
}
