import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'sqlite_service.dart';

/// Service managing full database JSON backups and safe atomic restores.
class BackupService {
  final SqliteService _sqliteService;

  BackupService({SqliteService? sqliteService})
      : _sqliteService = sqliteService ?? SqliteService();

  /// STEP 1: BACKUP
  /// Exports all transactions, wallets, and users data to a structured JSON file.
  Future<File> exportBackup() async {
    final db = await _sqliteService.database;

    // Fetch all records from SQLite tables
    final transactions = await db.query('transactions', orderBy: 'date DESC, id DESC');
    final wallets = await db.query('wallets', orderBy: 'name ASC');
    final users = await db.query('users');
    final settings = await db.query('app_settings');

    final backupPayload = {
      'app': 'Paisa',
      'version': 1,
      'backup_timestamp': DateTime.now().toIso8601String(),
      'record_counts': {
        'transactions': transactions.length,
        'wallets': wallets.length,
        'users': users.length,
      },
      'users': users,
      'wallets': wallets,
      'transactions': transactions,
      'app_settings': settings,
    };

    // Get downloads directory or fallback to application documents directory
    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {}
    targetDir ??= await getApplicationDocumentsDirectory();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(join(targetDir.path, 'paisa_backup_$timestamp.json'));

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backupPayload),
    );

    // Save timestamp to app_settings
    await _sqliteService.setSetting('last_backup_date', DateTime.now().toIso8601String());

    return file;
  }

  /// STEP 1: RESTORE
  /// Reads the JSON backup, validates its structure, clears current DB tables,
  /// and restores all records inside an atomic SQLite transaction to ensure wallet balances never break.
  Future<int> restoreBackup(File backupFile) async {
    if (!await backupFile.exists()) {
      throw FileSystemException('Backup file not found at ${backupFile.path}');
    }

    final rawContent = await backupFile.readAsString();
    Map<String, dynamic> data;

    try {
      data = jsonDecode(rawContent) as Map<String, dynamic>;
    } catch (e) {
      throw const FormatException('Invalid backup file: Not a valid JSON document.');
    }

    // Validation: Verify required keys exist
    if (!data.containsKey('transactions') || !data.containsKey('wallets')) {
      throw const FormatException(
        'Invalid backup format: Missing required "transactions" or "wallets" tables.',
      );
    }

    final List rawTransactions = data['transactions'] as List? ?? [];
    final List rawWallets = data['wallets'] as List? ?? [];
    final List rawUsers = data['users'] as List? ?? [];
    final List rawSettings = data['app_settings'] as List? ?? [];

    // Ensure wallets table has minimum Cash and UPI
    bool hasCash = false;
    bool hasUpi = false;
    for (final w in rawWallets) {
      if (w is Map) {
        final name = (w['name'] ?? '').toString().toLowerCase();
        if (name == 'cash') hasCash = true;
        if (name == 'upi') hasUpi = true;
      }
    }

    if (!hasCash || !hasUpi) {
      throw const FormatException(
        'Invalid backup data: Wallets table must contain both "Cash" and "UPI" entries.',
      );
    }

    final db = await _sqliteService.database;

    // ATOMIC TRANSACTION RESTORE:
    // Clears tables and restores records safely. If anything fails, entire restore is rolled back.
    await db.transaction((txn) async {
      // 1. Clear current database tables
      await txn.delete('transactions');
      await txn.delete('wallets');
      if (rawUsers.isNotEmpty) {
        await txn.delete('users');
      }

      // 2. Restore Wallets
      for (final w in rawWallets) {
        final map = Map<String, dynamic>.from(w as Map);
        await txn.insert('wallets', map);
      }

      // 3. Restore Users (if present in backup)
      for (final u in rawUsers) {
        final map = Map<String, dynamic>.from(u as Map);
        await txn.insert('users', map);
      }

      // 4. Restore Transactions
      for (final t in rawTransactions) {
        final map = Map<String, dynamic>.from(t as Map);
        await txn.insert('transactions', map);
      }

      // 5. Restore App Settings (optional)
      for (final s in rawSettings) {
        final map = Map<String, dynamic>.from(s as Map);
        if (map.containsKey('key') && map.containsKey('value')) {
          await txn.rawInsert(
            'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
            [map['key'], map['value']],
          );
        }
      }
    });

    return rawTransactions.length;
  }

  /// Locates the most recent local JSON backup file
  Future<File?> getLatestBackupFile() async {
    final List<Directory> dirsToCheck = [];

    try {
      final dl = await getDownloadsDirectory();
      if (dl != null) dirsToCheck.add(dl);
    } catch (_) {}

    try {
      final docs = await getApplicationDocumentsDirectory();
      dirsToCheck.add(docs);
    } catch (_) {}

    final List<File> backupFiles = [];
    for (final dir in dirsToCheck) {
      if (dir.existsSync()) {
        final files = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('paisa_backup_') && f.path.endsWith('.json'))
            .toList();
        backupFiles.addAll(files);
      }
    }

    if (backupFiles.isEmpty) return null;

    backupFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return backupFiles.first;
  }
}
