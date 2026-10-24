import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authService});

  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DompetKu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(authService: authService),
        '/login': (context) => LoginScreen(authService: authService),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) {
          final user = ModalRoute.of(context)?.settings.arguments;
          return HomeScreen(
            user: user is AuthUser ? user : null,
            authService: authService,
          );
        },
      },
    );
  }
}
