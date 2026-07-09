import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../services/data_service.dart';
import '../services/net_status.dart';
import 'ai_screen.dart';
import 'charts_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

// Uygulamanin ana cercevesi: altta 5 sekmeli gezinme cubugu.
// Ana sayfa . Gecmis . Grafikler . AI . Ayarlar
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _data = DataService();

  // Sekmelere her donuste veriyi tazelemek icin anahtarlar.
  final _homeKey = GlobalKey<HomeScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();
  final _chartsKey = GlobalKey<ChartsScreenState>();
  final _aiKey = GlobalKey<AiScreenState>();

  // IndexedStack: sekmeler arasi gecince ekranin durumu korunur.
  late final List<Widget> _screens = [
    HomeScreen(key: _homeKey),
    HistoryScreen(key: _historyKey),
    ChartsScreen(key: _chartsKey),
    AiScreen(key: _aiKey),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _ensureDefaultMetrics();
  }

  // Yeni kullaniciya (hic metrigi yoksa) notr baslangic setini otomatik ekler,
  // sonra ana sayfayi tazeler. Mevcut kullanicilarda hicbir sey yapmaz.
  Future<void> _ensureDefaultMetrics() async {
    try {
      final added = await _data.seedDefaultMetricsIfEmpty();
      if (added && mounted) {
        _homeKey.currentState?.reload();
      }
    } catch (_) {
      // Seed kritik degil; basarisiz olursa kullanici elle ekleyebilir.
    }
  }

  void _onSelect(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
    // Ilgili sekmeye gecince guncel veriyi cek.
    switch (i) {
      case 0:
        _homeKey.currentState?.reload();
      case 1:
        _historyKey.currentState?.reload();
      case 2:
        _chartsKey.currentState?.reload();
      case 3:
        _aiKey.currentState?.reload();
    }
  }

  // Sekme tanimlari: (yuvarlatilmis ikon, etiket). Ikon hem secili hem
  // pasif durumda ayni; yalnizca renk degisir.
  static const _tabs = <(IconData, String)>[
    (Icons.home_rounded, 'Ana sayfa'),
    (Icons.calendar_today_rounded, 'Geçmiş'),
    (Icons.bar_chart_rounded, 'Grafikler'),
    (Icons.auto_awesome_rounded, 'AI'),
    (Icons.settings_rounded, 'Ayarlar'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      // Cevrimdisi cubugu (varsa) + alt gezinme cubugu birlikte, en altta.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: NetStatus.online,
            builder: (_, online, __) =>
                online ? const SizedBox.shrink() : const _OfflineBar(),
          ),
          _buildNavBar(),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBar,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++) _navItem(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final selected = _index == i;
    final (icon, label) = _tabs[i];
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color:
                    selected ? AppColors.purpleBright : AppColors.textSecondary,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.purpleBright
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Internet yokken gezinme cubugunun ustunde beliren ince bilgi seridi.
// Girisler yerelde tutulur; baglanti gelince otomatik gonderilir.
class _OfflineBar extends StatelessWidget {
  const _OfflineBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3E0),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.cloud_off_rounded,
                  size: 15, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Çevrimdışısın · girişlerin kaydedilip bağlantı gelince eşitlenecek',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
