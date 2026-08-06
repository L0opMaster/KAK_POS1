import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../services/report_service.dart';
import '../models/report_models.dart';

/// Monthly Sales — revenue trend across months in a year.
class MonthlySalesScreen extends ConsumerStatefulWidget {
  const MonthlySalesScreen({super.key});

  @override
  ConsumerState<MonthlySalesScreen> createState() => _MonthlySalesScreenState();
}

class _MonthlySalesScreenState extends ConsumerState<MonthlySalesScreen> {
  int _year = DateTime.now().year;
  List<MonthlySales> _data = [];
  bool _loading = false;
  String? _error;

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
      final data = await svc.monthlySales(_year);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.monthlySalesTitle(_year.toString())),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() => _year--);
                _load();
              },
              tooltip: context.l10n.monthlySalesPreviousYear),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() => _year++);
                _load();
              },
              tooltip: context.l10n.monthlySalesNextYear),
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
                      child: Text(context.l10n.monthlySalesNoData,
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
    final maxTotal =
        _data.fold<double>(0, (m, m2) => m2.total > m ? m2.total : m);
    final grandTotal = _data.fold<double>(0, (s, m) => s + m.total);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Grand total ──
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
                  Text(context.l10n.monthlySalesTotalRevenue,
                      style: const TextStyle(
                          color: PosTheme.textHint,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('\$${_fmtNum(grandTotal)}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: PosTheme.primaryGreen)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Monthly bars ──
          ..._data.map((m) {
            final bar = maxTotal > 0 ? m.total / maxTotal : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: PosTheme.dividerColor),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(m.month,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: PosTheme.textPrimary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: bar,
                          backgroundColor: PosTheme.dividerColor,
                          color: PosTheme.primaryGreen,
                          minHeight: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '\$${_fmtNum(m.total)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: PosTheme.textPrimary),
                      ),
                    ),
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
