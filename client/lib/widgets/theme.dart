import 'package:flutter/material.dart';

/// Design tokens. Editorial "content-first" style: neutral surfaces, one indigo
/// brand colour, violet reserved for AI features. All text pairs meet WCAG AA (4.5:1).
class AppColors {
  static const brand = Color(0xFF4338CA); // indigo-700, 7.9:1 on white
  static const brandDark = Color(0xFFA5B4FC); // indigo-300 for dark surfaces
  static const ai = Color(0xFF6D28D9); // violet-700, AI features
  static const aiDark = Color(0xFFC4B5FD);
  static const like = Color(0xFFE11D48); // rose-600

  static const lightBg = Color(0xFFF8FAFC);
  static const lightSurface = Colors.white;
  static const lightText = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF475569); // 7.5:1 on white
  static const lightOutline = Color(0xFFE2E8F0);

  static const darkBg = Color(0xFF0B1120);
  static const darkSurface = Color(0xFF111827);
  static const darkText = Color(0xFFF1F5F9);
  static const darkMuted = Color(0xFF94A3B8); // 7.0:1 on darkSurface
  static const darkOutline = Color(0xFF1F2937);
}

/// 4/8dp spacing scale.
class Space {
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0;
}

extension ThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get muted => isDark ? AppColors.darkMuted : AppColors.lightMuted;
  Color get aiColor => isDark ? AppColors.aiDark : AppColors.ai;
}

class AppTheme {
  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: b,
    ).copyWith(
      primary: dark ? AppColors.brandDark : AppColors.brand,
      onPrimary: dark ? const Color(0xFF1E1B4B) : Colors.white,
      surface: dark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: dark ? AppColors.darkText : AppColors.lightText,
      onSurfaceVariant: dark ? AppColors.darkMuted : AppColors.lightMuted,
      outlineVariant: dark ? AppColors.darkOutline : AppColors.lightOutline,
      error: dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
    );
    final textColor = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    final text = TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, color: textColor, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25, color: textColor, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, color: textColor),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35, color: textColor),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35, color: textColor),
      bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: textColor),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: muted),
      labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted, letterSpacing: 0.2),
    );

    final radius = BorderRadius.circular(14);
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: dark ? AppColors.darkBg : AppColors.lightBg,
      appBarTheme: AppBarThemeData(
        backgroundColor: dark ? AppColors.darkBg : AppColors.lightBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: dark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.error, width: 2)),
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: muted),
        prefixIconColor: muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? scheme.primary : muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : muted)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 20),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: error ? const Color(0xFFB91C1C) : const Color(0xFF1E293B),
    ));
}
