// Temel widget testleri. Yerel supabase_config.dart dolu ya da bos olsun,
// makineden bagimsiz calisacak sekilde ekranlar dogrudan test edilir
// (HabitTrackerApp uzerinden test etmek gercek yapilandirmaya bagimliydi).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/screens/setup_needed_screen.dart';
import 'package:habit_tracker/utils/friendly_error.dart';

void main() {
  testWidgets('Kurulum ekrani yonergeyi gosterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetupNeededScreen()));
    expect(find.text('Kurulum gerekli'), findsOneWidget);
  });

  group('friendlyError', () {
    test('bilinmeyen hatada teknik detay sizdirmaz', () {
      final msg = friendlyError(Exception('PostgrestException(secret)'));
      expect(msg.contains('secret'), isFalse);
      expect(msg, 'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.');
    });

    test('ag hatasini baglanti mesajina cevirir', () {
      final msg = friendlyError(
        Exception('SocketException: Failed host lookup: xyz.supabase.co'),
      );
      expect(msg.contains('İnternet bağlantısı'), isTrue);
    });
  });
}
