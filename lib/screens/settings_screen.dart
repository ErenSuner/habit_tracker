import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';
import '../widgets/profile_dialog.dart';
import 'metrics_screen.dart';

// "Ayarlar" sekmesi: hesap, metrik yonetimi, hatirlatma ve cikis.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _data = DataService();

  // Hatirlatma ayarlari (SharedPreferences'ta saklanir)
  static const _kEnabled = 'reminder_enabled';
  static const _kHour = 'reminder_hour';
  static const _kMinute = 'reminder_minute';

  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _reminderEnabled = p.getBool(_kEnabled) ?? false;
      _reminderTime = TimeOfDay(
        hour: p.getInt(_kHour) ?? 20,
        minute: p.getInt(_kMinute) ?? 0,
      );
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, _reminderEnabled);
    await p.setInt(_kHour, _reminderTime.hour);
    await p.setInt(_kMinute, _reminderTime.minute);
  }

  Future<void> _toggleReminder(bool value) async {
    if (value) {
      // Once izin iste.
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bildirim izni verilmedi. Telefon ayarlarından açabilirsin.',
              ),
            ),
          );
        }
        return;
      }
      await NotificationService.scheduleDaily(_reminderTime);
    } else {
      await NotificationService.cancel();
    }
    setState(() => _reminderEnabled = value);
    await _savePrefs();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;
    setState(() => _reminderTime = picked);
    await _savePrefs();
    if (_reminderEnabled) {
      await NotificationService.scheduleDaily(_reminderTime);
    }
  }

  // Hesap kartina basinca profil (isim degistirme) penceresini acar.
  Future<void> _openProfile(String name, String email) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ProfileDialog(initialName: name, email: email),
    );
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final email = _data.currentUser?.email ?? '-';
    final name = _data.effectiveDisplayName;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _accountCard(name, email),
          const SizedBox(height: 22),

          _sectionTitle('Takip'),
          const SizedBox(height: 8),
          _card([
            _tile(
              icon: Icons.tune,
              title: 'Metrikleri yönet',
              subtitle: 'Takip kalemlerini ekle / düzenle',
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MetricsScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 22),

          _sectionTitle('Hatırlatma'),
          const SizedBox(height: 8),
          _card([
            _switchTile(
              icon: Icons.notifications_active_outlined,
              title: 'Akşam hatırlatması',
              subtitle: 'Her gün gününü doldurmayı hatırlat',
              value: _reminderEnabled,
              onChanged: _toggleReminder,
            ),
            if (_reminderEnabled)
              _tile(
                icon: Icons.schedule,
                title: 'Hatırlatma saati',
                trailing: Text(
                  _reminderTime.format(context),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purpleBright,
                  ),
                ),
                onTap: _pickTime,
              ),
            _tile(
              icon: Icons.science_outlined,
              title: 'Test bildirimi gönder',
              subtitle: 'Bildirimlerin çalıştığını hemen dene',
              onTap: () async {
                await NotificationService.requestPermission();
                await NotificationService.showTest();
              },
            ),
          ]),
          const SizedBox(height: 22),

          _card([
            _tile(
              icon: Icons.logout,
              title: 'Çıkış yap',
              danger: true,
              onTap: () async {
                await _data.signOut();
              },
            ),
          ]),
        ],
      ),
    );
  }

  // ---- Tasarim yardimcilari ----

  Widget _accountCard(String name, String email) {
    final initial = name.isEmpty ? 'A' : name[0].toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openProfile(name, email),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppColors.gradient,
                ),
                child: Text(initial,
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name.isEmpty ? 'Profil' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _card(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(const Divider(
            height: 1, indent: 66, color: AppColors.border));
      }
      children.add(rows[i]);
    }
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _iconBox(IconData icon, {bool danger = false}) {
    final base = danger ? AppColors.danger : AppColors.purple;
    final fg = danger ? AppColors.danger : AppColors.purpleBright;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: base.withValues(alpha: 0.14),
      ),
      child: Icon(icon, size: 20, color: fg),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              _iconBox(icon, danger: danger),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: danger
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        )),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _iconBox(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
