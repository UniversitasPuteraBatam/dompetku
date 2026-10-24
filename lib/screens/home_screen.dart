import 'package:flutter/material.dart';

import '../data/dummy_transactions.dart';
import '../data/user_profile.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';
import 'about_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'financial_chart_screen.dart';
import 'monthly_financial_report_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import '../services/auth_service.dart';
import '../services/app_clock.dart';
import '../widgets/profile_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.photoPicker, this.user, this.authService});

  final ProfilePhotoPicker? photoPicker;
  final AuthUser? user;
  final AuthService? authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final _authService = widget.authService ?? AuthService();
  late final _transactionStore = TransactionStore(initialTransactions: []);
  UserProfile _profile = const UserProfile(name: '', email: '');
  bool _isLoadingTransactions = false;
  bool _hasLoadedTransactions = false;
  String? _transactionsError;
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user != null) _profile = _profileFromUser(user);
    _loadTransactions();
    if (user == null) _restoreProfileFromSession();
  }

  /// Keeps a photo picked in this session while its server URL is unchanged,
  /// so it is not downloaded again right after uploading.
  UserProfile _profileFromUser(AuthUser user) {
    final photoUrl = _authService.resolvePhotoUrl(user.profilePhoto);
    final keepsPhoto = photoUrl != null && photoUrl == _profile.profilePhoto;
    return UserProfile(
      name: user.name,
      email: user.email,
      photoBytes: keepsPhoto ? _profile.photoBytes : null,
      profilePhoto: photoUrl,
    );
  }

  Future<void> _restoreProfileFromSession() async {
    final user = await _authService.getSavedUser();
    if (!mounted || user == null) return;
    setState(() => _profile = _profileFromUser(user));
  }

  Future<void> _loadProfile() async {
    if (_isLoadingProfile) return;
    _isLoadingProfile = true;
    try {
      final savedUser = await _authService.getSavedUser();
      if (!mounted || savedUser == null) return;
      setState(() => _profile = _profileFromUser(savedUser));

      final user = await _authService.getProfile();
      if (!mounted) return;
      setState(() => _profile = _profileFromUser(user));
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil tidak dapat dimuat. Periksa koneksi.'),
        ),
      );
    } finally {
      _isLoadingProfile = false;
    }
  }

  void _openProfile() {
    final wasOnProfile = _selectedIndex == 3;
    setState(() => _selectedIndex = 3);
    if (!wasOnProfile) _loadProfile();
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout gagal. Silakan coba lagi.')),
      );
    }
  }

  Future<void> _loadTransactions() async {
    if (_isLoadingTransactions) return;
    setState(() {
      _isLoadingTransactions = true;
      _transactionsError = null;
    });
    try {
      final transactions = await _authService.getTransactions();
      if (!mounted) return;
      _transactionStore.replaceAll(transactions);
      _hasLoadedTransactions = true;
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }
      setState(() => _transactionsError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _transactionsError =
            'Riwayat transaksi tidak dapat dimuat. Periksa koneksi lalu coba lagi.',
      );
    } finally {
      if (mounted) setState(() => _isLoadingTransactions = false);
    }
  }

  Future<void> _editProfile() async {
    final updatedProfile = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          profile: _profile,
          authService: _authService,
          photoPicker: widget.photoPicker,
        ),
      ),
    );
    if (!mounted || updatedProfile == null) return;
    setState(() => _profile = updatedProfile);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui')));
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          onChangePassword: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (context) =>
                    ChangePasswordScreen(authService: _authService),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAbout() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (context) => const AboutScreen()));
  }

  Future<void> _editTransaction(int index) async {
    final currentTransaction = _transactionStore.transactions[index];
    final updatedTransaction = await Navigator.of(context)
        .push<TransactionItem>(
          MaterialPageRoute(
            builder: (context) => AddTransactionScreen(
              transaction: currentTransaction,
              authService: _authService,
            ),
          ),
        );
    if (!mounted || updatedTransaction == null) return;
    await _loadTransactions();
    if (!mounted) return;
    if (_transactionsError != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi berhasil diperbarui')),
    );
  }

  Future<void> _deleteTransaction(int index) async {
    final transaction = _transactionStore.transactions[index];
    final id = transaction.id;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID transaksi tidak tersedia. Muat ulang riwayat.'),
        ),
      );
      return;
    }

    try {
      await _authService.deleteTransaction(id: id);
      if (!mounted) return;
      await _loadTransactions();
      if (!mounted) return;
      if (_transactionsError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_transactionsError!)));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil dihapus')),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server. Periksa koneksi.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _transactionStore.dispose();
    super.dispose();
  }

  Future<void> _addTransaction() async {
    final transaction = await Navigator.of(context).push<TransactionItem>(
      MaterialPageRoute(
        builder: (context) =>
            AddTransactionScreen(authService: _authService),
      ),
    );
    if (!mounted || transaction == null) return;
    await _loadTransactions();
    if (!mounted) return;
    if (_transactionsError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_transactionsError!)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi berhasil ditambahkan')),
    );
  }

  Future<void> _openFinancialChart() async {
    final wasOnReports = _selectedIndex == 2;
    setState(() => _selectedIndex = 2);
    if (!wasOnReports && !_hasLoadedTransactions) {
      await _loadTransactions();
    }
  }

  Future<String?> _refreshFinancialChart() async {
    await _loadTransactions();
    return _transactionsError;
  }

  Future<void> _openMonthlyReport() async {
    if (!_hasLoadedTransactions && !_isLoadingTransactions) {
      await _loadTransactions();
      if (!mounted) return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => MonthlyFinancialReportScreen(
          store: _transactionStore,
          isLoading: _isLoadingTransactions && !_hasLoadedTransactions,
          errorMessage: _transactionsError,
          onRefresh: _refreshFinancialChart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardScreen(
        profile: _profile,
        store: _transactionStore,
        onProfileTap: _openProfile,
        onTransactionsTap: () => setState(() => _selectedIndex = 1),
        onFinancialChartTap: _openFinancialChart,
        onMonthlyReportTap: _openMonthlyReport,
      ),
      TransactionsScreen(
        store: _transactionStore,
        profile: _profile,
        isLoading: _isLoadingTransactions && !_hasLoadedTransactions,
        errorMessage: _transactionsError,
        onRefresh: _loadTransactions,
        onProfileTap: _openProfile,
        onEditTransaction: _editTransaction,
        onDeleteTransaction: _deleteTransaction,
      ),
      FinancialChartScreen(
        store: _transactionStore,
        isLoading: _isLoadingTransactions && !_hasLoadedTransactions,
        errorMessage: _transactionsError,
        onRefresh: _refreshFinancialChart,
        onMonthlyReportTap: _openMonthlyReport,
      ),
      ProfileScreen(
        profile: _profile,
        onEdit: _editProfile,
        onSettings: _openSettings,
        onAbout: _openAbout,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _hasLoadedTransactions
                ? pages[0]
                : _DashboardTransactionsState(
                    isLoading: _isLoadingTransactions,
                    errorMessage: _transactionsError,
                    onRetry: _loadTransactions,
                  ),
            pages[1],
            pages[2],
            pages[3],
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _addTransaction,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Transaksi'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          final wasOnTransactions = _selectedIndex == 1;
          final wasOnReports = _selectedIndex == 2;
          final wasOnProfile = _selectedIndex == 3;
          setState(() => _selectedIndex = index);
          if (index == 1 && !wasOnTransactions) _loadTransactions();
          if (index == 2 && !wasOnReports && !_hasLoadedTransactions) {
            _loadTransactions();
          }
          if (index == 3 && !wasOnProfile) _loadProfile();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _DashboardTransactionsState extends StatelessWidget {
  const _DashboardTransactionsState({
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            errorMessage ?? 'Transaksi belum dapat dimuat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({
    required this.profile,
    required this.store,
    required this.onProfileTap,
    required this.onTransactionsTap,
    required this.onFinancialChartTap,
    required this.onMonthlyReportTap,
  });

  final UserProfile profile;
  final TransactionStore store;
  final VoidCallback onProfileTap;
  final VoidCallback onTransactionsTap;
  final Future<void> Function() onFinancialChartTap;
  final Future<void> Function() onMonthlyReportTap;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, child) => LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 600 ? 40.0 : 22.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greetingForJakartaTime(AppClock.now()),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.secondaryText),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Buka profile',
                        onPressed: onProfileTap,
                        icon: ProfileAvatar(
                          photoBytes: profile.photoBytes,
                          photoUrl: profile.profilePhoto,
                          radius: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _BalanceCard(amount: formatRupiah(store.balance)),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, summaryConstraints) {
                      final isWide = summaryConstraints.maxWidth >= 440;
                      final cardWidth = isWide
                          ? (summaryConstraints.maxWidth - 12) / 2
                          : summaryConstraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _SummaryCard(
                              label: 'Pemasukan',
                              amount: formatRupiah(store.totalIncome),
                              icon: Icons.south_west_rounded,
                              color: AppColors.success,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _SummaryCard(
                              label: 'Pengeluaran',
                              amount: formatRupiah(store.totalExpense),
                              icon: Icons.north_east_rounded,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onFinancialChartTap,
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: const Text('Grafik Keuangan'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onMonthlyReportTap,
                      icon: const Icon(Icons.summarize_outlined),
                      label: const Text('Laporan Bulanan'),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Transaksi Terbaru',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: onTransactionsTap,
                        child: const Text('Lihat semua'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final transaction in store.transactions.take(3))
                    TransactionTile(transaction: transaction),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total Saldo',
                style: TextStyle(color: Color(0xFFDCE8FF), fontSize: 14),
              ),
            ),
            Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              Icons.trending_up_rounded,
              color: Color(0xFFBBF7D0),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Saldo saat ini',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.86)),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(height: 14),
        Text(label, style: const TextStyle(color: AppColors.secondaryText)),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
