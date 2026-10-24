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
    return buildNumber.isEmpty
        ? info.version
        : '${info.version}+$buildNumber';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tentang DompetKu')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 28),
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
              const SizedBox(height: 18),
              Text(
                'DompetKu',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Aplikasi pencatat keuangan pribadi untuk membantu memantau pemasukan, pengeluaran, dan laporan keuangan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Versi aplikasi'),
                  subtitle: FutureBuilder<String>(
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
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
