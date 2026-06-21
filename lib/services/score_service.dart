import '../models/entry.dart';
import '../models/metric.dart';

// Bir gunun "% verim" puanini hesaplar (0..100).
//
// Mantik: agirligi > 0 olan her metrik icin 0..1 arasi bir "basari" degeri
// bulunur, agirlikla carpilir, toplam agirliga bolunur ve 100 ile carpilir.
//
//   - numeric: hedef varsa orana gore (yon: up/down); hedef yoksa girildiyse 1
//   - boolean: "Evet/yaptim" (true) ise iyiyle karsilastirilir; cevapsiz =
//              "Hayir/yapmadim" varsayilir. Yani iyi sonuc goodValue ile
//              belirlenir (orn. masturbasyon-yok metriginde goodValue=false:
//              yapmadigin -> cevapsiz/false -> 1 puan, yaptigin -> true -> 0).
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
    return (weightedSum / totalWeight) * 100;
  }

  // Tek bir metrigin 0..1 arasi basari degeri.
  static double _metricScore(Metric m, Entry? entry, List<String>? tagList) {
    switch (m.type) {
      case MetricType.numeric:
        final v = entry?.numValue;
        if (v == null) return 0;
        final t = m.target;
        if (m.targetDirection == TargetDirection.up) {
          // Sayi artinca iyilesir.
          if (t == null || t == 0) return v > 0 ? 1 : 0;
          return (v / t).clamp(0, 1).toDouble();
        } else {
          // Sayi artinca kotulesir.
          if (t == null || t == 0) {
            // Hedef yok: 0 en iyi, her artis puani yumusakca dusurur
            // (0 -> 1.0, 1 -> 0.5, 2 -> 0.33, 3 -> 0.25 ...).
            return v <= 0 ? 1.0 : (1 / (1 + v));
          }
          // Hedef var: hedefin altinda/esitse tam puan, ustunde duser.
          if (v <= t) return 1;
          return (t / v).clamp(0, 1).toDouble();
        }
      case MetricType.boolean:
        // Cevapsiz = "Hayir/yapmadim" (false) varsayilir.
        final b = entry?.boolValue ?? false;
        return b == m.goodValue ? 1 : 0;
      case MetricType.tag:
        return (tagList != null && tagList.isNotEmpty) ? 1 : 0;
      case MetricType.text:
        final t = entry?.textValue;
        return (t != null && t.trim().isNotEmpty) ? 1 : 0;
    }
  }
}
