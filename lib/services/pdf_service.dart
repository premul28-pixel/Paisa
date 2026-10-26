import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'sqlite_service.dart';

/// Service generating and exporting PDF financial statements.
class PdfService {
  final SqliteService _sqliteService;

  PdfService({SqliteService? sqliteService})
      : _sqliteService = sqliteService ?? SqliteService();

  /// STEP 3: PDF EXPORT
  /// Generates a clean, readable financial summary PDF and opens the native print/save/share preview.
  Future<void> generateAndPreviewFinancialSummaryPdf() async {
    final pdfBytes = await _generatePdfDocumentBytes();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'paisa_statement_$timestamp.pdf',
    );
  }

  /// Allows the user to share the generated PDF statement directly via device share sheet.
  Future<void> shareFinancialSummaryPdf() async {
    final pdfBytes = await _generatePdfDocumentBytes();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'paisa_statement_$timestamp.pdf',
    );
  }

  /// Saves the PDF statement directly to the device's downloads folder.
  Future<File> savePdfToDownloads() async {
    final pdfBytes = await _generatePdfDocumentBytes();

    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {}
    targetDir ??= await getApplicationDocumentsDirectory();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(join(targetDir.path, 'paisa_financial_statement_$timestamp.pdf'));

    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  /// Generates the raw PDF bytes with Financial Summary cards and transactions table.
  Future<Uint8List> _generatePdfDocumentBytes() async {
    final summary = await _sqliteService.getFinancialSummary();
    final transactions = await _sqliteService.getAllTransactions(
      orderBy: 'date DESC, id DESC',
      limit: 100, // Top 100 transactions in statement
    );
    final user = await _sqliteService.getFirstUser();

    final pdf = pw.Document();

    final totalIncome = summary['totalIncome'] ?? 0.0;
    final totalExpense = summary['totalExpense'] ?? 0.0;
    final cashBalance = summary['cashBalance'] ?? 0.0;
    final upiBalance = summary['upiBalance'] ?? 0.0;
    final remainingBalance = summary['remainingBalance'] ?? 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PAISA',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal800,
                        ),
                      ),
                      pw.Text(
                        'Personal Finance Management • Offline Ledger',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated On',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        DateTime.now().toIso8601String().split('T').first,
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (pw.Context context) => [
          // User Information Banner (if user profile is present)
          if (user != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Account: ${user.profileName ?? user.userId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('Email: ${user.email ?? "Offline"}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // FINANCIAL SUMMARY METRIC CARDS (Total Income, Expenses, Cash, UPI, Remaining)
          pw.Text(
            'Financial Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildSummaryBox('Net Balance', 'Rs. ${remainingBalance.toStringAsFixed(2)}', PdfColors.teal700, true),
              pw.SizedBox(width: 8),
              _buildSummaryBox('Total Income', 'Rs. ${totalIncome.toStringAsFixed(2)}', PdfColors.green700, false),
              pw.SizedBox(width: 8),
              _buildSummaryBox('Total Expenses', 'Rs. ${totalExpense.toStringAsFixed(2)}', PdfColors.red700, false),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildSummaryBox('Cash Wallet', 'Rs. ${cashBalance.toStringAsFixed(2)}', PdfColors.orange700, false),
              pw.SizedBox(width: 8),
              _buildSummaryBox('UPI Wallet', 'Rs. ${upiBalance.toStringAsFixed(2)}', PdfColors.blue700, false),
            ],
          ),
          pw.SizedBox(height: 20),

          // TRANSACTIONS TABLE
          pw.Text(
            'Transaction Statement (${transactions.length} records)',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Date', 'Type', 'Category / Source', 'Wallet', 'Amount'],
            data: transactions.map((t) {
              final isInc = t.isIncome;
              return [
                t.date.toIso8601String().split('T').first,
                t.type.toUpperCase(),
                isInc ? (t.source ?? 'Income') : (t.category ?? 'Expense'),
                t.paymentMethod,
                '${isInc ? "+" : "-"} Rs. ${t.amount.toStringAsFixed(2)}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          ),
        ],
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummaryBox(String label, String value, PdfColor color, bool isHero) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: pw.BoxDecoration(
          color: isHero ? PdfColors.teal50 : PdfColors.white,
          border: pw.Border.all(color: color, width: isHero ? 1.5 : 1.0),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: isHero ? 14 : 12, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
