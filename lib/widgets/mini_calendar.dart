import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

// Belirli gunleri (orn. basarili olunan ya da etiket eklenen gunler)
// isaretleyen kucuk takvim. Aylar arasinda gezilebilir.
class MiniCalendar extends StatefulWidget {
  final Set<DateTime> markedDays;
  final Color color;

  const MiniCalendar({
    super.key,
    required this.markedDays,
    required this.color,
  });

  @override
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  DateTime _focused = DateTime.now();

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      locale: 'tr_TR',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      focusedDay: _focused,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      availableCalendarFormats: const {CalendarFormat.month: 'Ay'},
      startingDayOfWeek: StartingDayOfWeek.monday,
      rowHeight: 38,
      onPageChanged: (f) => setState(() => _focused = f),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (ctx, day, _) {
          if (widget.markedDays.contains(_d(day))) {
            // Basarili gun: mor alev ikonu, uzerinde gun numarasi.
            return Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: widget.color,
                      size: 38,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
