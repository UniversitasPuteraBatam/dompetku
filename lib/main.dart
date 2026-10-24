import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await ThemeController.load();
  runApp(MyApp(themeController: themeController));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.authService, this.themeController});

  final AuthService? authService;
  final ThemeController? themeController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final _themeController = widget.themeController ?? ThemeController();

  @override
  void dispose() {
    if (widget.themeController == null) _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = widget.authService;
    return ThemeScope(
      controller: _themeController,
      child: ListenableBuilder(
        listenable: _themeController,
        builder: (context, child) => MaterialApp(
          title: 'DompetKu',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeController.mode,
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
        ),
      ),
    );
  }
}
