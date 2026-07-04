import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/metric.dart';
import '../services/data_service.dart';
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

  static const String _verimKey = '__verim__';
  static const int _maxDays = 90; // her zaman son 90 gunu cek; kartlar suzer

  bool _loading = true;

  Map<DateTime, double> _scores = {};
  List<Metric> _metrics = [];
  final Map<String, Map<DateTime, double>> _numericSeries = {};
  final Map<String, Map<DateTime, bool>> _boolValues = {};
  Map<String, Set<DateTime>> _tagDays = {};
  // Kullanicinin en az bir veri girdigi gunler (boolean "Hayir iyi"
  // metriklerin istatistigini dogru hesaplamak icin).
  Set<DateTime> _activeDays = {};

  final Set<String> _selected = {_verimKey};

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

      _numericSeries.clear();
      _boolValues.clear();
      final activeDays = <DateTime>{};
      for (final e in entries) {
        final d = _dateOnly(e.date);
        activeDays.add(d);
        if (e.numValue != null) {
          (_numericSeries[e.metricId] ??= {})[d] = e.numValue!;
        }
        if (e.boolValue != null) {
          (_boolValues[e.metricId] ??= {})[d] = e.boolValue!;
        }
      }
      for (final s in tagDays.values) {
        activeDays.addAll(s.map(_dateOnly));
      }

      if (mounted) {
        setState(() {
          _scores = {
            for (final e in scores.entries) _dateOnly(e.key): e.value,
          };
          _metrics =
              metrics.where((m) => m.type != MetricType.text).toList();
          _tagDays = tagDays;
          _activeDays = activeDays;
        });
      }
    } catch (e) {
      if (mounted) {
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
                children: [
                  _selector(),
                  const SizedBox(height: 16),
                  ..._selectedCards(),
                ],
              ),
            ),
    );
  }

  Widget _selector() {
    final chips = <Widget>[
      FilterChip(
        label: const Text('Genel verim'),
        selected: _selected.contains(_verimKey),
        onSelected: (s) {
          HapticFeedback.selectionClick();
          setState(() {
            s ? _selected.add(_verimKey) : _selected.remove(_verimKey);
          });
        },
      ),
      ..._metrics.map((m) => FilterChip(
            label: Text(m.name),
            selected: _selected.contains(m.id),
            onSelected: (s) {
              HapticFeedback.selectionClick();
              setState(() {
                s ? _selected.add(m.id) : _selected.remove(m.id);
              });
            },
          )),
    ];
    return Wrap(spacing: 8, runSpacing: 4, children: chips);
  }

  List<Widget> _selectedCards() {
    if (_selected.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Center(
            child: Text(
              'İstatistiğini görmek istediğin metrikleri yukarıdan seç.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ];
    }

    final cards = <Widget>[];
    if (_selected.contains(_verimKey)) {
      cards.add(VerimStatCard(scores: _scores, today: _today));
    }

    for (final m in _metrics) {
      if (!_selected.contains(m.id)) continue;
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
            activeDays: _activeDays,
            today: _today,
          ));
        case MetricType.tag:
          cards.add(TagStatCard(
            metric: m,
            tagDays: _tagDays[m.id] ?? {},
            today: _today,
          ));
        case MetricType.text:
          break;
      }
    }
    return cards;
  }
}
