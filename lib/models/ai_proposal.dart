import 'metric.dart';

// AI'nin onerdigi tek bir giris (bir metrik icin bir deger).
class ProposedEntry {
  final String metricId;
  final String? metricName;
  final MetricType type;
  final double? numValue;
  final bool? boolValue;
  final String? textValue;
  final List<String> tags;

  const ProposedEntry({
    required this.metricId,
    this.metricName,
    required this.type,
    this.numValue,
    this.boolValue,
    this.textValue,
    this.tags = const [],
  });

  factory ProposedEntry.fromJson(Map<String, dynamic> j) {
    return ProposedEntry(
      metricId: j['metric_id'] as String,
      metricName: j['metric_name'] as String?,
      type: MetricTypeX.fromDb(j['type'] as String),
      numValue: (j['num_value'] as num?)?.toDouble(),
      boolValue: j['bool_value'] as bool?,
      textValue: j['text_value'] as String?,
      tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  // Kullaniciya gosterilecek ozet (orn. "Spor yaptim: Evet").
  String summary() {
    final name = metricName ?? 'Metrik';
    switch (type) {
      case MetricType.numeric:
        return '$name: ${numValue ?? '-'}';
      case MetricType.boolean:
        return '$name: ${boolValue == true ? 'Evet' : boolValue == false ? 'Hayir' : '-'}';
      case MetricType.tag:
        return '$name: ${tags.join(', ')}';
      case MetricType.text:
        return '$name: ${textValue ?? '-'}';
    }
  }
}

// AI'nin tum cevabi: kullaniciya yanit + onerilen girisler.
class AiProposal {
  final String reply;
  final List<ProposedEntry> entries;

  const AiProposal({required this.reply, required this.entries});

  factory AiProposal.fromJson(Map<String, dynamic> j) {
    return AiProposal(
      reply: j['reply'] as String? ?? '',
      entries: (j['entries'] as List? ?? [])
          .map((e) => ProposedEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
