import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../income/add_edit_income_screen.dart';
import '../expenses/add_edit_expense_screen.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedType; // null = All, 'income', 'expense'
  String? _selectedCategory; // null = All
  String? _selectedPaymentMethod; // null = All, 'Cash', 'UPI'
  DateTimeRange? _selectedDateRange;
  String _dateFilterPreset = 'All Time'; // 'All Time', 'Today', 'This Week', 'This Month', 'Custom'

  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);

    DateTime? start;
    DateTime? end;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_dateFilterPreset == 'Today') {
      start = today;
      end = today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    } else if (_dateFilterPreset == 'This Week') {
      start = today.subtract(Duration(days: today.weekday - 1));
      end = now;
    } else if (_dateFilterPreset == 'This Month') {
      start = DateTime(now.year, now.month, 1);
      end = now;
    } else if (_dateFilterPreset == 'Custom' && _selectedDateRange != null) {
      start = _selectedDateRange!.start;
      end = DateTime(
        _selectedDateRange!.end.year,
        _selectedDateRange!.end.month,
        _selectedDateRange!.end.day,
        23,
        59,
        59,
      );
    }

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final results = await repo.getFilteredTransactions(
        startDate: start,
        endDate: end,
        type: _selectedType,
        category: _selectedCategory,
        paymentMethod: _selectedPaymentMethod,
        searchQuery: _searchQuery,
      );

      setState(() {
        _filteredTransactions = results;
      });
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedType = null;
      _selectedCategory = null;
      _selectedPaymentMethod = null;
      _selectedDateRange = null;
      _dateFilterPreset = 'All Time';
    });
    _applyFilters();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _dateFilterPreset = 'Custom';
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to main transactionsProvider to auto-refresh whenever DB updates
    ref.listen(transactionsProvider, (_, __) {
      _applyFilters();
    });

    final hasActiveFilters = _searchQuery.isNotEmpty ||
        _selectedType != null ||
        _selectedCategory != null ||
        _selectedPaymentMethod != null ||
        _dateFilterPreset != 'All Time';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          if (hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear Filters',
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. TOP SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes, source, or category...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _applyFilters();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _applyFilters();
              },
            ),
          ),

          // 2. HORIZONTAL FILTER CHIPS ROW
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Date Preset Filter Menu
                PopupMenuButton<String>(
                  initialValue: _dateFilterPreset,
                  onSelected: (val) {
                    if (val == 'Custom') {
                      _pickCustomDateRange();
                    } else {
                      setState(() => _dateFilterPreset = val);
                      _applyFilters();
                    }
                  },
                  itemBuilder: (context) => [
                    'All Time',
                    'Today',
                    'This Week',
                    'This Month',
                    'Custom',
                  ].map((preset) {
                    return PopupMenuItem(
                      value: preset,
                      child: Text(preset),
                    );
                  }).toList(),
                  child: Chip(
                    avatar: const Icon(Icons.calendar_month, size: 16),
                    label: Text(
                      _dateFilterPreset == 'Custom' && _selectedDateRange != null
                          ? '${DateFormatter.toDisplayDate(_selectedDateRange!.start)} - ${DateFormatter.toDisplayDate(_selectedDateRange!.end)}'
                          : _dateFilterPreset,
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: _dateFilterPreset != 'All Time' ? const Icon(Icons.close, size: 14) : null,
                    onDeleted: _dateFilterPreset != 'All Time'
                        ? () {
                            setState(() => _dateFilterPreset = 'All Time');
                            _applyFilters();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),

                // Type Filter (Income / Expense)
                PopupMenuButton<String?>(
                  initialValue: _selectedType,
                  onSelected: (val) {
                    setState(() => _selectedType = val);
                    _applyFilters();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: null, child: Text('All Types')),
                    const PopupMenuItem(value: 'income', child: Text('Income Only')),
                    const PopupMenuItem(value: 'expense', child: Text('Expenses Only')),
                  ],
                  child: Chip(
                    avatar: Icon(
                      _selectedType == 'income'
                          ? Icons.arrow_downward
                          : (_selectedType == 'expense' ? Icons.arrow_upward : Icons.swap_vert),
                      size: 16,
                      color: _selectedType == 'income'
                          ? AppTheme.incomeColor
                          : (_selectedType == 'expense' ? AppTheme.expenseColor : null),
                    ),
                    label: Text(
                      _selectedType == 'income'
                          ? 'Income'
                          : (_selectedType == 'expense' ? 'Expenses' : 'Type: All'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: _selectedType != null ? const Icon(Icons.close, size: 14) : null,
                    onDeleted: _selectedType != null
                        ? () {
                            setState(() => _selectedType = null);
                            _applyFilters();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),

                // Payment Method Filter (Cash / UPI)
                PopupMenuButton<String?>(
                  initialValue: _selectedPaymentMethod,
                  onSelected: (val) {
                    setState(() => _selectedPaymentMethod = val);
                    _applyFilters();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: null, child: Text('All Wallets')),
                    const PopupMenuItem(value: 'Cash', child: Text('Cash Wallet')),
                    const PopupMenuItem(value: 'UPI', child: Text('UPI Wallet')),
                  ],
                  child: Chip(
                    avatar: Icon(
                      _selectedPaymentMethod == 'Cash'
                          ? Icons.payments_outlined
                          : (_selectedPaymentMethod == 'UPI' ? Icons.account_balance_wallet_outlined : Icons.wallet),
                      size: 16,
                    ),
                    label: Text(
                      _selectedPaymentMethod ?? 'Wallet: All',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: _selectedPaymentMethod != null ? const Icon(Icons.close, size: 14) : null,
                    onDeleted: _selectedPaymentMethod != null
                        ? () {
                            setState(() => _selectedPaymentMethod = null);
                            _applyFilters();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),

                // Category Filter
                PopupMenuButton<String?>(
                  initialValue: _selectedCategory,
                  onSelected: (val) {
                    setState(() => _selectedCategory = val);
                    _applyFilters();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: null, child: Text('All Categories')),
                    ...AppConstants.expenseCategories.map((cat) {
                      return PopupMenuItem(value: cat, child: Text(cat));
                    }),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.category_outlined, size: 16),
                    label: Text(
                      _selectedCategory ?? 'Category: All',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: _selectedCategory != null ? const Icon(Icons.close, size: 14) : null,
                    onDeleted: _selectedCategory != null
                        ? () {
                            setState(() => _selectedCategory = null);
                            _applyFilters();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // 3. FILTER RESULTS HEADER SUMMARY
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredTransactions.length} matching ${_filteredTransactions.length == 1 ? "record" : "records"}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                if (hasActiveFilters)
                  GestureDetector(
                    onTap: _clearFilters,
                    child: Text(
                      'Reset Filters',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 4. TRANSACTION LIST / EMPTY STATE
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'No matching transactions',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try clearing or changing your search terms or filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              if (hasActiveFilters)
                                ElevatedButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Clear All Filters'),
                                ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredTransactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tx = _filteredTransactions[index];

                          return Card(
                            child: ListTile(
                              onTap: () {
                                if (tx.isIncome) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddEditIncomeScreen(transaction: tx),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddEditExpenseScreen(transaction: tx),
                                    ),
                                  );
                                }
                              },
                              leading: CircleAvatar(
                                backgroundColor: (tx.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor).withOpacity(0.15),
                                child: Icon(
                                  tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: tx.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                tx.isIncome ? (tx.source ?? 'Income') : (tx.category ?? 'Expense'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Text(
                                '${DateFormatter.toDisplayDate(tx.date)} • ${tx.paymentMethod}${tx.notes != null && tx.notes!.isNotEmpty ? " • ${tx.notes}" : ""}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${tx.isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}',
                                    style: TextStyle(
                                      color: tx.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
