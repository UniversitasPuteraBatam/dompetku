import 'package:dompetku/data/user_profile.dart';
import 'package:dompetku/screens/about_screen.dart';
import 'package:dompetku/screens/profile_screen.dart';
import 'package:dompetku/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile menu preserves actions and cancels logout safely', (
    WidgetTester tester,
  ) async {
    var editTapped = false;
    var settingsTapped = false;
    var aboutTapped = false;
    var logoutCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            profile: const UserProfile(
              name: 'Nadia Putri',
              email: 'nadia@example.com',
            ),
            onEdit: () => editTapped = true,
            onSettings: () => settingsTapped = true,
            onAbout: () => aboutTapped = true,
            onLogout: () async => logoutCount++,
          ),
        ),
      ),
    );

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Nadia Putri'), findsOneWidget);
    expect(find.text('nadia@example.com'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Edit Profile'));
    await tester.tap(find.widgetWithText(ListTile, 'Pengaturan'));
    await tester.tap(find.widgetWithText(ListTile, 'Tentang DompetKu'));
    expect(editTapped, isTrue);
    expect(settingsTapped, isTrue);
    expect(aboutTapped, isTrue);

    await tester.tap(find.widgetWithText(ListTile, 'Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Logout dari DompetKu?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Profil'), findsOneWidget);
    expect(logoutCount, 0);
  });

  testWidgets('settings opens the existing password-change action', (
    WidgetTester tester,
  ) async {
    var changePasswordTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          onChangePassword: () => changePasswordTapped = true,
        ),
      ),
    );

    expect(find.text('Tema terang'), findsOneWidget);
    expect(find.textContaining('Tema gelap belum tersedia'), findsOneWidget);
    await tester.tap(find.text('Ganti Password'));
    expect(changePasswordTapped, isTrue);
  });

  testWidgets('about page displays app identity and configured app version', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AboutScreen(loadVersion: () async => '1.0.0+1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tentang DompetKu'), findsOneWidget);
    expect(find.text('DompetKu'), findsOneWidget);
    expect(find.text('1.0.0+1'), findsOneWidget);
    expect(
      find.textContaining('Aplikasi pencatat keuangan pribadi'),
      findsOneWidget,
    );
  });
}
