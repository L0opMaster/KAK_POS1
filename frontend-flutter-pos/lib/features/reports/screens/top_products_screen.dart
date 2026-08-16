import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../services/report_service.dart';
import '../models/report_models.dart';

/// Top Products — best-selling items by quantity & revenue.
class TopProductsScreen extends ConsumerStatefulWidget {
  const TopProductsScreen({super.key});

  @override
  ConsumerState<TopProductsScreen> createState() => _TopProductsScreenState();
}

class _TopProductsScreenState extends ConsumerState<TopProductsScreen> {
  String _from = _fmt(DateTime.now().subtract(const Duration(days: 30)));
  String _to = _fmt(DateTime.now());
  List<TopProduct> _data = [];
  bool _loading = false;
  String? _error;

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      final data = await svc.topProducts(from: _from, to: _to);
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

  Future<void> _pickRange() async {
    final from = DateTime.tryParse(_from) ?? DateTime.now();
    final to = DateTime.tryParse(_to) ?? DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (range != null) {
      setState(() {
        _from = _fmt(range.start);
        _to = _fmt(range.end);
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reportsTopProducts),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: _pickRange,
              tooltip: context.l10n.reportsDateRange),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: context.l10n.commonRefresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _data.isEmpty
                  ? Center(
                      child: Text(context.l10n.reportsNoDataForPeriod,
                          style: const TextStyle(color: PosTheme.textHint)))
                  : _buildContent(),
    );
  }

  Widget _errorView() => Center(
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
                  onPressed: _load, child: Text(context.l10n.commonRetry)),
            ],
          ),
        ),
      );

  Widget _buildContent() {
    final lang = ref.watch(appLanguageProvider);
    final cur = watchCurrency(ref);
    final maxQty =
        _data.fold<double>(0, (m, p) => m > p.quantity ? m : p.quantity);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Text('$_from — $_to',
                style: const TextStyle(
                    fontSize: 13,
                    color: PosTheme.textHint,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          ..._data.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final barWidth = maxQty > 0 ? p.quantity / maxQty : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: PosTheme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: PosTheme.primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: PosTheme.primaryGreen)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              resolveBilingual(
                                  en: p.nameEn, km: p.nameKm, language: lang),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: PosTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(formatAmount(p.total, cur),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: PosTheme.primaryGreen)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: barWidth,
                        backgroundColor: PosTheme.dividerColor,
                        color: PosTheme.primaryGreen,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        context.l10n
                            .reportsQuantitySold(_fmtNum(p.quantity)),
                        style: const TextStyle(
                            fontSize: 12, color: PosTheme.textHint)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _fmtNum(double v) => v.toStringAsFixed(2);
}
