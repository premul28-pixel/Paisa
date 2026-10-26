import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import 'wallet_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

class TransactionNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final TransactionRepository _repository;
  final Ref _ref;

  TransactionNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  /// Fetches all transactions from SQLite database
  Future<void> loadTransactions({bool showLoading = false}) async {
    try {
      if (showLoading && !state.isLoading) {
        state = const AsyncValue.loading();
      }
      final transactions = await _repository.getAllTransactions();
      state = AsyncValue.data(transactions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Adds a transaction, automatically updating wallet balances and refreshing all streams
  Future<void> addTransaction(TransactionModel tx) async {
    try {
      await _repository.addTransaction(tx);
      await loadTransactions();
      // Refresh dependent state so wallet balances NEVER go out of sync
      _ref.invalidate(walletsProvider);
      _ref.invalidate(financialSummaryProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Updates a transaction, atomically reversing previous effect and applying new effect
  Future<void> updateTransaction(TransactionModel tx) async {
    try {
      await _repository.updateTransaction(tx);
      await loadTransactions();
      // Refresh dependent state
      _ref.invalidate(walletsProvider);
      _ref.invalidate(financialSummaryProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Deletes a transaction and restores wallet balances
  Future<void> deleteTransaction(int id) async {
    try {
      await _repository.deleteTransaction(id);
      await loadTransactions();
      // Refresh dependent state
      _ref.invalidate(walletsProvider);
      _ref.invalidate(financialSummaryProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Global provider for all transactions
final transactionsProvider =
    StateNotifierProvider<TransactionNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return TransactionNotifier(repo, ref);
});

/// Exposes only Income transactions
final incomeTransactionsProvider = Provider<AsyncValue<List<TransactionModel>>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  return transactionsAsync.whenData(
    (list) => list.where((tx) => tx.isIncome).toList(),
  );
});

/// Exposes only Expense transactions
final expenseTransactionsProvider = Provider<AsyncValue<List<TransactionModel>>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  return transactionsAsync.whenData(
    (list) => list.where((tx) => tx.isExpense).toList(),
  );
});

/// Financial summary provider calculating real-time balances
final financialSummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getFinancialSummary();
});
