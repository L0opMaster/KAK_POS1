import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/widgets/
/// report_charts.dart` — `ReportBarChart`/`ReportLineChart` are
/// COPY/ADAPT NEARLY EXACTLY (fl_chart API is the same on mobile).
/// `ReportPieChart` reflows for a narrow phone: source lays the pie and
/// its legend side-by-side in a 3:2 `Row` on a wide desktop panel; below
/// ~360px that split cramps both the pie and the legend text, so here the
/// legend stacks BELOW the pie instead, each given its own natural height
/// rather than sharing one fixed-height row.
///
/// A single labeled data point consumed by the report chart wrappers.
typedef ChartRow = ({String label, double value});

/// Fixed-order categorical palette per the `dataviz` skill's validated
/// default (`references/palette.md`): blue, orange, aqua, yellow, magenta,
/// green, violet, red. Assigned in this fixed order — never cycled/re-sorted
/// by rank.
const List<Color> kReportChartColors = [
  Color(0xFF2A78D6), // 1 blue
  Color(0xFFEB6834), // 2 orange
  Color(0xFF1BAF7A), // 3 aqua
  Color(0xFFEDA100), // 4 yellow
  Color(0xFFE87BA4), // 5 magenta
  Color(0xFF008300), // 6 green
  Color(0xFF4A3AA7), // 7 violet
  Color(0xFFE34948), // 8 red
];

/// Single-series emphasis color (categorical slot 1 / sequential default hue).
const Color kReportChartPrimary = Color(0xFF2A78D6);

Widget _emptyState(BuildContext context, double height) => SizedBox(
  height: height,
  child: Center(
    child: Text(
      context.l10n.reportsNoDataForPeriod,
      style: const TextStyle(color: PosTheme.textHint, fontSize: 13),
    ),
  ),
);

String _shortLabel(String label, int maxLen) =>
    label.length > maxLen ? '${label.substring(0, maxLen)}…' : label;

/// Thin wrapper around fl_chart's [BarChart] for a single categorical
/// series (e.g. top categories/items/cashiers by revenue).
class ReportBarChart extends StatelessWidget {
  const ReportBarChart({
    super.key,
    required this.data,
    this.height = 220,
    this.valueFormatter,
  });

  final List<ChartRow> data;
  final double height;
  final String Function(double)? valueFormatter;

  String _fmt(double v) => valueFormatter?.call(v) ?? v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _emptyState(context, height);

    final double maxY = data
        .map((d) => d.value)
        .fold<double>(0, (m, v) => v > m ? v : m);
    final double axisMax = maxY <= 0 ? 1 : maxY * 1.2;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) => BarChart(
          BarChartData(
            maxY: axisMax,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      '${data[group.x.toInt()].label}\n'
                      '${_fmt(rod.toY)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: axisMax / 4,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: PosTheme.dividerColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _shortLabel(data[i].label, 8),
                        style: const TextStyle(
                          fontSize: 10,
                          color: PosTheme.textHint,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (int i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].value,
                      color: kReportChartPrimary,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin wrapper around fl_chart's [LineChart] for a single series over
/// time (e.g. net sales per day, tax collected per day).
class ReportLineChart extends StatelessWidget {
  const ReportLineChart({
    super.key,
    required this.data,
    this.height = 220,
    this.valueFormatter,
  });

  final List<ChartRow> data;
  final double height;
  final String Function(double)? valueFormatter;

  String _fmt(double v) => valueFormatter?.call(v) ?? v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _emptyState(context, height);

    final double maxY = data
        .map((d) => d.value)
        .fold<double>(0, (m, v) => v > m ? v : m);
    final double axisMax = maxY <= 0 ? 1 : maxY * 1.2;
    final double labelInterval = (data.length / 5)
        .ceil()
        .clamp(1, data.length)
        .toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: axisMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: axisMax / 4,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: PosTheme.dividerColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: labelInterval,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox();
                  final label = data[i].label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label.length > 5
                          ? label.substring(label.length - 5)
                          : label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: PosTheme.textHint,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final i = s.x.toInt();
                final label = (i >= 0 && i < data.length) ? data[i].label : '';
                return LineTooltipItem(
                  '$label\n${_fmt(s.y)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i].value),
              ],
              isCurved: false,
              color: kReportChartPrimary,
              barWidth: 2,
              dotData: FlDotData(show: data.length <= 20),
              belowBarData: BarAreaData(
                show: true,
                color: kReportChartPrimary.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin wrapper around fl_chart's [PieChart] with a legend (identity is
/// never color-alone) for a multi-series share breakdown (e.g. payment
/// mix). On mobile the legend is stacked BELOW the pie — a side-by-side
/// split (as on desktop's wider panel) would cramp either the pie or the
/// label text on a narrow phone screen.
class ReportPieChart extends StatelessWidget {
  const ReportPieChart({super.key, required this.data, this.height = 220});

  final List<ChartRow> data;

  /// Height of the pie itself; the legend below adds its own height on
  /// top of this, so the overall widget is taller than [height].
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _emptyState(context, height);

    final double total = data.fold<double>(0, (s, d) => s + d.value);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (int i = 0; i < data.length; i++)
                  PieChartSectionData(
                    value: data[i].value,
                    color: kReportChartColors[i % kReportChartColors.length],
                    title: total > 0
                        ? '${(data[i].value / total * 100).toStringAsFixed(0)}%'
                        : '',
                    radius: 64,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            for (int i = 0; i < data.length; i++)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color:
                            kReportChartColors[i % kReportChartColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        data[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PosTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
