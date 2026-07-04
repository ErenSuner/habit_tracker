import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/supabase_config.dart';
import 'data_service.dart';
import 'screen_time_service.dart';
import 'screen_time_sync.dart';

// Ekran suresini UYGULAMA KAPALIYKEN de bulutla esitleyen arka plan gorevi.
//
// Neden gerekli: Android, gunluk kullanim olaylarini cihazda yalnizca
// ~1 hafta tutar. Kullanici uygulamayi 1 haftadan uzun acmazsa aradaki
// gunler kaybolurdu. WorkManager bu gorevi ~6 saatte bir (cihaz uygun
// oldugunda) calistirir ve eksik gunleri tamamlar.

// Gorevin WorkManager'daki adlari.
const _kUniqueName = 'screen-time-sync';
const _kTaskName = 'screenTimeSync';

// Arka plan isolate'inde calisir. Uygulamanin geri kalanindan tamamen
// ayri bir ortamdir: Supabase burada YENIDEN baslatilir; oturum bilgisi
// cihazda kayitli oldugu icin otomatik geri yuklenir.
@pragma('vm:entry-point')
void screenTimeWorkerCallback() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      if (!SupabaseConfig.isConfigured) return true;
      try {
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          publishableKey: SupabaseConfig.supabaseAnonKey,
        );
      } catch (_) {
        // Ayni isolate'te ikinci calisma: zaten baslatilmis olabilir.
      }

      // Oturum ya da izin yoksa yapacak is yok; "basarili" don ki
      // WorkManager bosuna yeniden denemesin.
      if (Supabase.instance.client.auth.currentSession == null) return true;
      if (!await ScreenTimeService.hasPermission()) return true;

      await ScreenTimeSync.backfill(DataService());
      return true;
    } catch (_) {
      // Basarisiz: WorkManager backoff ile daha sonra yeniden dener.
      return false;
    }
  });
}

class ScreenTimeWorker {
  // Uygulama acilisinda bir kez cagrilir. Ayni benzersiz adla tekrar
  // kayit "keep" politikasi sayesinde coklamaz.
  static Future<void> register() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await Workmanager().initialize(screenTimeWorkerCallback);
      await Workmanager().registerPeriodicTask(
        _kUniqueName,
        _kTaskName,
        frequency: const Duration(hours: 6),
        initialDelay: const Duration(minutes: 30),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        // Buluta yazacagi icin internet bagli olsun.
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {
      // Kurulamazsa sorun degil: ana sayfa karti acilista zaten son 7
      // gunu geriye donuk dolduruyor.
    }
  }
}
