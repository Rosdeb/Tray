import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const _seedColor = Color(0xFF0F766E);

  static const _fontFamily = '.AppleSystemUIFont';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
      surface: isDark ? const Color(0xFF161616) : const Color(0xFFF8F8F8),
      onSurface: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF18181B),
      surfaceContainerLowest: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF4F4F5),
      surfaceContainer: isDark ? const Color(0xFF212121) : const Color(0xFFEFEFEF),
      surfaceContainerHigh: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
      outline: isDark ? const Color(0xFF333333) : const Color(0xFFD4D4D8),
      outlineVariant: isDark ? const Color(0xFF262626) : const Color(0xFFE4E4E7),
    );

    final textTheme = _textTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: _fontFamily,
      visualDensity: VisualDensity.compact,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
        space: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(32, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      dialogTheme: DialogThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFFE4E4E7) : Colors.white,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
      ),

      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(6),
        thumbColor: WidgetStateProperty.all(
          colorScheme.onSurface.withValues(alpha: 0.15),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(fontSize: 13, color: colorScheme.onSurface),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: colorScheme.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: colorScheme.outlineVariant,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: colorScheme.surfaceContainerHigh,
        linearMinHeight: 3,
      ),

      navigationRailTheme: NavigationRailThemeData(
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme cs) {
    return TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.3),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
      bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: cs.onSurface),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: cs.onSurface.withValues(alpha: 0.65)),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.65)),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.5)),
    );
  }
}
