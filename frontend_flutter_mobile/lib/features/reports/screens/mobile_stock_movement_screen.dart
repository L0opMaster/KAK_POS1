import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// stock_movement_screen.dart` — COPY/ADAPT NEARLY EXACTLY: a bare
/// date-range picker, no hour/cashier filter (matching source), and print/
/// PDF built directly from the single loaded page — `stockMovements`
/// returns a flat (unpaginated) list, so there's no `fetchAllPages` call
/// here either, matching source. Doesn't use `MobileReportListScreen` —
/// the filter shape (no hour filter) and unpaginated fetch don't fit that
/// config.
class MobileStockMovementScreen extends ConsumerStatefulWidget {
  const MobileStockMovementScreen({super.key});

  @override
  ConsumerState<MobileStockMovementScreen> createState() =>
      _MobileStockMovementScreenState();
}

class _MobileStockMovementScreenState
    extends ConsumerState<MobileStockMovementScreen> {
  late DateTime _from;
  late DateTime _to;
  List<StockMovementRow> _data = const [];
  bool _loading = false;
  bool _exporting = false;
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
          .stockMovements(from: _iso(_from), to: _iso(_to));
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

  Future<void> _exportPdf() async {
    final l10n = context.l10n;
    setState(() => _exporting = true);
    try {
      final company = ref.read(companyProfileProvider).valueOrNull;
      final pdfBytes = await A4ReportPdf.build(
        title: l10n.reportsStockMovements,
        subtitle: '${_iso(_from)} — ${_iso(_to)}',
        businessName: company?['businessName'] as String?,
        businessAddress: company?['address'] as String?,
        businessPhone: company?['phone'] as String?,
        columns: [
          l10n.inventoryValuationColProduct,
          l10n.stockMovementPdfColType,
          l10n.receiptQty,
          l10n.receiptDate,
        ],
        rows: [
          for (final m in _data)
            [
              m.productNameEn ?? l10n.reportsProductFallback('${m.productId}'),
              m.movementType ?? '',
              m.quantity.toStringAsFixed(0),
              m.createdAt ?? '',
            ],
        ],
        summary: [MapEntry(l10n.stockMovementPdfMovementsLabel, '${_data.length}')],
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'stock_movements.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.printerPrintFailed}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsStockMovements),
        actions: [
          IconButton(
            tooltip: l10n.reportsDateRange,
            icon: const Icon(Icons.date_range_outlined),
            onPressed: _pickRange,
          ),
          IconButton(
            tooltip: l10n.commonPrint,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting || _data.isEmpty ? null : _exportPdf,
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
          ? Center(child: Text(l10n.reportsNoMovementsForPeriod))
          : ListView.builder(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: _data.length,
              itemBuilder: (context, i) {
                final m = _data[i];
                final isIn = (m.movementType ?? '').toLowerCase().contains(
                  'in',
                );
                final isOut = (m.movementType ?? '').toLowerCase().contains(
                  'out',
                );
                final color = isIn
                    ? PosTheme.successGreen
                    : isOut
                    ? PosTheme.errorRed
                    : PosTheme.textSecondaryOf(context);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      PosTheme.radiusMedium,
                    ),
                    side: BorderSide(color: PosTheme.borderColorOf(context)),
                  ),
                  child: ListTile(
                    title: Text(
                      m.productNameEn ??
                          l10n.reportsProductFallback('${m.productId}'),
                    ),
                    subtitle: Text(
                      '${m.movementType ?? ''} • ${m.createdAt ?? ''}',
                      style: TextStyle(
                        fontSize: PosTheme.fontSizeXs,
                        color: PosTheme.textSecondaryOf(context),
                      ),
                    ),
                    trailing: Text(
                      '${m.quantity >= 0 ? '+' : ''}${m.quantity.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
