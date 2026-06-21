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

  static bool get isConfigured =>
      supabaseUrl != 'BURAYA_PROJECT_URL' &&
      supabaseAnonKey != 'BURAYA_ANON_KEY';
}
