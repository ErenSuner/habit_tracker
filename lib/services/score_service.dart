import '../models/entry.dart';
import '../models/metric.dart';

// Bir gunun "% verim" puanini hesaplar (0..100).
//
// Mantik: agirligi > 0 olan her metrik icin 0..1 arasi bir "basari" degeri
// bulunur, agirlikla carpilir, toplam agirliga bolunur ve 100 ile carpilir.
//
//   - numeric (artis iyi): hedefe orana gore (0..1); hedef yoksa girildiyse 1
//   - numeric (artis kotu): 0 en iyi (+1), hedef notr (0), hedefi astikca
//     NEGATIF (en cok -1) -> verime ceza olarak yansir
//   - numeric (aralik): [alt, ust] icindeyse 1; disina ciktikca aralik
//     genisligi basina dogrusal duser, NEGATIFE gecebilir (en az -1)
//   - boolean: YALNIZCA acik cevap puanlanir. Evet/Hayir'dan goodValue ile
//     eslesen 1, eslesmeyen 0. CEVAPSIZ (bos) her zaman 0 — "hic giris
//     yapmamak" ile "Hayir demek" farkli seylerdir; yoksa hicbir sey
//     girmeyen biri "Hayir iyi" metriklerden bedava puan alirdi.
//   - tag:     o gun en az bir etiket varsa 1, yoksa 0
//   - text:    (varsayilan agirlik 0 -> sayilmaz) yazildiysa 1
class ScoreService {
  static double computeDay({
    required List<Metric> metrics,
    required Map<String, Entry> entries,
    required Map<String, List<String>> tags,
  }) {
    double weightedSum = 0;
    double totalWeight = 0;

    for (final m in metrics) {
      if (m.weight <= 0) continue;
      totalWeight += m.weight;
      weightedSum += m.weight * _metricScore(m, entries[m.id], tags[m.id]);
    }

    if (totalWeight == 0) return 0;
    // Negatif (cezali) metrikler sonucu asagi ceker; verimi 0..100'de tutariz.
    final pct = (weightedSum / totalWeight) * 100;
    return pct.clamp(0, 100).toDouble();
  }

  // Tek bir metrigin 0..1 arasi basari degeri.
  static double _metricScore(Metric m, Entry? entry, List<String>? tagList) {
    switch (m.type) {
      case MetricType.numeric:
        final v = entry?.numValue;
        if (v == null) return 0;
        final t = m.target;
        if (m.targetDirection == TargetDirection.range) {
          // Aralik: [alt, ust] icinde tam puan; disina ciktikca aralik
          // genisligi (ust - alt) basina dogrusal duser ve negatife gecer.
          // Ornek uyku 7-9: 6sa -> 0.5, 5sa -> 0, 11sa -> 0, 13sa -> -1.
          final lo = m.targetMin, hi = t;
          if (lo == null || hi == null || hi <= lo) {
            // Aralik duzgun tanimlanmamis: girildiyse tam puan.
            return 1;
          }
          if (v >= lo && v <= hi) return 1;
          final w = hi - lo;
          final dist = v < lo ? lo - v : v - hi;
          return (1 - dist / w).clamp(-1.0, 1.0).toDouble();
        }
        if (m.targetDirection == TargetDirection.up) {
          // Sayi artinca iyilesir.
          if (t == null || t == 0) return v > 0 ? 1 : 0;
          return (v / t).clamp(0, 1).toDouble();
        } else {
          // Sayi artinca kotulesir: 0 en iyi (+1), arttikca duser ve NEGATIFE
          // gecer (verime ceza). Alt sinir -1.
          if (t == null || t == 0) {
            // Hedef yok: 0 -> +1, 1 -> 0, sonrasi negatif (-1'e yaklasir).
            if (v <= 0) return 1.0;
            return (1 - v) / (1 + v);
          }
          // Hedef var: 0 -> +1, hedef -> 0, hedefi astikca negatif (en az -1).
          final s = 1 - v / t;
          return s.clamp(-1.0, 1.0).toDouble();
        }
      case MetricType.boolean:
        // Cevapsiz (bos) puan almaz — acik "Hayir" ile ayni sey DEGILDIR.
        final b = entry?.boolValue;
        if (b == null) return 0;
        return b == m.goodValue ? 1 : 0;
      case MetricType.tag:
        return (tagList != null && tagList.isNotEmpty) ? 1 : 0;
      case MetricType.text:
        final t = entry?.textValue;
        return (t != null && t.trim().isNotEmpty) ? 1 : 0;
    }
  }
}
