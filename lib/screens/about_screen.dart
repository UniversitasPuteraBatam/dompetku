import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.loadVersion});

  final Future<String> Function()? loadVersion;

  Future<String> _version() async {
    final loader = loadVersion;
    if (loader != null) return loader();
    final info = await PackageInfo.fromPlatform();
    final buildNumber = info.buildNumber;
    return buildNumber.isEmpty ? info.version : '${info.version}+$buildNumber';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tentang DompetKu')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'DompetKu',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.palette.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aplikasi pencatat keuangan pribadi untuk membantu memantau pemasukan, pengeluaran, dan laporan keuangan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.palette.secondaryText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _InfoCard(
                children: [
                  _InfoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Versi aplikasi',
                    value: FutureBuilder<String>(
                      future: _version(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Versi tidak dapat dimuat');
                        }
                        if (!snapshot.hasData) {
                          return const Text('Memuat versi...');
                        }
                        return Text(snapshot.data!);
                      },
                    ),
                  ),
                ],
              ),
              const _SectionTitle('Fitur Utama'),
              const _InfoCard(
                children: [
                  _FeatureRow(
                    icon: Icons.receipt_long_outlined,
                    text: 'Pencatatan pemasukan dan pengeluaran',
                  ),
                  _FeatureRow(
                    icon: Icons.bar_chart_rounded,
                    text: 'Grafik keuangan 7 hari, bulanan, dan tahunan',
                  ),
                  _FeatureRow(
                    icon: Icons.summarize_outlined,
                    text: 'Laporan bulanan dengan ekspor PDF dan Excel',
                  ),
                  _FeatureRow(
                    icon: Icons.dark_mode_outlined,
                    text: 'Pilihan tema terang dan gelap',
                  ),
                ],
              ),
              const _SectionTitle('Pengembang'),
              const _InfoCard(
                children: [
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Anggota 1',
                    value: Text('Indra Lasmana Putra\n241510014'),
                  ),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Anggota 2',
                    value: Text('M. Risky Alfianda\n241510048'),
                  ),
                  _InfoRow(
                    icon: Icons.menu_book_outlined,
                    label: 'Mata Kuliah',
                    value: Text('Pemrograman Mobile'),
                  ),
                  _InfoRow(
                    icon: Icons.school_outlined,
                    label: 'Kampus',
                    value: Text('Universitas Putera Batam'),
                  ),
                ],
              ),
              const _SectionTitle('Teknologi'),
              const _InfoCard(
                children: [
                  _InfoRow(
                    icon: Icons.phone_android_rounded,
                    label: 'Aplikasi',
                    value: Text('Flutter (Dart)'),
                  ),
                  _InfoRow(
                    icon: Icons.dns_outlined,
                    label: 'Backend',
                    value: Text('REST API DompetKu'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                '© 2026 DompetKu. All rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.palette.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: context.palette.text,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.palette.surface,
      border: Border.all(color: context.palette.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0)
            Divider(height: 1, indent: 50, color: context.palette.border),
          children[index],
        ],
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Icon(icon, size: 20, color: context.palette.accent),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(color: context.palette.secondaryText, fontSize: 13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.right,
            style: TextStyle(
              color: context.palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            child: value,
          ),
        ),
      ],
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Icon(icon, size: 20, color: context.palette.accent),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: context.palette.text, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
