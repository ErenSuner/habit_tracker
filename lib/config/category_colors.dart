import 'package:flutter/material.dart';

// Kategori adindan DETERMINISTIK (sabit) bir renk uretir: ayni ad her zaman
// ayni rengi alir. Boylece kategori rengini ayrica saklamaya gerek kalmaz.
// Beyaz zeminde okunur, sicaga meyilli ama birbirinden ayrik tonlar.
const List<Color> _categoryPalette = [
  Color(0xFFF97316), // turuncu
  Color(0xFFEA580C), // koyu turuncu
  Color(0xFF16A34A), // yesil
  Color(0xFFD97706), // amber
  Color(0xFFE11D48), // gul
  Color(0xFF0891B2), // camgobegi
  Color(0xFFDB2777), // pembe
  Color(0xFF65A30D), // zeytin yesili
  Color(0xFF7C3AED), // mor
  Color(0xFF2563EB), // mavi
];

// Notr sicak gri (kategorisiz / "Diger" icin).
const Color kNoCategoryColor = Color(0xFF9C8579);

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
