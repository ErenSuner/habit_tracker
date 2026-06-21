import 'package:flutter/material.dart';

import '../models/metric.dart';
import '../services/data_service.dart';

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
  late final TextEditingController _categoryCtrl;

  late MetricType _type;
  late TargetDirection _direction;
  late bool _goodValue;
  late bool _boolHasValue;
  late double _weight;
  bool _saving = false;

  bool get _isEditing => widget.metric != null;

  @override
  void initState() {
    super.initState();
    final m = widget.metric;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _unitCtrl = TextEditingController(text: m?.unit ?? '');
    _targetCtrl = TextEditingController(
      text: m?.target != null ? _trimNum(m!.target!) : '',
    );
    _categoryCtrl = TextEditingController(text: m?.category ?? '');
    _type = m?.type ?? MetricType.numeric;
    _direction = m?.targetDirection ?? TargetDirection.up;
    _goodValue = m?.goodValue ?? true;
    _boolHasValue = m?.boolHasValue ?? false;
    _weight = m?.weight ?? 1;
  }

  // "uyku" -> "Uyku" : ilk harfi buyut.
  String _capitalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  // Bu metrik sayisal deger istiyor mu? (numeric, ya da "Evet'te sayi iste"
  // secili boolean)
  bool get _wantsNumber =>
      _type == MetricType.numeric ||
      (_type == MetricType.boolean && _boolHasValue);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _targetCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  // 2.0 -> "2", 2.5 -> "2.5" gibi gosterim icin.
  String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final metric = Metric(
      // Yeni metrikte id veritabaninda olusur; bu deger toInsert'te yok sayilir.
      id: widget.metric?.id ?? '',
      name: _capitalize(_nameCtrl.text),
      type: _type,
      unit: _wantsNumber && _unitCtrl.text.trim().isNotEmpty
          ? _unitCtrl.text.trim()
          : null,
      target: _wantsNumber
          ? double.tryParse(_targetCtrl.text.replaceAll(',', '.'))
          : null,
      targetDirection: _direction,
      weight: _weight,
      goodValue: _goodValue,
      boolHasValue: _type == MetricType.boolean && _boolHasValue,
      sortOrder: widget.metric?.sortOrder ?? widget.nextSortOrder,
      category: _categoryCtrl.text.trim().isEmpty
          ? null
          : _capitalize(_categoryCtrl.text),
    );

    try {
      if (_isEditing) {
        await _data.updateMetric(metric);
      } else {
        await _data.addMetric(metric);
      }
      if (mounted) Navigator.pop(context, true); // true = degisiklik oldu
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e')),
        );
      }
    }
  }

  // Sayisal ayar alanlari (birim, hedef, yon). Hem numeric metrikte
  // hem de "Evet'te sayi iste" secili boolean metrikte gosterilir.
  List<Widget> _numericFields(BuildContext context) {
    return [
      TextFormField(
        controller: _unitCtrl,
        decoration: const InputDecoration(
          labelText: 'Birim (isteğe bağlı)',
          hintText: 'kcal, sayfa, dk, adım...',
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _targetCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Günlük hedef (isteğe bağlı)',
          hintText: 'örn. 2200',
        ),
      ),
      const SizedBox(height: 16),
      Text('Sayı artınca:', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<TargetDirection>(
        segments: const [
          ButtonSegment(
            value: TargetDirection.up,
            label: Text('İyileşir'),
            icon: Icon(Icons.trending_up),
          ),
          ButtonSegment(
            value: TargetDirection.down,
            label: Text('Kötüleşir'),
            icon: Icon(Icons.trending_down),
          ),
        ],
        selected: {_direction},
        onSelectionChanged: (s) => setState(() => _direction = s.first),
      ),
      const SizedBox(height: 8),
      Text(
        _direction == TargetDirection.up
            ? 'Sayı yükseldikçe daha iyi (örn. adım, su, uyku, okunan sayfa).'
            : 'Sayı yükseldikçe daha kötü (örn. mastürbasyon, sigara, '
                'kalori, ekran süresi).',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isBoolean = _type == MetricType.boolean;
    // Metin tipinin verim puanina katkisi yok; agirlik sadece digerlerinde.
    final showWeight = _type != MetricType.text;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Metriği düzenle' : 'Yeni metrik'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Ad',
                hintText: 'örn. Kalori, Spor yaptım, Okunan kitap',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ad boş olamaz' : null,
            ),
            const SizedBox(height: 16),

            // Kategori (gruplama icin, istege bagli)
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Kategori (isteğe bağlı)',
                hintText: 'örn. Sağlık, Zihin, Alışkanlık',
              ),
            ),
            const SizedBox(height: 16),

            // Tip secimi
            DropdownButtonFormField<MetricType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tip'),
              items: MetricType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (t) => setState(() => _type = t ?? _type),
            ),
            const SizedBox(height: 8),
            Text(
              _typeHelp(_type),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            // Evet/Hayir tipine ozel ayarlar
            if (isBoolean) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('"Evet" iyi mi?'),
                subtitle: Text(
                  _goodValue
                      ? 'Evet demek iyi (örn. Spor yaptım).'
                      : 'Hayır demek iyi (örn. Sigara içtim -> hayır iyi).',
                ),
                value: _goodValue,
                onChanged: (v) => setState(() => _goodValue = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('"Evet" seçilince sayı da iste'),
                subtitle: const Text(
                  'örn. "Spor yaptım" -> Evet ise kaç dakika? gibi.',
                ),
                value: _boolHasValue,
                onChanged: (v) => setState(() => _boolHasValue = v),
              ),
              const SizedBox(height: 8),
            ],

            // Sayisal ayarlar (numeric metrik ya da degerli boolean)
            if (_wantsNumber) ..._numericFields(context),

            // Agirlik (verim puanindaki onemi)
            if (showWeight) ...[
              Text(
                'Verimdeki ağırlığı: ${_trimNum(_weight)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Slider(
                value: _weight,
                min: 0,
                max: 5,
                divisions: 10,
                label: _trimNum(_weight),
                onChanged: (v) => setState(() => _weight = v),
              ),
              Text(
                'Yüksek ağırlık = bu metriğin günlük verim puanına etkisi büyük.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
            ],

            FilledButton.icon(
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
          ],
        ),
      ),
    );
  }

  String _typeHelp(MetricType t) => switch (t) {
        MetricType.numeric => 'Sayı girersin (kalori, adım, sayfa...).',
        MetricType.boolean => 'Evet / Hayır seçersin (spor yaptım mı?).',
        MetricType.tag =>
          'O gün için birden çok etiket eklersin (araştırılan konular...).',
        MetricType.text => 'Serbest not yazarsın (günün notu).',
      };
}
