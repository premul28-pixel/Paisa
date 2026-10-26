import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'sqlite_service.dart';

/// Service managing CSV export, PDF statement generation, and local backup/restore.
class ExportBackupService {
  final SqliteService _sqliteService;

  ExportBackupService({SqliteService? sqliteService})
      : _sqliteService = sqliteService ?? SqliteService();

  /// EXPORT CSV: Generates a CSV file of all transaction records and returns the File.
  Future<File> exportCsv() async {
    final transactions = await _sqliteService.getAllTransactions();

    final List<List<dynamic>> rows = [
      [
        'ID',
        'Type',
        'Amount',
        'Date',
        'Source',
        'Category',
        'Payment Method',
        'Notes',
        'Created At',
      ],
    ];

    for (final tx in transactions) {
      rows.add([
        tx.id,
        tx.type,
        tx.amount,
        tx.date.toIso8601String(),
        tx.source ?? '',
        tx.category ?? '',
        tx.paymentMethod,
        tx.notes ?? '',
        tx.createdAt.toIso8601String(),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(join(dir.path, 'paisa_transactions_$timestamp.csv'));

    return await file.writeAsString(csvData);
  }

  /// EXPORT PDF: Generates a printable PDF financial statement and opens system print/preview.
  Future<void> exportPdf() async {
    final transactions = await _sqliteService.getAllTransactions();
    final summary = await _sqliteService.getFinancialSummary();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PAISA Financial Statement',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  DateTime.now().toIso8601String().split('T').first,
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          // Financial Summary Table
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildPdfSummaryItem('Total Income', 'Rs. ${summary['totalIncome']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildPdfSummaryItem('Total Expense', 'Rs. ${summary['totalExpense']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildPdfSummaryItem('Net Balance', 'Rs. ${summary['remainingBalance']?.toStringAsFixed(2) ?? '0.00'}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Transactions Log', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Type', 'Amount', 'Date', 'Category/Source', 'Wallet'],
            data: transactions.map((tx) {
              return [
                tx.type.toUpperCase(),
                'Rs. ${tx.amount.toStringAsFixed(2)}',
                tx.date.toIso8601String().split('T').first,
                tx.isIncome ? (tx.source ?? '-') : (tx.category ?? '-'),
                tx.paymentMethod,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'paisa_statement_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// BACKUP DATA: Generates a JSON backup snapshot of all SQLite tables and writes to disk.
  Future<File> backupData() async {
    final transactions = await _sqliteService.getAllTransactions();
    final wallets = await _sqliteService.getAllWallets();
    final user = await _sqliteService.getFirstUser();

    final backupPayload = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'user': user?.toMap(),
      'wallets': wallets.map((w) => w.toMap()).toList(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(join(dir.path, 'paisa_backup_$timestamp.json'));

    await file.writeAsString(jsonEncode(backupPayload));

    // Update last backup date in app_settings
    await _sqliteService.setSetting(
      'last_backup_date',
      DateTime.now().toIso8601String(),
    );

    return file;
  }

  /// RESTORE DATA: Reads and verifies backup JSON data and restores records into SQLite.
  Future<int> restoreData({File? backupFile}) async {
    File fileToRestore;

    if (backupFile != null) {
      fileToRestore = backupFile;
    } else {
      // Find latest backup in application documents directory
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().whereType<File>().where((f) => f.path.contains('paisa_backup_')).toList();
      if (files.isEmpty) {
        throw Exception('No local backup file found in documents folder.');
      }
      files.sort((a, b) => b.path.compareTo(a.path));
      fileToRestore = files.first;
    }

    final rawJson = await fileToRestore.readAsString();
    final Map<String, dynamic> data = jsonDecode(rawJson);

    if (!data.containsKey('transactions') || !data.containsKey('wallets')) {
      throw const FormatException('Invalid backup file structure.');
    }

    final List txList = data['transactions'] as List;
    final List walletList = data['wallets'] as List;

    final db = await _sqliteService.database;

    await db.transaction((txn) async {
      // Clear current transactions and wallets
      await txn.delete('transactions');
      await txn.delete('wallets');

      // Restore wallets
      for (final w in walletList) {
        await txn.insert('wallets', Map<String, dynamic>.from(w as Map));
      }

      // Restore transactions
      for (final t in txList) {
        await txn.insert('transactions', Map<String, dynamic>.from(t as Map));
      }
    });

    return txList.length;
  }
}
