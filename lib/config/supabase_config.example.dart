// ORNEK dosya — gercek anahtarlar repoya konmaz.
//
// Kurulum: bu dosyayi ayni klasore "supabase_config.dart" adiyla kopyala
// ve kendi degerlerini gir:
//   Supabase paneli > Project Settings > API
//     - "Project URL"        -> supabaseUrl
//     - "anon public" anahtar -> supabaseAnonKey
//
// NOT: anon anahtari sifre DEGILDIR; istemci uygulamada bulunmasi normaldir.
// Asil guvenlik veritabanindaki RLS politikalari ile saglanir (schema.sql).
class SupabaseConfig {
  static const String supabaseUrl = 'BURAYA_PROJECT_URL';
  static const String supabaseAnonKey = 'BURAYA_ANON_KEY';

  // Kimlik dogrulama e-postalarindaki baglantilarin uygulamaya donus adresi.
  // Supabase paneli > Authentication > URL Configuration > Redirect URLs
  // listesine AYNEN eklenmis olmali (AndroidManifest'teki sema ile ayni).
  static const String authCallbackUrl =
      'com.erensuner.habittracker://auth-callback';

  // Sentry crash raporlama DSN'i (sentry.io). Bos ise raporlama kapali.
  static const String sentryDsn = '';

  static bool get isConfigured =>
      supabaseUrl != 'BURAYA_PROJECT_URL' &&
      supabaseAnonKey != 'BURAYA_ANON_KEY';
}
