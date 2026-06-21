import 'package:flutter/material.dart';

// Uygulamanin koyu (siyah + mor) renk paleti.
class AppColors {
  // Zeminler
  static const Color bg = Color(0xFF0B0910); // neredeyse siyah, hafif mor
  static const Color surface = Color(0xFF15121E); // kartlar
  static const Color surfaceHigh = Color(0xFF1F1B2B); // istatistik kutulari
  static const Color navBar = Color(0xFF110E18);

  // Mor accent
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleBright = Color(0xFFB39DFF);
  static const Color purpleDeep = Color(0xFF6D28D9);

  // Metin
  static const Color textPrimary = Color(0xFFECEAF3);
  static const Color textSecondary = Color(0xFF9A93AE);

  // Cizgi / kenarlik
  static const Color border = Color(0xFF272231);

  // Semantik
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFFB7185);

  // Mor gradyan (halka, butonlar, vurgular icin)
  static const LinearGradient gradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
