import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/data_service.dart';
import '../utils/friendly_error.dart';

// Giris / kayit ekrani. Ayni ekran iki modda calisir:
//  - Giris yap (mevcut hesap)
//  - Kayit ol (yeni hesap)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _data = DataService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isLogin = true; // true: giris, false: kayit
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'E-posta ve şifre boş olamaz.');
      return;
    }
    // Kayitta daha guclu sifre iste.
    if (!_isLogin && pass.length < 8) {
      setState(() => _error = 'Şifre en az 8 karakter olmalı.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await _data.signIn(email, pass);
      } else {
        await _data.signUp(email, pass);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kayıt alındı. E-postanı doğrula ve giriş yap.',
              ),
            ),
          );
          setState(() => _isLogin = true);
        }
      }
      // Basariliysa AuthGate otomatik ana ekrana gecirir.
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // "Sifremi unuttum": e-posta girilir, sifirlama baglantisi gonderilir.
  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şifre sıfırlama'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'E-posta',
            hintText: 'Hesabının e-postası',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Bağlantı gönder'),
          ),
        ],
      ),
    );
    final mail = (email ?? '').trim();
    if (mail.isEmpty) return;
    try {
      await _data.sendPasswordReset(mail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Sıfırlama bağlantısı e-postana gönderildi (varsa spam klasörüne de bak).'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
                SnackBar(content: Text('Gönderilemedi: ${friendlyError(e)}')));
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
                // Gradyan logo rozeti
                Center(
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.45),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 44),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Habit Tracker',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _isLogin ? 'Tekrar hoş geldin' : 'Yeni bir hesap oluştur',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                // Form karti
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
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
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
                            : Text(_isLogin ? 'Giriş yap' : 'Kayıt ol'),
                      ),
                    ],
                  ),
                ),
                if (_isLogin)
                  TextButton(
                    onPressed: _loading ? null : _forgotPassword,
                    child: const Text('Şifremi unuttum'),
                  ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _isLogin = !_isLogin;
                            _error = null;
                          }),
                  child: Text(
                    _isLogin
                        ? 'Hesabın yok mu? Kayıt ol'
                        : 'Zaten hesabın var mı? Giriş yap',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
