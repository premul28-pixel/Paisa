import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'sqlite_service.dart';

/// Service managing CSV conversion and file exports for financial transactions.
class CsvService {
  final SqliteService _sqliteService;

  CsvService({SqliteService? sqliteService})
      : _sqliteService = sqliteService ?? SqliteService();

  /// STEP 2: CSV EXPORT
  /// Converts all transactions into a CSV file and saves it to the device's downloads folder.
  Future<File> exportTransactionsToDownloads() async {
    final transactions = await _sqliteService.getAllTransactions(
      orderBy: 'date DESC, id DESC',
    );

    // 1. Build CSV Table Header
    final List<List<dynamic>> csvRows = [
      [
        'Transaction ID',
        'Type',
        'Amount (INR)',
        'Date',
        'Source (Income)',
        'Category (Expense)',
        'Payment Method (Wallet)',
        'Notes',
        'Created At',
      ],
    ];

    // 2. Populate CSV rows
    for (final tx in transactions) {
      csvRows.add([
        tx.id ?? '',
        tx.type.toUpperCase(),
        tx.amount.toStringAsFixed(2),
        tx.date.toIso8601String().split('T').first,
        tx.isIncome ? (tx.source ?? 'N/A') : '',
        tx.isExpense ? (tx.category ?? 'N/A') : '',
        tx.paymentMethod,
        tx.notes ?? '',
        tx.createdAt.toIso8601String(),
      ]);
    }

    // 3. Convert rows to CSV string
    final String csvContent = const ListToCsvConverter().convert(csvRows);

    // 4. Resolve the device downloads directory (fallback to documents)
    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {}
    targetDir ??= await getApplicationDocumentsDirectory();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(join(targetDir.path, 'paisa_transactions_$timestamp.csv'));

    // 5. Write CSV file
    await file.writeAsString(csvContent, flush: true);

    return file;
  }
}
