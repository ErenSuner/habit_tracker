import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/data_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onSelect,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Geçmiş',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Grafikler',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
