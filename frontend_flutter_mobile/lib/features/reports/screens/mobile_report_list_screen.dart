import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';
import '../widgets/report_list_config.dart';

const _pageSize = 20;

/// See `report_list_config.dart`'s doc comment for why this one generic
/// screen stands in for 8 of source's 11 report screens. Filters: date
/// range (with the same preset menu source's `ReportFilterBar` offers —
/// Today/Yesterday/This Week/Last Week/This Month/Last Month/Last 7
/// Days/Last 30 Days/Custom Range) and an optional hour-of-day range
/// (config.showHourFilter). Pagination is Prev/Next (source's own
/// `report_pagination_bar.dart` is the same shape, just a page-number
/// strip rather than infinite scroll — matches the UI-shows-one-page,
/// export-walks-all-pages split `fetchAllPages` exists for).
class MobileReportListScreen<T> extends ConsumerStatefulWidget {
  const MobileReportListScreen({super.key, required this.config});

  final ReportListConfig<T> config;

  @override
  ConsumerState<MobileReportListScreen<T>> createState() =>
      _MobileReportListScreenState<T>();
}

class _MobileReportListScreenState<T>
    extends ConsumerState<MobileReportListScreen<T>> {
  late DateTime _from;
  late DateTime _to;
  bool _customHours = false;
  int _fromHour = 0;
  int _toHour = 23;
  int _page = 0;

  PagedResult<T>? _result;
  bool _loading = true;
  Object? _error;
  bool _exporting = false;

  static String _iso(DateTime d) => d.toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _to = DateTime(today.year, today.month, today.day);
    _from = _to.subtract(Duration(days: widget.config.initialFromDaysAgo));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.config.fetchPage(
        from: _iso(_from),
        to: _iso(_to),
        fromHour: _customHours ? _fromHour : null,
        toHour: _customHours ? _toHour : null,
        page: _page,
        size: _pageSize,
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyPreset(int fromDaysAgo, int toDaysAgo) {
    final today = DateTime.now();
    final to = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: toDaysAgo));
    setState(() {
      _to = to;
      _from = to.subtract(Duration(days: fromDaysAgo - toDaysAgo));
      _page = 0;
    });
    _load();
  }

  Future<void> _pickCustomRange() async {
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
      _page = 0;
    });
    _load();
  }

  Future<void> _pickHourRange() async {
    final l10n = context.l10n;
    bool custom = _customHours;
    int fromHour = _fromHour;
    int toHour = _toHour;
    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.reportFilterCustomPeriod),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<bool>(
                title: Text(l10n.reportFilterAllDay),
                value: false,
                groupValue: custom,
                onChanged: (v) => setState(() => custom = v!),
              ),
              RadioListTile<bool>(
                title: Text(l10n.reportFilterCustomPeriod),
                value: true,
                groupValue: custom,
                onChanged: (v) => setState(() => custom = v!),
              ),
              if (custom)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: fromHour,
                        decoration: InputDecoration(
                          labelText: l10n.reportFilterStart,
                        ),
                        items: [
                          for (var h = 0; h < 24; h++)
                            DropdownMenuItem(value: h, child: Text('$h:00')),
                        ],
                        onChanged: (v) => setState(() => fromHour = v!),
                      ),
                    ),
                    const SizedBox(width: PosTheme.spacingSm),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: toHour,
                        decoration: InputDecoration(
                          labelText: l10n.reportFilterEnd,
                        ),
                        items: [
                          for (var h = 0; h < 24; h++)
                            DropdownMenuItem(value: h, child: Text('$h:00')),
                        ],
                        onChanged: (v) => setState(() => toHour = v!),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (applied == true) {
      setState(() {
        _customHours = custom;
        _fromHour = fromHour;
        _toHour = toHour;
        _page = 0;
      });
      _load();
    }
  }

  Future<void> _exportPdf() async {
    final l10n = context.l10n;
    final pdfConfig = widget.config.pdfExport;
    if (pdfConfig == null) return;
    setState(() => _exporting = true);
    try {
      final allRows = await fetchAllPages<T>(
        fetchPage: (page) async {
          final result = await widget.config.fetchPage(
            from: _iso(_from),
            to: _iso(_to),
            fromHour: _customHours ? _fromHour : null,
            toHour: _customHours ? _toHour : null,
            page: page,
            size: reportPrintPageSize,
          );
          return (result.content, result.meta);
        },
      );
      final company = ref.read(companyProfileProvider).valueOrNull;
      final pdfBytes = await A4ReportPdf.build(
        title: pdfConfig.pdfTitle,
        subtitle: '${_iso(_from)} — ${_iso(_to)}',
        businessName: company?['businessName'] as String?,
        businessAddress: company?['address'] as String?,
        businessPhone: company?['phone'] as String?,
        columns: [for (final c in widget.config.columns) c.header],
        rows: [
          for (final row in allRows)
            [for (final c in widget.config.columns) c.cell(row)],
        ],
        summary: widget.config.summaryBuilder?.call(allRows) ?? const [],
        generatedAt: DateTime.now(),
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
        landscape: pdfConfig.landscape,
      );
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: '${widget.config.title}.pdf',
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
        title: Text(widget.config.title),
        actions: [
          if (widget.config.showHourFilter)
            IconButton(
              tooltip: l10n.reportFilterCustomPeriod,
              icon: const Icon(Icons.schedule_outlined),
              onPressed: _pickHourRange,
            ),
          IconButton(
            tooltip: l10n.reportFilterCustomRange,
            icon: const Icon(Icons.date_range_outlined),
            onPressed: _pickCustomRange,
          ),
          if (widget.config.pdfExport != null)
            IconButton(
              tooltip: l10n.commonPrint,
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _exporting ? null : _exportPdf,
            ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: PosTheme.spacingMd,
              vertical: PosTheme.spacingSm,
            ),
            child: Row(
              children: [
                ActionChip(
                  label: Text(l10n.reportFilterToday),
                  onPressed: () => _applyPreset(0, 0),
                ),
                const SizedBox(width: PosTheme.spacingXs),
                ActionChip(
                  label: Text(l10n.reportFilterThisWeek),
                  onPressed: () => _applyPreset(6, 0),
                ),
                const SizedBox(width: PosTheme.spacingXs),
                ActionChip(
                  label: Text(l10n.reportFilterThisMonth),
                  onPressed: () => _applyPreset(29, 0),
                ),
                const SizedBox(width: PosTheme.spacingXs),
                Chip(label: Text('${_iso(_from)} — ${_iso(_to)}')),
              ],
            ),
          ),
          Expanded(child: _buildBody(context)),
          if (_result != null && _result!.meta.totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(PosTheme.spacingSm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: l10n.reportPaginationPreviousPage,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _page > 0
                        ? () {
                            setState(() => _page--);
                            _load();
                          }
                        : null,
                  ),
                  Text(
                    l10n.reportPaginationPageInfo(
                      '${_page + 1}',
                      '${_result!.meta.totalPages}',
                      '${_result!.meta.totalElements}',
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.reportPaginationNextPage,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _page + 1 < _result!.meta.totalPages
                        ? () {
                            setState(() => _page++);
                            _load();
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_error'),
            const SizedBox(height: PosTheme.spacingSm),
            OutlinedButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    final rows = _result?.content ?? const [];
    if (rows.isEmpty) {
      return Center(child: Text(l10n.reportsNoDataForPeriod));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              for (final c in widget.config.columns)
                DataColumn(
                  label: Text(c.header),
                  numeric: c.numeric,
                ),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    for (final c in widget.config.columns)
                      DataCell(Text(c.cell(row))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
