import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/data_management_provider.dart';
import '../profile/profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;

  void _showCustomHexDialog(BuildContext context, Color currentColor) {
    final hexController = TextEditingController(
      text: AppTheme.colorToHex(currentColor).replaceFirst('#', ''),
    );
    Color previewColor = currentColor;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Custom Theme Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter a 6-digit hex color code (e.g. 10B981, 6366F1):'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: previewColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400, width: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: hexController,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        prefixText: '#',
                        hintText: 'RRGGBB',
                        counterText: '',
                      ),
                      onChanged: (val) {
                        if (val.length == 6) {
                          setDialogState(() {
                            previewColor = AppTheme.hexToColor(val);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final color = AppTheme.hexToColor(hexController.text.trim());
                ref.read(themeProvider.notifier).setCustomColor(color);
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Theme seed color changed to #${hexController.text.trim().toUpperCase()}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Apply Color'),
            ),
          ],
        ),
      ),
    ).then((_) => hexController.dispose());
  }

  Future<void> _handleBackup() async {
    setState(() => _isExporting = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final file = await backupService.exportBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('Backup saved to downloads!\n${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Backup failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Financial Data?'),
        content: const Text(
          'Restoring will validate the JSON backup, safely replace database records, and update wallet balances without desynchronization.\n\nDo you wish to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isExporting = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final latestBackup = await backupService.getLatestBackupFile();

      if (latestBackup == null) {
        throw Exception('No local backup file found in Downloads or Documents folder.');
      }

      final count = await backupService.restoreBackup(latestBackup);

      // Invalidate state to reflect restored data in UI
      ref.invalidate(transactionsProvider);
      ref.invalidate(walletsProvider);
      ref.invalidate(financialSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('Successfully restored $count transactions and wallet balances!'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Restore failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleExportCsv() async {
    setState(() => _isExporting = true);
    try {
      final csvService = ref.read(csvServiceProvider);
      final file = await csvService.exportTransactionsToDownloads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal.shade700,
            content: Text('CSV file saved to Downloads folder!\n${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('CSV Export failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleExportPdf() async {
    setState(() => _isExporting = true);
    try {
      final pdfService = ref.read(pdfServiceProvider);
      await pdfService.generateAndPreviewFinancialSummaryPdf();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('PDF financial statement generated successfully!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('PDF Export failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final authState = ref.watch(authProvider);
    final currentUser = authState.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. APPEARANCE & THEME CARD
          _buildSectionHeader('Appearance & Theme'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme Mode',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeState.themeMode},
                    onSelectionChanged: (Set<ThemeMode> selection) {
                      themeNotifier.setThemeMode(selection.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Theme Accent Color',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => _showCustomHexDialog(context, themeState.customColor),
                        icon: const Icon(Icons.colorize, size: 18),
                        label: const Text('Custom Hex'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: AppTheme.presetColors.map((color) {
                      final isSelected = themeState.customColor.value == color.value;
                      return GestureDetector(
                        onTap: () => themeNotifier.setCustomColor(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 22)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. PROFILE & ACCOUNT CARD
          _buildSectionHeader('User Profile'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        child: Text(
                          (currentUser?.profileName != null && currentUser!.profileName!.isNotEmpty)
                              ? currentUser.profileName![0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser?.profileName ?? 'Paisa User',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentUser?.email ?? 'No email registered',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                            Text(
                              'ID: ${currentUser?.userId ?? "Offline"}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('View & Edit Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. DATA BACKUP, RESTORE & EXPORT (NO DEAD BUTTONS!)
          _buildSectionHeader('Data Management & Exports'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Backup Data Button
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.12),
                      child: const Icon(Icons.backup_outlined, color: Colors.blue),
                    ),
                    title: const Text('Backup Financial Data', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Save encrypted JSON snapshot locally'),
                    trailing: ElevatedButton(
                      onPressed: _isExporting ? null : _handleBackup,
                      child: const Text('Backup'),
                    ),
                  ),
                  const Divider(),

                  // Restore Data Button
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.12),
                      child: const Icon(Icons.restore_outlined, color: Colors.orange),
                    ),
                    title: const Text('Restore Financial Data', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Recover transactions from backup'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isExporting ? null : _handleRestore,
                      child: const Text('Restore'),
                    ),
                  ),
                  const Divider(),

                  // Export CSV Button
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.withOpacity(0.12),
                      child: const Icon(Icons.table_chart_outlined, color: Colors.teal),
                    ),
                    title: const Text('Export to CSV', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Spreadsheet format for Excel & Sheets'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isExporting ? null : _handleExportCsv,
                      child: const Text('CSV'),
                    ),
                  ),
                  const Divider(),

                  // Export PDF Button
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.12),
                      child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                    ),
                    title: const Text('Export to PDF Statement', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Printable statement with summary'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isExporting ? null : _handleExportPdf,
                      child: const Text('PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. ABOUT & SECURITY CARD
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('100% Offline & Private', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text(
                          'Paisa stores all records on your local device. No external servers.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }
}
