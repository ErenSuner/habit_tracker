import 'package:flutter/material.dart';

// Uygulamanin sicak, enerjik ACIK renk paleti (gun dogumu: turuncu + beyaz).
// Not: bazi isimler (purple*) tarihseldir; degerler artik turuncudur.
// Ekranlar bu isimleri kullandigi icin isimler korunup renkler degistirildi.
class AppColors {
  // Zeminler
  static const Color bg = Color(0xFFFFF7F0); // sicak krem-beyaz
  static const Color surface = Color(0xFFFFFFFF); // kartlar
  static const Color surfaceHigh = Color(0xFFFFF1E7); // istatistik kutulari
  static const Color navBar = Color(0xFFFFFFFF);

  // Turuncu accent (eski "purple*" isimleri)
  static const Color purple = Color(0xFFFF6B2C); // ana turuncu
  static const Color purpleBright = Color(0xFFDD5A1B); // acik zeminde okunur ton
  static const Color purpleDeep = Color(0xFFE85D1F);

  // Turuncu ailesinin dogrudan isimli hali (yeni kod icin)
  static const Color accent = Color(0xFFFF6B2C);
  static const Color accentSoft = Color(0xFFFFE7D6); // cok acik turuncu dolgu

  // Metin
  static const Color textPrimary = Color(0xFF2A1E17); // sicak neredeyse-siyah
  static const Color textSecondary = Color(0xFF9C8579); // sicak gri

  // Cizgi / kenarlik
  static const Color border = Color(0xFFF1E4D8);

  // Semantik (acik zeminde okunur tonlar)
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Gun dogumu gradyani (halka, butonlar, vurgular icin)
  static const LinearGradient gradient = LinearGradient(
    colors: [Color(0xFFFF8A3D), Color(0xFFFF5A1F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
