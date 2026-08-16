import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// monthly_sales_screen.dart` — COPY/ADAPT NEARLY EXACTLY: a bare year
/// picker (prev/next chevrons in the AppBar), no date range, no hour or
/// cashier filter, no print/PDF action — matching source exactly (one of
/// the 3 report screens that never had one). Doesn't use
/// `MobileReportListScreen` since `monthlySales(year)` takes only a year,
/// not a from/to range — a genuinely different shape, not just a smaller
/// config.
class MobileMonthlySalesScreen extends ConsumerStatefulWidget {
  const MobileMonthlySalesScreen({super.key});

  @override
  ConsumerState<MobileMonthlySalesScreen> createState() =>
      _MobileMonthlySalesScreenState();
}

class _MobileMonthlySalesScreenState
    extends ConsumerState<MobileMonthlySalesScreen> {
  int _year = DateTime.now().year;
  List<MonthlySales> _data = const [];
  bool _loading = false;
  Object? _error;

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
      final data = await ref.read(reportServiceProvider).monthlySales(_year);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cur = watchCurrency(ref);
    final maxTotal = _data.isEmpty
        ? 0.0
        : _data.map((m) => m.total).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monthlySalesTitle('$_year')),
        actions: [
          IconButton(
            tooltip: l10n.monthlySalesPreviousYear,
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _year--);
              _load();
            },
          ),
          IconButton(
            tooltip: l10n.monthlySalesNextYear,
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _year++);
              _load();
            },
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
          ? Center(child: Text('$_error'))
          : _data.every((m) => m.total == 0 && m.count == 0)
          ? Center(child: Text(l10n.monthlySalesNoData))
          : ListView(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: PosTheme.spacingMd),
                  child: Text(
                    '${l10n.monthlySalesTotalRevenue}: '
                    '${formatAmount(_data.fold<double>(0, (s, m) => s + m.total), cur)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                for (final m in _data)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: PosTheme.spacingSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(m.month),
                            Text(formatAmount(m.total, cur)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxTotal == 0 ? 0 : m.total / maxTotal,
                            minHeight: 8,
                            backgroundColor: PosTheme.dividerColorOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
