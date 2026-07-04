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
  // UsageEvents.Event sabitleri (int degerlerin metin hali).
  static const _screenOn = '15'; // SCREEN_INTERACTIVE
  static const _screenOff = '16'; // SCREEN_NON_INTERACTIVE

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
  // Yontem: ekranin acik/kapali oldugu anlar (SCREEN_INTERACTIVE /
  // SCREEN_NON_INTERACTIVE olaylari) eslestirilerek acik gecen sure
  // toplanir. Bu, "Dijital Denge"nin gosterdigi ekran suresine en yakin
  // olcumdur. Bu olaylari vermeyen cihazlarda uygulama bazli on plan
  // surelerinin toplamina dusulur (yaklasik deger).
  static Future<int?> minutesForDay(DateTime day) async {
    if (!Platform.isAndroid) return null;

    final start = DateTime(day.year, day.month, day.day);
    var end = start.add(const Duration(days: 1));
    final now = DateTime.now();
    if (end.isAfter(now)) end = now;
    if (!end.isAfter(start)) return null;

    List<EventUsageInfo> events;
    try {
      events = await UsageStats.queryEvents(start, end);
    } catch (_) {
      return null;
    }

    var totalMs = 0;
    int? onSince; // ekranin acildigi an (epoch ms)
    var sawScreenEvents = false;
    var isFirstScreenEvent = true;

    for (final e in events) {
      final type = e.eventType;
      if (type != _screenOn && type != _screenOff) continue;
      final ts = int.tryParse(e.timeStamp ?? '');
      if (ts == null) continue;
      sawScreenEvents = true;

      if (type == _screenOn) {
        onSince ??= ts;
      } else {
        if (onSince != null) {
          totalMs += ts - onSince;
          onSince = null;
        } else if (isFirstScreenEvent) {
          // Gun, ekran acikken baslamis: gun basindan ilk kapanisa kadar say.
          totalMs += ts - start.millisecondsSinceEpoch;
        }
      }
      isFirstScreenEvent = false;
    }
    // Su an hala acik (bugunun devam eden kullanimi).
    if (onSince != null) {
      totalMs += end.millisecondsSinceEpoch - onSince;
    }

    // Yedek yontem: ekran olaylari yoksa uygulama on plan surelerini topla.
    if (!sawScreenEvents) {
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
    final maxMs = end.difference(start).inMilliseconds;
    if (totalMs > maxMs) totalMs = maxMs;
    return (totalMs / 60000).round();
  }
}
