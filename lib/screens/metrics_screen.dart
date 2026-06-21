import 'package:flutter/material.dart';

import '../config/default_metrics.dart';
import '../models/metric.dart';
import '../services/data_service.dart';
import 'metric_edit_screen.dart';

// Takip kalemlerinin (metrik) listesi. Ekle / duzenle / sil yapilir.
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  final _data = DataService();
  List<Metric> _metrics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _data.fetchMetrics(onlyActive: false);
      if (mounted) setState(() => _metrics = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yüklenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({Metric? metric}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MetricEditScreen(
          metric: metric,
          nextSortOrder: _metrics.length,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Metric m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Metriği sil'),
        content: Text(
          '"${m.name}" silinsin mi? Bu metriğe ait tüm günlük kayıtlar da '
          'silinir. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _data.deleteMetric(m.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinemedi: $e')),
        );
      }
    }
  }

  // Ilk kullanim icin birkac ornek metrik ekler.
  Future<void> _seedDefaults() async {
    try {
      for (final m in kDefaultMetrics) {
        await _data.addMetric(m);
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eklenemedi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metrikleri yönet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Metrik ekle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _metrics.isEmpty
              ? _EmptyState(onSeed: _seedDefaults, onAdd: () => _openEditor())
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 88),
                  itemCount: _metrics.length,
                  buildDefaultDragHandles: false,
                  onReorder: _onReorder,
                  itemBuilder: (_, i) {
                    final m = _metrics[i];
                    return ListTile(
                      key: ValueKey(m.id),
                      leading: Icon(_iconForType(m.type)),
                      title: Text(m.name),
                      subtitle: Text(_subtitle(m)),
                      onTap: () => _openEditor(metric: m),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(m),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4, right: 4),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  // Suruklemeyle yeni sirayi kaydeder.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final m = _metrics.removeAt(oldIndex);
      _metrics.insert(newIndex, m);
    });
    for (var i = 0; i < _metrics.length; i++) {
      try {
        await _data.updateSortOrder(_metrics[i].id, i);
      } catch (_) {}
    }
  }

  String _subtitle(Metric m) {
    final parts = <String>[];
    if (m.category != null && m.category!.isNotEmpty) parts.add(m.category!);
    parts.add(m.type.label);
    if (m.type == MetricType.numeric && m.target != null) {
      final dir = m.targetDirection == TargetDirection.down ? '≤' : '≥';
      parts.add('hedef $dir ${m.target!.toInt()}${m.unit != null ? ' ${m.unit}' : ''}');
    }
    if (m.type != MetricType.text) parts.add('ağırlık ${m.weight}');
    return parts.join(' · ');
  }

  IconData _iconForType(MetricType t) => switch (t) {
        MetricType.numeric => Icons.numbers,
        MetricType.boolean => Icons.toggle_on_outlined,
        MetricType.tag => Icons.label_outline,
        MetricType.text => Icons.notes,
      };
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSeed;
  final VoidCallback onAdd;
  const _EmptyState({required this.onSeed, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 56),
            const SizedBox(height: 16),
            Text(
              'Henüz metrik yok',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Takip etmek istediğin kalemleri ekle. Hızlı başlamak için '
              'hazır örnekleri de ekleyebilirsin.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onSeed,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Örnek metrikleri ekle'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Kendim ekleyeyim'),
            ),
          ],
        ),
      ),
    );
  }
}
