import 'package:flutter/material.dart';

import '../models/entry.dart';
import '../models/metric.dart';

// Bir gunun girislerini salt-okunur gosterir (Gecmis ekraninda kullanilir).
class DaySummary extends StatelessWidget {
  final List<Metric> metrics;
  final Map<String, Entry> entries;
  final Map<String, List<String>> tags;

  const DaySummary({
    super.key,
    required this.metrics,
    required this.entries,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Bu gün için metrik yok.'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: metrics.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _row(context, metrics[i]),
    );
  }

  Widget _row(BuildContext context, Metric m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              m.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(flex: 3, child: _value(context, m)),
        ],
      ),
    );
  }

  Widget _value(BuildContext context, Metric m) {
    final c = Theme.of(context).colorScheme;
    final muted = TextStyle(color: c.onSurfaceVariant);
    final e = entries[m.id];

    switch (m.type) {
      case MetricType.numeric:
        if (e?.numValue == null) return Text('—', style: muted);
        final v = e!.numValue!;
        final txt = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
        return Text('$txt${m.unit != null ? ' ${m.unit}' : ''}');
      case MetricType.boolean:
        if (e?.boolValue == null) return Text('—', style: muted);
        final good = e!.boolValue == m.goodValue;
        var label = e.boolValue! ? 'Evet' : 'Hayir';
        // "Evet" + sayisal deger varsa parantez icinde goster.
        if (e.boolValue! && m.boolHasValue && e.numValue != null) {
          final v = e.numValue!;
          final vStr =
              v == v.roundToDouble() ? v.toInt().toString() : v.toString();
          label += ' ($vStr${m.unit != null ? ' ${m.unit}' : ''})';
        }
        return Text(
          label,
          style: TextStyle(
            color: good ? c.primary : c.error,
            fontWeight: FontWeight.w500,
          ),
        );
      case MetricType.tag:
        final list = tags[m.id] ?? [];
        if (list.isEmpty) return Text('—', style: muted);
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: list
              .map((t) => Chip(
                    label: Text(t),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        );
      case MetricType.text:
        final t = e?.textValue;
        if (t == null || t.trim().isEmpty) return Text('—', style: muted);
        return Text(t);
    }
  }
}
