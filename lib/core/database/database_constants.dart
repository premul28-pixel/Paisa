/// Database table and column names for Paisa SQLite DB
class DatabaseConstants {
  static const String databaseName = 'paisa.db';
  static const int databaseVersion = 1;

  // Table: users
  static const String tableUsers = 'users';
  static const String colUserId = 'id';
  static const String colUserCustomId = 'user_id';
  static const String colUserPasswordHash = 'password_hash';
  static const String colUserRecoveryPin = 'recovery_pin';
  static const String colUserProfileName = 'profile_name';
  static const String colUserDob = 'dob';
  static const String colUserEmail = 'email';
  static const String colUserPhone = 'phone';

  // Table: app_settings
  static const String tableAppSettings = 'app_settings';
  static const String colSettingKey = 'key';
  static const String colSettingValue = 'value';

  // Table: wallets
  static const String tableWallets = 'wallets';
  static const String colWalletId = 'id';
  static const String colWalletName = 'name';
  static const String colWalletBalance = 'balance';

  // Table: transactions
  static const String tableTransactions = 'transactions';
  static const String colTxId = 'id';
  static const String colTxType = 'type';
  static const String colTxAmount = 'amount';
  static const String colTxDate = 'date';
  static const String colTxSource = 'source';
  static const String colTxCategory = 'category';
  static const String colTxPaymentMethod = 'payment_method';
  static const String colTxNotes = 'notes';
  static const String colTxCreatedAt = 'created_at';
  static const String colTxUpdatedAt = 'updated_at';
}
