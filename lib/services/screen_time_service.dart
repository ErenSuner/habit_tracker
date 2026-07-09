import 'dart:io';

import 'package:usage_stats/usage_stats.dart';

// Telefonun gunluk ekran suresini okur (yalnizca Android).
//
// Kaynak: UsageStatsManager. Kullanicinin telefon ayarlarindan "Kullanim
// verisi erisimi" (usage access) izni vermesi gerekir; bu izin normal
// calisma zamani izinlerinden farklidir, ayarlar sayfasindan acilir.
//
// NOT: Android gunluk detayi cihazda yalnizca ~1 hafta tutar. Bu yuzden
// okunan degerler her acilista Supabase'e (screen_times tablosu) yazilir;
// 7/30/60 gunluk ortalamalar oradan hesaplanir.
class ScreenTimeService {
  static Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  // Telefonun "Kullanim verisi erisimi" ayar sayfasini acar.
  static Future<void> requestPermission() async {
    try {
      await UsageStats.grantUsagePermission();
    } catch (_) {}
  }

  // Bir gunun toplam ekran suresi (dakika). Okunamazsa null.
  //
  // Yontem: uygulamalarin ON PLANA gelme/gitme olaylari (RESUMED/PAUSED)
  // eslestirilir ve "en az bir uygulama on planda" gecen surenin BIRLESIMI
  // alinir. Bu, telefonun "Dijital Denge / Ekran Suresi" degerine en yakin
  // olcumdur (ekran-acik anlarini saymak Samsung gibi cihazlarda eksik/
  // yanlis cikiyordu). Olay yoksa uygulama on plan surelerinin toplamina
  // dusulur.
  static Future<int?> minutesForDay(DateTime day) async {
    if (!Platform.isAndroid) return null;

    final start = DateTime(day.year, day.month, day.day);
    var end = start.add(const Duration(days: 1));
    final now = DateTime.now();
    if (end.isAfter(now)) end = now;
    if (!end.isAfter(start)) return null;

    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    List<EventUsageInfo> events;
    try {
      events = await UsageStats.queryEvents(start, end);
    } catch (_) {
      return null;
    }

    // Olaylari zamana gore sirala (eklenti sirali dondurmeyebilir).
    final sorted = [
      for (final e in events)
        if (int.tryParse(e.timeStamp ?? '') != null) e,
    ]..sort((a, b) =>
        int.parse(a.timeStamp!).compareTo(int.parse(b.timeStamp!)));

    var totalMs = 0;
    var sawForeground = false;
    final fg = <String>{}; // su an on planda olan paketler
    int? activeSince; // en az bir uygulamanin on planda oldugu anin baslangici

    for (final e in sorted) {
      final type = e.eventType ?? '';
      final ts = int.parse(e.timeStamp!);
      final pkg = e.packageName ?? '?';
      final resumed = type == '1' || type.contains('RESUME');
      final paused = type == '2' || type.contains('PAUSE') ||
          type.contains('STOP');
      if (!resumed && !paused) continue;
      sawForeground = true;

      if (resumed) {
        if (fg.isEmpty) activeSince = ts;
        fg.add(pkg);
      } else {
        fg.remove(pkg);
        if (fg.isEmpty && activeSince != null) {
          totalMs += ts - activeSince;
          activeSince = null;
        }
      }
    }
    // Gun sonunda hala on planda (bugunun devam eden kullanimi).
    if (fg.isNotEmpty && activeSince != null) {
      totalMs += endMs - activeSince;
    }

    // Yedek: on plan olayi yoksa uygulama on plan surelerinin toplamini kullan.
    if (!sawForeground) {
      try {
        final infos = await UsageStats.queryUsageStats(start, end);
        var ms = 0;
        for (final u in infos) {
          ms += int.tryParse(u.totalTimeInForeground ?? '') ?? 0;
        }
        totalMs = ms;
      } catch (_) {
        return null;
      }
    }

    // Gunden uzun olamaz (cifte sayim korumasi).
    final maxMs = endMs - startMs;
    if (totalMs > maxMs) totalMs = maxMs;
    if (totalMs < 0) totalMs = 0;
    return (totalMs / 60000).round();
  }
}
