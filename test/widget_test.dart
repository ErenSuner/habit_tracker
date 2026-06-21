// Basit acilis testi: Supabase bilgileri girilmeden uygulama acilinca
// "Kurulum gerekli" ekrani gosterilmeli.
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/main.dart';

void main() {
  testWidgets('Uygulama acilis testi', (WidgetTester tester) async {
    await tester.pumpWidget(const HabitTrackerApp());
    // Supabase yapilandirilmadiysa kurulum ekrani cikar.
    expect(find.text('Kurulum gerekli'), findsOneWidget);
  });
}
