import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/data_service.dart';
import '../widgets/day_entry_form.dart';
import '../widgets/score_badge.dart';

// "Gecmis" sekmesi: takvimden bir gun secince o gunun girislerini
// duzenleyebilirsin. Gelecek gunler duzenlenemez (salt-okunur).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final _data = DataService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = _dateOnly(DateTime.now());
  final DateTime _todayDate = _dateOnly(DateTime.now());

  // Takvim boyutu: Ay (buyuk) <-> 2 Hafta <-> Hafta (kucuk).
  // Takvim uzerinde veya tarih satirinda dikey surukleyerek degisir.
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Takvimi renklendirmek icin: gun -> verim puani
  Map<DateTime, double> _scores = {};

  // Formu yeniden olusturup tazelemek icin sayac (anahtarin parcasi).
  int _tick = 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isFuture => _selectedDay.isAfter(_todayDate);

  @override
  void initState() {
    super.initState();
    _loadMonthScores(_focusedDay);
  }

  // Disaridan (sekme degisince) cagrilir.
  void reload() {
    _loadMonthScores(_focusedDay);
    setState(() => _tick++); // formu yeniden olustur
  }

  Future<void> _loadMonthScores(DateTime month) async {
    final from = DateTime(month.year, month.month - 1, 1);
    final to = DateTime(month.year, month.month + 2, 0);
    try {
      final scores = await _data.fetchScores(from, to);
      if (mounted) {
        setState(() {
          _scores = {
            for (final e in scores.entries) _dateOnly(e.key): e.value,
          };
        });
      }
    } catch (_) {
      // Renklendirme kritik degil; sessizce gec.
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = _scores[_selectedDay];
    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş')),
      body: Column(
        children: [
          TableCalendar(
            locale: 'tr_TR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            rowHeight: 46,
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Ay',
              CalendarFormat.twoWeeks: '2 Hafta',
              CalendarFormat.week: 'Hafta',
            },
            // Takvim uzerinde dikey kaydirinca format degisir; format butonu
            // gizli (kullanici sadece surukleyerek buyutup kucultur).
            availableGestures: AvailableGestures.all,
            onFormatChanged: (f) => setState(() => _calendarFormat = f),
            // Buyume/kuculme gecisini yumusat.
            formatAnimationDuration: const Duration(milliseconds: 400),
            formatAnimationCurve: Curves.easeInOutCubic,
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = _dateOnly(selected);
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              _loadMonthScores(focused);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, _) {
                final s = _scores[_dateOnly(day)];
                if (s == null) return null;
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: scoreColor(context, s),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
          ),
          // Secili gun basligi + puan. Ayni zamanda takvim icin "cekme
          // tutamaci": bu satirdan yukari surukle -> takvim kuculur,
          // asagi surukle -> buyur.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v > 80) {
                _resizeCalendar(grow: true); // asagi -> buyut
              } else if (v < -80) {
                _resizeCalendar(grow: false); // yukari -> kucult
              }
            },
            child: Column(
              children: [
                const Divider(height: 1),
                // Cekme ipucu cubugu (buton degil, surukleme gostergesi)
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('d MMMM y, EEEE', 'tr_TR')
                              .format(_selectedDay),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (score != null && !_isFuture) ScoreBadge(score: score),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isFuture
                ? _futureNotice()
                : DayEntryForm(
                    key: ValueKey('$_selectedDay#$_tick'),
                    date: _selectedDay,
                    onScoreChanged: (s) =>
                        setState(() => _scores[_selectedDay] = s),
                  ),
          ),
        ],
      ),
    );
  }

  // Tarih satirindan surukleyince takvimi bir kademe buyutur/kucultur.
  // Ay (en buyuk) <-> 2 Hafta <-> Hafta (en kucuk).
  void _resizeCalendar({required bool grow}) {
    final next = grow
        ? (_calendarFormat == CalendarFormat.week
            ? CalendarFormat.twoWeeks
            : CalendarFormat.month)
        : (_calendarFormat == CalendarFormat.month
            ? CalendarFormat.twoWeeks
            : CalendarFormat.week);
    if (next == _calendarFormat) return;
    HapticFeedback.selectionClick();
    setState(() => _calendarFormat = next);
  }

  Widget _futureNotice() {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_clock, size: 48, color: c.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Gelecek bir günü düzenleyemezsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
