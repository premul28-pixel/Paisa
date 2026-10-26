import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../services/sqlite_service.dart';

/// State representation for app theme and color customization
class ThemeState {
  final ThemeMode themeMode;
  final Color customColor;
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  const ThemeState({
    required this.themeMode,
    required this.customColor,
    required this.lightTheme,
    required this.darkTheme,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    Color? customColor,
  }) {
    final color = customColor ?? this.customColor;
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      customColor: color,
      lightTheme: AppTheme.buildThemeData(
        seedColor: color,
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.buildThemeData(
        seedColor: color,
        brightness: Brightness.dark,
      ),
    );
  }
}

/// ThemeNotifier manages theme mode (light/dark/system) and custom seed color,
/// reading from and persisting to SQLite app_settings.
class ThemeNotifier extends StateNotifier<ThemeState> {
  final SqliteService _sqliteService;

  static const String keyThemeMode = 'theme_mode';
  static const String keyCustomColor = 'custom_color';

  ThemeNotifier({SqliteService? sqliteService})
      : _sqliteService = sqliteService ?? SqliteService(),
        super(
          ThemeState(
            themeMode: ThemeMode.system,
            customColor: AppTheme.defaultSeedColor,
            lightTheme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
          ),
        ) {
    _loadThemeFromSettings();
  }

  /// Loads saved theme preferences from SQLite app_settings
  Future<void> _loadThemeFromSettings() async {
    try {
      final savedMode = await _sqliteService.getSetting(keyThemeMode);
      final savedColorHex = await _sqliteService.getSetting(keyCustomColor);

      ThemeMode mode = ThemeMode.system;
      if (savedMode == 'light') {
        mode = ThemeMode.light;
      } else if (savedMode == 'dark') {
        mode = ThemeMode.dark;
      }

      Color color = AppTheme.defaultSeedColor;
      if (savedColorHex != null && savedColorHex.isNotEmpty) {
        color = AppTheme.hexToColor(savedColorHex);
      }

      state = ThemeState(
        themeMode: mode,
        customColor: color,
        lightTheme: AppTheme.buildThemeData(
          seedColor: color,
          brightness: Brightness.light,
        ),
        darkTheme: AppTheme.buildThemeData(
          seedColor: color,
          brightness: Brightness.dark,
        ),
      );
    } catch (_) {
      // Fallback to default state on any database retrieval issue
    }
  }

  /// Updates theme mode (Light, Dark, System) and persists to SQLite
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _sqliteService.setSetting(keyThemeMode, mode.name);
  }

  /// Updates custom theme seed color, regenerates ColorScheme, and persists to SQLite
  Future<void> setCustomColor(Color color) async {
    state = state.copyWith(customColor: color);
    await _sqliteService.setSetting(
      keyCustomColor,
      AppTheme.colorToHex(color),
    );
  }
}

/// Global provider for application theme state
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
