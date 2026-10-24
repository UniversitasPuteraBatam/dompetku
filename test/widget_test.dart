// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dompetku/main.dart';
import 'package:dompetku/services/app_clock.dart';
import 'package:dompetku/services/auth_service.dart';
import 'package:dompetku/screens/change_password_screen.dart';
import 'package:dompetku/screens/home_screen.dart';
import 'package:dompetku/screens/login_screen.dart';
import 'package:dompetku/screens/settings_screen.dart';
import 'package:dompetku/widgets/profile_avatar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('splash screen opens before login', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(authService: _testAuthService()));

    expect(find.text('DompetKu'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang'), findsOneWidget);
    expect(find.text('Masuk ke akun DompetKu kamu'), findsOneWidget);
  });

  testWidgets('splash restores a saved login session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auth_session': jsonEncode({
        'id': 1,
        'name': 'Rizky Pratama',
        'email': 'rizky@email.com',
        'profile_photo': null,
        'token': 'saved-jwt-token',
      }),
    });
    await tester.pumpWidget(MyApp(authService: _testAuthService()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Total Saldo'), findsOneWidget);
    expect(find.text('Rizky Pratama'), findsOneWidget);
  });

  testWidgets('API login opens dashboard and profile can log out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(authService: _testAuthService()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'rizky@email.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Total Saldo'), findsOneWidget);
    expect(find.text('Transaksi Terbaru'), findsOneWidget);

    await tester.tap(find.text('Profil').first);
    await tester.pumpAndSettle();
    expect(find.text('rizky@email.com'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Logout dari DompetKu?'), findsOneWidget);
    await tester.tap(find.text('Logout').last);
    await tester.pumpAndSettle();
    expect(find.text('Selamat Datang'), findsOneWidget);
  });

  testWidgets('Home and Profile show user data returned by the login API', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(authService: _testAuthService(name: 'Indra')),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'indra@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('Indra'), findsOneWidget);

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Indra'), findsOneWidget);
    expect(find.text('indra@gmail.com'), findsOneWidget);

    await tester.ensureVisible(find.text('Pengaturan'));
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('Tema terang'), findsOneWidget);
    await tester.tap(find.text('Ganti Password'));
    await tester.pumpAndSettle();
    expect(find.text('Password lama'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Tentang DompetKu'));
    await tester.tap(find.text('Tentang DompetKu'));
    await tester.pumpAndSettle();
    expect(find.text('Tentang DompetKu'), findsOneWidget);
    expect(find.textContaining('Versi aplikasi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(ListTile, 'Logout'));
    await tester.tap(find.widgetWithText(ListTile, 'Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout').last);
    await tester.pumpAndSettle();
    expect(
      await const FlutterSecureStorage().read(key: 'auth_session'),
      isNull,
    );
  });

  testWidgets('Home restores its profile from the saved API session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auth_session': jsonEncode({
        'id': 2,
        'name': 'Indra',
        'email': 'indra@gmail.com',
        'profile_photo': null,
        'token': 'saved-jwt-token',
      }),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(authService: _testAuthService(name: 'Indra')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Indra'), findsOneWidget);
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('indra@gmail.com'), findsOneWidget);
  });

  testWidgets('invalid session on initial dashboard redirects to Login', (
    WidgetTester tester,
  ) async {
    final authService = AuthService(
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 1,
                'name': 'Indra',
                'email': 'indra@gmail.com',
                'profile_photo': null,
                'token': 'expired-token',
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'success': false, 'message': 'Token tidak valid'}),
          401,
        );
      }),
      baseUrl: 'http://localhost:3000',
    );
    await tester.pumpWidget(MyApp(authService: authService));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'indra@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: 'auth_session'),
      isNull,
    );
  });

  testWidgets(
    'dashboard loads current totals and recent transactions from API',
    (WidgetTester tester) async {
      var transactionGetCount = 0;
      final authService = AuthService(
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/login') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 1,
                  'name': 'Indra',
                  'email': 'indra@gmail.com',
                  'profile_photo': null,
                  'token': 'test-jwt-token',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/api/transactions' &&
              request.method == 'GET') {
            transactionGetCount++;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 21,
                    'type': 'income',
                    'category': 'Freelance',
                    'amount': 70000,
                    'description': 'Data dashboard terbaru',
                    'transaction_date': AppClock.dateString(AppClock.now()),
                  },
                  {
                    'id': 22,
                    'type': 'expense',
                    'category': 'Makanan',
                    'amount': 12000,
                    'description': 'Pengeluaran API',
                    'transaction_date': AppClock.dateString(AppClock.now()),
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'success': false, 'message': 'Unexpected request'}),
            500,
          );
        }),
        baseUrl: 'http://localhost:3000',
      );
      await tester.pumpWidget(MyApp(authService: authService));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'indra@gmail.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(transactionGetCount, 1);
      expect(find.text('Rp 58.000'), findsOneWidget);
      expect(find.text('Rp 70.000'), findsOneWidget);
      expect(find.text('Rp 12.000'), findsOneWidget);
      expect(find.text('Data dashboard terbaru'), findsOneWidget);
      expect(find.text('Gaji bulanan'), findsNothing);
    },
  );

  testWidgets(
    'financial chart uses API transactions and refreshes after delete',
    (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(authService: _testAuthService()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'rizky@email.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grafik Keuangan'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Transaksi').last, findsOneWidget);
      expect(find.text('Laporan'), findsOneWidget);
      expect(find.text('Profil').last, findsOneWidget);
      expect(find.text('Pemasukan & Pengeluaran'), findsOneWidget);
      expect(find.text('Rp 5.850.000'), findsOneWidget);
      expect(find.text('Rp 488.000'), findsOneWidget);
      expect(find.text('Rp 5.362.000'), findsOneWidget);

      await tester.tap(find.byTooltip('Laporan Bulanan'));
      await tester.pumpAndSettle();
      expect(find.text('Laporan Keuangan'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transaksi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aksi transaksi').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hapus').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grafik Keuangan'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 850.000'), findsOneWidget);
      expect(find.text('Rp 488.000'), findsOneWidget);
      expect(find.text('Rp 362.000'), findsOneWidget);
    },
  );

  testWidgets('saved income appears in transactions and updates totals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(authService: _testAuthService()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'rizky@email.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transaksi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Transaksi'));
    await tester.pumpAndSettle();

    final incomeType = find.descendant(
      of: find.byType(SegmentedButton<bool>),
      matching: find.text('Pemasukan'),
    );
    await tester.tap(incomeType);
    await tester.pumpAndSettle();

    final categoryField = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(categoryField);
    await tester.tap(categoryField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gaji').last);
    await tester.pumpAndSettle();

    final amountField = find.byType(TextFormField).first;
    await tester.ensureVisible(amountField);
    await tester.enterText(amountField, '100000');
    await tester.ensureVisible(find.text('Pilih tanggal'));
    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Gaji'), findsOneWidget);
    expect(find.text('+Rp 100.000'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('Rp 5.950.000'), findsOneWidget);
    expect(find.text('Rp 488.000'), findsOneWidget);
    expect(find.text('Rp 5.462.000'), findsOneWidget);
    expect(find.text('Rp 5.462.000'), findsOneWidget);

    await tester.tap(find.text('Transaksi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Transaksi'));
    await tester.pumpAndSettle();

    final expenseType = find.descendant(
      of: find.byType(SegmentedButton<bool>),
      matching: find.text('Pengeluaran'),
    );
    await tester.ensureVisible(expenseType);
    await tester.tap(expenseType);
    await tester.pumpAndSettle();

    final expenseCategoryField = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(expenseCategoryField);
    await tester.tap(expenseCategoryField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makanan').last);
    await tester.pumpAndSettle();

    final expenseAmountField = find.byType(TextFormField).first;
    await tester.ensureVisible(expenseAmountField);
    await tester.enterText(expenseAmountField, '25000');
    await tester.ensureVisible(find.text('Pilih tanggal'));
    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('-Rp 25.000'), findsOneWidget);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('Rp 513.000'), findsOneWidget);
    expect(find.text('Rp 5.437.000'), findsOneWidget);
  });

  testWidgets('editing transaction saves the newly selected date via API', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        authService: _testAuthService(
          firstTransactionDate: DateTime.utc(2026, 10, 1, 22, 35),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'rizky@email.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transaksi').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aksi transaksi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Transaksi'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Transaksi'), findsOneWidget);
    expect(find.text('Gaji'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      '5000000',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller
          ?.text,
      'Gaji bulanan',
    );
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {true},
    );
    await tester.scrollUntilVisible(
      find.text('1 Okt 2026, 22:35'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('1 Okt 2026, 22:35'), findsOneWidget);

    await tester.tap(find.text('1 Okt 2026, 22:35'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
    expect(find.text('15 Okt 2026, 22:35'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Simpan'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Gaji · 15 Okt 2026, 22:35'), findsOneWidget);
  });

  testWidgets(
    'deleting a transaction requires confirmation and updates totals',
    (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(authService: _testAuthService()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'rizky@email.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transaksi').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Aksi transaksi').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();
      expect(find.text('Hapus transaksi ini?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Gaji bulanan'), findsOneWidget);

      await tester.tap(find.byTooltip('Aksi transaksi').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();
      expect(find.text('Hapus transaksi ini?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Hapus').last);
      await tester.pumpAndSettle();
      expect(find.text('Gaji bulanan'), findsNothing);

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.text('Rp 850.000'), findsOneWidget);
      expect(find.text('Rp 488.000'), findsOneWidget);
      expect(find.text('Rp 362.000'), findsOneWidget);
    },
  );

  testWidgets('editing profile validates and updates Profile and Home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(authService: _testAuthService()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'rizky@email.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_rounded), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ListTile, 'Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Ganti Password'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      'Rizky Pratama',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller
          ?.text,
      'rizky@email.com',
    );

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama wajib diisi'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Nadia Putri');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Nadia Putri'), findsOneWidget);
    expect(find.text('rizky@email.com'), findsOneWidget);
    expect(find.text('Profil berhasil diperbarui'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('Nadia Putri'), findsOneWidget);

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Logout'));
    tester
        .widget<ListTile>(find.widgetWithText(ListTile, 'Logout'))
        .onTap!
        .call();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'rizky@email.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('Nadia Putri'), findsOneWidget);
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Nadia Putri'), findsOneWidget);
  });

  testWidgets('selected profile photo uploads and is restored from the server', (
    WidgetTester tester,
  ) async {
    final photoBytes = Uint8List.fromList(_testPngBytes);
    SharedPreferences.setMockInitialValues({
      'auth_session': jsonEncode({
        'id': 1,
        'name': 'Rizky Pratama',
        'email': 'rizky@email.com',
        'profile_photo': null,
        'token': 'test-jwt-token',
      }),
    });
    final authService = _testAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          user: const AuthUser(
            id: 1,
            name: 'Rizky Pratama',
            email: 'rizky@email.com',
            token: 'test-jwt-token',
          ),
          authService: authService,
          photoPicker: () async => photoBytes,
        ),
        routes: {
          '/login': (context) => LoginScreen(authService: authService),
          '/home': (context) => HomeScreen(authService: authService),
        },
      ),
    );

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ProfileAvatar).first,
        matching: find.byIcon(Icons.person_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ListTile, 'Edit Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih Foto'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar).first).photoBytes,
      same(photoBytes),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pumpAndSettle();

    for (final tab in ['Home', 'Transaksi', 'Laporan', 'Profil']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      if (tab == 'Profil') {
        final avatar = tester.widget<ProfileAvatar>(
          find.byType(ProfileAvatar).first,
        );
        expect(avatar.photoBytes, same(photoBytes));
      }
    }

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'rizky@email.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    // After logging in again the photo comes from the server, not the device.
    final restoredPhoto = tester.widget<ProfileAvatar>(
      find.byType(ProfileAvatar).first,
    );
    expect(restoredPhoto.photoBytes, isNull);
    expect(restoredPhoto.photoUrl, endsWith('/uploads/profile/1-photo.png'));
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Rizky Pratama'), findsOneWidget);
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar).first).photoUrl,
      endsWith('/uploads/profile/1-photo.png'),
    );

    await tester.tap(find.widgetWithText(ListTile, 'Edit Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Foto Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pumpAndSettle();
    final removedPhoto = tester.widget<ProfileAvatar>(
      find.byType(ProfileAvatar).first,
    );
    expect(removedPhoto.photoBytes, isNull);
    expect(removedPhoto.photoUrl, isNull);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('profile_photo_1'), isFalse);
  });

  testWidgets('change password screen validates and sends password update', (
    WidgetTester tester,
  ) async {
    final authService = _testAuthService();
    SharedPreferences.setMockInitialValues({
      'auth_session': jsonEncode({
        'id': 1,
        'name': 'Rizky Pratama',
        'email': 'rizky@email.com',
        'profile_photo': null,
        'token': 'test-jwt-token',
      }),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => SettingsScreen(
            onChangePassword: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      ChangePasswordScreen(authService: authService),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ganti Password'));
    await tester.pumpAndSettle();
    expect(find.text('Ganti Password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Password berhasil diperbarui'), findsOneWidget);
  });
}

AuthService _testAuthService({
  String name = 'Rizky Pratama',
  DateTime? firstTransactionDate,
}) {
  final today = AppClock.now();
  final transactions = <Map<String, dynamic>>[
    {
      'id': 1,
      'type': 'income',
      'category': 'Gaji',
      'amount': 5000000,
      'description': 'Gaji bulanan',
      'transaction_date': AppClock.timestampString(
        firstTransactionDate ?? today,
      ),
    },
    {
      'id': 2,
      'type': 'expense',
      'category': 'Belanja',
      'amount': 450000,
      'description': 'Belanja bulanan',
      'transaction_date': AppClock.timestampString(today),
    },
    {
      'id': 3,
      'type': 'expense',
      'category': 'Makanan',
      'amount': 38000,
      'description': 'Kopi & sarapan',
      'transaction_date': AppClock.timestampString(
        today.subtract(const Duration(days: 1)),
      ),
    },
    {
      'id': 4,
      'type': 'income',
      'category': 'Freelance',
      'amount': 850000,
      'description': 'Freelance desain',
      'transaction_date': AppClock.timestampString(
        today.subtract(const Duration(days: 2)),
      ),
    },
  ];
  final profile = <String, dynamic>{
    'id': 1,
    'name': name,
    'email': name == 'Indra' ? 'indra@gmail.com' : 'rizky@email.com',
    'profile_photo': null,
  };

  return AuthService(
    client: MockClient((request) async {
      if (request.url.path == '/api/auth/login') {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Login berhasil',
            'data': {'id': 1, ...profile, 'token': 'test-jwt-token'},
          }),
          200,
        );
      }
      if (request.url.path == '/api/profile' && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Profil berhasil diambil',
            'data': profile,
          }),
          200,
        );
      }
      if (request.url.path == '/api/profile' && request.method == 'PUT') {
        final updatedProfile = jsonDecode(request.body) as Map<String, dynamic>;
        profile['name'] = updatedProfile['name'];
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Profil berhasil diperbarui',
            'data': profile,
          }),
          200,
        );
      }
      if (request.url.path == '/api/profile/photo') {
        profile['profile_photo'] = request.method == 'POST'
            ? '/uploads/profile/1-photo.png'
            : null;
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Profil berhasil diperbarui',
            'data': profile,
          }),
          200,
        );
      }
      if (request.url.path == '/api/auth/change-password' &&
          request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Password berhasil diperbarui',
          }),
          200,
        );
      }
      if (request.url.path == '/api/transactions' && request.method == 'GET') {
        return http.Response(
          jsonEncode({'success': true, 'data': transactions}),
          200,
        );
      }
      if (request.url.path == '/api/transactions' && request.method == 'POST') {
        final transaction = jsonDecode(request.body) as Map<String, dynamic>;
        transactions.insert(0, {'id': transactions.length + 1, ...transaction});
        return http.Response(
          jsonEncode({'success': true, 'message': 'Transaksi berhasil'}),
          201,
        );
      }
      if (request.url.path.startsWith('/api/transactions/') &&
          request.method == 'PUT') {
        final id = int.parse(request.url.path.split('/').last);
        final index = transactions.indexWhere((row) => row['id'] == id);
        if (index == -1) {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'Transaksi tidak ditemukan',
            }),
            404,
          );
        }
        transactions[index] = {
          'id': id,
          ...(jsonDecode(request.body) as Map<String, dynamic>),
        };
        return http.Response(
          jsonEncode({'success': true, 'message': 'Transaksi diperbarui'}),
          200,
        );
      }
      if (request.url.path.startsWith('/api/transactions/') &&
          request.method == 'DELETE') {
        final id = int.parse(request.url.path.split('/').last);
        final index = transactions.indexWhere((row) => row['id'] == id);
        if (index == -1) {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'Transaksi tidak ditemukan',
            }),
            404,
          );
        }
        transactions.removeAt(index);
        return http.Response(
          jsonEncode({'success': true, 'message': 'Transaksi dihapus'}),
          200,
        );
      }
      return http.Response(
        jsonEncode({'success': false, 'message': 'Unexpected test request'}),
        500,
      );
    }),
    baseUrl: 'http://localhost:3000',
  );
}

const _testPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x60,
  0x60,
  0x60,
  0x60,
  0x00,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0xA5,
  0xF6,
  0x45,
  0x40,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
