import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';

/// Immutable filter state driven by [ReportFilterBar]. Screens hold one of
/// these in their local state and pass it down, receiving updates via
/// [ReportFilterBar.onChanged] every time the user picks a date preset,
/// custom range, hour range, or cashier. (`employeeId` is a legacy field
/// name — it actually filters by the User account that processed the sale,
/// not an Employee HR record; the visible label is "Cashier".)
class ReportFilterState {
  const ReportFilterState({
    required this.period,
    required this.from,
    required this.to,
    this.employeeId,
    this.fromHour = 0,
    this.toHour = 23,
    this.customHours = false,
  });

  final ReportPeriod period;
  final DateTime from;
  final DateTime to;
  final int? employeeId;
  final int fromHour;
  final int toHour;

  /// Whether [fromHour]/[toHour] should be applied. When false the filter
  /// covers the full day (00:00–23:00), matching the "All day" option.
  final bool customHours;

  static String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get fromStr => fmt(from);
  String get toStr => fmt(to);

  /// Default state: today's date, full-day hours, no cashier filter.
  factory ReportFilterState.initial() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return ReportFilterState(period: ReportPeriod.today, from: today, to: today);
  }

  ReportFilterState copyWith({
    ReportPeriod? period,
    DateTime? from,
    DateTime? to,
    int? employeeId,
    bool clearEmployee = false,
    int? fromHour,
    int? toHour,
    bool? customHours,
  }) {
    return ReportFilterState(
      period: period ?? this.period,
      from: from ?? this.from,
      to: to ?? this.to,
      employeeId: clearEmployee ? null : (employeeId ?? this.employeeId),
      fromHour: fromHour ?? this.fromHour,
      toHour: toHour ?? this.toHour,
      customHours: customHours ?? this.customHours,
    );
  }

  /// Resolves [period] to concrete [from]/[to] dates, keeping other fields.
  static ReportFilterState resolvePeriod(
    ReportFilterState state,
    ReportPeriod period, {
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime from;
    DateTime to;
    switch (period) {
      case ReportPeriod.all:
        from = DateTime(2000, 1, 1);
        to = today;
        break;
      case ReportPeriod.today:
        from = today;
        to = from;
        break;
      case ReportPeriod.yesterday:
        final y = today.subtract(const Duration(days: 1));
        from = y;
        to = y;
        break;
      case ReportPeriod.thisWeek:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        from = monday;
        to = monday.add(const Duration(days: 6));
        break;
      case ReportPeriod.lastWeek:
        final thisMonday = today.subtract(Duration(days: today.weekday - 1));
        final lastMonday = thisMonday.subtract(const Duration(days: 7));
        from = lastMonday;
        to = lastMonday.add(const Duration(days: 6));
        break;
      case ReportPeriod.thisMonth:
        from = DateTime(today.year, today.month, 1);
        to = DateTime(today.year, today.month + 1, 0);
        break;
      case ReportPeriod.lastMonth:
        from = DateTime(today.year, today.month - 1, 1);
        to = DateTime(today.year, today.month, 0);
        break;
      case ReportPeriod.last7Days:
        to = today;
        from = today.subtract(const Duration(days: 6));
        break;
      case ReportPeriod.last30Days:
        to = today;
        from = today.subtract(const Duration(days: 29));
        break;
      case ReportPeriod.thisYear:
        from = DateTime(today.year, 1, 1);
        to = DateTime(today.year, 12, 31);
        break;
      case ReportPeriod.custom:
        from = customFrom ?? state.from;
        to = customTo ?? state.to;
        break;
    }
    return state.copyWith(period: period, from: from, to: to);
  }
}

/// Reusable filter bar for the Reports screens: a compact row of pill
/// controls — date range (with prev/next paging and a preset/calendar
/// popover), an hour-of-day popover, and a cashier popover. Every
/// selection calls [onChanged] immediately (no separate Apply step).
/// Designed to sit at the top of a report screen's body (below the
/// AppBar).
class ReportFilterBar extends StatefulWidget {
  const ReportFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.employees = const [],
    this.showEmployeeFilter = true,
    this.showHourFilter = true,
  });

  /// Current filter state (owned by the parent screen).
  final ReportFilterState value;

  /// Called with the new filter state whenever the user changes a filter.
  final ValueChanged<ReportFilterState> onChanged;

  /// Cashier options, typically from the report response's `cashiers`
  /// `FilterOption` list.
  final List<FilterOption> employees;

  final bool showEmployeeFilter;
  final bool showHourFilter;

  @override
  State<ReportFilterBar> createState() => _ReportFilterBarState();
}

class _ReportFilterBarState extends State<ReportFilterBar> {
  final _dateAnchorKey = GlobalKey();
  final _timeAnchorKey = GlobalKey();
  final _employeeAnchorKey = GlobalKey();

  OverlayEntry? _openEntry;

  static final _dateFmt = DateFormat('d MMM yyyy');

  static const _datePresets = [
    ReportPeriod.today,
    ReportPeriod.yesterday,
    ReportPeriod.thisWeek,
    ReportPeriod.lastWeek,
    ReportPeriod.thisMonth,
    ReportPeriod.lastMonth,
    ReportPeriod.last7Days,
    ReportPeriod.last30Days,
  ];

  @override
  void dispose() {
    _closePopover();
    super.dispose();
  }

  void _closePopover() {
    _openEntry?.remove();
    _openEntry = null;
  }

  void _apply(ReportFilterState next) {
    widget.onChanged(next);
  }

  void _shiftRange(int direction) {
    final rangeLength = widget.value.to.difference(widget.value.from).inDays + 1;
    final shift = Duration(days: rangeLength * direction);
    _apply(widget.value.copyWith(
      period: ReportPeriod.custom,
      from: widget.value.from.add(shift),
      to: widget.value.to.add(shift),
    ));
  }

  Future<void> _openCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: widget.value.from, end: widget.value.to),
    );
    if (range == null) return;
    _apply(widget.value.copyWith(
      period: ReportPeriod.custom,
      from: range.start,
      to: range.end,
    ));
  }

  void _showPopover(GlobalKey anchorKey, double width, WidgetBuilder builder) {
    _closePopover();
    const margin = 8.0;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final anchorBox = anchorKey.currentContext!.findRenderObject() as RenderBox;
    final anchorOffset = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final anchorSize = anchorBox.size;
    final screenSize = overlayBox.size;

    double left = anchorOffset.dx;
    if (left + width + margin > screenSize.width) {
      left = screenSize.width - width - margin;
    }
    if (left < margin) left = margin;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closePopover,
            ),
          ),
          Positioned(
            left: left,
            top: anchorOffset.dy + anchorSize.height + 6,
            child: builder(ctx),
          ),
        ],
      ),
    );
    _openEntry = entry;
    overlay.insert(entry);
  }

  Widget _popoverCard({required Widget child, double width = 220}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: PosTheme.backgroundCard,
          borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
          border: Border.all(color: PosTheme.dividerColor),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _menuItem(String label, {required VoidCallback onTap, bool selected = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? PosTheme.primaryGreenDark : PosTheme.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 16, color: PosTheme.primaryGreenDark),
          ],
        ),
      ),
    );
  }

  String _periodLabel(BuildContext context, ReportPeriod period) {
    switch (period) {
      case ReportPeriod.today:
        return context.l10n.reportFilterToday;
      case ReportPeriod.yesterday:
        return context.l10n.reportFilterYesterday;
      case ReportPeriod.thisWeek:
        return context.l10n.reportFilterThisWeek;
      case ReportPeriod.lastWeek:
        return context.l10n.reportFilterLastWeek;
      case ReportPeriod.thisMonth:
        return context.l10n.reportFilterThisMonth;
      case ReportPeriod.lastMonth:
        return context.l10n.reportFilterLastMonth;
      case ReportPeriod.last7Days:
        return context.l10n.reportFilterLast7Days;
      case ReportPeriod.last30Days:
        return context.l10n.reportFilterLast30Days;
      case ReportPeriod.thisYear:
        return context.l10n.reportFilterThisYear;
      case ReportPeriod.all:
        return context.l10n.commonAll;
      case ReportPeriod.custom:
        return context.l10n.reportFilterCustomRange;
    }
  }

  void _openDateMenu() {
    _showPopover(_dateAnchorKey, 200, (ctx) {
      return _popoverCard(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            ..._datePresets.map((p) => _menuItem(
                  _periodLabel(context, p),
                  selected: widget.value.period == p,
                  onTap: () {
                    _closePopover();
                    _apply(ReportFilterState.resolvePeriod(widget.value, p));
                  },
                )),
            const Divider(height: 1),
            _menuItem(
              context.l10n.reportFilterCustomRange,
              selected: widget.value.period == ReportPeriod.custom,
              onTap: () {
                _closePopover();
                _openCustomRange();
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
    });
  }

  void _openTimeMenu() {
    bool customHours = widget.value.customHours;
    int fromHour = widget.value.fromHour;
    int toHour = widget.value.toHour;
    final fromController =
        TextEditingController(text: fromHour.toString().padLeft(2, '0'));
    final toController = TextEditingController(text: toHour.toString().padLeft(2, '0'));

    _showPopover(_timeAnchorKey, 230, (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          void applyNow() {
            _apply(widget.value.copyWith(
              customHours: customHours,
              fromHour: customHours ? fromHour : 0,
              toHour: customHours ? toHour : 23,
            ));
          }

          void submitHour(
            TextEditingController controller,
            int current,
            ValueChanged<int> onValid,
          ) {
            final parsed = int.tryParse(controller.text);
            final clamped = (parsed ?? current).clamp(0, 23);
            controller.text = clamped.toString().padLeft(2, '0');
            if (clamped != current) {
              onValid(clamped);
            }
          }

          Widget hourField(
            TextEditingController controller,
            int current,
            ValueChanged<int> onValid,
          ) {
            return SizedBox(
              width: 90,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  suffixText: ':00',
                  suffixStyle: TextStyle(fontSize: 13, color: PosTheme.textSecondary),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                ),
                onSubmitted: (_) => submitHour(controller, current, onValid),
                onTapOutside: (_) => submitHour(controller, current, onValid),
              ),
            );
          }

          return _popoverCard(
            width: 230,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<bool>(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    activeColor: PosTheme.primaryGreen,
                    title: Text(context.l10n.reportFilterAllDay,
                        style: const TextStyle(fontSize: 13)),
                    value: false,
                    groupValue: customHours,
                    onChanged: (_) {
                      setLocal(() => customHours = false);
                      applyNow();
                    },
                  ),
                  RadioListTile<bool>(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    activeColor: PosTheme.primaryGreen,
                    title: Text(context.l10n.reportFilterCustomPeriod,
                        style: const TextStyle(fontSize: 13)),
                    value: true,
                    groupValue: customHours,
                    onChanged: (_) {
                      setLocal(() => customHours = true);
                      applyNow();
                    },
                  ),
                  if (customHours)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.reportFilterStart,
                                    style: const TextStyle(
                                        fontSize: 11, color: PosTheme.textHint)),
                                hourField(fromController, fromHour, (v) {
                                  setLocal(() => fromHour = v);
                                  applyNow();
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.reportFilterEnd,
                                    style: const TextStyle(
                                        fontSize: 11, color: PosTheme.textHint)),
                                hourField(toController, toHour, (v) {
                                  setLocal(() => toHour = v);
                                  applyNow();
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _openEmployeeMenu() {
    _showPopover(_employeeAnchorKey, 220, (ctx) {
      return _popoverCard(
        width: 220,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            _menuItem(
              context.l10n.reportFilterAllCashiers,
              selected: widget.value.employeeId == null,
              onTap: () {
                _closePopover();
                _apply(widget.value.copyWith(clearEmployee: true));
              },
            ),
            ...widget.employees.map((e) => _menuItem(
                  e.label,
                  selected: widget.value.employeeId == int.tryParse(e.value),
                  onTap: () {
                    _closePopover();
                    _apply(widget.value.copyWith(employeeId: int.tryParse(e.value)));
                  },
                )),
            const SizedBox(height: 4),
          ],
        ),
      );
    });
  }

  Widget _controlContainer(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: PosTheme.backgroundCard,
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(color: PosTheme.dividerColor),
      ),
      child: child,
    );
  }

  Widget _verticalDivider() => Container(width: 1, height: 20, color: PosTheme.dividerColor);

  Widget _buildDateRangeControl() {
    return _controlContainer(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(PosTheme.radiusMedium)),
            onTap: () => _shiftRange(-1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Icon(Icons.chevron_left, size: 18, color: PosTheme.textSecondary),
            ),
          ),
          _verticalDivider(),
          InkWell(
            key: _dateAnchorKey,
            onTap: _openDateMenu,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 15, color: PosTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${_dateFmt.format(widget.value.from)} - ${_dateFmt.format(widget.value.to)}',
                    style: const TextStyle(fontSize: 13, color: PosTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          _verticalDivider(),
          InkWell(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(PosTheme.radiusMedium)),
            onTap: () => _shiftRange(1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Icon(Icons.chevron_right, size: 18, color: PosTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeControl() {
    final label = widget.value.customHours
        ? '${widget.value.fromHour.toString().padLeft(2, '0')}:00 - '
            '${widget.value.toHour.toString().padLeft(2, '0')}:00'
        : context.l10n.reportFilterAllDay;
    return _controlContainer(
      InkWell(
        key: _timeAnchorKey,
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        onTap: _openTimeMenu,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 15, color: PosTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, color: PosTheme.textPrimary)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 18, color: PosTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeControl() {
    final selectedId = widget.value.employeeId;
    String label = context.l10n.reportFilterAllCashiers;
    if (selectedId != null) {
      for (final e in widget.employees) {
        if (int.tryParse(e.value) == selectedId) {
          label = e.label;
          break;
        }
      }
    }
    return _controlContainer(
      InkWell(
        key: _employeeAnchorKey,
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        onTap: _openEmployeeMenu,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 15, color: PosTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, color: PosTheme.textPrimary)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 18, color: PosTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildDateRangeControl(),
            if (widget.showHourFilter) ...[
              const SizedBox(width: 8),
              _buildTimeControl(),
            ],
            if (widget.showEmployeeFilter) ...[
              const SizedBox(width: 8),
              _buildEmployeeControl(),
            ],
          ],
        ),
      ),
    );
  }
}
