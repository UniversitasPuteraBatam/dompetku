import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../data/user_profile.dart';
import '../widgets/profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onEdit,
    required this.onSettings,
    required this.onAbout,
    required this.onLogout,
  });

  final UserProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onSettings;
  final VoidCallback onAbout;
  final Future<void> Function() onLogout;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.logout_rounded, color: context.palette.danger),
        title: const Text('Logout dari DompetKu?'),
        content: const Text(
          'Kamu perlu login kembali untuk mengakses akun ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onLogout();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
          child: Text(
            'Profil',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.palette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth > 720 ? 640 : 520,
                  ),
                  child: Column(
                    children: [
                      ProfileAvatar(
                        photoBytes: profile.photoBytes,
                        photoUrl: profile.profilePhoto,
                        radius: 46,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        profile.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.palette.secondaryText),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _ProfileMenuTile(
                icon: Icons.person_outline_rounded,
                title: 'Edit Profile',
                onTap: onEdit,
              ),
              const SizedBox(height: 8),
              _ProfileMenuTile(
                icon: Icons.settings_outlined,
                title: 'Pengaturan',
                onTap: onSettings,
              ),
              const SizedBox(height: 8),
              _ProfileMenuTile(
                icon: Icons.info_outline_rounded,
                title: 'Tentang DompetKu',
                onTap: onAbout,
              ),
              const SizedBox(height: 8),
              _ProfileMenuTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                color: context.palette.danger,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// Defaults to the theme text color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.palette.text;
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.palette.border),
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color == context.palette.danger
                ? context.palette.dangerSoft
                : context.palette.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
