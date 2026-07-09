import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';
import '../models/metric.dart';
import '../services/stats_util.dart';
import 'mini_calendar.dart';
import 'simple_bar_chart.dart';
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

// Grafik karti. collapsible=true ise varsayilan KAPALI gelir: baslik +
// ozet istatistik gorunur, dokununca grafik acilir. Boylece Grafikler
// sekmesi az kaydirilir. collapsible=false kartlar hep aciktir.
Widget _cardShell(
  BuildContext c,
  String title,
  List<Widget> children, {
  Widget? trailing,
  bool collapsible = false,
  String? summary,
  IconData? icon,
}) =>
    _ChartCard(
      title: title,
      trailing: trailing,
      collapsible: collapsible,
      summary: summary,
      icon: icon,
      children: children,
    );

class _ChartCard extends StatefulWidget {
  final String title;
  final Widget? trailing;
  final bool collapsible;
  final String? summary;
  final IconData? icon;
  final List<Widget> children;
  const _ChartCard({
    required this.title,
    required this.children,
    this.trailing,
    this.collapsible = false,
    this.summary,
    this.icon,
  });

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expanded = !widget.collapsible || _open;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.collapsible
                  ? () => setState(() => _open = !_open)
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(widget.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (expanded && widget.trailing != null)
                    widget.trailing!
                  else if (widget.collapsible) ...[
                    if (widget.summary != null)
                      Text(widget.summary!,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: cs.primary)),
                    const SizedBox(width: 4),
                    Icon(_open ? Icons.expand_less : Icons.expand_more,
                        color: cs.onSurfaceVariant),
                  ],
                ],
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
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
      icon: Icons.local_fire_department,
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

  bool _meets(double v) {
    final m = widget.metric;
    return switch (m.targetDirection) {
      TargetDirection.up => v >= m.target!,
      TargetDirection.down => v <= m.target!,
      // Aralik: alt ve ust sinirin ikisinin de icinde kalmali.
      TargetDirection.range => v >= m.targetMin! && v <= m.target!,
    };
  }

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

    // Hedef tanimli mi? (aralikta iki sinir da gerekli)
    final hasTarget = m.targetDirection == TargetDirection.range
        ? (m.target != null && m.targetMin != null)
        : (m.target != null && m.target! > 0);

    if (hasTarget) {
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
      icon: Icons.bar_chart_rounded,
      collapsible: true,
      summary: values.isEmpty
          ? '—'
          : '${_fmt(avg)}${unit != null ? ' $unit' : ''}',
      [
        _statsRow(context, stats),
        const SizedBox(height: 16),
        SizedBox(
          height: 190,
          child: window.isEmpty
              ? _empty(context)
              : SimpleBarChart(
                  data: window,
                  from: from,
                  days: _days,
                  maxY: _niceMax(values, m.target),
                  color: AppColors.accent,
                  unit: unit,
                  targetLine: m.target,
                  targetLine2: m.targetDirection == TargetDirection.range
                      ? m.targetMin
                      : null,
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
  final Map<DateTime, bool> values; // TUM veri (ACIK Evet/Hayir kayitlari)
  final Map<DateTime, double> numSeries; // TUM veri (boolHasValue ise)
  final DateTime today;
  const BooleanStatCard({
    super.key,
    required this.metric,
    required this.values,
    required this.numSeries,
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

    // YALNIZCA acik cevaplar degerlendirilir (skor motoruyla ayni kural):
    // "kayit yok" ile "Hayir" farkli seylerdir. Boylece metrik eklenmeden
    // onceki bos gunler sahte basari/seri uretmez.
    final fullSuccess = <DateTime>{
      for (final e in widget.values.entries)
        if (e.value == m.goodValue) e.key,
    };

    // Pencere: basari orani icin (acik cevap verilen gunler).
    var winSuccess = 0;
    var winTotal = 0;
    widget.values.forEach((d, v) {
      if (d.isBefore(from)) return;
      winTotal++;
      if (v == m.goodValue) winSuccess++;
    });

    final goodLabel = m.goodValue ? 'Evet' : 'Hayır';
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
      icon: m.goodValue ? Icons.check_circle_outline : Icons.block,
      collapsible: true,
      summary: '${StatsUtil.streak(fullSuccess, widget.today)} gün seri',
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
            child: SimpleBarChart(
              data: numWindow,
              from: from,
              days: _days,
              maxY: _niceMax(numWindow.values, m.target),
              color: AppColors.accent,
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
  // Bir gunun etiketlerini getirir; takvimde gune dokununca gosterilir.
  final Future<List<String>> Function(DateTime day)? loadTags;
  const TagStatCard({
    super.key,
    required this.metric,
    required this.tagDays,
    required this.today,
    this.loadTags,
  });

  @override
  State<TagStatCard> createState() => _TagStatCardState();
}

class _TagStatCardState extends State<TagStatCard> {
  int _days = 30;

  // Takvimde isaretli bir gune dokununca o gunun etiketlerini kucuk bir
  // pencerede gosterir.
  Future<void> _showDayTags(DateTime day) async {
    if (widget.loadTags == null) return;
    if (!widget.tagDays.contains(day)) return; // etiketsiz gun: sessiz gec
    final tagsFuture = widget.loadTags!(day);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          DateFormat('d MMMM EEEE', 'tr_TR').format(day),
          style: const TextStyle(fontSize: 17),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<String>>(
            future: tagsFuture,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 56,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final tags = snap.data ?? const <String>[];
              if (tags.isEmpty) {
                return const Text('Bu gün için etiket bulunamadı.');
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final t in tags) Chip(label: Text(t))],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final from = widget.today.subtract(Duration(days: _days - 1));
    final windowCount =
        widget.tagDays.where((d) => !d.isBefore(from)).length;

    return _cardShell(
      context,
      widget.metric.name,
      icon: Icons.sell_outlined,
      collapsible: true,
      summary: '${StatsUtil.streak(widget.tagDays, widget.today)} gün seri',
      [
        _statsRow(context, [
          ('Seri', '${StatsUtil.streak(widget.tagDays, widget.today)} gün'),
          ('Etiketli gün', '$windowCount'),
        ]),
        const SizedBox(height: 12),
        Text(
          'Etiket eklenen günler işaretli · güne dokun, etiketleri gör:',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        MiniCalendar(
          markedDays: widget.tagDays,
          color: color,
          onDayTap: _showDayTags,
        ),
      ],
      trailing: _RangeSelector(days: _days, onChanged: (d) => setState(() => _days = d)),
    );
  }
}

Widget _empty(BuildContext c) => Center(
      child: Text('Henüz veri yok.',
          style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
    );
