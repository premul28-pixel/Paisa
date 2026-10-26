import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';

class AddEditIncomeScreen extends ConsumerStatefulWidget {
  final TransactionModel? transaction;

  const AddEditIncomeScreen({super.key, this.transaction});

  @override
  ConsumerState<AddEditIncomeScreen> createState() => _AddEditIncomeScreenState();
}

class _AddEditIncomeScreenState extends ConsumerState<AddEditIncomeScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late TextEditingController _notesController;

  late DateTime _selectedDate;
  late String _selectedSource;
  late String _selectedPaymentMethod;
  bool _isLoading = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;

    _amountController = TextEditingController(
      text: tx != null ? tx.amount.toString() : '',
    );
    _selectedDate = tx != null ? tx.date : DateTime.now();
    _dateController = TextEditingController(
      text: DateFormatter.toIsoDate(_selectedDate),
    );

    // Source fallback
    final initialSource = tx?.source ?? AppConstants.incomeSources.first;
    _selectedSource = AppConstants.incomeSources.contains(initialSource)
        ? initialSource
        : AppConstants.incomeSources.first;

    // Payment method fallback ('Cash' or 'UPI')
    _selectedPaymentMethod = tx?.paymentMethod ?? AppConstants.walletCash;

    _notesController = TextEditingController(text: tx?.notes ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Income Date',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormatter.toIsoDate(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount must be greater than 0.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      if (_isEditing) {
        final updatedTx = widget.transaction!.copyWith(
          type: AppConstants.typeIncome,
          amount: amount,
          date: _selectedDate,
          source: _selectedSource,
          category: null,
          paymentMethod: _selectedPaymentMethod,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          updatedAt: now,
        );
        await ref.read(transactionsProvider.notifier).updateTransaction(updatedTx);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Income record updated! Wallet balances adjusted.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final newTx = TransactionModel(
          type: AppConstants.typeIncome,
          amount: amount,
          date: _selectedDate,
          source: _selectedSource,
          category: null,
          paymentMethod: _selectedPaymentMethod,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: now,
        );
        await ref.read(transactionsProvider.notifier).addTransaction(newTx);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Income added! Wallet balance increased.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save income: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Income' : 'Add Income'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.incomeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.incomeColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.incomeColor.withOpacity(0.2),
                      child: const Icon(Icons.arrow_downward, color: AppTheme.incomeColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Update Income Entry' : 'Record New Income',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Automatically adds funds to selected wallet',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount Field (Compulsory Amount > 0)
              _buildLabel('Amount (₹) *'),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an amount.';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null) {
                    return 'Please enter a valid numeric value.';
                  }
                  if (parsed <= 0) {
                    return 'Amount must be greater than 0.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Date Field (Native DatePicker)
              _buildLabel('Date *'),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  hintText: 'Select date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
              ),
              const SizedBox(height: 20),

              // Source Dropdown
              _buildLabel('Income Source *'),
              DropdownButtonFormField<String>(
                value: _selectedSource,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.source_outlined),
                ),
                items: AppConstants.incomeSources.map((source) {
                  return DropdownMenuItem(
                    value: source,
                    child: Text(source),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSource = val);
                },
              ),
              const SizedBox(height: 20),

              // Payment Method Toggle (Cash / UPI)
              _buildLabel('Deposit To Wallet (Payment Method) *'),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: AppConstants.walletCash,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Cash Wallet'),
                  ),
                  ButtonSegment(
                    value: AppConstants.walletUpi,
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    label: Text('UPI Wallet'),
                  ),
                ],
                selected: {_selectedPaymentMethod},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _selectedPaymentMethod = newSelection.first);
                },
              ),
              const SizedBox(height: 20),

              // Optional Notes Field
              _buildLabel('Notes (Optional)'),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Add remarks, client name, or details...',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.incomeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isLoading
                        ? 'Saving...'
                        : (_isEditing ? 'Update Income' : 'Add Income'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
