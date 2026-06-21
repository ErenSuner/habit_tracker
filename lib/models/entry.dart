// Belirli bir metrigin belirli bir GUNDEKI degeri.
// (Veritabanindaki "entries" tablosuyla eslesir: numeric/boolean/text tipleri icin.)
//
// Etiket (tag) tipli metrikler ayri "entry_tags" tablosunda tutulur;
// onlari asagidaki DayTags modeliyle temsil ediyoruz.

class Entry {
  final String? id;
  final String metricId;
  final DateTime date;
  final double? numValue;
  final bool? boolValue;
  final String? textValue;

  const Entry({
    this.id,
    required this.metricId,
    required this.date,
    this.numValue,
    this.boolValue,
    this.textValue,
  });

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String?,
      metricId: json['metric_id'] as String,
      date: DateTime.parse(json['entry_date'] as String),
      numValue: (json['num_value'] as num?)?.toDouble(),
      boolValue: json['bool_value'] as bool?,
      textValue: json['text_value'] as String?,
    );
  }

  // Var olan bir kaydin uzerine yazmak / yeni kayit eklemek icin (upsert).
  Map<String, dynamic> toUpsert() {
    // entry_date'i 'YYYY-MM-DD' formatinda gondeririz.
    final d = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return {
      'metric_id': metricId,
      'entry_date': d,
      'num_value': numValue,
      'bool_value': boolValue,
      'text_value': textValue,
    };
  }

  Entry copyWith({double? numValue, bool? boolValue, String? textValue}) {
    return Entry(
      id: id,
      metricId: metricId,
      date: date,
      numValue: numValue ?? this.numValue,
      boolValue: boolValue ?? this.boolValue,
      textValue: textValue ?? this.textValue,
    );
  }
}

// Bir metrigin bir gundeki etiketleri (tag tipli metrikler icin).
class DayTags {
  final String metricId;
  final DateTime date;
  final List<String> tags;

  const DayTags({
    required this.metricId,
    required this.date,
    required this.tags,
  });
}
