// Verim puani motorunun birim testleri.
// Ozellikle iki kritik kural:
//   1) Cevapsiz (bos) boolean puan ALMAZ — "Hayir iyi" metrikte bile.
//   2) Aralik hedefi: [alt, ust] icinde tam puan, disina ciktikca duser.
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/models/entry.dart';
import 'package:habit_tracker/models/metric.dart';
import 'package:habit_tracker/services/score_service.dart';

void main() {
  final day = DateTime(2026, 7, 4);

  Metric boolMetric({required bool goodValue}) => Metric(
        id: 'b1',
        name: 'Instagram',
        type: MetricType.boolean,
        goodValue: goodValue,
      );

  Metric rangeMetric() => const Metric(
        id: 'n1',
        name: 'Uyku',
        type: MetricType.numeric,
        target: 9, // ust sinir
        targetMin: 7, // alt sinir
        targetDirection: TargetDirection.range,
      );

  double score(Metric m, {Entry? entry}) => ScoreService.computeDay(
        metrics: [m],
        entries: entry == null ? {} : {m.id: entry},
        tags: {},
      );

  group('boolean: bos gun ile Hayir farkli', () {
    test('hic giris yoksa "Hayir iyi" metrik bile 0 puan', () {
      expect(score(boolMetric(goodValue: false)), 0);
    });

    test('acik Hayir cevabi "Hayir iyi" metrikte tam puan', () {
      final m = boolMetric(goodValue: false);
      final e = Entry(metricId: m.id, date: day, boolValue: false);
      expect(score(m, entry: e), 100);
    });

    test('Evet cevabi "Hayir iyi" metrikte 0 puan', () {
      final m = boolMetric(goodValue: false);
      final e = Entry(metricId: m.id, date: day, boolValue: true);
      expect(score(m, entry: e), 0);
    });

    test('boolValue null olan entry de cevapsiz sayilir', () {
      final m = boolMetric(goodValue: false);
      final e = Entry(metricId: m.id, date: day);
      expect(score(m, entry: e), 0);
    });
  });

  group('numeric: aralik hedefi (7-9 uyku ornegi)', () {
    double sleep(double hours) => score(
          rangeMetric(),
          entry: Entry(metricId: 'n1', date: day, numValue: hours),
        );

    test('aralik icinde tam puan', () {
      expect(sleep(7), 100);
      expect(sleep(8), 100);
      expect(sleep(9), 100);
    });

    test('altina dustukce puan azalir', () {
      expect(sleep(6), 50); // 1 saat sapma / 2 saat genislik = %50
      expect(sleep(5), 0);
    });

    test('ustune ciktikca puan azalir (cok uyumak da kotu)', () {
      expect(sleep(10), 50);
      expect(sleep(11), 0);
      expect(sleep(13), 0); // negatif ceza, gun toplami 0'da kirpilir
    });
  });
}
