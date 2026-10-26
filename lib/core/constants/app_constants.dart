/// Application-wide constants
class AppConstants {
  static const String appName = 'Paisa';
  static const String appVersion = '1.0.0';

  // Transaction Types
  static const String typeIncome = 'income';
  static const String typeExpense = 'expense';

  // Wallets / Payment Methods
  static const String walletCash = 'Cash';
  static const String walletUpi = 'UPI';

  // Expense Categories
  static const List<String> expenseCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Education',
    'Entertainment',
    'Healthcare',
    'Others',
  ];

  // Income Sources
  static const List<String> incomeSources = [
    'Salary',
    'Freelance',
    'Business',
    'Investments',
    'Gift',
    'Others',
  ];
}
