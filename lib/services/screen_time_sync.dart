import 'data_service.dart';
import 'screen_time_service.dart';

// Telefondaki ekran suresi gecmisini bulutla esitleyen ortak mantik.
// Hem ana sayfadaki kart hem de arka plan gorevi (screen_time_worker)
// bunu kullanir; boylece kurallar tek yerde durur.
class ScreenTimeSync {
  // Son [lookbackDays] gunden buluta kaydi olmayan gunleri telefondan
  // okuyup kaydeder (Android olay gecmisi ~1 hafta tutuldugu icin 7 gun
  // geriye bakmak pencerenin tamamini kullanir). Bugun her cagrida
  // yeniden okunur cunku gun boyu degisir.
  //
  // Donus: (kayitli TUM gecmis, bugunun dakikasi). Ekran suresi
  // okunamazsa bugunun dakikasi null olur.
  static Future<(Map<DateTime, int>, int?)> backfill(
    DataService data, {
    int lookbackDays = 7,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Map<DateTime, int> history;
    try {
      history = await data.fetchScreenTimes(DateTime(2020, 1, 1), today);
    } catch (_) {
      history = {}; // cevrimdisi: telefondan okunanlar yine gosterilir
    }

    // Son [lookbackDays] gunu HER ZAMAN yeniden oku ve uzerine yaz. Boylece
    // eski/hatali yontemle yazilmis degerler (orn. sismis ekran suresi)
    // Android'in hala tuttugu olay gecmisiyle duzeltilir. Olay gecmisi
    // ~1 haftadan eski gunlere ulasamaz; oraya dokunmayiz.
    int? todayMin;
    for (var i = lookbackDays; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final min = await ScreenTimeService.minutesForDay(day);
      if (i == 0) todayMin = min;
      if (min == null) continue;
      // Gecmis gunde 0 dakika buyuk olasilikla "olay gecmisi silinmis"
      // demektir; sahte 0 ile gercek veriyi ezme.
      if (i != 0 && min == 0) continue;
      history[day] = min;
      try {
        await data.saveScreenTime(day, min);
      } catch (_) {}
    }
    return (history, todayMin);
  }
}
