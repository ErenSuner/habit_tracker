import 'package:flutter/material.dart';

import '../config/category_colors.dart';
import '../models/metric.dart';
import '../services/data_service.dart';
import '../utils/friendly_error.dart';

// Bir metrik (takip kalemi) ekleme veya duzenleme ekrani.
//  - metric == null  -> yeni metrik ekleme
//  - metric != null  -> var olan metrigi duzenleme
class MetricEditScreen extends StatefulWidget {
  final Metric? metric;
  final int nextSortOrder; // yeni metrik icin siralama degeri

  const MetricEditScreen({super.key, this.metric, this.nextSortOrder = 0});

  @override
  State<MetricEditScreen> createState() => _MetricEditScreenState();
}

class _MetricEditScreenState extends State<MetricEditScreen> {
  final _data = DataService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _targetMinCtrl; // aralik: alt sinir

  String? _selectedCategory;
  List<String> _categories = [];

  late MetricType _type;
  late TargetDirection _direction;
  late bool _goodValue;
  late bool _boolHasValue;
  late double _weight;
  bool _saving = false;

  bool get _isEditing => widget.metric != null;

  // Sayisal deger istiyor mu? (numeric ya da "Evet'te sayi iste" boolean)
  bool get _wantsNumber =>
      _type == MetricType.numeric ||
      (_type == MetricType.boolean && _boolHasValue);

  @override
  void initState() {
    super.initState();
    final m = widget.metric;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _unitCtrl = TextEditingController(text: m?.unit ?? '');
    _targetCtrl = TextEditingController(
      text: m?.target != null ? _trimNum(m!.target!) : '',
    );
    _targetMinCtrl = TextEditingController(
      text: m?.targetMin != null ? _trimNum(m!.targetMin!) : '',
    );
    _selectedCategory = (m?.category?.trim().isEmpty ?? true) ? null : m!.category;
    _type = m?.type ?? MetricType.numeric;
    _direction = m?.targetDirection ?? TargetDirection.up;
    _goodValue = m?.goodValue ?? true;
    _boolHasValue = m?.boolHasValue ?? false;
    _weight = m?.weight ?? 1;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _data.fetchCategories();
      if (_selectedCategory != null && !list.contains(_selectedCategory)) {
        list.add(_selectedCategory!);
      }
      list.sort();
      if (mounted) setState(() => _categories = list);
    } catch (_) {
      if (mounted && _selectedCategory != null) {
        setState(() => _categories = [_selectedCategory!]);
      }
    }
  }

  Future<void> _newCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni kategori'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'örn. Sağlık, Zihin'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    final cap = _capitalize(name ?? '');
    if (cap.isEmpty) return;
    setState(() {
      if (!_categories.contains(cap)) _categories.add(cap);
      _categories.sort();
      _selectedCategory = cap;
    });
  }

  Future<void> _deleteCategory(String cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategoriyi sil'),
        content: Text(
          '"$cat" kategorisi tüm alışkanlıklardan kaldırılsın mı? '
          'Alışkanlıklar silinmez, yalnızca kategorisiz kalır.',
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
      await _data.deleteCategory(cat);
      if (mounted) {
        setState(() {
          _categories.remove(cat);
          if (_selectedCategory == cat) _selectedCategory = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinemedi: ${friendlyError(e)}')),
        );
      }
    }
  }

  String _capitalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _targetCtrl.dispose();
    _targetMinCtrl.dispose();
    super.dispose();
  }

  String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final metric = Metric(
      id: widget.metric?.id ?? '',
      name: _capitalize(_nameCtrl.text),
      type: _type,
      unit: _wantsNumber && _unitCtrl.text.trim().isNotEmpty
          ? _unitCtrl.text.trim()
          : null,
      target: _wantsNumber
          ? double.tryParse(_targetCtrl.text.replaceAll(',', '.'))
          : null,
      // Alt sinir yalnizca "aralik" yonunde anlamli.
      targetMin: _wantsNumber && _direction == TargetDirection.range
          ? double.tryParse(_targetMinCtrl.text.replaceAll(',', '.'))
          : null,
      targetDirection: _direction,
      weight: _weight,
      goodValue: _goodValue,
      boolHasValue: _type == MetricType.boolean && _boolHasValue,
      sortOrder: widget.metric?.sortOrder ?? widget.nextSortOrder,
      category: _selectedCategory,
    );

    try {
      if (_isEditing) {
        await _data.updateMetric(metric);
      } else {
        await _data.addMetric(metric);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: ${friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Alışkanlığı düzenle' : 'Yeni alışkanlık'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    // 1) Ad
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Ad',
                        hintText: 'örn. Su, Spor, Kitap',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ad boş olamaz'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // 2) Tür
                    _label('Nasıl takip edilsin?'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<MetricType>(
                      value: _type,
                      items: MetricType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(_typeLabel(t)),
                              ))
                          .toList(),
                      onChanged: (t) => setState(() => _type = t ?? _type),
                    ),
                    const SizedBox(height: 20),

                    // 3) Türe özel ayarlar
                    ..._typeSettings(context),

                    // 4) Kategori
                    _label('Kategori (isteğe bağlı)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cat in _categories) _categoryChip(cat),
                        _newCategoryChip(),
                      ],
                    ),
                    if (_categories.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _hint('Seçmek için dokun · silmek için basılı tut'),
                    ],
                    const SizedBox(height: 20),

                    // 5) Önem (agirlik) — metin disi tiplerde
                    if (_type != MetricType.text) ...[
                      _label('Önem: ${_weightLabel(_weight)}'),
                      Slider(
                        value: _weight,
                        min: 0,
                        max: 5,
                        divisions: 10,
                        label: _trimNum(_weight),
                        onChanged: (v) => setState(() => _weight = v),
                      ),
                      _hint('Verim puanına etkisi. 0 = puana katılmaz.'),
                    ],
                  ],
                ),
              ),
            ),
            // Sabit alt kaydet butonu
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isEditing ? 'Kaydet' : 'Ekle'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Türe özel ayar alanlari.
  List<Widget> _typeSettings(BuildContext context) {
    final widgets = <Widget>[];

    // Evet / Hayir ayarlari
    if (_type == MetricType.boolean) {
      widgets.addAll([
        _label('Hangi cevap iyi?'),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Evet iyi')),
            ButtonSegment(value: false, label: Text('Hayır iyi')),
          ],
          selected: {_goodValue},
          onSelectionChanged: (s) => setState(() => _goodValue = s.first),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sayı sor'),
          subtitle: const Text('örn. kaç dakika, kaç sayfa'),
          value: _boolHasValue,
          onChanged: (v) => setState(() => _boolHasValue = v),
        ),
        const SizedBox(height: 20),
      ]);
    }

    // Sayisal ayarlar (numeric ya da degerli boolean)
    if (_wantsNumber) {
      final isUp = _direction == TargetDirection.up;
      final isRange = _direction == TargetDirection.range;

      double? parseNum(String s) =>
          double.tryParse(s.trim().replaceAll(',', '.'));

      widgets.addAll([
        _label('Sayı nasıl değerlendirilsin?'),
        const SizedBox(height: 8),
        SegmentedButton<TargetDirection>(
          segments: const [
            ButtonSegment(
              value: TargetDirection.up,
              label: Text('Artış iyi'),
            ),
            ButtonSegment(
              value: TargetDirection.down,
              label: Text('Azalış iyi'),
            ),
            ButtonSegment(
              value: TargetDirection.range,
              label: Text('Aralık iyi'),
            ),
          ],
          selected: {_direction},
          onSelectionChanged: (s) => setState(() => _direction = s.first),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _unitCtrl,
          decoration: const InputDecoration(
            labelText: 'Birim (isteğe bağlı)',
            hintText: 'kcal, adım, dk...',
          ),
        ),
        const SizedBox(height: 16),
        if (isRange) ...[
          // Aralik: alt ve ust sinir yan yana, ikisi de zorunlu.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _targetMinCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Alt sınır',
                    hintText: 'örn. 7',
                  ),
                  validator: (v) {
                    if (_direction != TargetDirection.range) return null;
                    if (parseNum(v ?? '') == null) return 'Gerekli';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _targetCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Üst sınır',
                    hintText: 'örn. 9',
                  ),
                  validator: (v) {
                    if (_direction != TargetDirection.range) return null;
                    final hi = parseNum(v ?? '');
                    if (hi == null) return 'Gerekli';
                    final lo = parseNum(_targetMinCtrl.text);
                    if (lo != null && hi <= lo) return 'Alttan büyük olmalı';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _hint('Aralık içinde kalırsan verim tam; dışına çıktıkça düşer. '
              'Örn. uyku için 7–9 saat.'),
        ] else ...[
          TextFormField(
            controller: _targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: isUp
                  ? 'Günlük hedef (isteğe bağlı)'
                  : 'Günlük üst sınır (isteğe bağlı)',
              hintText: isUp ? 'ulaşmak istediğin' : 'aşmaman gereken',
            ),
          ),
          const SizedBox(height: 6),
          _hint(isUp
              ? 'Hedefe ulaştıkça verim artar.'
              : 'Üst sınırı aştıkça verim düşer (ceza).'),
        ],
        const SizedBox(height: 20),
      ]);
    }

    return widgets;
  }

  // --- Kucuk yardimci gorunumler ---

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      );

  Widget _hint(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  String _weightLabel(double w) {
    if (w == 0) return 'yok';
    if (w <= 1) return 'düşük';
    if (w <= 2) return 'normal';
    if (w <= 3.5) return 'yüksek';
    return 'çok yüksek';
  }

  String _typeLabel(MetricType t) => switch (t) {
        MetricType.numeric => 'Sayı (kalori, adım, sayfa...)',
        MetricType.boolean => 'Evet / Hayır',
        MetricType.tag => 'Etiket listesi',
        MetricType.text => 'Metin / Not',
      };

  Widget _categoryChip(String cat) {
    final color = categoryColor(cat);
    final selected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () =>
          setState(() => _selectedCategory = selected ? null : cat),
      onLongPress: () => _deleteCategory(cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 15, color: onCategoryColor(color)),
              const SizedBox(width: 5),
            ],
            Text(
              cat,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? onCategoryColor(color) : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newCategoryChip() {
    return GestureDetector(
      onTap: _newCategory,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              'Yeni',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
