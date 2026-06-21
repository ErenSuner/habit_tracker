import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/ai_proposal.dart';
import '../models/metric.dart';
import '../services/ai_service.dart';
import '../services/data_service.dart';

// "AI" sekmesi: gununu anlat, asistan metrikleri senin icin doldursun.
// Sen onayladiktan sonra girisler buluta kaydedilir.
class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => AiScreenState();
}

// Disaridan reload() cagrilabilmesi icin State sinifi public.
class AiScreenState extends State<AiScreen> {
  final _ai = AiService();
  final _data = DataService();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final DateTime _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  List<Metric> _metrics = [];
  final List<_ChatMsg> _messages = [];
  bool _sending = false;

  // Sesli giris (cihazin konusma tanima motoru)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  // Android konusma tanima segment-bazli sonuc verir ve genelde finalResult
  // GONDERMEZ; bir segment bitince araya bos sonuc gelir. Bu yuzden
  // kesinlesmis metni (_committed) ve o anki aktif segmenti (_segment) ayri
  // tutariz; bos sonuc geldiginde aktif segmenti kalicilastiririz.
  String _committed = '';
  String _segment = '';

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _initSpeech();
  }

  @override
  void dispose() {
    _listening = false; // onStatus geri cagrisi yeniden baslatmasin
    _speech.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Konusma tanima motorunu hazirla (ilk kullanimda mikrofon izni istenir).
  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (_) {
          // Oturum kendiliginden bittiyse (kisa sessizlik / zaman asimi) ama
          // kullanici hala dinleme modundaysa kesintisiz dinleme icin yeniden
          // baslat. Boylece motor kendi kendine kapanmis gibi gorunmez.
          if (!_speech.isListening && _listening) {
            Future.delayed(const Duration(milliseconds: 250), () {
              if (mounted && _listening && !_speech.isListening) {
                _startListening();
              }
            });
          }
        },
        onError: (e) {
          // Kalici hata (izin yok, motor yok vb.) -> dinlemeyi tamamen birak.
          // Gecici hatalar (sessizlik, eslesme yok) onStatus ile yeniden baslar.
          if (e.permanent && mounted) {
            setState(() => _listening = false);
          }
        },
      );
      if (mounted) setState(() => _speechAvailable = ok);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  // Mikrofon butonu: dinlemeyi baslatir/durdurur.
  Future<void> _toggleListen() async {
    if (_sending) return;

    if (_listening) {
      // Once niyeti kapat ki onStatus yeniden baslatmasin.
      setState(() => _listening = false);
      await _speech.stop();
      return;
    }

    // Henuz hazir degilse (izin reddedilmis olabilir) tekrar dene.
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Konuşma tanıma kullanılamıyor. Mikrofon iznini kontrol et.'),
          ));
        }
        return;
      }
    }

    HapticFeedback.selectionClick();
    setState(() => _listening = true);
    await _startListening();
  }

  // Tek bir dinleme oturumu baslatir. Oturum bitince (onStatus) kullanici
  // hala dinliyorsa otomatik tekrar cagrilir.
  Future<void> _startListening() async {
    // Her oturum baslarken kutuda o an ne varsa onu kesinlesmis kabul et;
    // boylece yeni oturum mevcut metnin USTUNE ekler, ezmez.
    _committed = _inputCtrl.text.trim();
    _segment = '';
    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          localeId: 'tr_TR', // cihazda yoksa sistem varsayilanina duser
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 30),
        ),
        onResult: _onSpeechResult,
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  // Tanima sonucu geldikce kutuyu gunceller. Kesinlesen (final) her parcayi
  // _speechBase'e kalici ekleriz; boylece yeni oturum oncekini EZMEZ, sonuna
  // ekler.
  void _onSpeechResult(SpeechRecognitionResult r) {
    final words = r.recognizedWords.trim();
    if (words.isNotEmpty) {
      // Aktif segment buyuyor (kismi sonuc); son hali tutariz.
      _segment = words;
    } else if (_segment.isNotEmpty) {
      // Bos sonuc = aktif segment bitti; kalicilastir (Android final vermez).
      _committed = _join(_committed, _segment);
      _segment = '';
    }
    // Oturum kapanirken bazen final sonuc gelir; segmenti kesinlestir.
    if (r.finalResult && _segment.isNotEmpty) {
      _committed = _join(_committed, _segment);
      _segment = '';
    }
    final text = _join(_committed, _segment);
    _inputCtrl.text = text;
    _inputCtrl.selection = TextSelection.collapsed(offset: text.length);
  }

  // Iki metni tek boslukla birlestirir (bos olanlari atlar).
  String _join(String a, String b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a $b';
  }

  // Disaridan (sekme degisince) cagrilir: metrik listesini tazeler.
  void reload() => _loadMetrics();

  Future<void> _loadMetrics() async {
    try {
      final m = await _data.fetchMetrics(onlyActive: true);
      if (mounted) setState(() => _metrics = m);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    // Dinleme aciksa IPTAL et: stop() gec bir sonuc gonderip kutuyu yeniden
    // doldurabiliyor; cancel() bunu engeller (metni zaten kutudan aliyoruz).
    if (_listening) {
      setState(() => _listening = false); // once niyeti kapat (restart olmasin)
      await _speech.cancel();
    }
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMsg(fromUser: true, text: text));
      _sending = true;
      _inputCtrl.clear();
      _committed = ''; // biriktirme durumunu da sifirla
      _segment = '';
    });
    _scrollToBottom();

    // Onceki konusmayi baglam olarak gonder.
    final history = <Map<String, String>>[];
    for (final m in _messages) {
      if (m.fromUser) {
        history.add({'role': 'user', 'content': m.text ?? ''});
      } else if (m.proposal != null) {
        history.add({'role': 'assistant', 'content': m.proposal!.reply});
      }
    }
    // Son kullanici mesajini history'den cikar (ask zaten ekliyor).
    if (history.isNotEmpty) history.removeLast();

    try {
      final proposal = await _ai.ask(text, _metrics, history: history);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(fromUser: false, proposal: proposal));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(
            fromUser: false,
            text: 'Bir hata oluştu: $e',
            isError: true,
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _confirm(_ChatMsg msg) async {
    final proposal = msg.proposal;
    if (proposal == null || proposal.entries.isEmpty) return;
    setState(() => msg.applying = true);
    try {
      await _ai.apply(proposal.entries, _today);
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => msg.applied = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => msg.applying = false);
    }
  }

  // Oneriyi "Metrik adi: deger birim" seklinde gosterir.
  // Ad ve birimi AI'ya birakmak yerine metric_id'den kendimiz buluruz.
  String _entrySummary(ProposedEntry e) {
    Metric? m;
    for (final x in _metrics) {
      if (x.id == e.metricId) {
        m = x;
        break;
      }
    }
    final name = m?.name ?? e.metricName ?? 'Metrik';
    final unit = m?.unit;
    switch (e.type) {
      case MetricType.numeric:
        final v = e.numValue;
        final vStr = v == null
            ? '-'
            : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
        final suffix = (unit != null && unit.isNotEmpty) ? ' $unit' : '';
        return '$name: $vStr$suffix';
      case MetricType.boolean:
        final b = e.boolValue;
        var s = '$name: ${b == true ? 'Evet' : b == false ? 'Hayir' : '-'}';
        if (b == true && e.numValue != null) {
          final v = e.numValue!;
          final vStr =
              v == v.roundToDouble() ? v.toInt().toString() : v.toString();
          s += ' ($vStr${unit != null && unit.isNotEmpty ? ' $unit' : ''})';
        }
        return s;
      case MetricType.tag:
        return '$name: ${e.tags.join(', ')}';
      case MetricType.text:
        return '$name: ${e.textValue ?? '-'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Asistan')),
      body: Column(
        children: [
          if (_metrics.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Önce Ayarlar > Metrikleri yönet kısmından metrik ekle, '
                'sonra gününü anlat.',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _emptyHint()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _bubble(_messages[i]),
                  ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Düşünüyor...'),
                ],
              ),
            ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _emptyHint() {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 56, color: c.primary),
            const SizedBox(height: 16),
            Text('Gününü anlat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Örnek: "Bugün 1 saat koştum, Sefiller\'den 30 sayfa okudum, '
              'anarşizm araştırdım ve 1850 kalori aldım."',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_ChatMsg msg) {
    final c = Theme.of(context).colorScheme;
    if (msg.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(msg.text ?? ''),
        ),
      );
    }

    // Asistan balonu
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isError ? c.errorContainer : c.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.proposal?.reply ?? msg.text ?? ''),
            if (msg.proposal != null && msg.proposal!.entries.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...msg.proposal!.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check, size: 16, color: c.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_entrySummary(e))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (msg.applied)
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: c.primary),
                    const SizedBox(width: 6),
                    const Text('Kaydedildi'),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: msg.applying ? null : () => _confirm(msg),
                  icon: msg.applying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Onayla ve kaydet'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: _listening ? 'Dinleniyor...' : 'Gününü anlat...',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Sesli giris butonu (cihazda konusma tanima varsa)
            if (_speechAvailable)
              IconButton(
                onPressed: _sending ? null : _toggleListen,
                tooltip: _listening ? 'Durdur' : 'Sesli giriş',
                color: _listening
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                icon: Icon(_listening ? Icons.stop_circle : Icons.mic),
              ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

// Sohbetteki tek bir mesaj.
class _ChatMsg {
  final bool fromUser;
  final String? text;
  final AiProposal? proposal;
  final bool isError;
  bool applied = false;
  bool applying = false;

  _ChatMsg({
    required this.fromUser,
    this.text,
    this.proposal,
    this.isError = false,
  });
}
