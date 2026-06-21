import 'package:flutter/material.dart';

// Supabase bilgileri (URL + anon key) henuz girilmediyse gosterilir.
// lib/config/supabase_config.dart dosyasini doldurunca kaybolur.
class SetupNeededScreen extends StatelessWidget {
  const SetupNeededScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_suggest_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Kurulum gerekli',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Supabase bağlantı bilgileri henüz girilmemiş.\n\n'
                'lib/config/supabase_config.dart dosyasını aç ve '
                'Project URL ile anon anahtarını yaz, sonra uygulamayı '
                'yeniden başlat.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
