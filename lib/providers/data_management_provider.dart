import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backup_service.dart';
import '../services/csv_service.dart';
import '../services/pdf_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

final csvServiceProvider = Provider<CsvService>((ref) {
  return CsvService();
});

final pdfServiceProvider = Provider<PdfService>((ref) {
  return PdfService();
});
