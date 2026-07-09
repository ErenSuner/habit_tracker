import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';

// Gunluk MIKTAR verileri icin bar (cubuk) grafik: ekran suresi, sayisal
// metrikler gibi "o gun ne kadar?" sorusuna cubuklar cizgiden daha net cevap
// verir. Istege bagli hedef/ortalama cizgisi ekler.
class SimpleBarChart extends StatelessWidget {
  final Map<DateTime, double> data; // gun -> deger
  final DateTime from;
  final int days;
  final double maxY;
  final Color color;
  final String? unit;
  final double? targetLine;
  final double? targetLine2; // aralik hedefinde alt sinir
  final double? avgLine;

  const SimpleBarChart({
    super.key,
    required this.data,
    required this.from,
    required this.days,
    required this.maxY,
    required this.color,
    this.unit,
    this.targetLine,
    this.targetLine2,
    this.avgLine,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <BarChartGroupData>[];
    data.forEach((d, v) {
      final x = d.difference(from).inDays;
      if (x < 0 || x >= days) return;
      groups.add(BarChartGroupData(x: x, barRods: [
        BarChartRodData(
          toY: v,
          color: color,
          width: days <= 14 ? 12 : (days <= 40 ? 6 : 3),
          borderRadius: BorderRadius.circular(3),
        ),
      ]));
    });

    final yInterval = maxY / 4;
    final extraLines = <HorizontalLine>[];
    void addLine(double y, String label, Alignment a) {
      extraLines.add(HorizontalLine(
        y: y,
        color: color.withValues(alpha: 0.55),
        strokeWidth: 1,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: a,
          style: TextStyle(fontSize: 10, color: color),
          labelResolver: (_) => label,
        ),
      ));
    }

    if (targetLine != null) {
      addLine(targetLine!, targetLine2 != null ? 'üst' : 'hedef',
          Alignment.topRight);
    }
    if (targetLine2 != null) addLine(targetLine2!, 'alt', Alignment.bottomRight);
    if (avgLine != null) {
      extraLines.add(HorizontalLine(
        y: avgLine!,
        color: AppColors.textSecondary.withValues(alpha: 0.7),
        strokeWidth: 1,
        dashArray: [3, 3],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.bottomRight,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          labelResolver: (_) => 'ort',
        ),
      ));
    }

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceBetween,
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) {
              final date = from.add(Duration(days: group.x));
              final v = _fmt1(rod.toY);
              final u = (unit != null && unit!.isNotEmpty) ? ' $unit' : '';
              return BarTooltipItem(
                '${DateFormat('d MMM', 'tr_TR').format(date)}\n$v$u',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: yInterval,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
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
              getTitlesWidget: (v, _) => Text(_shortNum(v),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
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
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
        ),
        barGroups: groups,
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
