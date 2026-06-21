import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_theme.dart';
import 'config/supabase_config.dart';
import 'services/notification_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/setup_needed_screen.dart';

Future<void> main() async {
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
  }

  runApp(const HabitTrackerApp());
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

// Oturum acik mi? Acoksa ana ekran, degilse giris ekrani gosterir.
// Oturum durumu degisince otomatik gunceller.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const HomeShell();
        }
        return const AuthScreen();
      },
    );
  }
}
