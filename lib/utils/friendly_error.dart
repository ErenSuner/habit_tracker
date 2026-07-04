import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

// Ham hata nesnelerini kullaniciya gosterilebilir Turkce mesaja cevirir.
// Ekranlar "$e" yazmak yerine bunu kullanir; boylece kullanici
// "AuthApiException: invalid credentials" gibi teknik metin gormez.
String friendlyError(Object error) {
  const network =
      'İnternet bağlantısı kurulamadı. Bağlantını kontrol edip tekrar dene.';

  // Ag baglantisi sorunlari (istekler SocketException/Timeout firlatir).
  if (error is SocketException || error is TimeoutException) {
    return network;
  }

  // Kimlik dogrulama hatalari (giris, kayit, sifre islemleri).
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'E-posta veya şifre hatalı.';
      case 'email_not_confirmed':
        return 'E-postan henüz doğrulanmamış. Gelen kutundaki bağlantıya tıkla.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Bu e-posta ile zaten bir hesap var. Giriş yapmayı dene.';
      case 'weak_password':
        return 'Şifre çok zayıf. Daha uzun bir şifre seç.';
      case 'same_password':
        return 'Yeni şifre eskisiyle aynı olamaz.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Çok fazla deneme yapıldı. Birkaç dakika sonra tekrar dene.';
      case 'validation_failed':
        return 'Geçerli bir e-posta adresi gir.';
      case 'session_expired':
      case 'refresh_token_not_found':
        return 'Oturumun süresi doldu. Lütfen tekrar giriş yap.';
    }
    return 'İşlem gerçekleştirilemedi. Lütfen tekrar dene.';
  }

  // Edge Function hatalari (ai-fill, delete-account). Fonksiyon govdede
  // { "error": "..." } dondurduyse o mesaj zaten Turkce'dir, aynen goster.
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'Sunucu işlemi başarısız oldu. Lütfen tekrar dene.';
  }

  // Veritabani hatalari: teknik detayi kullaniciya sizdirmayalim.
  if (error is PostgrestException) {
    return 'Sunucuyla iletişimde bir sorun oluştu. Lütfen tekrar dene.';
  }

  // Bazi katmanlar ag hatasini kendi tipleriyle sarar; metinden yakala.
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset') ||
      text.contains('ClientException')) {
    return network;
  }

  return 'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.';
}
