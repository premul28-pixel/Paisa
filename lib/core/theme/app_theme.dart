import 'package:flutter/material.dart';

/// Material 3 Themes for Paisa Application with dynamic ColorScheme generation
class AppTheme {
  // Default brand colors
  static const Color defaultSeedColor = Color(0xFF10B981); // Emerald Green
  static const Color primaryColor = defaultSeedColor;
  static const Color primaryDark = Color(0xFF047857);
  static const Color secondaryColor = Color(0xFF6366F1); // Indigo
  static const Color incomeColor = Color(0xFF10B981);
  static const Color expenseColor = Color(0xFFEF4444); // Crimson
  static const Color cashColor = Color(0xFFF59E0B); // Amber
  static const Color upiColor = Color(0xFF3B82F6); // Blue

  // Curated preset seed colors for custom theme picker
  static const List<Color> presetColors = [
    Color(0xFF10B981), // Emerald
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF43F5E), // Rose
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFF14B8A6), // Teal
    Color(0xFFE11D48), // Ruby
  ];

  /// Parses a hex color string (e.g. '#10B981' or '0xFF10B981' or '10B981') to Color
  static Color hexToColor(String hex) {
    try {
      final cleanHex = hex.replaceFirst('#', '').replaceFirst('0x', '').trim();
      final buffer = StringBuffer();
      if (cleanHex.length == 6) {
        buffer.write('ff$cleanHex');
      } else if (cleanHex.length == 8) {
        buffer.write(cleanHex);
      } else {
        return defaultSeedColor;
      }
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return defaultSeedColor;
    }
  }

  /// Converts a Color to a hex string format '#RRGGBB'
  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  /// Generates a Material 3 ThemeData with a dynamic ColorScheme seeded from [seedColor].
  static ThemeData buildThemeData({
    required Color seedColor,
    required Brightness brightness,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      error: expenseColor,
    );

    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seedColor, width: 2),
        ),
      ),
    );
  }

  // Pre-configured default light and dark themes
  static ThemeData get lightTheme => buildThemeData(
        seedColor: defaultSeedColor,
        brightness: Brightness.light,
      );

  static ThemeData get darkTheme => buildThemeData(
        seedColor: defaultSeedColor,
        brightness: Brightness.dark,
      );
}
