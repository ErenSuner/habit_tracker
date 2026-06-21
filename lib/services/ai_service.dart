import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_proposal.dart';
import '../models/entry.dart';
import '../models/metric.dart';
import 'data_service.dart';

// AI sohbet sekmesinin beyni:
//  - Kullanici mesajini + metrik listesini Edge Function'a (ai-fill) gonderir
//  - Donen yapilandirilmis onerileri (AiProposal) verir
//  - Onaylanan girisleri buluta kaydeder
class AiService {
  final SupabaseClient _client = Supabase.instance.client;
  final DataService _data = DataService();

  // Mesaji AI'ya gonderip oneri alir.
  Future<AiProposal> ask(
    String message,
    List<Metric> metrics, {
    List<Map<String, String>> history = const [],
  }) async {
    final res = await _client.functions.invoke(
      'ai-fill',
      body: {
        'message': message,
        'history': history,
        'metrics': metrics
            .map((m) => {
                  'id': m.id,
                  'name': m.name,
                  'type': m.type.dbValue,
                  'unit': m.unit,
                  'target': m.target,
                  'good_value': m.goodValue,
                  'bool_has_value': m.boolHasValue,
                })
            .toList(),
      },
    );

    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return AiProposal.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // Onaylanan onerileri belirtilen gune kaydeder.
  Future<void> apply(List<ProposedEntry> entries, DateTime date) async {
    for (final e in entries) {
      switch (e.type) {
        case MetricType.numeric:
          await _data.saveEntry(
            Entry(metricId: e.metricId, date: date, numValue: e.numValue),
          );
        case MetricType.boolean:
          // Evet/Hayir + (varsa) sayisal degeri birlikte kaydet.
          await _data.saveEntry(
            Entry(
              metricId: e.metricId,
              date: date,
              boolValue: e.boolValue,
              numValue: e.numValue,
            ),
          );
        case MetricType.text:
          await _data.saveEntry(
            Entry(metricId: e.metricId, date: date, textValue: e.textValue),
          );
        case MetricType.tag:
          for (final t in e.tags) {
            await _data.addTag(date, e.metricId, t);
          }
      }
    }
  }
}
