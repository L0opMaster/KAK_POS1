import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// reports_hub_screen.dart`'s inline `DailyReportScreen` (the X-report —
/// lives inside the hub file in source, not its own file) — COPY/ADAPT
/// NEARLY EXACTLY. Single date picker (not a range), no filter bar, pure
/// read-only view: summary card, payment breakdown, top 5 products,
/// cashiers, shifts. No print/PDF action, matching source.
class MobileDailyReportScreen extends ConsumerStatefulWidget {
  const MobileDailyReportScreen({super.key});

  @override
  ConsumerState<MobileDailyReportScreen> createState() =>
      _MobileDailyReportScreenState();
}

class _MobileDailyReportScreenState
    extends ConsumerState<MobileDailyReportScreen> {
  String _selectedDate = _today();
  DailyReportResponse? _data;
  bool _loading = false;
  Object? _error;

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
      final data = await ref
          .read(reportServiceProvider)
          .dailyReport(_selectedDate);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
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
      final ds = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      setState(() => _selectedDate = ds);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsHubDailyReportTitle),
        actions: [
          IconButton(
            tooltip: l10n.reportsHubChangeDateTooltip,
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
          IconButton(
            tooltip: l10n.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
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
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: PosTheme.errorRed,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: PosTheme.errorRed),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _load,
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            )
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final s = _data?.summary;
    final cur = watchCurrency(ref);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        children: [
          if (s != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                side: BorderSide(color: PosTheme.borderColorOf(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(PosTheme.spacingLg),
                child: Column(
                  children: [
                    Text(
                      _selectedDate,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: PosTheme.spacingLg),
                    _metricRow(
                      context,
                      l10n.reportsHubGrossSales,
                      s.grossSales,
                      currencyCode: cur,
                    ),
                    _metricRow(
                      context,
                      l10n.reportsHubNetSales,
                      s.netSales,
                      currencyCode: cur,
                      color: PosTheme.primaryGreen,
                      bold: true,
                    ),
                    _metricRow(
                      context,
                      l10n.reportsHubTransactions,
                      s.salesCount.toDouble(),
                      isInt: true,
                    ),
                    if (s.salesCount > 0)
                      _metricRow(
                        context,
                        l10n.reportsHubAvgPerSale,
                        s.netSales / s.salesCount,
                        currencyCode: cur,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: PosTheme.spacingLg),
          if (_data?.payments.isNotEmpty ?? false) ...[
            _sectionTitle(context, l10n.reportsHubPaymentBreakdown),
            const SizedBox(height: PosTheme.spacingSm),
            for (final p in _data!.payments)
              _listRow(
                context,
                p.method,
                formatAmount(p.total, cur),
                l10n.reportsTxCount('${p.count}'),
              ),
            const SizedBox(height: PosTheme.spacingLg),
          ],
          if (_data?.topProducts.isNotEmpty ?? false) ...[
            _sectionTitle(context, l10n.reportsHubTopProductsTitle),
            const SizedBox(height: PosTheme.spacingSm),
            for (final p in _data!.topProducts.take(5))
              _listRow(
                context,
                resolveBilingual(en: p.nameEn, km: p.nameKm, language: language),
                formatAmount(p.total, cur),
                l10n.reportsHubQuantitySold(p.quantity.toStringAsFixed(2)),
              ),
            const SizedBox(height: PosTheme.spacingLg),
          ],
          if (_data?.cashiers.isNotEmpty ?? false) ...[
            _sectionTitle(context, l10n.reportsHubCashierPerformanceSection),
            const SizedBox(height: PosTheme.spacingSm),
            for (final c in _data!.cashiers)
              _listRow(
                context,
                c.cashierName,
                formatAmount(c.salesTotal, cur),
                l10n.reportsTxCount('${c.salesCount}'),
              ),
            const SizedBox(height: PosTheme.spacingLg),
          ],
          if (_data?.shifts.isNotEmpty ?? false) ...[
            _sectionTitle(context, l10n.navShifts),
            const SizedBox(height: PosTheme.spacingSm),
            for (final shift in _data!.shifts)
              _listRow(
                context,
                shift.openedBy ?? l10n.reportsHubNotAvailable,
                formatAmount(shift.salesTotal, cur),
                shift.status ?? '',
              ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 4),
    child: Text(
      t,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: PosTheme.textHintOf(context),
        fontSize: 13,
      ),
    ),
  );

  Widget _metricRow(
    BuildContext context,
    String label,
    double value, {
    bool bold = false,
    bool isInt = false,
    String? currencyCode,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: bold ? null : PosTheme.textSecondaryOf(context),
            ),
          ),
          Text(
            isInt ? value.toInt().toString() : formatAmount(value, currencyCode),
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listRow(
    BuildContext context,
    String title,
    String value,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              subtitle,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: PosTheme.textHintOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
