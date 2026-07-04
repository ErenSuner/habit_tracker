import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Yeniden kullanilabilir cizgi grafik (verim ve sayisal metrikler icin).
// Tarihe gore noktalar cizer; istege bagli hedef ve ortalama cizgileri ekler.
class SimpleLineChart extends StatelessWidget {
  final Map<DateTime, double> data; // gun -> deger
  final DateTime from;
  final int days;
  final double maxY;
  final Color color;
  final bool percent; // y ekseni % mi?
  final String? unit;
  final double? targetLine;
  final double? targetLine2; // aralik hedefinde ikinci (alt) sinir cizgisi
  final double? avgLine;

  const SimpleLineChart({
    super.key,
    required this.data,
    required this.from,
    required this.days,
    required this.maxY,
    required this.color,
    this.percent = false,
    this.unit,
    this.targetLine,
    this.targetLine2,
    this.avgLine,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    final sorted = data.keys.toList()..sort();
    for (final d in sorted) {
      final offset = d.difference(from).inDays.toDouble();
      if (offset < 0) continue;
      spots.add(FlSpot(offset, data[d]!));
    }

    final yInterval = maxY / 4;
    final extraLines = <HorizontalLine>[];
    if (targetLine != null) {
      extraLines.add(HorizontalLine(
        y: targetLine!,
        color: color.withValues(alpha: 0.5),
        strokeWidth: 1,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          style: TextStyle(fontSize: 10, color: color),
          // Iki cizgili aralikta ust/alt olarak adlandir.
          labelResolver: (_) => targetLine2 != null ? 'üst' : 'hedef',
        ),
      ));
    }
    if (targetLine2 != null) {
      extraLines.add(HorizontalLine(
        y: targetLine2!,
        color: color.withValues(alpha: 0.5),
        strokeWidth: 1,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.bottomRight,
          style: TextStyle(fontSize: 10, color: color),
          labelResolver: (_) => 'alt',
        ),
      ));
    }
    if (avgLine != null) {
      extraLines.add(HorizontalLine(
        y: avgLine!,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        strokeWidth: 1,
        dashArray: [3, 3],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.bottomRight,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          labelResolver: (_) => 'ort',
        ),
      ));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: 0,
        maxX: (days - 1).toDouble(),
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((s) {
              final date = from.add(Duration(days: s.x.toInt()));
              final valStr = percent
                  ? '%${_fmt1(s.y)}'
                  : '${_fmt1(s.y)}${unit != null && unit!.isNotEmpty ? ' $unit' : ''}';
              return LineTooltipItem(
                '${DateFormat('d MMM', 'tr_TR').format(date)}\n$valStr',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: yInterval,
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                percent ? '${v.toInt()}' : _shortNum(v),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (days / 4).ceilToDouble(),
              reservedSize: 26,
              getTitlesWidget: (v, _) {
                final date = from.add(Duration(days: v.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('d/M').format(date),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(show: spots.length <= 31),
            belowBarData:
                BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }

  static String _fmt1(double v) {
    final r = (v * 10).round() / 10;
    if (r == r.roundToDouble()) return r.toInt().toString();
    return r.toStringAsFixed(1);
  }

  static String _shortNum(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }
}
