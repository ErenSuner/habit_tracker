// Istatistik yardimcilari (streak vb.).
class StatsUtil {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // Bugun biten kesintisiz "basarili gun" serisi.
  // Bugun henuz islenmemisse seriyi dunden saymaya devam eder
  // (boylece "bugunu doldurmadim" seriyi kirmaz).
  static int streak(Set<DateTime> success, DateTime today) {
    final t = dateOnly(today);
    var d = t;
    if (!success.contains(d)) {
      d = d.subtract(const Duration(days: 1));
    }
    var s = 0;
    while (success.contains(d)) {
      s++;
      d = d.subtract(const Duration(days: 1));
    }
    return s;
  }

  // Yuzde basari orani (kayitli gunler icinde basarili olanlarin orani).
  static int rate(int success, int total) {
    if (total == 0) return 0;
    return ((success / total) * 100).round();
  }

  // Verilen basarili gunler icindeki TUM zamanlarin en uzun kesintisiz serisi.
  static int longestStreak(Set<DateTime> success) {
    if (success.isEmpty) return 0;
    final days = success.map(dateOnly).toSet();
    var best = 0;
    for (final d in days) {
      // Yalnizca bir serinin baslangic gununden say (onceki gun yoksa).
      if (days.contains(d.subtract(const Duration(days: 1)))) continue;
      var len = 1;
      var n = d.add(const Duration(days: 1));
      while (days.contains(n)) {
        len++;
        n = n.add(const Duration(days: 1));
      }
      if (len > best) best = len;
    }
    return best;
  }
}
