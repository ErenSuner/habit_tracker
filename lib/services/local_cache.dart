import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry.dart';
import '../models/metric.dart';

// Cevrimdisi destegi icin yerel depo (SharedPreferences uzerinde JSON).
//  - Okuma onbellegi: son cekilen metrik/giris/etiket verisi burada tutulur,
//    boylece internet yokken uygulama son bilinen veriyi gosterebilir.
//  - Yazma kuyrugu: cevrimdisi yapilan kayitlar sirayla saklanir ve yeniden
//    baglaninca sunucuya gonderilir (bkz. DataService.syncPending).
//
// Veri kucuk oldugu icin (birkac metrik + gorulen gunlerin girisleri)
// SharedPreferences yeterli; ayri bir veritabanina gerek yok.
class LocalCache {
  static const _kMetrics = 'cache_metrics';
  static const _kQueue = 'pending_ops';
  static String _entriesKey(String date) => 'cache_entries_$date';
  static String _tagsKey(String date) => 'cache_tags_$date';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  // ---------------------------------------------------------------
  // Metrikler (tam liste — aktif/pasif filtresi cagiran tarafta yapilir)
  // ---------------------------------------------------------------
  static Future<void> saveMetrics(List<Metric> metrics) async {
    final p = await _prefs;
    final list = metrics.map((m) => {...m.toInsert(), 'id': m.id}).toList();
    await p.setString(_kMetrics, jsonEncode(list));
  }

  static Future<List<Metric>?> readMetrics() async {
    final p = await _prefs;
    final s = p.getString(_kMetrics);
    if (s == null) return null;
    try {
      final list = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
      return list.map(Metric.fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------
  // Gunluk girisler (tarih basina)
  // ---------------------------------------------------------------
  static Future<void> saveEntries(String date, List<Entry> entries) async {
    final p = await _prefs;
    final list = entries
        .map((e) => {...e.toUpsert(), if (e.id != null) 'id': e.id})
        .toList();
    await p.setString(_entriesKey(date), jsonEncode(list));
  }

  static Future<List<Entry>?> readEntries(String date) async {
    final p = await _prefs;
    final s = p.getString(_entriesKey(date));
    if (s == null) return null;
    try {
      final list = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
      return list.map(Entry.fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  // Onbellekteki bir gunun girisini gunceller (ayni metrik varsa uzerine yazar).
  static Future<void> upsertEntry(String date, Entry entry) async {
    final cur = await readEntries(date) ?? [];
    final list = [
      for (final e in cur)
        if (e.metricId != entry.metricId) e,
      entry,
    ];
    await saveEntries(date, list);
  }

  // ---------------------------------------------------------------
  // Etiketler (tarih basina: metricId -> etiketler)
  // ---------------------------------------------------------------
  static Future<void> saveTags(
      String date, Map<String, List<String>> tags) async {
    final p = await _prefs;
    await p.setString(_tagsKey(date), jsonEncode(tags));
  }

  static Future<Map<String, List<String>>?> readTags(String date) async {
    final p = await _prefs;
    final s = p.getString(_tagsKey(date));
    if (s == null) return null;
    try {
      final map = (jsonDecode(s) as Map).map(
        (k, v) => MapEntry(k as String, (v as List).cast<String>()),
      );
      return map;
    } catch (_) {
      return null;
    }
  }

  static Future<void> addCachedTag(
      String date, String metricId, String tag) async {
    final cur = await readTags(date) ?? <String, List<String>>{};
    final list = <String>[...?cur[metricId]];
    if (!list.contains(tag)) list.add(tag);
    cur[metricId] = list;
    await saveTags(date, cur);
  }

  static Future<void> removeCachedTag(
      String date, String metricId, String tag) async {
    final cur = await readTags(date);
    if (cur == null) return;
    cur[metricId] = <String>[...?cur[metricId]]..remove(tag);
    await saveTags(date, cur);
  }

  // ---------------------------------------------------------------
  // Yazma kuyrugu (cevrimdisi yapilan islemler)
  // ---------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> readQueue() async {
    final p = await _prefs;
    final s = p.getString(_kQueue);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> writeQueue(List<Map<String, dynamic>> ops) async {
    final p = await _prefs;
    await p.setString(_kQueue, jsonEncode(ops));
  }

  // Kuyruga bir islem ekler. [dedupeKey] verilirse ayni anahtarli onceki
  // islem silinir (orn. ayni gun+metrik icin son deger yeter).
  static Future<void> enqueue(
    Map<String, dynamic> op, {
    String? dedupeKey,
  }) async {
    final ops = await readQueue();
    if (dedupeKey != null) {
      ops.removeWhere((o) => o['_key'] == dedupeKey);
      op = {...op, '_key': dedupeKey};
    }
    ops.add(op);
    await writeQueue(ops);
  }

  static Future<bool> hasPending() async => (await readQueue()).isNotEmpty;
}
