import 'package:flutter/material.dart';

import '../models/metric.dart';
import '../services/stats_util.dart';
import 'mini_calendar.dart';
import 'simple_line_chart.dart';

// ---- ortak yardimcilar ----

String _fmt(double v) {
  final r = (v * 10).round() / 10;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return r.toStringAsFixed(1);
}

double _niceMax(Iterable<double> values, double? target) {
  double m = 0;
  for (final v in values) {
    if (v > m) m = v;
  }
  if (target != null && target > m) m = target;
  if (m <= 0) return 1;
  return m * 1.2;
}

// Bir haritayi son [days] gune gore suzer.
Map<DateTime, T> _window<T>(Map<DateTime, T> full, DateTime from) {
  return {
    for (final e in full.entries)
      if (!e.key.isBefore(from)) e.key: e.value,
  };
}

Widget _statBox(BuildContext c, String label, String value) {
  final cs = Theme.of(c).colorScheme;
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

Widget _statsRow(BuildContext c, List<(String, String)> stats) {
  final children = <Widget>[];
  for (var i = 0; i < stats.length; i++) {
    if (i > 0) children.add(const SizedBox(width: 12));
    children.add(Expanded(child: _statBox(c, stats[i].$1, stats[i].$2)));
  }
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

// Karta ozel "Son N gun" secici.
class _RangeSelector extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;
  const _RangeSelector({required this.days, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: days,
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 7, child: Text('Son 7 gün')),
        PopupMenuItem(value: 30, child: Text('Son 30 gün')),
        PopupMenuItem(value: 90, child: Text('Son 90 gün')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Son $days gün',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }
}

Widget _cardShell(
  BuildContext c,
  String title,
  List<Widget> children, {
  Widget? trailing,
}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(c).textTheme.titleMedium),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          ...children,
        ],
      ),
    ),
  );
}

// ============================================================
// Genel verim karti
// ============================================================
class VerimStatCard extends StatefulWidget {
  final Map<DateTime, double> scores; // TUM veri (90 gun)
  final DateTime today;
  const VerimStatCard({super.key, required this.scores, required this.today});

  @override
  State<VerimStatCard> createState() => _VerimStatCardState();
}

class _VerimStatCardState extends State<VerimStatCard> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final from = widget.today.subtract(Duration(days: _days - 1));
    final window = _window(widget.scores, from);
    final values = window.values.toList();
    final avg =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
    final best = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);

    return _cardShell(
      context,
      'Genel verim',
      [
        _statsRow(context, [
          ('Ortalama', '%${avg.round()}'),
          ('En yüksek', '%${best.round()}'),
          ('Kayıtlı gün', '${values.length}'),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 190,
          child: window.isEmpty
              ? _empty(context)
              : SimpleLineChart(
                  data: window,
                  from: from,
                  days: _days,
                  maxY: 100,
                  color: Theme.of(context).colorScheme.primary,
                  percent: true,
                  avgLine: values.isEmpty ? null : avg,
                ),
        ),
      ],
      trailing: _RangeSelector(days: _days, onChanged: (d) => setState(() => _days = d)),
    );
  }
}

// ============================================================
// Sayisal metrik karti
// ============================================================
class NumericStatCard extends StatefulWidget {
  final Metric metric;
  final Map<DateTime, double> series; // TUM veri
  final DateTime today;
  const NumericStatCard({
    super.key,
    required this.metric,
    required this.series,
    required this.today,
  });

  @override
  State<NumericStatCard> createState() => _NumericStatCardState();
}

class _NumericStatCardState extends State<NumericStatCard> {
  int _days = 30;

  bool _meets(double v) => widget.metric.targetDirection == TargetDirection.up
      ? v >= widget.metric.target!
      : v <= widget.metric.target!;

  @override
  Widget build(BuildContext context) {
    final m = widget.metric;
    final unit = m.unit;
    final from = widget.today.subtract(Duration(days: _days - 1));
    final window = _window(widget.series, from);
    final values = window.values.toList();
    final avg =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

    final stats = <(String, String)>[
      ('Ortalama', '${_fmt(avg)}${unit != null ? ' $unit' : ''}'),
    ];

    if (m.target != null && m.target! > 0) {
      // Hedef tutma orani: secili pencere icinde.
      var winSuccess = 0;
      window.forEach((d, v) {
        if (_meets(v)) winSuccess++;
      });
      // Streak: tum veri uzerinden (pencereyle sinirli degil).
      final fullSuccess = <DateTime>{};
      widget.series.forEach((d, v) {
        if (_meets(v)) fullSuccess.add(d);
      });
      stats.add(('Hedef tutma', '%${StatsUtil.rate(winSuccess, values.length)}'));
      stats.add(('Streak', '${StatsUtil.streak(fullSuccess, widget.today)} gün'));
    }

    return _cardShell(
      context,
      _title(),
      [
        _statsRow(context, stats),
        const SizedBox(height: 16),
        SizedBox(
          height: 190,
          child: window.isEmpty
              ? _empty(context)
              : SimpleLineChart(
                  data: window,
                  from: from,
                  days: _days,
                  maxY: _niceMax(values, m.target),
                  color: Colors.teal,
                  unit: unit,
                  targetLine: m.target,
                  avgLine: values.isEmpty ? null : avg,
                ),
        ),
      ],
      trailing: _RangeSelector(days: _days, onChanged: (d) => setState(() => _days = d)),
    );
  }

  String _title() => widget.metric.unit != null && widget.metric.unit!.isNotEmpty
      ? '${widget.metric.name} (${widget.metric.unit})'
      : widget.metric.name;
}

// ============================================================
// Evet/Hayir metrik karti
// ============================================================
class BooleanStatCard extends StatefulWidget {
  final Metric metric;
  final Map<DateTime, bool> values; // TUM veri ("Evet/yaptim" kayitlari)
  final Map<DateTime, double> numSeries; // TUM veri (boolHasValue ise)
  final Set<DateTime> activeDays; // kullanicinin veri girdigi gunler
  final DateTime today;
  const BooleanStatCard({
    super.key,
    required this.metric,
    required this.values,
    required this.numSeries,
    required this.activeDays,
    required this.today,
  });

  @override
  State<BooleanStatCard> createState() => _BooleanStatCardState();
}

class _BooleanStatCardState extends State<BooleanStatCard> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final m = widget.metric;
    final color = Theme.of(context).colorScheme.primary;
    final from = widget.today.subtract(Duration(days: _days - 1));

    // Cevapsiz = "Hayir/yapmadim" varsayilir (skor motoruyla ayni kural);
    // yalnizca aktif gunler degerlendirilir. Boylece "Hayir iyi" metriklerin
    // iyi gunleri (kayit birakmayan gunler) de dogru sayilir.
    // Tum aktif gunler: takvim + streak icin.
    final fullSuccess = <DateTime>{};
    for (final d in widget.activeDays) {
      if ((widget.values[d] ?? false) == m.goodValue) fullSuccess.add(d);
    }

    // Pencere: basari orani icin.
    final winDays = widget.activeDays.where((d) => !d.isBefore(from));
    var winSuccess = 0;
    var winTotal = 0;
    for (final d in winDays) {
      winTotal++;
      if ((widget.values[d] ?? false) == m.goodValue) winSuccess++;
    }

    final goodLabel = m.goodValue ? 'Evet' : 'Hayir';
    final stats = <(String, String)>[
      ('Seri', '${StatsUtil.streak(fullSuccess, widget.today)} gün'),
      ('Başarı ($goodLabel)', '%${StatsUtil.rate(winSuccess, winTotal)}'),
    ];

    final numWindow = _window(widget.numSeries, from);
    if (m.boolHasValue && numWindow.isNotEmpty) {
      final avg =
          numWindow.values.reduce((a, b) => a + b) / numWindow.length;
      stats.add(
          ('Ortalama', '${_fmt(avg)}${m.unit != null ? ' ${m.unit}' : ''}'));
    }

    return _cardShell(
      context,
      m.name,
      [
        _statsRow(context, stats),
        const SizedBox(height: 12),
        Text(
          '$goodLabel olunan günler işaretli:',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        MiniCalendar(markedDays: fullSuccess, color: color),
        if (m.boolHasValue && numWindow.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: SimpleLineChart(
              data: numWindow,
              from: from,
              days: _days,
              maxY: _niceMax(numWindow.values, m.target),
              color: Colors.teal,
              unit: m.unit,
              targetLine: m.target,
            ),
          ),
        ],
      ],
      trailing: _RangeSelector(days: _days, onChanged: (d) => setState(() => _days = d)),
    );
  }
}

// ============================================================
// Etiket metrik karti
// ============================================================
class TagStatCard extends StatefulWidget {
  final Metric metric;
  final Set<DateTime> tagDays; // TUM veri
  final DateTime today;
  const TagStatCard({
    super.key,
    required this.metric,
    required this.tagDays,
    required this.today,
  });

  @override
  State<TagStatCard> createState() => _TagStatCardState();
}

class _TagStatCardState extends State<TagStatCard> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final from = widget.today.subtract(Duration(days: _days - 1));
    final windowCount =
        widget.tagDays.where((d) => !d.isBefore(from)).length;

    return _cardShell(
      context,
      widget.metric.name,
      [
        _statsRow(context, [
          ('Seri', '${StatsUtil.streak(widget.tagDays, widget.today)} gün'),
          ('Etiketli gün', '$windowCount'),
        ]),
        const SizedBox(height: 12),
        Text(
          'Etiket eklenen günler işaretli:',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        MiniCalendar(markedDays: widget.tagDays, color: color),
      ],
      trailing: _RangeSelector(days: _days, onChanged: (d) => setState(() => _days = d)),
    );
  }
}

Widget _empty(BuildContext c) => Center(
      child: Text('Henüz veri yok.',
          style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
    );
