import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';
import '../services/report_service.dart';
import '../models/report_models.dart';

/// Stock Movements — in/out movements within a date range.
class StockMovementScreen extends ConsumerStatefulWidget {
  const StockMovementScreen({super.key});

  @override
  ConsumerState<StockMovementScreen> createState() =>
      _StockMovementScreenState();
}

class _StockMovementScreenState extends ConsumerState<StockMovementScreen> {
  String _from = _fmt(DateTime.now().subtract(const Duration(days: 30)));
  String _to = _fmt(DateTime.now());
  List<StockMovementRow> _data = [];
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
      final data = await svc.stockMovements(from: _from, to: _to);
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

  Future<void> _printReport() async {
    if (_data.isEmpty) return;
    final l10n = context.l10n;
    try {
      final company =
          await ref.read(settingsServiceProvider).getCompanyProfile();

      final rows = _data
          .map((m) => [
                m.productNameEn ?? l10n.reportsProductFallback(m.productId),
                m.movementType ?? '',
                _fmtNum(m.quantity),
                m.createdAt ?? '',
              ])
          .toList();

      final pdfBytes = await A4ReportPdf.build(
        title: l10n.reportsStockMovements,
        subtitle: '$_from — $_to',
        businessName: '${company['businessName'] ?? ''}',
        businessAddress: '${company['address'] ?? ''}',
        businessPhone: '${company['phone'] ?? ''}',
        columns: const ['Product', 'Type', 'Qty', 'Date'],
        rows: rows,
        columnAlignments: const {2: pw.Alignment.centerRight},
        summary: [MapEntry('Movements', '${_data.length}')],
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'stock_movements',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${l10n.printerPrintFailed}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reportsStockMovements),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: _pickRange,
              tooltip: context.l10n.reportsDateRange),
          IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: _data.isEmpty ? null : _printReport,
              tooltip: context.l10n.commonPrint),
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
                      child: Text(context.l10n.reportsNoMovementsForPeriod,
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
          ..._data.map((m) {
            final isIn = m.movementType?.toLowerCase().contains('in') ?? false;
            final isOut =
                m.movementType?.toLowerCase().contains('out') ?? false;
            final color = isIn
                ? PosTheme.primaryGreen
                : isOut
                    ? PosTheme.errorRed
                    : PosTheme.warningAmber;
            final icon = isIn
                ? Icons.arrow_downward_rounded
                : isOut
                    ? Icons.arrow_upward_rounded
                    : Icons.swap_vert_rounded;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: PosTheme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              m.productNameEn ??
                                  context.l10n
                                      .reportsProductFallback(m.productId),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: PosTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            '${m.movementType ?? ''}  ·  ${m.createdAt ?? ''}',
                            style: const TextStyle(
                                fontSize: 12, color: PosTheme.textHint),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${m.quantity > 0 ? '+' : ''}${_fmtNum(m.quantity)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: color),
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
