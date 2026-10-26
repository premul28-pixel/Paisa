import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/wallet_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../income/add_edit_income_screen.dart';
import '../income/income_list_screen.dart';
import '../expenses/add_edit_expense_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../wallet/wallet_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction_history_screen.dart';
import '../reports/reports_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dynamic calculation using WalletProvider and TransactionProvider
    final walletsAsync = ref.watch(walletsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              child: Icon(
                Icons.account_balance_wallet,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              AppConstants.appName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Reports & Charts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Transaction History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Wallets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletsProvider);
          await ref.read(transactionsProvider.notifier).loadTransactions();
        },
        child: walletsAsync.when(
          data: (wallets) {
            final cashWallet = wallets.firstWhere(
              (w) => w.name.toLowerCase() == 'cash',
              orElse: () => const WalletModel(name: 'Cash', balance: 0.0),
            );
            final upiWallet = wallets.firstWhere(
              (w) => w.name.toLowerCase() == 'upi',
              orElse: () => const WalletModel(name: 'UPI', balance: 0.0),
            );

            return transactionsAsync.when(
              data: (transactions) {
                // Dynamically calculate totals from TransactionProvider
                final double totalIncome = transactions
                    .where((t) => t.isIncome)
                    .fold<double>(0.0, (sum, t) => sum + t.amount);

                final double totalExpense = transactions
                    .where((t) => t.isExpense)
                    .fold<double>(0.0, (sum, t) => sum + t.amount);

                final double cashBalance = cashWallet.balance;
                final double upiBalance = upiWallet.balance;
                final double remainingBalance = cashBalance + upiBalance;

                final recentTransactions = transactions.take(5).toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // =========================================================
                    // STEP 1: 5 MATERIAL 3 CARDS
                    // =========================================================

                    // CARD 1: REMAINING BALANCE (HERO CARD)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Remaining Balance (Net Total)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Cash + UPI',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.format(remainingBalance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Cash: ${CurrencyFormatter.format(cashBalance)}  •  UPI: ${CurrencyFormatter.format(upiBalance)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ROW 1: TOTAL INCOME & TOTAL EXPENSES CARDS
                    Row(
                      children: [
                        // CARD 2: TOTAL INCOME
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const IncomeListScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: _buildMetricCard(
                              context: context,
                              title: 'Total Income',
                              amount: totalIncome,
                              icon: Icons.arrow_downward,
                              accentColor: AppTheme.incomeColor,
                              subtitle: 'View history',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // CARD 3: TOTAL EXPENSES
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ExpenseListScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: _buildMetricCard(
                              context: context,
                              title: 'Total Expenses',
                              amount: totalExpense,
                              icon: Icons.arrow_upward,
                              accentColor: AppTheme.expenseColor,
                              subtitle: 'View history',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ROW 2: CASH BALANCE & UPI BALANCE CARDS
                    Row(
                      children: [
                        // CARD 4: CASH BALANCE
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WalletScreen(initialTabIndex: 0),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: _buildMetricCard(
                              context: context,
                              title: 'Cash Balance',
                              amount: cashBalance,
                              icon: Icons.payments_outlined,
                              accentColor: AppTheme.cashColor,
                              subtitle: 'Cash wallet',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // CARD 5: UPI BALANCE
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WalletScreen(initialTabIndex: 1),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: _buildMetricCard(
                              context: context,
                              title: 'UPI Balance',
                              amount: upiBalance,
                              icon: Icons.account_balance_wallet_outlined,
                              accentColor: AppTheme.upiColor,
                              subtitle: 'UPI wallet',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // =========================================================
                    // TWO QUICK ACTION BUTTONS: ADD INCOME & ADD EXPENSE
                    // =========================================================
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddEditIncomeScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.incomeColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text(
                              'Add Income',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddEditExpenseScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.expenseColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.remove, size: 20),
                            label: const Text(
                              'Add Expense',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // =========================================================
                    // RECENT TRANSACTIONS (LAST 5 ITEMS) & EMPTY STATE
                    // =========================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Transactions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (transactions.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TransactionHistoryScreen(),
                                ),
                              );
                            },
                            child: const Text('View All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // STEP 3: FRIENDLY EMPTY STATE IF NO TRANSACTIONS
                    if (transactions.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long_outlined,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Transactions Recorded Yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your financial journey begins here! Tap "Add Income" or "Add Expense" to track your money.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AddEditIncomeScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Your First Income'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // RECENT TRANSACTIONS LIST (5 ITEMS)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentTransactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tx = recentTransactions[index];

                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                radius: 20,
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
                                '${DateFormatter.toDisplayDate(tx.date)} • ${tx.paymentMethod}',
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
                                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error loading transactions: $e')),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error loading wallets: $e')),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required double amount,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: accentColor.withOpacity(0.15),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              CurrencyFormatter.format(amount),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios, size: 9, color: accentColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
