// Basit bir uygulama ikonu uretir (indigo zemin + beyaz tik).
// Calistir: dart run tool/gen_icon.dart
// Sonra: dart run flutter_launcher_icons  ve  dart run flutter_native_splash:create
import 'dart:io';
import 'package:image/image.dart' as img;

const int _size = 1024;
final _white = img.ColorRgb8(255, 255, 255);
const _bgR = 0x6D, _bgG = 0x28, _bgB = 0xD9; // mor

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // 1) Tam ikon: indigo zemin + beyaz tik
  final full = img.Image(width: _size, height: _size, numChannels: 4);
  img.fill(full, color: img.ColorRgb8(_bgR, _bgG, _bgB));
  _check(full, 1.0);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(full));

  // 2) Adaptif on plan: saydam zemin + beyaz tik (guvenli alan icin kucuk)
  final fg = img.Image(width: _size, height: _size, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  _check(fg, 0.62);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Ikonlar uretildi: assets/icon/icon.png + icon_foreground.png');
}

// Merkeze gore olcekli beyaz tik cizer (yuvarlatilmis koseli).
void _check(img.Image im, double scale) {
  const cx = _size ~/ 2, cy = _size ~/ 2;
  final th = (90 * scale).round();
  // Tik noktalari (merkeze gore, olcekli)
  final ax = (cx + -190 * scale).round(), ay = (cy + 40 * scale).round();
  final bx = (cx + -60 * scale).round(), by = (cy + 175 * scale).round();
  final dx = (cx + 240 * scale).round(), dy = (cy + -165 * scale).round();

  img.drawLine(im,
      x1: ax, y1: ay, x2: bx, y2: by, color: _white, thickness: th, antialias: true);
  img.drawLine(im,
      x1: bx, y1: by, x2: dx, y2: dy, color: _white, thickness: th, antialias: true);

  // Koseleri ve uclari yuvarlatmak icin daireler
  final r = (th / 2).round();
  img.fillCircle(im, x: ax, y: ay, radius: r, color: _white, antialias: true);
  img.fillCircle(im, x: bx, y: by, radius: r, color: _white, antialias: true);
  img.fillCircle(im, x: dx, y: dy, radius: r, color: _white, antialias: true);
}
