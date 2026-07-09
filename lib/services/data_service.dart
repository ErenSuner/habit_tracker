import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/default_metrics.dart';
import '../config/supabase_config.dart';
import '../models/entry.dart';
import '../models/metric.dart';
import 'local_cache.dart';
import 'net_status.dart';

// Tum veritabani ve oturum islemlerini tek yerden yoneten katman.
// Ekranlar dogrudan Supabase'e degil, bu servise konusur.
//
// Cevrimdisi destegi: gunluk giris/etiket/metrik okumalari yerel onbellege
// alinir (internet yokken son bilinen veri gosterilir); gunluk giris/etiket/
// puan YAZMALARI internet yoksa kuyruga alinir ve yeniden baglaninca
// gonderilir (bkz. [syncPending]).
class DataService {
  final SupabaseClient _client = Supabase.instance.client;

  // Bir hatanin internet baglantisizligindan mi kaynaklandigini anlar.
  static bool _isOfflineError(Object e) {
    if (e is SocketException || e is TimeoutException) return true;
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('ClientException') ||
        s.contains('Connection refused') ||
        s.contains('Connection reset') ||
        s.contains('Network is unreachable');
  }

  // ---- Oturum (auth) ----

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  String? get _uid => _client.auth.currentUser?.id;

  // Oturum durumu degisince (giris/cikis) haber veren akis.
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      // Dogrulama e-postasindaki baglanti uygulamaya geri donsun.
      emailRedirectTo: SupabaseConfig.authCallbackUrl,
    );
  }

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  // Sifre sifirlama baglantisini e-postaya gonderir. Baglanti tiklaninca
  // uygulama deep link ile acilir ve passwordRecovery olayi tetiklenir
  // (main.dart'taki AuthGate bunu yakalayip yeni sifre ekranini gosterir).
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: SupabaseConfig.authCallbackUrl,
    );
  }

  // Sifre sifirlama akisinin son adimi: yeni sifreyi kaydeder.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // Hesabi KALICI olarak siler (delete-account Edge Function'i service role
  // ile auth.users satirini siler; tablolardaki veriler cascade ile gider).
  // Basarili olursa yerel oturumu da kapatir.
  Future<void> deleteAccount() async {
    final res = await _client.functions.invoke('delete-account');
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    // Kullanici artik yok; oturumu kapat (sunucu 404 dondurse de yerel
    // oturum temizlenir, hata onemsiz).
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  // Kullanicinin gosterilen adi (auth metadata'da saklanir, buluta senkron).
  String? get displayName {
    final v = currentUser?.userMetadata?['display_name'];
    return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
  }

  Future<void> updateDisplayName(String name) async {
    await _client.auth.updateUser(
      UserAttributes(data: {'display_name': name.trim()}),
    );
  }

  // Gosterilecek ad: once kullanicinin belirledigi, yoksa e-postadan turetilen.
  String get effectiveDisplayName {
    final meta = displayName;
    if (meta != null) return meta;
    final email = currentUser?.email;
    if (email == null || email.isEmpty) return '';
    final raw = email.split('@').first.split(RegExp(r'[._\-+]')).first;
    return raw.isEmpty ? '' : raw[0].toUpperCase() + raw.substring(1);
  }

  // ---- Metrikler ----

  Future<List<Metric>> fetchMetrics({bool onlyActive = true}) async {
    // Tum metrikleri cekip onbellege alir, aktif filtresini Dart'ta uygular.
    // Boylece tek bir onbellek hem aktif hem tum liste sorularina cevap verir.
    List<Metric>? all;
    if (NetStatus.online.value) {
      try {
        // ascending: true onemli — Supabase order() varsayilani azalandir.
        final rows =
            await _client.from('metrics').select().order('sort_order', ascending: true);
        all = (rows as List)
            .map((r) => Metric.fromJson(r as Map<String, dynamic>))
            .toList();
        await LocalCache.saveMetrics(all);
      } catch (e) {
        if (!_isOfflineError(e)) rethrow;
      }
    }
    all ??= await LocalCache.readMetrics() ?? const [];
    final filtered = onlyActive ? all.where((m) => m.active).toList() : all;
    return filtered;
  }

  Future<void> addMetric(Metric metric) async {
    final data = metric.toInsert()..['user_id'] = _uid;
    await _client.from('metrics').insert(data);
  }

  // Bir kategoriyi havuzdan siler: o kategoriye sahip tum metriklerin
  // kategorisini bosaltir (metrikler silinmez, kategorisiz kalir).
  Future<void> deleteCategory(String name) async {
    await _client.from('metrics').update({'category': null}).eq('category', name);
  }

  // Var olan metriklerden kullanilan kategorilerin (bos olmayan) havuzu.
  Future<List<String>> fetchCategories() async {
    final metrics = await fetchMetrics(onlyActive: false);
    final set = <String>{};
    for (final m in metrics) {
      final c = m.category?.trim();
      if (c != null && c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }

  // Yeni kullanici (hic metrigi yok) ise notr baslangic setini bir kerede ekler.
  // Zaten metrik varsa hicbir sey yapmaz. Eklediyse true doner.
  Future<bool> seedDefaultMetricsIfEmpty() async {
    final existing = await fetchMetrics(onlyActive: false);
    if (existing.isNotEmpty) return false;
    final rows = [
      for (final m in kDefaultMetrics) m.toInsert()..['user_id'] = _uid,
    ];
    await _client.from('metrics').insert(rows);
    return true;
  }

  Future<void> updateMetric(Metric metric) async {
    await _client.from('metrics').update(metric.toInsert()).eq('id', metric.id);
  }

  Future<void> deleteMetric(String metricId) async {
    await _client.from('metrics').delete().eq('id', metricId);
  }

  // Tek bir metrigin siralama degerini gunceller (suruklemeli siralama icin).
  Future<void> updateSortOrder(String metricId, int order) async {
    await _client.from('metrics').update({'sort_order': order}).eq('id', metricId);
  }

  // ---- Gunluk kayitlar (numeric / boolean / text) ----

  Future<List<Entry>> fetchEntries(DateTime date) async {
    final d = _dateStr(date);
    if (NetStatus.online.value) {
      try {
        final rows = await _client.from('entries').select().eq('entry_date', d);
        final list = (rows as List)
            .map((r) => Entry.fromJson(r as Map<String, dynamic>))
            .toList();
        await LocalCache.saveEntries(d, list);
        return list;
      } catch (e) {
        if (!_isOfflineError(e)) rethrow;
      }
    }
    // Cevrimdisi: son bilinen veriyi goster (yoksa bos).
    return await LocalCache.readEntries(d) ?? const [];
  }

  // Bir tarih araliginda hangi gunlerde hangi metrige etiket eklenmis?
  // Donus: metricId -> o metrige etiket eklenen gunlerin kumesi.
  Future<Map<String, Set<DateTime>>> fetchTagDays(
      DateTime from, DateTime to) async {
    final rows = await _client
        .from('entry_tags')
        .select('metric_id, entry_date')
        .gte('entry_date', _dateStr(from))
        .lte('entry_date', _dateStr(to));
    final map = <String, Set<DateTime>>{};
    for (final r in rows as List) {
      final mid = r['metric_id'] as String;
      final d = DateTime.parse(r['entry_date'] as String);
      (map[mid] ??= {}).add(DateTime(d.year, d.month, d.day));
    }
    return map;
  }

  // Bir tarih araligindaki tum kayitlari getirir (grafiklerde metrik gecmisi icin).
  Future<List<Entry>> fetchEntriesRange(DateTime from, DateTime to) async {
    final rows = await _client
        .from('entries')
        .select()
        .gte('entry_date', _dateStr(from))
        .lte('entry_date', _dateStr(to))
        .order('entry_date');
    return (rows as List)
        .map((r) => Entry.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveEntry(Entry entry) async {
    final d = _dateStr(entry.date);
    // Onbellegi her zaman guncelle (cevrimdisi okuma tutarli olsun).
    await LocalCache.upsertEntry(d, entry);
    if (!NetStatus.online.value) {
      await _enqueueEntry(entry);
      return;
    }
    try {
      await _saveEntryRemote(entry);
    } catch (e) {
      if (_isOfflineError(e)) {
        await _enqueueEntry(entry);
        return;
      }
      rethrow;
    }
  }

  Future<void> _saveEntryRemote(Entry entry) async {
    final data = entry.toUpsert()..['user_id'] = _uid;
    // Ayni (kullanici, metrik, gun) varsa uzerine yazar; yoksa ekler.
    await _client
        .from('entries')
        .upsert(data, onConflict: 'user_id,metric_id,entry_date');
  }

  Future<void> _enqueueEntry(Entry entry) async {
    final d = _dateStr(entry.date);
    await LocalCache.enqueue({
      'type': 'saveEntry',
      'date': d,
      'metric_id': entry.metricId,
      'num': entry.numValue,
      'bool': entry.boolValue,
      'text': entry.textValue,
    }, dedupeKey: 'entry:$d:${entry.metricId}');
  }

  // ---- Etiketler (tag tipli metrikler) ----

  Future<List<String>> fetchTags(DateTime date, String metricId) async {
    final d = _dateStr(date);
    if (NetStatus.online.value) {
      try {
        final rows = await _client
            .from('entry_tags')
            .select('tag')
            .eq('entry_date', d)
            .eq('metric_id', metricId);
        final list = (rows as List).map((r) => r['tag'] as String).toList();
        // Onbellekteki gun haritasinda yalnizca bu metrigi guncelle.
        final map = await LocalCache.readTags(d) ?? {};
        map[metricId] = list;
        await LocalCache.saveTags(d, map);
        return list;
      } catch (e) {
        if (!_isOfflineError(e)) rethrow;
      }
    }
    final cached = await LocalCache.readTags(d);
    return cached?[metricId] ?? const [];
  }

  // Bir gunun TUM etiketlerini metrik bazinda gruplu getirir.
  // Donus: metricId -> [etiketler]
  Future<Map<String, List<String>>> fetchAllTags(DateTime date) async {
    final rows = await _client
        .from('entry_tags')
        .select('metric_id, tag')
        .eq('entry_date', _dateStr(date));
    final map = <String, List<String>>{};
    for (final r in rows as List) {
      final mid = r['metric_id'] as String;
      (map[mid] ??= []).add(r['tag'] as String);
    }
    return map;
  }

  Future<void> addTag(DateTime date, String metricId, String tag) async {
    final d = _dateStr(date);
    final t = tag.trim();
    await LocalCache.addCachedTag(d, metricId, t);
    if (!NetStatus.online.value) {
      await LocalCache.enqueue(
          {'type': 'addTag', 'date': d, 'metric_id': metricId, 'tag': t});
      return;
    }
    try {
      await _addTagRemote(d, metricId, t);
    } catch (e) {
      if (_isOfflineError(e)) {
        await LocalCache.enqueue(
            {'type': 'addTag', 'date': d, 'metric_id': metricId, 'tag': t});
        return;
      }
      rethrow;
    }
  }

  Future<void> _addTagRemote(String d, String metricId, String tag) async {
    await _client.from('entry_tags').upsert({
      'user_id': _uid,
      'metric_id': metricId,
      'entry_date': d,
      'tag': tag,
    }, onConflict: 'user_id,metric_id,entry_date,tag');
  }

  Future<void> removeTag(DateTime date, String metricId, String tag) async {
    final d = _dateStr(date);
    await LocalCache.removeCachedTag(d, metricId, tag);
    if (!NetStatus.online.value) {
      await LocalCache.enqueue(
          {'type': 'removeTag', 'date': d, 'metric_id': metricId, 'tag': tag});
      return;
    }
    try {
      await _removeTagRemote(d, metricId, tag);
    } catch (e) {
      if (_isOfflineError(e)) {
        await LocalCache.enqueue(
            {'type': 'removeTag', 'date': d, 'metric_id': metricId, 'tag': tag});
        return;
      }
      rethrow;
    }
  }

  Future<void> _removeTagRemote(String d, String metricId, String tag) async {
    await _client
        .from('entry_tags')
        .delete()
        .eq('entry_date', d)
        .eq('metric_id', metricId)
        .eq('tag', tag);
  }

  // ---- Verim puani ----

  Future<void> saveDailyScore(DateTime date, double score) async {
    final d = _dateStr(date);
    if (!NetStatus.online.value) {
      await LocalCache.enqueue(
          {'type': 'saveScore', 'date': d, 'score': score},
          dedupeKey: 'score:$d');
      return;
    }
    try {
      await _saveScoreRemote(d, score);
    } catch (e) {
      if (_isOfflineError(e)) {
        await LocalCache.enqueue(
            {'type': 'saveScore', 'date': d, 'score': score},
            dedupeKey: 'score:$d');
        return;
      }
      rethrow;
    }
  }

  Future<void> _saveScoreRemote(String d, double score) async {
    await _client.from('daily_scores').upsert({
      'user_id': _uid,
      'entry_date': d,
      'score': score,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,entry_date');
  }

  // ---- Cevrimdisi kuyrugu ----

  // Bekleyen (cevrimdisi yapilmis) yazmalari sirayla sunucuya gonderir.
  // Uygulama acilisinda ve yeniden baglaninca cagrilir. Internet yine yoksa
  // kalan islemler kuyrukta birakilir; bozuk bir islem (ag disi hata)
  // kuyrugu tikamamasi icin atilir.
  Future<void> syncPending() async {
    if (_uid == null) return;
    final ops = await LocalCache.readQueue();
    if (ops.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    var stop = false;
    for (final op in ops) {
      if (stop) {
        remaining.add(op);
        continue;
      }
      try {
        await _applyRemoteOp(op);
      } catch (e) {
        if (_isOfflineError(e)) {
          // Hala cevrimdisi: bunu ve kalanlari sirayla koru, dur.
          remaining.add(op);
          stop = true;
        }
        // Ag disi hata: islemi at (poison mesajin kuyrugu kilitlemesini onle).
      }
    }
    await LocalCache.writeQueue(remaining);
  }

  Future<void> _applyRemoteOp(Map<String, dynamic> op) async {
    final type = op['type'] as String?;
    final d = op['date'] as String?;
    switch (type) {
      case 'saveEntry':
        await _saveEntryRemote(Entry(
          metricId: op['metric_id'] as String,
          date: DateTime.parse(d!),
          numValue: (op['num'] as num?)?.toDouble(),
          boolValue: op['bool'] as bool?,
          textValue: op['text'] as String?,
        ));
      case 'addTag':
        await _addTagRemote(d!, op['metric_id'] as String, op['tag'] as String);
      case 'removeTag':
        await _removeTagRemote(
            d!, op['metric_id'] as String, op['tag'] as String);
      case 'saveScore':
        await _saveScoreRemote(d!, (op['score'] as num).toDouble());
    }
  }

  // Belirli bir tarih araligindaki verim puanlarini getirir (grafikler icin).
  Future<Map<DateTime, double>> fetchScores(DateTime from, DateTime to) async {
    final rows = await _client
        .from('daily_scores')
        .select()
        .gte('entry_date', _dateStr(from))
        .lte('entry_date', _dateStr(to))
        .order('entry_date');
    final map = <DateTime, double>{};
    for (final r in rows as List) {
      map[DateTime.parse(r['entry_date'] as String)] =
          (r['score'] as num).toDouble();
    }
    return map;
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
