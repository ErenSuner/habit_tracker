import 'package:flutter/material.dart';

import '../models/metric.dart';
import '../services/data_service.dart';
import '../services/net_status.dart';
import '../utils/friendly_error.dart';
import '../widgets/metric_stat_cards.dart';

// "Grafikler" sekmesi: ustte metrik secimi, altta secilen metriklerin
// istatistikleri. Her kartin kendi "Son N gun" secimi vardir.
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => ChartsScreenState();
}

class ChartsScreenState extends State<ChartsScreen> {
  final _data = DataService();

  static const int _maxDays = 90; // her zaman son 90 gunu cek; kartlar suzer

  bool _loading = true;

  Map<DateTime, double> _scores = {};
  List<Metric> _metrics = [];
  final Map<String, Map<DateTime, double>> _numericSeries = {};
  final Map<String, Map<DateTime, bool>> _boolValues = {};
  Map<String, Set<DateTime>> _tagDays = {};
  Map<DateTime, int> _screenTimes = {};

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime get _today => _dateOnly(DateTime.now());
  DateTime get _from => _today.subtract(const Duration(days: _maxDays - 1));

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final scores = await _data.fetchScores(_from, _today);
      final metrics = await _data.fetchMetrics(onlyActive: true);
      final entries = await _data.fetchEntriesRange(_from, _today);
      final tagDays = await _data.fetchTagDays(_from, _today);
      final screenTimes = await _data.fetchScreenTimes(_from, _today);

      _numericSeries.clear();
      _boolValues.clear();
      for (final e in entries) {
        final d = _dateOnly(e.date);
        if (e.numValue != null) {
          (_numericSeries[e.metricId] ??= {})[d] = e.numValue!;
        }
        if (e.boolValue != null) {
          (_boolValues[e.metricId] ??= {})[d] = e.boolValue!;
        }
      }
      if (mounted) {
        setState(() {
          _scores = {
            for (final e in scores.entries) _dateOnly(e.key): e.value,
          };
          _metrics =
              metrics.where((m) => m.type != MetricType.text).toList();
          _tagDays = tagDays;
          _screenTimes = {
            for (final e in screenTimes.entries) _dateOnly(e.key): e.value,
          };
        });
      }
    } catch (e) {
      // Cevrimdisi hatayi bastir: ust cubuk zaten durumu bildiriyor.
      if (mounted && NetStatus.online.value) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
                SnackBar(content: Text('Yüklenemedi: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grafikler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _allCards(),
              ),
            ),
    );
  }

  // Tum grafikler her zaman gosterilir (secim yok). Ekran suresi en ustte,
  // sonra genel verim, sonra her metrigin karti.
  List<Widget> _allCards() {
    final cards = <Widget>[
      ScreenTimeChartCard(minutes: _screenTimes, today: _today),
      VerimStatCard(scores: _scores, today: _today),
    ];

    for (final m in _metrics) {
      switch (m.type) {
        case MetricType.numeric:
          cards.add(NumericStatCard(
            metric: m,
            series: _numericSeries[m.id] ?? {},
            today: _today,
          ));
        case MetricType.boolean:
          cards.add(BooleanStatCard(
            metric: m,
            values: _boolValues[m.id] ?? {},
            numSeries: _numericSeries[m.id] ?? {},
            today: _today,
          ));
        case MetricType.tag:
          cards.add(TagStatCard(
            metric: m,
            tagDays: _tagDays[m.id] ?? {},
            today: _today,
            // Takvimde gune dokununca o gunun etiketleri gosterilir.
            loadTags: (d) => _data.fetchTags(d, m.id),
          ));
        case MetricType.text:
          break;
      }
    }
    return cards;
  }
}
