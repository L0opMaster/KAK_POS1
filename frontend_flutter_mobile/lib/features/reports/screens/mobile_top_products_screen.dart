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
/// top_products_screen.dart` — COPY/ADAPT NEARLY EXACTLY: a bare date-
/// range picker (single `IconButton`), no hour/cashier filter, no
/// print/PDF action — matching source exactly (one of the 3 report
/// screens that never had one). Doesn't use `MobileReportListScreen` —
/// `topProducts` isn't paginated and the filter shape is simpler than
/// the shared config assumes.
class MobileTopProductsScreen extends ConsumerStatefulWidget {
  const MobileTopProductsScreen({super.key});

  @override
  ConsumerState<MobileTopProductsScreen> createState() =>
      _MobileTopProductsScreenState();
}

class _MobileTopProductsScreenState
    extends ConsumerState<MobileTopProductsScreen> {
  late DateTime _from;
  late DateTime _to;
  List<TopProduct> _data = const [];
  bool _loading = false;
  Object? _error;

  static String _iso(DateTime d) => d.toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _to = DateTime(today.year, today.month, today.day);
    _from = _to.subtract(const Duration(days: 6));
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
          .topProducts(from: _iso(_from), to: _iso(_to));
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final cur = watchCurrency(ref);
    final maxTotal = _data.isEmpty
        ? 0.0
        : _data.map((p) => p.total).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTopProducts),
        actions: [
          IconButton(
            tooltip: l10n.reportsDateRange,
            icon: const Icon(Icons.date_range_outlined),
            onPressed: _pickRange,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_error'),
                  const SizedBox(height: PosTheme.spacingSm),
                  OutlinedButton(
                    onPressed: _load,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            )
          : _data.isEmpty
          ? Center(child: Text(l10n.reportsNoDataForPeriod))
          : ListView.builder(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: _data.length,
              itemBuilder: (context, i) {
                final p = _data[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '#${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resolveBilingual(
                                en: p.nameEn,
                                km: p.nameKm,
                                language: language,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maxTotal == 0 ? 0 : p.total / maxTotal,
                                minHeight: 6,
                                backgroundColor: PosTheme.dividerColorOf(
                                  context,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PosTheme.spacingSm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatAmount(p.total, cur)),
                          Text(
                            p.quantity.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: PosTheme.fontSizeXs,
                              color: PosTheme.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
