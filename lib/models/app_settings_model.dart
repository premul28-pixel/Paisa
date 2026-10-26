class AppSettingsModel {
  final String key;
  final String value;

  const AppSettingsModel({
    required this.key,
    required this.value,
  });

  /// Factory constructor to create an AppSettingsModel instance from an SQLite map.
  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    return AppSettingsModel(
      key: map['key'] as String,
      value: map['value'] as String,
    );
  }

  /// Converts the AppSettingsModel into a Map suitable for SQLite operations.
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
    };
  }

  /// Common setting keys
  static const String keyDarkMode = 'is_dark_mode';
  static const String keyCurrencySymbol = 'currency_symbol';
  static const String keyNotifications = 'notifications_enabled';
  static const String keyLastBackup = 'last_backup_date';

  @override
  String toString() => 'AppSettingsModel(key: $key, value: $value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettingsModel &&
        other.key == key &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(key, value);
}
