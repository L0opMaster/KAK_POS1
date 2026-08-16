import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../services/report_service.dart';
import '../models/report_models.dart';
import 'sales_summary_report_screen.dart';
import 'sales_report_screen.dart';
import 'category_performance_screen.dart';
import 'monthly_sales_screen.dart';
import 'top_products_screen.dart';
import 'payment_mix_screen.dart';
import 'cashier_performance_screen.dart';
import 'stock_movement_screen.dart';
import 'sales_by_item_screen.dart';
import 'sales_by_modifier_screen.dart';
import 'discounts_screen.dart';
import 'taxes_screen.dart';

/// Reports hub — Loyverse-inspired main reports menu with categorized cards.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reportsTitle),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sales Reports section ──
          _sectionHeader(context, context.l10n.reportsHubSalesReportsSection,
              Icons.trending_up),
          const SizedBox(height: 8),
          _reportCard(
            context,
            icon: Icons.date_range_rounded,
            title: context.l10n.reportsSalesSummary,
            subtitle: context.l10n.reportsHubSalesSummarySubtitle,
            color: const Color(0xFF2E7D32),
            onTap: () => _push(context, const SalesSummaryReportScreen()),
          ),
          _reportCard(
            context,
            icon: Icons.inventory_rounded,
            title: context.l10n.reportsSalesByItem,
            subtitle: context.l10n.reportsHubSalesByItemSubtitle,
            color: const Color(0xFF388E3C),
            onTap: () => _push(context, const SalesByItemScreen()),
          ),
          _reportCard(
            context,
            icon: Icons.category_rounded,
            title: context.l10n.reportsSalesByCategory,
            subtitle: context.l10n.reportsHubSalesByCategorySubtitle,
            color: const Color(0xFF43A047),
            onTap: () => _push(context, const CategoryPerformanceScreen()),
          ),
          _reportCard(
            context,
            icon: Icons.person_rounded,
            title: context.l10n.cashierPerformanceTitle,
            subtitle: context.l10n.reportsHubSalesByCashierSubtitle,
            color: const Color(0xFF558B2F),
            onTap: () => _push(context, const CashierPerformanceScreen()),
          ),
          _reportCard(
            context,
            icon: Icons.payment_rounded,
            title: context.l10n.reportsSalesByPaymentType,
            subtitle: context.l10n.reportsHubPaymentMixSubtitle,
            color: const Color(0xFF81C784),
            onTap: () => _push(context, const PaymentMixScreen()),
          ),
          _reportCard(
            context,
            icon: Icons.receipt_long_rounded,
            title: context.l10n.navReceipts,
            subtitle: context.l10n.reportsHubReceiptsSubtitle,
            color: const Color(0xFF00695C),
            onTap: () => _push(context, const SalesReportScreen()),
          ),
          _reportCard(
            context,
            icon: Icons.tune_rounded,
            title: context.l10n.reportsHubSalesByModifierTitle,
            subtitle: context.l10n.reportsHubSalesByModifierSubtitle,
            color: const Color(0xFF00897B),
            onTap: () => _push(context, const SalesByModifierScreen()),
          ),
          _reportCard(
            context,
            icon: Icons.discount_rounded,
            title: context.l10n.reportsDiscounts,
            subtitle: context.l10n.reportsHubDiscountsSubtitle,
            color: const Color(0xFFEF6C00),
            onTap: () => _push(context, const DiscountsScreen()),
          ),
          _reportCard(
            context,
            icon: Icons.request_quote_rounded,
            title: context.l10n.reportsTaxes,
            subtitle: context.l10n.reportsHubTaxesSubtitle,
            color: const Color(0xFF6D4C41),
            onTap: () => _push(context, const TaxesScreen()),
          ),
          const SizedBox(height: 20),

          // ── Other Reports section ──
          _sectionHeader(context, context.l10n.reportsHubOtherReportsSection,
              Icons.insights_rounded),
          const SizedBox(height: 8),
          _reportCard(
            context,
            icon: Icons.summarize_rounded,
            title: context.l10n.reportsHubDailyReportTitle,
            subtitle: context.l10n.reportsHubDailyReportSubtitle,
            color: const Color(0xFF1B5E20),
            onTap: () => _push(context, const DailyReportScreen()),
          ),
          _reportCard(
            context,
            icon: Icons.star_rounded,
            title: context.l10n.reportsHubTopProductsTitle,
            subtitle: context.l10n.reportsHubTopProductsSubtitle,
            color: const Color(0xFF66BB6A),
            onTap: () => _push(context, const TopProductsScreen()),
          ),
          const SizedBox(height: 20),

          // ── Performance section ──
          // Note: Cashier Performance was upgraded in place and renamed
          // "Sales by Employee" — it now lives in the Sales Reports section
          // above (same CashierPerformanceScreen, not a duplicate screen).
          _sectionHeader(context, context.l10n.reportsHubPerformanceSection,
              Icons.people_outline),
          const SizedBox(height: 8),
          _reportCard(
            context,
            icon: Icons.calendar_month_rounded,
            title: context.l10n.reportsHubMonthlySalesTitle,
            subtitle: context.l10n.reportsHubMonthlySalesSubtitle,
            color: const Color(0xFF1976D2),
            onTap: () => _push(context, const MonthlySalesScreen()),
          ),
          const SizedBox(height: 20),

          // ── Inventory section ──
          _sectionHeader(
              context, context.l10n.navInventory, Icons.inventory_2_rounded),
          const SizedBox(height: 8),
          _reportCard(
            context,
            icon: Icons.swap_vert_rounded,
            title: context.l10n.reportsHubStockMovementsTitle,
            subtitle: context.l10n.reportsHubStockMovementsSubtitle,
            color: const Color(0xFF6A1B9A),
            onTap: () => _push(context, const StockMovementScreen()),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: PosTheme.textHint),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PosTheme.textHint,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: PosTheme.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: PosTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PosTheme.textHint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: PosTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

// ══════════════════════════════════════════════
// Daily / X-Report Screen
// ══════════════════════════════════════════════

class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  String _selectedDate = _today();
  DailyReportResponse? _data;
  bool _loading = false;
  String? _error;

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(reportServiceProvider);
      final data = await svc.dailyReport(_selectedDate);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_selectedDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      final ds =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _selectedDate = ds);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reportsHubDailyReportTitle),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
            tooltip: context.l10n.reportsHubChangeDateTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: context.l10n.commonRefresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: PosTheme.errorRed),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: PosTheme.errorRed)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _load,
                            child: Text(context.l10n.commonRetry)),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final s = _data?.summary;
    final cur = watchCurrency(ref);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary card ──
          if (s != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: PosTheme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _selectedDate,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    _metricRow(context.l10n.reportsHubGrossSales,
                        s.grossSales,
                        currencyCode: cur),
                    _metricRow(context.l10n.reportsHubNetSales, s.netSales,
                        currencyCode: cur,
                        color: PosTheme.primaryGreen, bold: true),
                    _metricRow(context.l10n.reportsHubTransactions,
                        s.salesCount.toDouble(),
                        isInt: true),
                    if (s.salesCount > 0)
                      _metricRow(
                        context.l10n.reportsHubAvgPerSale,
                        s.netSales / s.salesCount,
                        currencyCode: cur,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // ── Payment breakdown ──
          if ((_data?.payments.length ?? 0) > 0) ...[
            _sectionTitle(context.l10n.reportsHubPaymentBreakdown),
            const SizedBox(height: 8),
            ..._data!.payments.map(
              (p) => _listRow(p.method, formatAmount(p.total, cur),
                  context.l10n.reportsTxCount(p.count.toString())),
            ),
            const SizedBox(height: 16),
          ],

          // ── Top Products ──
          if ((_data?.topProducts.length ?? 0) > 0) ...[
            _sectionTitle(context.l10n.reportsHubTopProductsTitle),
            const SizedBox(height: 8),
            ..._data!.topProducts.take(5).map(
                  (p) => _listRow(
                    _topProductLabel(p),
                    formatAmount(p.total, cur),
                    context.l10n.reportsHubQuantitySold(_fmtNum(p.quantity)),
                  ),
                ),
            const SizedBox(height: 16),
          ],

          // ── Cashiers ──
          if ((_data?.cashiers.length ?? 0) > 0) ...[
            _sectionTitle(context.l10n.reportsHubCashierPerformanceSection),
            const SizedBox(height: 8),
            ..._data!.cashiers.map(
              (c) => _listRow(
                c.cashierName,
                formatAmount(c.salesTotal, cur),
                context.l10n.reportsTxCount(c.salesCount.toString()),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Shifts ──
          if ((_data?.shifts.length ?? 0) > 0) ...[
            _sectionTitle(context.l10n.navShifts),
            const SizedBox(height: 8),
            ..._data!.shifts.map(
              (s) => _listRow(
                s.openedBy ?? context.l10n.reportsHubNotAvailable,
                formatAmount(s.salesTotal, cur),
                s.status ?? '',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: PosTheme.textHint,
                fontSize: 13)),
      );

  Widget _metricRow(String label, double value,
      {bool bold = false,
      bool isInt = false,
      String? currencyCode,
      Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14, color: bold ? null : PosTheme.textSecondary)),
          Text(
            isInt
                ? value.toInt().toString()
                : formatAmount(value, currencyCode),
            style: TextStyle(
                fontSize: 15,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color),
          ),
        ],
      ),
    );
  }

  Widget _listRow(String title, String value, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 14, color: PosTheme.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimary)),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(subtitle,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: PosTheme.textHint)),
          ),
        ],
      ),
    );
  }

  String _fmtNum(double v) => v.toStringAsFixed(2);

  /// Resolves the display name for a top-product row, switching between the
  /// bilingual DB name's English/Khmer values with the current app language.
  String _topProductLabel(TopProduct p) {
    final lang = ref.watch(appLanguageProvider);
    return resolveBilingual(en: p.nameEn, km: p.nameKm, language: lang);
  }
}
