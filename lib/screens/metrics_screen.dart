import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../config/category_colors.dart';
import '../config/default_metrics.dart';
import '../models/metric.dart';
import '../services/data_service.dart';
import '../utils/friendly_error.dart';
import 'metric_edit_screen.dart';

// Takip kalemlerinin (metrik) listesi. Ekle / duzenle / sil / sirala.
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
          SnackBar(content: Text('Yüklenemedi: ${friendlyError(e)}')),
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
          SnackBar(content: Text('Silinemedi: ${friendlyError(e)}')),
        );
      }
    }
  }

  // Ilk kullanim icin notr ornek metrikleri ekler.
  Future<void> _seedDefaults() async {
    try {
      for (final m in kDefaultMetrics) {
        await _data.addMetric(m);
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eklenemedi: ${friendlyError(e)}')),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _metrics.length,
                  buildDefaultDragHandles: false,
                  onReorder: _onReorder,
                  proxyDecorator: (child, index, animation) => Material(
                    color: Colors.transparent,
                    child: child,
                  ),
                  itemBuilder: (_, i) => _metricCard(_metrics[i], i),
                ),
    );
  }

  Widget _metricCard(Metric m, int index) {
    return Padding(
      key: ValueKey(m.id),
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openEditor(metric: m),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _iconBox(m),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _subtitle(m),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.textSecondary),
                  onPressed: () => _delete(m),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drag_handle,
                        color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBox(Metric m) {
    final hasCat = m.category != null && m.category!.trim().isNotEmpty;
    final bg = hasCat ? categoryColor(m.category) : AppColors.purple;
    final fg = hasCat ? categoryColor(m.category) : AppColors.purpleBright;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: bg.withValues(alpha: 0.16),
      ),
      child: Icon(_iconForType(m.type), size: 21, color: fg),
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
      parts.add(
          'hedef $dir ${m.target!.toInt()}${m.unit != null ? ' ${m.unit}' : ''}');
    }
    if (m.type != MetricType.text) parts.add('ağırlık ${m.weight}');
    return parts.join(' · ');
  }

  IconData _iconForType(MetricType t) => switch (t) {
        MetricType.numeric => Icons.tag,
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
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.gradient,
              ),
              child: const Icon(Icons.tune, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(
              'Henüz metrik yok',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Takip etmek istediğin kalemleri ekle. Hızlı başlamak için '
              'hazır örnekleri de ekleyebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
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
