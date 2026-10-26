import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_constants.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/user_model.dart';
import '../models/app_settings_model.dart';

/// Database service managing SQLite storage and ACID-compliant transaction operations.
class SqliteService {
  static final SqliteService _instance = SqliteService._internal();
  factory SqliteService() => _instance;
  SqliteService._internal();

  static Database? _database;

  /// Getter for the SQLite database instance. Initializes if not yet opened.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the SQLite database.
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, DatabaseConstants.databaseName);

    return await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  /// Creates tables and indexes on database creation with exact requested columns.
  Future<void> _onCreate(Database db, int version) async {
    // 1. Table: users
    // id (INTEGER PK), user_id (TEXT UNIQUE), password_hash (TEXT), recovery_pin (TEXT 6-digit),
    // profile_name (TEXT), dob (TEXT), email (TEXT), phone (TEXT)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableUsers} (
        ${DatabaseConstants.colUserId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colUserCustomId} TEXT UNIQUE NOT NULL,
        ${DatabaseConstants.colUserPasswordHash} TEXT NOT NULL,
        ${DatabaseConstants.colUserRecoveryPin} TEXT NOT NULL,
        ${DatabaseConstants.colUserProfileName} TEXT,
        ${DatabaseConstants.colUserDob} TEXT,
        ${DatabaseConstants.colUserEmail} TEXT,
        ${DatabaseConstants.colUserPhone} TEXT
      );
    ''');

    // 2. Table: app_settings
    // key (TEXT PK), value (TEXT)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableAppSettings} (
        ${DatabaseConstants.colSettingKey} TEXT PRIMARY KEY,
        ${DatabaseConstants.colSettingValue} TEXT NOT NULL
      );
    ''');

    // 3. Table: wallets
    // id (INTEGER PK), name (TEXT UNIQUE: 'Cash', 'UPI'), balance (REAL DEFAULT 0)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableWallets} (
        ${DatabaseConstants.colWalletId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colWalletName} TEXT UNIQUE NOT NULL,
        ${DatabaseConstants.colWalletBalance} REAL NOT NULL DEFAULT 0
      );
    ''');

    // 4. Table: transactions
    // id (INTEGER PK AUTO), type (TEXT: income/expense), amount (REAL), date (TEXT),
    // source (TEXT), category (TEXT), payment_method (TEXT: Cash/UPI), notes (TEXT),
    // created_at (TEXT), updated_at (TEXT)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableTransactions} (
        ${DatabaseConstants.colTxId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colTxType} TEXT NOT NULL,
        ${DatabaseConstants.colTxAmount} REAL NOT NULL,
        ${DatabaseConstants.colTxDate} TEXT NOT NULL,
        ${DatabaseConstants.colTxSource} TEXT,
        ${DatabaseConstants.colTxCategory} TEXT,
        ${DatabaseConstants.colTxPaymentMethod} TEXT NOT NULL,
        ${DatabaseConstants.colTxNotes} TEXT,
        ${DatabaseConstants.colTxCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colTxUpdatedAt} TEXT
      );
    ''');

    // 5. Create performance indexes
    await _createIndexes(db);

    // 6. Pre-seed default wallets: 'Cash' and 'UPI' with balance 0
    await db.rawInsert('''
      INSERT INTO ${DatabaseConstants.tableWallets} (${DatabaseConstants.colWalletName}, ${DatabaseConstants.colWalletBalance})
      VALUES (?, ?), (?, ?)
    ''', ['Cash', 0.0, 'UPI', 0.0]);

    // 7. Pre-seed default settings
    await db.insert(DatabaseConstants.tableAppSettings, {
      DatabaseConstants.colSettingKey: AppSettingsModel.keyDarkMode,
      DatabaseConstants.colSettingValue: 'false',
    });
    await db.insert(DatabaseConstants.tableAppSettings, {
      DatabaseConstants.colSettingKey: AppSettingsModel.keyCurrencySymbol,
      DatabaseConstants.colSettingValue: '₹',
    });
  }

  /// Hook called whenever the database is opened.
  /// Ensures all indexes exist even across version migrations or pre-existing DBs.
  Future<void> _onOpen(Database db) async {
    await _createIndexes(db);
  }

  /// Creates and maintains query optimization indexes.
  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON ${DatabaseConstants.tableTransactions}(${DatabaseConstants.colTxDate});',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date_id ON ${DatabaseConstants.tableTransactions}(${DatabaseConstants.colTxDate} DESC, ${DatabaseConstants.colTxId} DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type ON ${DatabaseConstants.tableTransactions}(${DatabaseConstants.colTxType});',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON ${DatabaseConstants.tableTransactions}(${DatabaseConstants.colTxCategory});',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_payment_method ON ${DatabaseConstants.tableTransactions}(${DatabaseConstants.colTxPaymentMethod});',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type_date ON ${DatabaseConstants.tableTransactions}(${DatabaseConstants.colTxType}, ${DatabaseConstants.colTxDate} DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_payment_date ON ${DatabaseConstants.tableTransactions}(${DatabaseConstants.colTxPaymentMethod}, ${DatabaseConstants.colTxDate} DESC);',
    );
  }

  // ===========================================================================
  // TRANSACTION CRUD OPERATIONS WITH ATOMIC WALLET BALANCE SYNCHRONIZATION
  // ===========================================================================

  /// CREATE TRANSACTION
  /// Inserts a transaction and adjusts the wallet balance atomically:
  /// Add for income, Subtract for expense based on payment_method.
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      final transactionMap = transaction.toMap();
      transactionMap.remove('id');

      final insertedId = await txn.insert(
        DatabaseConstants.tableTransactions,
        transactionMap,
      );

      final double delta = transaction.isIncome
          ? transaction.amount
          : -transaction.amount;

      final rowsUpdated = await txn.rawUpdate('''
        UPDATE ${DatabaseConstants.tableWallets} 
        SET ${DatabaseConstants.colWalletBalance} = ${DatabaseConstants.colWalletBalance} + ? 
        WHERE ${DatabaseConstants.colWalletName} = ?
      ''', [delta, transaction.paymentMethod]);

      if (rowsUpdated == 0) {
        throw Exception(
          'Wallet "${transaction.paymentMethod}" does not exist. Transaction rolled back.',
        );
      }

      return insertedId;
    });
  }

  /// UPDATE TRANSACTION
  /// Atomically updates a transaction:
  /// 1. Loads the old transaction.
  /// 2. REVERSES its effect on the old wallet.
  /// 3. APPLIES the new transaction's effect on the new wallet.
  /// 4. Updates the row.
  Future<int> updateTransaction(TransactionModel newTx) async {
    if (newTx.id == null) {
      throw ArgumentError('Transaction ID cannot be null during update.');
    }

    final db = await database;

    return await db.transaction<int>((txn) async {
      // 1. Load the old transaction
      final List<Map<String, dynamic>> existingRows = await txn.query(
        DatabaseConstants.tableTransactions,
        where: '${DatabaseConstants.colTxId} = ?',
        whereArgs: [newTx.id],
        limit: 1,
      );

      if (existingRows.isEmpty) {
        throw Exception('Transaction with ID ${newTx.id} not found.');
      }

      final oldTx = TransactionModel.fromMap(existingRows.first);

      // 2. REVERSE old transaction effect on old wallet
      final double reverseDelta = oldTx.isIncome
          ? -oldTx.amount
          : oldTx.amount;

      final reverseUpdated = await txn.rawUpdate('''
        UPDATE ${DatabaseConstants.tableWallets} 
        SET ${DatabaseConstants.colWalletBalance} = ${DatabaseConstants.colWalletBalance} + ? 
        WHERE ${DatabaseConstants.colWalletName} = ?
      ''', [reverseDelta, oldTx.paymentMethod]);

      if (reverseUpdated == 0) {
        throw Exception(
          'Original wallet "${oldTx.paymentMethod}" not found. Update rolled back.',
        );
      }

      // 3. APPLY new transaction effect on new wallet
      final double applyDelta = newTx.isIncome
          ? newTx.amount
          : -newTx.amount;

      final applyUpdated = await txn.rawUpdate('''
        UPDATE ${DatabaseConstants.tableWallets} 
        SET ${DatabaseConstants.colWalletBalance} = ${DatabaseConstants.colWalletBalance} + ? 
        WHERE ${DatabaseConstants.colWalletName} = ?
      ''', [applyDelta, newTx.paymentMethod]);

      if (applyUpdated == 0) {
        throw Exception(
          'Target wallet "${newTx.paymentMethod}" not found. Update rolled back.',
        );
      }

      // 4. Update the transaction row
      final updatedData = newTx.toMap();
      updatedData['updated_at'] = DateTime.now().toIso8601String();

      return await txn.update(
        DatabaseConstants.tableTransactions,
        updatedData,
        where: '${DatabaseConstants.colTxId} = ?',
        whereArgs: [newTx.id],
      );
    });
  }

  /// DELETE TRANSACTION
  /// Atomically deletes a transaction:
  /// 1. Loads the transaction.
  /// 2. REVERSES its effect on the wallet.
  /// 3. Deletes the row.
  Future<int> deleteTransaction(int id) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      // 1. Load the transaction
      final List<Map<String, dynamic>> existingRows = await txn.query(
        DatabaseConstants.tableTransactions,
        where: '${DatabaseConstants.colTxId} = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (existingRows.isEmpty) {
        throw Exception('Transaction with ID $id not found.');
      }

      final tx = TransactionModel.fromMap(existingRows.first);

      // 2. REVERSE its effect on the wallet
      final double reverseDelta = tx.isIncome ? -tx.amount : tx.amount;

      final rowsUpdated = await txn.rawUpdate('''
        UPDATE ${DatabaseConstants.tableWallets} 
        SET ${DatabaseConstants.colWalletBalance} = ${DatabaseConstants.colWalletBalance} + ? 
        WHERE ${DatabaseConstants.colWalletName} = ?
      ''', [reverseDelta, tx.paymentMethod]);

      if (rowsUpdated == 0) {
        throw Exception(
          'Wallet "${tx.paymentMethod}" not found. Deletion rolled back.',
        );
      }

      // 3. Delete the transaction row
      return await txn.delete(
        DatabaseConstants.tableTransactions,
        where: '${DatabaseConstants.colTxId} = ?',
        whereArgs: [id],
      );
    });
  }

  // ===========================================================================
  // READ & FILTER OPERATIONS
  // ===========================================================================

  /// Retrieves all transactions ordered by date descending.
  Future<List<TransactionModel>> getAllTransactions({
    String orderBy = 'date DESC, id DESC',
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableTransactions,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  /// Retrieves a single transaction by ID.
  Future<TransactionModel?> getTransactionById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableTransactions,
      where: '${DatabaseConstants.colTxId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  /// Searches and filters transactions with multiple criteria.
  Future<List<TransactionModel>> getFilteredTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? category,
    String? paymentMethod,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClauses.add('${DatabaseConstants.colTxDate} >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClauses.add('${DatabaseConstants.colTxDate} <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    if (type != null && type.isNotEmpty) {
      whereClauses.add('${DatabaseConstants.colTxType} = ?');
      whereArgs.add(type.toLowerCase());
    }

    if (category != null && category.isNotEmpty) {
      whereClauses.add('${DatabaseConstants.colTxCategory} = ?');
      whereArgs.add(category);
    }

    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      whereClauses.add('${DatabaseConstants.colTxPaymentMethod} = ?');
      whereArgs.add(paymentMethod);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      whereClauses.add(
        '(${DatabaseConstants.colTxSource} LIKE ? OR ${DatabaseConstants.colTxCategory} LIKE ? OR ${DatabaseConstants.colTxNotes} LIKE ?)',
      );
      whereArgs.addAll([term, term, term]);
    }

    final whereString = whereClauses.isEmpty ? null : whereClauses.join(' AND ');

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableTransactions,
      where: whereString,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // ===========================================================================
  // WALLET OPERATIONS & FINANCIAL SUMMARY
  // ===========================================================================

  /// Retrieves all wallets.
  Future<List<WalletModel>> getAllWallets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableWallets,
      orderBy: '${DatabaseConstants.colWalletName} ASC',
    );
    return maps.map((map) => WalletModel.fromMap(map)).toList();
  }

  /// Retrieves a specific wallet by name.
  Future<WalletModel?> getWalletByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableWallets,
      where: '${DatabaseConstants.colWalletName} = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WalletModel.fromMap(maps.first);
  }

  /// Calculates real-time financial summary.
  Future<Map<String, double>> getFinancialSummary() async {
    final db = await database;

    final summaryResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN ${DatabaseConstants.colTxType} = 'income' THEN ${DatabaseConstants.colTxAmount} ELSE 0.0 END), 0.0) as totalIncome,
        COALESCE(SUM(CASE WHEN ${DatabaseConstants.colTxType} = 'expense' THEN ${DatabaseConstants.colTxAmount} ELSE 0.0 END), 0.0) as totalExpense
      FROM ${DatabaseConstants.tableTransactions}
    ''');

    final double totalIncome = (summaryResult.first['totalIncome'] as num).toDouble();
    final double totalExpense = (summaryResult.first['totalExpense'] as num).toDouble();

    final wallets = await getAllWallets();
    double cashBalance = 0.0;
    double upiBalance = 0.0;

    for (final wallet in wallets) {
      if (wallet.name.toLowerCase() == 'cash') {
        cashBalance = wallet.balance;
      } else if (wallet.name.toLowerCase() == 'upi') {
        upiBalance = wallet.balance;
      }
    }

    final double remainingBalance = cashBalance + upiBalance;

    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'cashBalance': cashBalance,
      'upiBalance': upiBalance,
      'remainingBalance': remainingBalance,
    };
  }

  // ===========================================================================
  // USERS & APP SETTINGS OPERATIONS
  // ===========================================================================

  /// Inserts a new user record.
  Future<int> insertUser(UserModel user) async {
    final db = await database;
    final map = user.toMap();
    map.remove('id');
    return await db.insert(DatabaseConstants.tableUsers, map);
  }

  /// Retrieves a user by user_id.
  Future<UserModel?> getUserByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableUsers,
      where: '${DatabaseConstants.colUserCustomId} = ?',
      whereArgs: [userId.trim()],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  /// Retrieves the first/primary user in the local database.
  Future<UserModel?> getFirstUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableUsers,
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  /// Updates a user's password hash.
  Future<int> updateUserPassword(String userId, String newPasswordHash) async {
    final db = await database;
    return await db.update(
      DatabaseConstants.tableUsers,
      {DatabaseConstants.colUserPasswordHash: newPasswordHash},
      where: '${DatabaseConstants.colUserCustomId} = ?',
      whereArgs: [userId.trim()],
    );
  }

  /// Updates a user's profile information (Name, DOB, Email, Phone).
  Future<int> updateUserProfile({
    required String userId,
    required String profileName,
    required String dob,
    required String email,
    required String phone,
  }) async {
    final db = await database;
    return await db.update(
      DatabaseConstants.tableUsers,
      {
        DatabaseConstants.colUserProfileName: profileName.trim(),
        DatabaseConstants.colUserDob: dob.trim(),
        DatabaseConstants.colUserEmail: email.trim(),
        DatabaseConstants.colUserPhone: phone.trim(),
      },
      where: '${DatabaseConstants.colUserCustomId} = ?',
      whereArgs: [userId.trim()],
    );
  }

  /// Updates an entire user entity.
  Future<int> updateUser(UserModel user) async {
    final db = await database;
    return await db.update(
      DatabaseConstants.tableUsers,
      user.toMap(),
      where: '${DatabaseConstants.colUserCustomId} = ?',
      whereArgs: [user.userId],
    );
  }

  /// Gets a setting value by key.
  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableAppSettings,
      where: '${DatabaseConstants.colSettingKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first[DatabaseConstants.colSettingValue] as String?;
  }

  /// Sets or updates a setting value by key.
  Future<int> setSetting(String key, String value) async {
    final db = await database;
    return await db.insert(
      DatabaseConstants.tableAppSettings,
      {
        DatabaseConstants.colSettingKey: key,
        DatabaseConstants.colSettingValue: value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Closes database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
