import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';
import '../models/metric.dart';
import '../services/data_service.dart';
import '../services/stats_util.dart';
import '../widgets/day_entry_form.dart';
import '../widgets/profile_dialog.dart';

// "Ana sayfa": ustte pano (verim halkasi, streak'ler, gun ozeti, mini trend),
// altinda bugunun giris kartlari (DayEntryForm).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _data = DataService();
  final _formKey = GlobalKey<DayEntryFormState>();

  final DateTime _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  // Form'dan gelen canli degerler
  double _score = 0;
  int _filled = 0;
  int _total = 0;

  // Pano verileri
  List<_Streak> _streaks = [];
  int _weeklyPct = 0; // son 7 gun ortalama verim
  int _bestStreak = 0; // tum zamanlarin en uzun serisi
  int _totalDone = 0; // toplam tamamlanan (basarili) metrik-gun sayisi

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  void reload() {
    _formKey.currentState?.reload();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final from90 = _today.subtract(const Duration(days: 89));
      final metrics = await _data.fetchMetrics(onlyActive: true);
      final entries = await _data.fetchEntriesRange(from90, _today);
      final tagDays = await _data.fetchTagDays(from90, _today);
      final scores = await _data.fetchScores(
          _today.subtract(const Duration(days: 6)), _today);

      // Metrik bazinda gunluk degerler
      final numByMetric = <String, Map<DateTime, double>>{};
      for (final e in entries) {
        final d = _dateOnly(e.date);
        if (e.numValue != null) {
          (numByMetric[e.metricId] ??= {})[d] = e.numValue!;
        }
      }
      final scoreMap = {
        for (final s in scores.entries) _dateOnly(s.key): s.value,
      };

      // Boolean basari kumeleri
      final boolByMetric = <String, Map<DateTime, bool>>{};
      for (final e in entries) {
        if (e.boolValue != null) {
          (boolByMetric[e.metricId] ??= {})[_dateOnly(e.date)] = e.boolValue!;
        }
      }

      // "Aktif gunler": kullanicinin o gun en az bir veri girdigi gunler.
      // Boolean "Hayir iyi" metriklerde iyi gun (yapmadigin gun) kayit
      // birakmadigi icin seri/toplam hesabini bu havuzla sinirliyoruz;
      // boylece veri girilmeyen gunler sahte seri uretmez.
      final activeDays = <DateTime>{};
      for (final e in entries) {
        activeDays.add(_dateOnly(e.date));
      }
      for (final s in tagDays.values) {
        activeDays.addAll(s.map(_dateOnly));
      }

      final streaks = <_Streak>[];
      var bestStreak = 0;
      var totalDone = 0;
      for (final m in metrics) {
        Set<DateTime>? success;
        switch (m.type) {
          case MetricType.boolean:
            // Cevapsiz = "Hayir/yapmadim" (false) varsayilir (skor motoruyla
            // ayni kural); yalnizca aktif gunleri degerlendiririz.
            final vals = boolByMetric[m.id] ?? {};
            success = {
              for (final d in activeDays)
                if ((vals[d] ?? false) == m.goodValue) d,
            };
          case MetricType.tag:
            success = tagDays[m.id] ?? {};
          case MetricType.numeric:
            if (m.target != null && m.target! > 0) {
              final vals = numByMetric[m.id] ?? {};
              success = {
                for (final x in vals.entries)
                  if (_meets(m, x.value)) x.key,
              };
            }
          case MetricType.text:
            success = null;
        }
        if (success == null) continue;
        totalDone += success.length;
        final longest = StatsUtil.longestStreak(success);
        if (longest > bestStreak) bestStreak = longest;
        final s = StatsUtil.streak(success, _today);
        if (s > 0) streaks.add(_Streak(m.name, s));
      }
      streaks.sort((a, b) => b.days.compareTo(a.days));

      final trend = <double>[];
      for (var i = 6; i >= 0; i--) {
        final d = _today.subtract(Duration(days: i));
        trend.add(scoreMap[d] ?? 0);
      }
      final weeklyPct = trend.isEmpty
          ? 0
          : (trend.reduce((a, b) => a + b) / trend.length).round();

      if (mounted) {
        setState(() {
          _streaks = streaks.take(4).toList();
          _weeklyPct = weeklyPct;
          _bestStreak = bestStreak;
          _totalDone = totalDone;
        });
      }
    } catch (_) {
      // Pano kritik degil; sessizce gec.
    }
  }

  bool _meets(Metric m, double v) =>
      m.targetDirection == TargetDirection.up ? v >= m.target! : v <= m.target!;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM EEEE', 'tr_TR').format(_today);
    final name = _displayName();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dateLabel,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              name.isEmpty ? _greeting() : '${_greeting()}, $name',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: _openProfile,
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppColors.gradient,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.13)),
                ),
                child: Text(
                  name.isEmpty ? 'A' : name[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: DayEntryForm(
        key: _formKey,
        date: _today,
        header: _dashboard(),
        onScoreChanged: (s) => setState(() => _score = s),
        onProgress: (f, t) => setState(() {
          _filled = f;
          _total = t;
        }),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  String _displayName() => _data.effectiveDisplayName;

  // Sag ust profil simgesine basinca acilan kucuk profil penceresi.
  Future<void> _openProfile() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ProfileDialog(
        initialName: _displayName(),
        email: _data.currentUser?.email ?? '',
      ),
    );
    // Isim degistiyse selamlamayi tazele.
    if (changed == true && mounted) setState(() {});
  }

  Widget _dashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _heroCard(),
        const SizedBox(height: 14),
        _statTiles(),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'Bugünün Alışkanlıkları',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Üstteki büyük kart: solda verim halkası, sağda özet + seri rozeti.
  Widget _heroCard() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Yumuşak mor ışıltı (kartın arkasında)
        Positioned(
          top: 6,
          left: 40,
          right: 40,
          child: IgnorePointer(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(80),
                gradient: RadialGradient(
                  colors: [
                    AppColors.purple.withValues(alpha: 0.32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B1430), Color(0xFF15121E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2E2740)),
          ),
          child: Row(
            children: [
              _ring(),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Harika gidiyorsun',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      _total == 0
                          ? 'Henüz metrik yok'
                          : '$_filled / $_total alışkanlık',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3),
                    ),
                    if (_streaks.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _streakBadge(_streaks.first),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _streakBadge(_Streak s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 6),
          Text('${s.days} günlük seri',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statTiles() {
    return Row(
      children: [
        Expanded(child: _statTile('$_weeklyPct%', 'Haftalık')),
        const SizedBox(width: 12),
        Expanded(child: _statTile('$_bestStreak', 'En iyi seri')),
        const SizedBox(width: 12),
        Expanded(child: _statTile('$_totalDone', 'Toplam')),
      ],
    );
  }

  Widget _statTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF272231)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _ring() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _score),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(104, 104),
                painter: _RingPainter((value / 100).clamp(0, 1).toDouble()),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${value.round()}%',
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.0)),
                  const SizedBox(height: 2),
                  const Text('bugün',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Streak {
  final String name;
  final int days;
  const _Streak(this.name, this.days);
}

// Mor gradyanli, yuvarlatilmis uclu verim halkasi cizici.
class _RingPainter extends CustomPainter {
  final double value; // 0..1
  _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = AppColors.surfaceHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (value <= 0) return;
    final shader = const SweepGradient(
      colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFB39DFF)],
      startAngle: 0,
      endAngle: 2 * math.pi,
      transform: GradientRotation(-math.pi / 2),
    ).createShader(rect);
    final arc = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
