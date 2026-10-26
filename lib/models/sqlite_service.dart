import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/user_model.dart';
import '../models/app_settings_model.dart';

class SqliteService {
  static final SqliteService _instance = SqliteService._internal();
  factory SqliteService() => _instance;
  SqliteService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'paisa_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        recovery_pin TEXT NOT NULL,
        profile_name TEXT NOT NULL,
        dob TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');

    // 2. Create app_settings table
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 3. Create wallets table
    await db.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        balance REAL NOT NULL DEFAULT 0
      )
    ''');

    // 4. Create transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        source TEXT,
        category TEXT,
        payment_method TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // 5. Create Indexes for fast querying
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
    await db.execute('CREATE INDEX idx_transactions_payment_method ON transactions(payment_method)');

    // 6. Initialize default wallets
    await db.insert('wallets', {'name': 'Cash', 'balance': 0.0});
    await db.insert('wallets', {'name': 'UPI', 'balance': 0.0});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here
  }

  // ==========================================
  // TRANSACTION CRUD OPERATIONS
  // ==========================================

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    int id = await db.insert('transactions', transaction.toMap());

    // Update wallet balance immediately
    await _updateWalletBalance(
      transaction.paymentMethod,
      transaction.isIncome ? transaction.amount : -transaction.amount,
    );

    return id;
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;

    // CRITICAL: Load the original transaction to reverse its effect FIRST
    final oldTransaction = await getTransactionById(transaction.id!);
    if (oldTransaction != null) {
      double oldAmount = oldTransaction.isIncome ? oldTransaction.amount : -oldTransaction.amount;
      await _updateWalletBalance(oldTransaction.paymentMethod, -oldAmount);
    }

    // Update the transaction record
    int result = await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );

    // CRITICAL: Apply the NEW transaction's effect
    double newAmount = transaction.isIncome ? transaction.amount : -transaction.amount;
    await _updateWalletBalance(transaction.paymentMethod, newAmount);

    return result;
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;

    // CRITICAL: Load transaction to reverse its effect before deleting
    final transaction = await getTransactionById(id);
    if (transaction != null) {
      double amount = transaction.isIncome ? transaction.amount : -transaction.amount;
      await _updateWalletBalance(transaction.paymentMethod, -amount);
    }

    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return TransactionModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByFilter({
    String? searchQuery,
    String? startDate,
    String? endDate,
    String? category,
    String? paymentMethod,
  }) async {
    final db = await database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('(source LIKE ? OR category LIKE ? OR notes LIKE ?)');
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }
    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(endDate);
    }
    if (category != null && category.isNotEmpty) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      whereClauses.add('payment_method = ?');
      whereArgs.add(paymentMethod);
    }

    String whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : '1';

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereString,
      whereArgs: whereArgs,
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // ==========================================
  // WALLET OPERATIONS
  // ==========================================

  Future<List<WalletModel>> getAllWallets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('wallets');
    return maps.map((map) => WalletModel.fromMap(map)).toList();
  }

  Future<WalletModel?> getWalletByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'wallets',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isNotEmpty) {
      return WalletModel.fromMap(maps.first);
    }
    return null;
  }

  Future<void> _updateWalletBalance(String paymentMethod, double amountChange) async {
    final db = await database;
    final wallet = await getWalletByName(paymentMethod);

    if (wallet != null) {
      double newBalance = wallet.balance + amountChange;
      await db.update(
        'wallets',
        {'balance': newBalance},
        where: 'name = ?',
        whereArgs: [paymentMethod],
      );
    }
  }

  // ==========================================
  // AGGREGATE QUERIES (Dashboard & Reports)
  // ==========================================

  Future<double> getTotalIncome() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM transactions WHERE type = "income"');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalExpenses() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM transactions WHERE type = "expense"');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getExpensesByCategory() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM transactions WHERE type = "expense" GROUP BY category'
    );

    Map<String, double> categoryMap = {};
    for (var row in result) {
      categoryMap[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return categoryMap;
  }

  // ==========================================
  // USER & AUTH OPERATIONS
  // ==========================================

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> getUserByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'user_id = ?',
      whereArgs: [user.userId],
    );
  }

  // ==========================================
  // APP SETTINGS OPERATIONS
  // ==========================================

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  // ==========================================
  // UTILITIES
  // ==========================================

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}