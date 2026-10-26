import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/export_backup_service.dart';

final exportBackupServiceProvider = Provider<ExportBackupService>((ref) {
  return ExportBackupService();
});
