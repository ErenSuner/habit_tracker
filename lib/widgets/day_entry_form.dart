import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../config/category_colors.dart';
import '../models/entry.dart';
import '../models/metric.dart';
import '../services/data_service.dart';
import '../services/score_service.dart';

// Belirli bir GUNUN metriklerini doldurup duzenledigimiz form.
// Hem "Bugun" sekmesi hem de "Gecmis" ekrani bunu kullanir (farkli tarihle).
// Her degisiklik aninda Supabase'e kaydedilir; verim puani onScoreChanged
// ile ust ekrana bildirilir.
class DayEntryForm extends StatefulWidget {
  final DateTime date;
  final ValueChanged<double>? onScoreChanged;
  // Kac metrik dolduruldu / toplam kac metrik (pano gostergesi icin).
  final void Function(int filled, int total)? onProgress;
  // Giris kartlarinin ustunde gosterilecek widget (ana sayfa panosu gibi).
  final Widget? header;

  const DayEntryForm({
    super.key,
    required this.date,
    this.onScoreChanged,
    this.onProgress,
    this.header,
  });

  @override
  State<DayEntryForm> createState() => DayEntryFormState();
}

class DayEntryFormState extends State<DayEntryForm> {
  final _data = DataService();

  DateTime get _date => widget.date;

  bool _loading = true;
  List<Metric> _metrics = [];

  final Map<String, Entry> _entries = {};
  final Map<String, List<String>> _tags = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, TextEditingController> _tagControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _tagControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Disaridan tazeleme.
  void reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final metrics = await _data.fetchMetrics(onlyActive: true);
      final entries = await _data.fetchEntries(_date);

      _entries.clear();
      for (final e in entries) {
        _entries[e.metricId] = e;
      }

      _tags.clear();
      for (final m in metrics.where((m) => m.type == MetricType.tag)) {
        _tags[m.id] = await _data.fetchTags(_date, m.id);
        _tagControllers.putIfAbsent(m.id, () => TextEditingController());
      }

      for (final m in metrics) {
        if (m.type == MetricType.numeric || m.type == MetricType.text) {
          final e = _entries[m.id];
          final text = m.type == MetricType.numeric
              ? (e?.numValue != null ? _trimNum(e!.numValue!) : '')
              : (e?.textValue ?? '');
          _controllers[m.id] = TextEditingController(text: text);
        } else if (m.type == MetricType.boolean && m.boolHasValue) {
          final e = _entries[m.id];
          _controllers[m.id] = TextEditingController(
            text: e?.numValue != null ? _trimNum(e!.numValue!) : '',
          );
        }
      }

      if (mounted) {
        setState(() => _metrics = metrics);
        _recalcScore();
      }
    } catch (e) {
      if (mounted) _snack('Yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _recalcScore() {
    final score = ScoreService.computeDay(
      metrics: _metrics,
      entries: _entries,
      tags: _tags,
    );
    widget.onScoreChanged?.call(score);
    widget.onProgress?.call(_filledCount(), _metrics.length);
    _data.saveDailyScore(_date, score).catchError((_) {});
  }

  // Bugun kac metrige deger girilmis?
  int _filledCount() {
    var n = 0;
    for (final m in _metrics) {
      switch (m.type) {
        case MetricType.numeric:
          if (_entries[m.id]?.numValue != null) n++;
        case MetricType.boolean:
          if (_entries[m.id]?.boolValue != null) n++;
        case MetricType.text:
          if ((_entries[m.id]?.textValue ?? '').trim().isNotEmpty) n++;
        case MetricType.tag:
          if ((_tags[m.id] ?? []).isNotEmpty) n++;
      }
    }
    return n;
  }

  // ---- Kaydetme yardimcilari ----

  Future<void> _saveNumeric(Metric m, String raw) async {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    _entries[m.id] = Entry(metricId: m.id, date: _date, numValue: value);
    if (mounted) setState(() {});
    _recalcScore();
    try {
      await _data.saveEntry(_entries[m.id]!);
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    }
  }

  Future<void> _saveText(Metric m, String raw) async {
    _entries[m.id] = Entry(
      metricId: m.id,
      date: _date,
      textValue: raw.trim().isEmpty ? null : raw.trim(),
    );
    if (mounted) setState(() {});
    _recalcScore();
    try {
      await _data.saveEntry(_entries[m.id]!);
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    }
  }

  // Boolean metrigi isaretler/kaldirir. value=null -> bos (cevapsiz).
  // Isaretliyken "iyi" sonuc (goodValue) saklanir; istege bagli sayi da tutulur.
  Future<void> _setBool(Metric m, bool? value, {double? num}) async {
    HapticFeedback.selectionClick();
    _entries[m.id] =
        Entry(metricId: m.id, date: _date, boolValue: value, numValue: num);
    if (mounted) setState(() {});
    _recalcScore();
    try {
      await _data.saveEntry(_entries[m.id]!);
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    }
  }

  Future<void> _addTag(Metric m, String tag) async {
    final t = tag.trim();
    if (t.isEmpty) return;
    final list = _tags[m.id] ?? [];
    if (list.contains(t)) return;
    HapticFeedback.selectionClick();
    _tags[m.id] = [...list, t];
    if (mounted) setState(() {});
    _recalcScore();
    try {
      await _data.addTag(_date, m.id, t);
    } catch (e) {
      _snack('Eklenemedi: $e');
    }
  }

  Future<void> _removeTag(Metric m, String tag) async {
    _tags[m.id] = (_tags[m.id] ?? []).where((x) => x != tag).toList();
    if (mounted) setState(() {});
    _recalcScore();
    try {
      await _data.removeTag(_date, m.id, tag);
    } catch (e) {
      _snack('Silinemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = <Widget>[
      if (widget.header != null) widget.header!,
      if (_metrics.isEmpty) _emptyState() else ..._buildGrouped(),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: items,
      ),
    );
  }

  // Metrikleri kategoriye gore gruplar; kategori varsa basliklar ekler.
  List<Widget> _buildGrouped() {
    final hasCategory =
        _metrics.any((m) => m.category != null && m.category!.isNotEmpty);
    if (!hasCategory) {
      return _metrics.map(_metricCard).toList();
    }
    final order = <String>[];
    final groups = <String, List<Metric>>{};
    for (final m in _metrics) {
      final key = (m.category != null && m.category!.isNotEmpty)
          ? m.category!
          : 'Diğer';
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(m);
    }
    // "Diğer" grubunu en sona al.
    if (order.remove('Diğer')) order.add('Diğer');

    final widgets = <Widget>[];
    for (final key in order) {
      final color = key == 'Diğer' ? kNoCategoryColor : categoryColor(key);
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              key,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
            ),
          ],
        ),
      ));
      widgets.addAll(groups[key]!.map(_metricCard));
    }
    return widgets;
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 56),
            const SizedBox(height: 16),
            Text('Henüz metrik yok',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Önce Ayarlar > Metrikleri yönet kısmından takip etmek '
              'istediğin kalemleri ekle.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---- Alışkanlık satırı (tasarım stili) ----

  // Veri girilmis mi (basarili olmasa bile)?
  bool _isFilled(Metric m) {
    switch (m.type) {
      case MetricType.boolean:
        return _entries[m.id]?.boolValue != null;
      case MetricType.numeric:
        return _entries[m.id]?.numValue != null;
      case MetricType.tag:
        return (_tags[m.id] ?? []).isNotEmpty;
      case MetricType.text:
        return (_entries[m.id]?.textValue ?? '').trim().isNotEmpty;
    }
  }

  Widget _metricCard(Metric m) {
    final filled = _isFilled(m);
    final isBool = m.type == MetricType.boolean;
    // Boolean'da tik = "Evet, yaptim" (boolValue==true) anlamina gelir;
    // verime etkisi goodValue'ya gore skor motorunda hesaplanir.
    final boolDone = isBool && _entries[m.id]?.boolValue == true;
    final highlight = isBool ? boolDone : filled;
    return GestureDetector(
      onTap: () => _onRowTap(m),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlight ? const Color(0xFF3A2E55) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            _iconBox(m, filled),
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
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _metaFor(m),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Tik isareti SADECE Evet/Hayir metriklerinde; digerlerinde
            // duzenleme oku (isaretleme mantigi yok).
            if (isBool)
              _checkCircle(boolDone)
            else
              const Icon(Icons.chevron_right,
                  size: 22, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(Metric m, bool filled) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: filled
            ? const LinearGradient(
                colors: [Color(0x337C3AED), Color(0x336366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: filled ? null : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: filled
              ? AppColors.purple.withValues(alpha: 0.27)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Icon(
        _iconFor(m),
        size: 22,
        color: filled ? AppColors.purpleBright : AppColors.textSecondary,
      ),
    );
  }

  Widget _checkCircle(bool on) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: on ? AppColors.gradient : null,
        border:
            on ? null : Border.all(color: const Color(0xFF3A3450), width: 2),
      ),
      child:
          on ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
    );
  }

  void _onRowTap(Metric m) {
    switch (m.type) {
      case MetricType.boolean:
        if (m.boolHasValue) {
          _editBoolValue(m);
        } else {
          // Tik = "Evet, yaptim" (true); tekrar dokununca isaret kalkar (null).
          final done = _entries[m.id]?.boolValue == true;
          _setBool(m, done ? null : true);
        }
      case MetricType.numeric:
        _editNumeric(m);
      case MetricType.text:
        _editText(m);
      case MetricType.tag:
        _editTags(m);
    }
  }

  // Sayisal metrik icin hedef/sinir etiketi (yon'e gore).
  String? _targetLabel(Metric m) {
    if (m.target == null) return null;
    final unit = m.unit != null ? ' ${m.unit}' : '';
    return m.targetDirection == TargetDirection.down
        ? 'Sınır ≤ ${_trimNum(m.target!)}$unit'
        : 'Hedef ≥ ${_trimNum(m.target!)}$unit';
  }

  // Satirin altindaki aciklama metni.
  String _metaFor(Metric m) {
    switch (m.type) {
      case MetricType.boolean:
        final done = _entries[m.id]?.boolValue == true;
        if (m.boolHasValue && done && _entries[m.id]?.numValue != null) {
          return '${_trimNum(_entries[m.id]!.numValue!)}'
              '${m.unit != null ? ' ${m.unit}' : ''}';
        }
        return done ? 'Yaptım' : 'Dokunarak işaretle';
      case MetricType.numeric:
        final v = _entries[m.id]?.numValue;
        final target = _targetLabel(m);
        if (v == null) return target ?? 'Değer girmek için dokun';
        final cur = '${_trimNum(v)}${m.unit != null ? ' ${m.unit}' : ''}';
        return target != null ? '$cur · $target' : cur;
      case MetricType.tag:
        final list = _tags[m.id] ?? [];
        return list.isEmpty ? 'Etiket eklemek için dokun' : list.join(', ');
      case MetricType.text:
        final t = (_entries[m.id]?.textValue ?? '').trim();
        return t.isEmpty ? 'Not eklemek için dokun' : t.replaceAll('\n', ' ');
    }
  }

  // Metrik adina/tipine gore uygun ikon sec.
  IconData _iconFor(Metric m) {
    final n = m.name.toLowerCase();
    final words = n.split(RegExp(r'\s+'));
    bool word(String w) => words.any((x) => x == w || x.startsWith(w));
    bool has(String k) => n.contains(k);

    if (word('su') || has('water')) return Icons.water_drop;
    if (has('kitap') || has('oku') || has('read') || has('sayfa')) {
      return Icons.menu_book;
    }
    if (has('spor') ||
        has('egzersiz') ||
        has('antren') ||
        has('gym') ||
        has('koş') ||
        has('yürü') ||
        has('fit')) {
      return Icons.fitness_center;
    }
    if (has('uyku') || has('uyu') || has('sleep') || has('yat')) {
      return Icons.bedtime;
    }
    if (has('medit') || has('nefes') || has('yoga') || has('huzur')) {
      return Icons.self_improvement;
    }
    if (has('kalori') ||
        has('yemek') ||
        has('beslen') ||
        has('diyet') ||
        has('öğün')) {
      return Icons.restaurant;
    }
    if (has('kod') || has('yazılım') || has('proje')) return Icons.code;
    if (has('ders') || has('çalış') || has('study') || has('öğren')) {
      return Icons.school;
    }
    if (has('günlük') || has('journal') || has('not') || has('yaz')) {
      return Icons.edit_note;
    }
    if (has('ekran') || has('telefon') || has('screen') || has('sosyal')) {
      return Icons.phone_iphone;
    }
    if (has('para') || has('bütçe') || has('tasarru') || has('harca')) {
      return Icons.savings;
    }
    if (has('sigara') || has('alkol') || has('içki')) return Icons.smoke_free;
    if (has('müzik') || has('gitar') || has('piyano')) return Icons.music_note;

    return switch (m.type) {
      MetricType.numeric => Icons.tag,
      MetricType.boolean => Icons.bolt,
      MetricType.tag => Icons.label,
      MetricType.text => Icons.sticky_note_2,
    };
  }

  // ---- Düzenleme alt sayfaları (bottom sheet) ----

  Future<void> _showSheet({
    required String title,
    required Widget child,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _editNumeric(Metric m) async {
    final ctrl = _controllers.putIfAbsent(m.id, () => TextEditingController());
    ctrl.text = _entries[m.id]?.numValue != null
        ? _trimNum(_entries[m.id]!.numValue!)
        : '';
    await _showSheet(
      title: m.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: m.unit,
              helperText: _targetLabel(m),
            ),
            onSubmitted: (_) {
              _saveNumeric(m, ctrl.text);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_entries[m.id]?.numValue != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _saveNumeric(m, '');
                      Navigator.of(context).pop();
                    },
                    child: const Text('Temizle'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    _saveNumeric(m, ctrl.text);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editText(Metric m) async {
    final ctrl = _controllers.putIfAbsent(m.id, () => TextEditingController());
    ctrl.text = _entries[m.id]?.textValue ?? '';
    await _showSheet(
      title: m.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Bir not yaz...'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              _saveText(m, ctrl.text);
              Navigator.of(context).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTags(Metric m) async {
    final ctrl =
        _tagControllers.putIfAbsent(m.id, () => TextEditingController());
    await _showSheet(
      title: m.name,
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          final list = _tags[m.id] ?? [];
          void add() {
            _addTag(m, ctrl.text);
            ctrl.clear();
            setSheet(() {});
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (list.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: list
                      .map((t) => InputChip(
                            label: Text(t),
                            onDeleted: () {
                              _removeTag(m, t);
                              setSheet(() {});
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Etiket ekle (örn. liberalizm)',
                        isDense: true,
                      ),
                      onSubmitted: (_) => add(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.purple),
                    onPressed: add,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // Sayi alanini delta kadar artirir/azaltir (0'in altina inmez).
  void _bump(TextEditingController ctrl, int delta) {
    final cur = double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 0;
    var next = cur + delta;
    if (next < 0) next = 0;
    ctrl.text = _trimNum(next);
    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
  }

  // boolHasValue olan boolean: hem isaret hem sayi girilir.
  Future<void> _editBoolValue(Metric m) async {
    final ctrl = _controllers.putIfAbsent(m.id, () => TextEditingController());
    var checked = _entries[m.id]?.boolValue == true;
    // Kayitli sayi varsa onu; yoksa isaretliyken 0 yerine 1 ile basla.
    ctrl.text = _entries[m.id]?.numValue != null
        ? _trimNum(_entries[m.id]!.numValue!)
        : (checked ? '1' : '');
    await _showSheet(
      title: m.name,
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bugün yaptım'),
                value: checked,
                onChanged: (v) => setSheet(() {
                  checked = v;
                  // Yeni isaretlendi ve alan bossa 1 ile basla.
                  if (v && ctrl.text.trim().isEmpty) ctrl.text = '1';
                }),
              ),
              if (checked) ...[
                const SizedBox(height: 8),
                // - [ sayi ] + adimlayici
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => setSheet(() => _bump(ctrl, -1)),
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          hintText: '1',
                          suffixText: m.unit,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => setSheet(() => _bump(ctrl, 1)),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  _setBool(
                    m,
                    checked ? true : null,
                    num: checked
                        ? double.tryParse(ctrl.text.trim().replaceAll(',', '.'))
                        : null,
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }
}
