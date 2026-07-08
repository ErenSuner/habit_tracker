import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_theme.dart';
import 'config/supabase_config.dart';
import 'services/data_service.dart';
import 'services/net_status.dart';
import 'services/notification_service.dart';
import 'services/screen_time_worker.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/new_password_screen.dart';
import 'screens/setup_needed_screen.dart';

Future<void> main() async {
  if (SupabaseConfig.sentryDsn.isEmpty) {
    // Sentry DSN girilmemis: crash raporlama olmadan dogrudan baslat.
    await _bootstrap();
    runApp(const HabitTrackerApp());
  } else {
    // Sentry yakalanmamis tum hatalari otomatik raporlar.
    await SentryFlutter.init(
      (options) {
        options.dsn = SupabaseConfig.sentryDsn;
        options.tracesSampleRate = 0.2;
      },
      appRunner: () async {
        await _bootstrap();
        runApp(SentryWidget(child: const HabitTrackerApp()));
      },
    );
  }
}

// Uygulama baslamadan once yapilmasi gereken hazirliklar.
Future<void> _bootstrap() async {
  // Flutter motorunu hazirla (async islem oncesi gerekli).
  WidgetsFlutterBinding.ensureInitialized();

  // Turkce tarih bicimlendirmesi (orn. "19 Haziran Cuma") icin gerekli.
  await initializeDateFormatting('tr_TR', null);

  // Bildirim altyapisini hazirla.
  await NotificationService.init();

  // Supabase bilgileri girilmediyse uygulamayi baslatma, uyari ekrani goster.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      // "publishableKey" yeni isim; degeri Supabase panelindeki
      // "anon public" anahtaridir (ikisi de ayni ise yarar).
      publishableKey: SupabaseConfig.supabaseAnonKey,
    );

    // Baglanti durumunu izlemeye basla; yeniden baglaninca cevrimdisi
    // yapilan yazmalari sunucuya gonder. Acilista da bir kez dene.
    await NetStatus.init();
    NetStatus.onReconnect(() => DataService().syncPending());
    if (NetStatus.online.value) {
      unawaited(DataService().syncPending());
    }
  }

  // Ekran suresini uygulama kapaliyken de esitleyen arka plan gorevi
  // (yalnizca Android'de calisir; kurulamazsa sessizce atlanir).
  await ScreenTimeWorker.register();
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: SupabaseConfig.isConfigured
          ? const AuthGate()
          : const SetupNeededScreen(),
    );
  }
}

// Oturum acik mi? Aciksa ana ekran, degilse giris ekrani gosterir.
// Ayrica sifre sifirlama baglantisiyla gelindiyse (deep link ->
// passwordRecovery olayi) yeni sifre ekranina yonlendirir.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;

  // Sifre sifirlama e-postasindaki baglantiyla mi gelindi?
  bool _passwordRecovery = false;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecovery = true;
        } else if (state.event == AuthChangeEvent.signedOut) {
          _passwordRecovery = false;
        }
        // Diger olaylarda da (signedIn vb.) build yeniden calisip
        // guncel oturuma gore dogru ekrani secer.
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthScreen();
    if (_passwordRecovery) {
      return NewPasswordScreen(
        onDone: () => setState(() => _passwordRecovery = false),
      );
    }
    return const HomeShell();
  }
}
