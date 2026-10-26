import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../income/add_edit_income_screen.dart';
import '../expenses/add_edit_expense_screen.dart';

class WalletScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const WalletScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets Detail'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.payments_outlined),
              text: 'Cash Wallet',
            ),
            Tab(
              icon: Icon(Icons.account_balance_wallet_outlined),
              text: 'UPI Wallet',
            ),
          ],
        ),
      ),
      body: walletsAsync.when(
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
            data: (allTransactions) {
              final cashTransactions = allTransactions
                  .where((t) => t.paymentMethod == AppConstants.walletCash)
                  .toList();
              final upiTransactions = allTransactions
                  .where((t) => t.paymentMethod == AppConstants.walletUpi)
                  .toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: CASH WALLET
                  _buildWalletDetailView(
                    walletName: 'Cash Wallet',
                    balance: cashWallet.balance,
                    icon: Icons.payments_outlined,
                    accentColor: AppTheme.cashColor,
                    transactions: cashTransactions,
                    onAddIncome: () => _openAddIncome(AppConstants.walletCash),
                    onAddExpense: () => _openAddExpense(AppConstants.walletCash),
                  ),

                  // TAB 2: UPI WALLET
                  _buildWalletDetailView(
                    walletName: 'UPI Wallet',
                    balance: upiWallet.balance,
                    icon: Icons.account_balance_wallet_outlined,
                    accentColor: AppTheme.upiColor,
                    transactions: upiTransactions,
                    onAddIncome: () => _openAddIncome(AppConstants.walletUpi),
                    onAddExpense: () => _openAddExpense(AppConstants.walletUpi),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading transactions: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading wallets: $e')),
      ),
    );
  }

  void _openAddIncome(String paymentMethod) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditIncomeScreen(),
      ),
    );
  }

  void _openAddExpense(String paymentMethod) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditExpenseScreen(),
      ),
    );
  }

  Widget _buildWalletDetailView({
    required String walletName,
    required double balance,
    required IconData icon,
    required Color accentColor,
    required List<TransactionModel> transactions,
    required VoidCallback onAddIncome,
    required VoidCallback onAddExpense,
  }) {
    final incomeSum = transactions
        .where((t) => t.isIncome)
        .fold<double>(0.0, (s, t) => s + t.amount);
    final expenseSum = transactions
        .where((t) => t.isExpense)
        .fold<double>(0.0, (s, t) => s + t.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. HERO WALLET CARD
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.35),
                blurRadius: 12,
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
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        walletName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${transactions.length} logs',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Available Liquid Balance',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.format(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. INFLOW & OUTFLOW STATS FOR THIS WALLET
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_downward, color: AppTheme.incomeColor, size: 18),
                          const SizedBox(width: 6),
                          Text('Deposits', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.format(incomeSum),
                        style: const TextStyle(
                          color: AppTheme.incomeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_upward, color: AppTheme.expenseColor, size: 18),
                          const SizedBox(width: 6),
                          Text('Withdrawals', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.format(expenseSum),
                        style: const TextStyle(
                          color: AppTheme.expenseColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. QUICK WALLET ACTIONS
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAddIncome,
                icon: const Icon(Icons.add, color: AppTheme.incomeColor),
                label: const Text('Deposit Income'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAddExpense,
                icon: const Icon(Icons.remove, color: AppTheme.expenseColor),
                label: const Text('Spend Expense'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 4. WALLET TRANSACTIONS LIST
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$walletName History',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${transactions.length} total',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (transactions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: accentColor.withOpacity(0.12),
                    child: Icon(icon, size: 32, color: accentColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No $walletName transactions yet',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Any income or expense logged using $walletName will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tx = transactions[index];

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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${DateFormatter.toDisplayDate(tx.date)}${tx.notes != null && tx.notes!.isNotEmpty ? " • ${tx.notes}" : ""}'),
                  trailing: Text(
                    '${tx.isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}',
                    style: TextStyle(
                      color: tx.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
