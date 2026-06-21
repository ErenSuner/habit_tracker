import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// Gunluk hatirlatma bildirimlerini yoneten servis.
// Her gun belirlenen saatte "gununu doldurmayi unutma" bildirimi gonderir.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Gunluk hatirlatma';
  static const int _reminderId = 1001;

  // Uygulama acilisinda bir kez cagrilir.
  static Future<void> init() async {
    // Zaman dilimlerini hazirla (zamanlanmis bildirim icin gerekli).
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Bulunamazsa makul bir varsayilan.
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Android bildirim kanali (Android 8+ icin zorunlu).
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Gunu doldurmayi unutma hatirlatmasi',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Android 13+ icin bildirim izni ister. Izin verildiyse true doner.
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  // Her gun verilen saatte tekrarlanan hatirlatma kurar.
  static Future<void> scheduleDaily(TimeOfDay time) async {
    await cancel();
    await _plugin.zonedSchedule(
      _reminderId,
      'Gununu doldurmayi unutma',
      'Bugun neler yaptin? Birkac saniyede gir.',
      _nextInstanceOf(time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Gunu doldurmayi unutma hatirlatmasi',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Her gun ayni saatte tekrarla.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel() => _plugin.cancel(_reminderId);

  // Verilen saatin bir sonraki gerceklesme anini hesaplar.
  static tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
