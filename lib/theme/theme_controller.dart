import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the chosen light/dark/system theme and remembers it on the device.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initialMode = ThemeMode.system})
    : _mode = initialMode;

  static const _preferenceKey = 'theme_mode';

  ThemeMode _mode;
  ThemeMode get mode => _mode;

  /// Reads the saved choice; falls back to following the system setting.
  static Future<ThemeController> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_preferenceKey);
      final mode = ThemeMode.values.firstWhere(
        (value) => value.name == saved,
        orElse: () => ThemeMode.system,
      );
      return ThemeController(initialMode: mode);
    } catch (_) {
      return ThemeController();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, mode.name);
  }
}

/// Makes the [ThemeController] reachable from any screen, e.g. Settings.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
