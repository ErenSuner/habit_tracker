import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/default_metrics.dart';
import '../config/supabase_config.dart';
import '../models/entry.dart';
import '../models/metric.dart';

// Tum veritabani ve oturum islemlerini tek yerden yoneten katman.
// Ekranlar dogrudan Supabase'e degil, bu servise konusur.
class DataService {
  final SupabaseClient _client = Supabase.instance.client;

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
    var query = _client.from('metrics').select();
    if (onlyActive) query = query.eq('active', true);
    // ascending: true onemli — Supabase order() varsayilani azalandir,
    // bu da suralamayi ters cevirir.
    final rows = await query.order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => Metric.fromJson(r as Map<String, dynamic>))
        .toList();
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
    final rows = await _client.from('entries').select().eq('entry_date', d);
    return (rows as List)
        .map((r) => Entry.fromJson(r as Map<String, dynamic>))
        .toList();
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
    final data = entry.toUpsert()..['user_id'] = _uid;
    // Ayni (kullanici, metrik, gun) varsa uzerine yazar; yoksa ekler.
    await _client
        .from('entries')
        .upsert(data, onConflict: 'user_id,metric_id,entry_date');
  }

  // ---- Etiketler (tag tipli metrikler) ----

  Future<List<String>> fetchTags(DateTime date, String metricId) async {
    final rows = await _client
        .from('entry_tags')
        .select('tag')
        .eq('entry_date', _dateStr(date))
        .eq('metric_id', metricId);
    return (rows as List).map((r) => r['tag'] as String).toList();
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
    await _client.from('entry_tags').upsert({
      'user_id': _uid,
      'metric_id': metricId,
      'entry_date': _dateStr(date),
      'tag': tag.trim(),
    }, onConflict: 'user_id,metric_id,entry_date,tag');
  }

  Future<void> removeTag(DateTime date, String metricId, String tag) async {
    await _client
        .from('entry_tags')
        .delete()
        .eq('entry_date', _dateStr(date))
        .eq('metric_id', metricId)
        .eq('tag', tag);
  }

  // ---- Verim puani ----

  Future<void> saveDailyScore(DateTime date, double score) async {
    await _client.from('daily_scores').upsert({
      'user_id': _uid,
      'entry_date': _dateStr(date),
      'score': score,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,entry_date');
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

  // ---- Ekran suresi ----
  // Android gunluk kullanim detayini yalnizca ~1 hafta tuttugu icin okunan
  // degerler burada saklanir; 7/30/60 gunluk ortalamalar buradan hesaplanir.

  Future<void> saveScreenTime(DateTime date, int minutes) async {
    await _client.from('screen_times').upsert({
      'user_id': _uid,
      'entry_date': _dateStr(date),
      'minutes': minutes,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,entry_date');
  }

  Future<Map<DateTime, int>> fetchScreenTimes(
      DateTime from, DateTime to) async {
    final rows = await _client
        .from('screen_times')
        .select()
        .gte('entry_date', _dateStr(from))
        .lte('entry_date', _dateStr(to));
    final map = <DateTime, int>{};
    for (final r in rows as List) {
      map[DateTime.parse(r['entry_date'] as String)] =
          (r['minutes'] as num).toInt();
    }
    return map;
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
