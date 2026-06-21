import 'package:flutter/material.dart';

// Kategori adindan DETERMINISTIK (sabit) bir renk uretir: ayni ad her zaman
// ayni rengi alir. Boylece kategori rengini ayrica saklamaya gerek kalmaz.
const List<Color> _categoryPalette = [
  Color(0xFF8B5CF6), // mor
  Color(0xFF6366F1), // indigo
  Color(0xFF34D399), // yesil
  Color(0xFFFBBF24), // sari
  Color(0xFFFB7185), // mercan
  Color(0xFF22D3EE), // camgobegi
  Color(0xFFF472B6), // pembe
  Color(0xFFA3E635), // lime
  Color(0xFFFB923C), // turuncu
  Color(0xFF818CF8), // acik indigo
];

// Notr gri (kategorisiz / "Diger" icin).
const Color kNoCategoryColor = Color(0xFF6B6480);

Color categoryColor(String? name) {
  final t = (name ?? '').trim();
  if (t.isEmpty) return kNoCategoryColor;
  var h = 0;
  for (final c in t.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _categoryPalette[h % _categoryPalette.length];
}

// Verilen renk uzerinde okunur metin rengi (acik tonlarda siyah, koyularda beyaz).
Color onCategoryColor(Color c) =>
    c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
