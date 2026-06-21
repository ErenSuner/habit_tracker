import '../models/metric.dart';

// Yeni kullanicilara verilen notr/genel baslangic metrikleri.
// Hem kayit sonrasi otomatik seed (DataService.seedDefaultMetricsIfEmpty)
// hem de Metrikler ekranindaki "Ornek metrikleri ekle" butonu bunu kullanir.
// Her tipten (sayisal / evet-hayir / etiket / metin) ornek icerir; isimler
// _iconFor heuristigiyle otomatik uygun ikon alir.
const List<Metric> kDefaultMetrics = [
  Metric(
    id: '',
    name: 'Su',
    type: MetricType.numeric,
    unit: 'bardak',
    target: 8,
    targetDirection: TargetDirection.up,
    weight: 1,
    sortOrder: 0,
  ),
  Metric(
    id: '',
    name: 'Uyku',
    type: MetricType.numeric,
    unit: 'saat',
    target: 7,
    targetDirection: TargetDirection.up,
    weight: 1,
    sortOrder: 1,
  ),
  Metric(
    id: '',
    name: 'Egzersiz',
    type: MetricType.boolean,
    goodValue: true,
    weight: 2,
    sortOrder: 2,
  ),
  Metric(
    id: '',
    name: 'Meditasyon',
    type: MetricType.boolean,
    goodValue: true,
    weight: 1,
    sortOrder: 3,
  ),
  Metric(
    id: '',
    name: 'Okunan sayfa',
    type: MetricType.numeric,
    unit: 'sayfa',
    target: 10,
    targetDirection: TargetDirection.up,
    weight: 1,
    sortOrder: 4,
  ),
  Metric(
    id: '',
    name: 'Yeni öğrendiklerim',
    type: MetricType.tag,
    weight: 1,
    sortOrder: 5,
  ),
  Metric(
    id: '',
    name: 'Günün notu',
    type: MetricType.text,
    weight: 0,
    sortOrder: 6,
  ),
];
