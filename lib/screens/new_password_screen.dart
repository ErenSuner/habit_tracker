import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/data_service.dart';
import '../utils/friendly_error.dart';

// Sifre sifirlama e-postasindaki baglantiyla uygulamaya donuldugunde
// (AuthChangeEvent.passwordRecovery) gosterilir. Kullanici yeni sifresini
// belirler; basarili olunca onDone ile normal akisa devam edilir.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, required this.onDone});

  // Sifre guncellenince veya kullanici vazgecince cagrilir.
  final VoidCallback onDone;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _data = DataService();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pass = _passCtrl.text;
    if (pass.length < 8) {
      setState(() => _error = 'Şifre en az 8 karakter olmalı.');
      return;
    }
    if (pass != _pass2Ctrl.text) {
      setState(() => _error = 'Şifreler birbiriyle aynı değil.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _data.updatePassword(pass);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifren güncellendi.')),
        );
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset_rounded,
                    size: 56, color: AppColors.purpleBright),
                const SizedBox(height: 16),
                Text(
                  'Yeni şifre belirle',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hesabın için yeni bir şifre seç.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Yeni şifre',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pass2Ctrl,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'Yeni şifre (tekrar)',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Şifreyi güncelle'),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : widget.onDone,
                  child: const Text('Şimdilik geç'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
