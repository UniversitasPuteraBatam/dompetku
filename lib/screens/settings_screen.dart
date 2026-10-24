import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onChangePassword});

  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                'Akun',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.palette.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.lock_reset_rounded,
                title: 'Ganti Password',
                subtitle: 'Perbarui password akun kamu',
                onTap: onChangePassword,
              ),
              const SizedBox(height: 24),
              Text(
                'Tampilan',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.palette.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const _ThemeModePicker(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker();

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    final mode = controller?.mode ?? ThemeMode.system;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tema aplikasi',
            style: TextStyle(
              color: context.palette.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            switch (mode) {
              ThemeMode.system => 'Mengikuti pengaturan terang/gelap perangkat',
              ThemeMode.light => 'Selalu memakai tema terang',
              ThemeMode.dark => 'Selalu memakai tema gelap',
            },
            style: TextStyle(
              color: context.palette.secondaryText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<ThemeMode>(
            key: const ValueKey('theme-mode-picker'),
            showSelectedIcon: false,
            selected: {mode},
            onSelectionChanged: controller == null
                ? null
                : (selection) => controller.setMode(selection.first),
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('Sistem'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Terang'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Gelap'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    borderRadius: BorderRadius.circular(14),
    child: ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.palette.border),
      ),
      leading: Icon(icon, color: context.palette.accent),
      title: Text(
        title,
        style: TextStyle(
          color: context.palette.text,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
