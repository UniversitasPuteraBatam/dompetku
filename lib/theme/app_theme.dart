import 'package:flutter/material.dart';

/// Brand colors that read well on both the light and the dark theme.
/// Colors that depend on the theme live in [AppPalette].
abstract final class AppColors {
  static const primary = Color(0xFF2563EB);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
}

/// Theme-dependent colors, read with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.text,
    required this.secondaryText,
    required this.border,
    required this.primarySoft,
    required this.primarySoftBorder,
    required this.dangerSoft,
    required this.dangerTrack,
    required this.accent,
    required this.success,
    required this.danger,
  });

  /// Page background.
  final Color background;

  /// Cards, tiles and input fields.
  final Color surface;
  final Color text;
  final Color secondaryText;
  final Color border;

  /// Info boxes, icon chips and the avatar background.
  final Color primarySoft;
  final Color primarySoftBorder;

  /// Danger icon chip background.
  final Color dangerSoft;

  /// Track behind expense progress bars.
  final Color dangerTrack;

  /// Brand blue, green and red for text, icons and chart bars on a surface;
  /// lighter in the dark theme so they keep enough contrast.
  final Color accent;
  final Color success;
  final Color danger;

  static const light = AppPalette(
    background: Color(0xFFF8FAFC),
    surface: Colors.white,
    text: Color(0xFF0F172A),
    secondaryText: Color(0xFF64748B),
    border: Color(0xFFE2E8F0),
    primarySoft: Color(0xFFEFF6FF),
    primarySoftBorder: Color(0xFFDBEAFE),
    dangerSoft: Color(0xFFFEF2F2),
    dangerTrack: Color(0xFFFEE2E2),
    accent: AppColors.primary,
    success: AppColors.success,
    danger: AppColors.danger,
  );

  static const dark = AppPalette(
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    text: Color(0xFFF1F5F9),
    secondaryText: Color(0xFF94A3B8),
    border: Color(0xFF334155),
    primarySoft: Color(0xFF172554),
    primarySoftBorder: Color(0xFF1E3A8A),
    dangerSoft: Color(0xFF450A0A),
    dangerTrack: Color(0xFF7F1D1D),
    accent: Color(0xFF60A5FA),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFF87171),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? text,
    Color? secondaryText,
    Color? border,
    Color? primarySoft,
    Color? primarySoftBorder,
    Color? dangerSoft,
    Color? dangerTrack,
    Color? accent,
    Color? success,
    Color? danger,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    text: text ?? this.text,
    secondaryText: secondaryText ?? this.secondaryText,
    border: border ?? this.border,
    primarySoft: primarySoft ?? this.primarySoft,
    primarySoftBorder: primarySoftBorder ?? this.primarySoftBorder,
    dangerSoft: dangerSoft ?? this.dangerSoft,
    dangerTrack: dangerTrack ?? this.dangerTrack,
    accent: accent ?? this.accent,
    success: success ?? this.success,
    danger: danger ?? this.danger,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      border: Color.lerp(border, other.border, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primarySoftBorder: Color.lerp(
        primarySoftBorder,
        other.primarySoftBorder,
        t,
      )!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      dangerTrack: Color.lerp(dangerTrack, other.dangerTrack, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppPalette.light);
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          error: AppColors.danger,
          surface: palette.background,
          onSurface: palette.text,
        );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: palette.border),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        elevation: 0,
      ),
      cardTheme: CardThemeData(color: palette.surface),
      dialogTheme: DialogThemeData(backgroundColor: palette.surface),
      listTileTheme: ListTileThemeData(
        textColor: palette.text,
        iconColor: palette.secondaryText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
