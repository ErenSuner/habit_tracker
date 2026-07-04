// Bir takip kaleminin TANIMI. (Veritabanindaki "metrics" tablosuyla eslesir.)
//
// Ornekler:
//   Metric(name: 'Kalori', type: numeric, unit: 'kcal', target: 2200, targetDirection: down)
//   Metric(name: 'Spor yaptim', type: boolean, goodValue: true)
//   Metric(name: 'Arastirilan konular', type: tag)

// Metrik tipleri.
enum MetricType { numeric, boolean, tag, text }

extension MetricTypeX on MetricType {
  // Veritabaninda metin olarak saklariz.
  String get dbValue => switch (this) {
        MetricType.numeric => 'numeric',
        MetricType.boolean => 'boolean',
        MetricType.tag => 'tag',
        MetricType.text => 'text',
      };

  // Kullaniciya gosterilecek Turkce etiket.
  String get label => switch (this) {
        MetricType.numeric => 'Sayısal',
        MetricType.boolean => 'Evet / Hayır',
        MetricType.tag => 'Etiket listesi',
        MetricType.text => 'Metin / Not',
      };

  static MetricType fromDb(String value) => switch (value) {
        'numeric' => MetricType.numeric,
        'boolean' => MetricType.boolean,
        'tag' => MetricType.tag,
        'text' => MetricType.text,
        _ => MetricType.text,
      };
}

// Hedef yonu: hedefe gore "cok mu iyi, az mi iyi, yoksa aralikta mi iyi?"
//   up    -> sayi arttikca iyi (adim, sayfa)
//   down  -> sayi arttikca kotu (kalori, sigara)
//   range -> belirli araliktaki deger iyi (orn. uyku 7-9 saat);
//            aralikta target = ust sinir, targetMin = alt sinir.
enum TargetDirection { up, down, range }

class Metric {
  final String id;
  final String name;
  final MetricType type;
  final String? unit;
  final double? target;
  final double? targetMin; // yalnizca range yonunde kullanilir (alt sinir)
  final TargetDirection targetDirection;
  final double weight;
  final bool goodValue; // boolean tipte hangi cevap "iyi" sayilir
  final bool boolHasValue; // boolean tipte "Evet" secilince sayi da istenir mi
  final bool active;
  final int sortOrder;
  final String? icon;
  final String? category; // gruplama icin (orn. Saglik, Zihin)

  const Metric({
    required this.id,
    required this.name,
    required this.type,
    this.unit,
    this.target,
    this.targetMin,
    this.targetDirection = TargetDirection.up,
    this.weight = 1,
    this.goodValue = true,
    this.boolHasValue = false,
    this.active = true,
    this.sortOrder = 0,
    this.icon,
    this.category,
  });

  // Supabase'den gelen JSON satirini Metric nesnesine cevirir.
  factory Metric.fromJson(Map<String, dynamic> json) {
    return Metric(
      id: json['id'] as String,
      name: json['name'] as String,
      type: MetricTypeX.fromDb(json['type'] as String),
      unit: json['unit'] as String?,
      target: (json['target'] as num?)?.toDouble(),
      targetMin: (json['target_min'] as num?)?.toDouble(),
      targetDirection: switch (json['target_direction'] as String?) {
        'down' => TargetDirection.down,
        'range' => TargetDirection.range,
        _ => TargetDirection.up,
      },
      weight: (json['weight'] as num?)?.toDouble() ?? 1,
      goodValue: json['good_value'] as bool? ?? true,
      boolHasValue: json['bool_has_value'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      icon: json['icon'] as String?,
      category: json['category'] as String?,
    );
  }

  // Metric nesnesini Supabase'e yazmak icin JSON'a cevirir.
  // (id ve user_id'yi servis katmani ekler.)
  Map<String, dynamic> toInsert() {
    return {
      'name': name,
      'type': type.dbValue,
      'unit': unit,
      'target': target,
      'target_min': targetMin,
      'target_direction': switch (targetDirection) {
        TargetDirection.down => 'down',
        TargetDirection.range => 'range',
        TargetDirection.up => 'up',
      },
      'weight': weight,
      'good_value': goodValue,
      'bool_has_value': boolHasValue,
      'active': active,
      'sort_order': sortOrder,
      'icon': icon,
      'category': category,
    };
  }

  Metric copyWith({int? sortOrder}) => Metric(
        id: id,
        name: name,
        type: type,
        unit: unit,
        target: target,
        targetMin: targetMin,
        targetDirection: targetDirection,
        weight: weight,
        goodValue: goodValue,
        boolHasValue: boolHasValue,
        active: active,
        sortOrder: sortOrder ?? this.sortOrder,
        icon: icon,
        category: category,
      );
}
