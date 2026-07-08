// Cevrimdisi onbellek ve yazma kuyrugu birim testleri.
// SharedPreferences'in test sahtesi (setMockInitialValues) kullanilir;
// gercek cihaz/bulut gerekmez.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_tracker/models/entry.dart';
import 'package:habit_tracker/services/local_cache.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final day = DateTime(2026, 7, 4);
  const date = '2026-07-04';

  group('giris onbellegi', () {
    test('kaydedip geri okur', () async {
      await LocalCache.saveEntries(date, [
        Entry(metricId: 'm1', date: day, numValue: 5),
        Entry(metricId: 'm2', date: day, boolValue: true),
      ]);
      final read = await LocalCache.readEntries(date);
      expect(read, isNotNull);
      expect(read!.length, 2);
      expect(read.firstWhere((e) => e.metricId == 'm1').numValue, 5);
      expect(read.firstWhere((e) => e.metricId == 'm2').boolValue, true);
    });

    test('upsert ayni metrigin degerini gunceller, cogaltmaz', () async {
      await LocalCache.upsertEntry(date, Entry(metricId: 'm1', date: day, numValue: 1));
      await LocalCache.upsertEntry(date, Entry(metricId: 'm1', date: day, numValue: 9));
      final read = await LocalCache.readEntries(date);
      expect(read!.where((e) => e.metricId == 'm1').length, 1);
      expect(read.first.numValue, 9);
    });

    test('okunmamis tarih icin null doner', () async {
      expect(await LocalCache.readEntries('2020-01-01'), isNull);
    });
  });

  group('etiket onbellegi', () {
    test('ekler ve tekrarlari yok sayar', () async {
      await LocalCache.addCachedTag(date, 'm1', 'kitap');
      await LocalCache.addCachedTag(date, 'm1', 'kitap');
      await LocalCache.addCachedTag(date, 'm1', 'spor');
      final tags = await LocalCache.readTags(date);
      expect(tags!['m1'], ['kitap', 'spor']);
    });

    test('siler', () async {
      await LocalCache.addCachedTag(date, 'm1', 'kitap');
      await LocalCache.removeCachedTag(date, 'm1', 'kitap');
      final tags = await LocalCache.readTags(date);
      expect(tags!['m1'], isEmpty);
    });
  });

  group('yazma kuyrugu', () {
    test('sirayla ekler', () async {
      await LocalCache.enqueue({'type': 'addTag', 'tag': 'a'});
      await LocalCache.enqueue({'type': 'addTag', 'tag': 'b'});
      final q = await LocalCache.readQueue();
      expect(q.length, 2);
      expect(q[0]['tag'], 'a');
      expect(q[1]['tag'], 'b');
    });

    test('dedupeKey ayni anahtarli onceki islemi degistirir', () async {
      await LocalCache.enqueue({'type': 'saveEntry', 'num': 1},
          dedupeKey: 'entry:x');
      await LocalCache.enqueue({'type': 'saveEntry', 'num': 2},
          dedupeKey: 'entry:x');
      final q = await LocalCache.readQueue();
      expect(q.length, 1);
      expect(q.first['num'], 2);
    });

    test('farkli dedupeKey ayri tutulur', () async {
      await LocalCache.enqueue({'num': 1}, dedupeKey: 'entry:a');
      await LocalCache.enqueue({'num': 2}, dedupeKey: 'entry:b');
      expect((await LocalCache.readQueue()).length, 2);
    });
  });
}
