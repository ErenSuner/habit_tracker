import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/data_service.dart';
import '../services/screen_time_service.dart';
import '../services/screen_time_sync.dart';

// Ana sayfa panosundaki "Ekran süresi" karti.
//  - Bugunun ekran suresini telefondan okur, Supabase'e kaydeder
//  - 7 / 30 / 60 gunluk ortalamalari gosterir (gecmis DB'de tutulur)
//  - Sureye gore esprili/kisa bir yorum cumlesi yazar
// Izin verilmemisse aciklama + "Izin ver" dugmesi gosterir.
class ScreenTimeCard extends StatefulWidget {
  const ScreenTimeCard({super.key});

  @override
  State<ScreenTimeCard> createState() => ScreenTimeCardState();
}

class ScreenTimeCardState extends State<ScreenTimeCard>
    with WidgetsBindingObserver {
  final _data = DataService();

  bool _loading = true;
  bool _hasPermission = false;
  int? _todayMinutes;
  Map<DateTime, int> _history = {};

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime get _today => _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    // Ayarlardan izin verip donunce otomatik yenilemek icin.
    WidgetsBinding.instance.addObserver(this);
    reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  Future<void> reload() async {
    final granted = await ScreenTimeService.hasPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _hasPermission = false;
        _loading = false;
      });
      return;
    }

    // Kayitli gecmisi cek, son 7 gunun eksiklerini telefondan tamamla.
    // (Ayni mantik arka plan gorevinde de calisir: screen_time_worker.)
    final (history, todayMin) = await ScreenTimeSync.backfill(_data);

    if (!mounted) return;
    setState(() {
      _hasPermission = true;
      _history = history;
      _todayMinutes = todayMin;
      _loading = false;
    });
  }

  // Son [days] gunun ortalamasi (verisi olan gunler uzerinden).
  // O pencerede hic veri yoksa null doner; kartta "-" gosterilir.
  int? _avg(int days) {
    final from = _today.subtract(Duration(days: days - 1));
    final vals = [
      for (final e in _history.entries)
        if (!_dateOnly(e.key).isBefore(from)) e.value,
    ];
    if (vals.isEmpty) return null;
    return (vals.reduce((a, b) => a + b) / vals.length).round();
  }

  // Genel ortalama: kayitli TUM gunler uzerinden.
  int? _avgAll() {
    if (_history.isEmpty) return null;
    return (_history.values.reduce((a, b) => a + b) / _history.length).round();
  }

  static String _fmtDur(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    if (h == 0) return '$m dk';
    if (m == 0) return '$h sa';
    return '$h sa $m dk';
  }

  // Sureye gore yorum cumlesi. Cok sayida saat araligi ve her aralikta
  // birden fazla cumle var; gun icinde sabit kalsin diye tarihle secilir.
  String _comment(int min) {
    final options = _commentOptions(min);
    return options[(_today.day + _today.month) % options.length];
  }

  List<String> _commentOptions(int min) {
    if (min < 30) {
      return [
        'Telefon bugün seni özlemiş olabilir. Harikasın!',
        'Neredeyse hiç bakmamışsın — gerçek dünya kazandı.',
        'Bu kadar az kullanım mı? Efsane bir gün.',
      ];
    }
    if (min < 60) {
      return [
        'Bir saatin altı — gayet kontrollü gidiyorsun.',
        'Kısa ve öz kullanmışsın, böyle devam.',
        'Telefon sadece bir araç olmuş bugün, güzel.',
      ];
    }
    if (min < 120) {
      return [
        '1-2 saat bandı: dengeli bir gün.',
        'Makul bir süre, ipler hâlâ sende.',
        'Ne az ne çok — tam kararında.',
      ];
    }
    if (min < 180) {
      return [
        '2 saati geçtin, farkında ol yeter.',
        'Ekran biraz ısınmaya başladı, sen de molaya ne dersin?',
        'Hâlâ makul sayılır ama gözünü üstünde tut.',
      ];
    }
    if (min < 240) {
      return [
        '3 saat oldu — bugün ekran seni de biraz kullanmış olabilir.',
        'Bir dizi bölümü değil, üç bölüm kadar süre geçti.',
        'Şöyle bir esneyip uzaklara bakma vakti.',
      ];
    }
    if (min < 300) {
      return [
        '4 saati aştın; parmakların maraton koşuyor.',
        'Ekran süresi yükseliyor — küçük bir yürüyüş iyi gelir.',
        'Bugün kaydırdığın mesafe kaç kilometre eder acaba?',
      ];
    }
    if (min < 360) {
      return [
        '5 saat üstü: telefonla ciddi bir ilişkiniz var.',
        'Bugünün neredeyse çeyreği ekranda geçmiş.',
        'Gözlerin bir teşekkürü hak ediyor, biraz dinlendir.',
      ];
    }
    if (min < 480) {
      return [
        '6 saati geçtin — bu bir yarı zamanlı iş sayılır.',
        'Ekran maratonundasın; bari ara sıra su iç.',
        'Telefon şarjı kadar kendi şarjını da düşün.',
      ];
    }
    if (min < 600) {
      return [
        '8 saat?! Telefonla mesaiye mi başladın?',
        'Bugün ekran tam bir tam gün mesai yaptı.',
        'Cidden uzun bir gün olmuş — yarın telafi günü olsun mu?',
      ];
    }
    return [
      '10 saatten fazla... Telefon artık uzvun sayılır.',
      'Bu sürede bir kitap biterdi — sadece söylüyorum.',
      'Rekor kitabına yaklaşıyorsun, ama bu iyi bir rekor değil.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: _loading
          ? const SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : (_hasPermission ? _content() : _permissionPrompt()),
    );
  }

  Widget _permissionPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleRow(null),
        const SizedBox(height: 8),
        const Text(
          'Günlük ekran süreni burada görmek için telefonun '
          '"Kullanım verisi erişimi" iznine ihtiyaç var.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: ScreenTimeService.requestPermission,
            icon: const Icon(Icons.lock_open, size: 18),
            label: const Text('İzin ver'),
          ),
        ),
      ],
    );
  }

  Widget _content() {
    final min = _todayMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleRow(min),
        if (min != null) ...[
          const SizedBox(height: 8),
          Text(
            _comment(min),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'Ekran süresi okunamadı.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _avgBox('Genel ort.', _avgAll()),
            const SizedBox(width: 10),
            _avgBox('Son 7 gün', _avg(7)),
            const SizedBox(width: 10),
            _avgBox('Son 30 gün', _avg(30)),
          ],
        ),
      ],
    );
  }

  Widget _titleRow(int? todayMin) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: AppColors.purple.withValues(alpha: 0.14),
          ),
          child: const Icon(Icons.phone_android,
              size: 20, color: AppColors.purpleBright),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Ekran süresi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        if (todayMin != null)
          Text(
            _fmtDur(todayMin),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.purpleBright,
            ),
          ),
      ],
    );
  }

  Widget _avgBox(String label, int? min) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 3),
            Text(
              min == null ? '-' : _fmtDur(min),
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
