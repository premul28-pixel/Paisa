import '../models/transaction_model.dart';
import '../services/sqlite_service.dart';

/// Repository abstracting data access for Transactions
class TransactionRepository {
  final SqliteService _sqliteService;

  TransactionRepository({SqliteService? sqliteService})
      : _sqliteService = sqliteService ?? SqliteService();

  Future<int> addTransaction(TransactionModel transaction) {
    return _sqliteService.insertTransaction(transaction);
  }

  Future<int> updateTransaction(TransactionModel transaction) {
    return _sqliteService.updateTransaction(transaction);
  }

  Future<int> deleteTransaction(int id) {
    return _sqliteService.deleteTransaction(id);
  }

  Future<List<TransactionModel>> getAllTransactions({
    String orderBy = 'date DESC, id DESC',
    int? limit,
    int? offset,
  }) {
    return _sqliteService.getAllTransactions(
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<TransactionModel?> getTransactionById(int id) {
    return _sqliteService.getTransactionById(id);
  }

  Future<List<TransactionModel>> getFilteredTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? category,
    String? paymentMethod,
    String? searchQuery,
  }) {
    return _sqliteService.getFilteredTransactions(
      startDate: startDate,
      endDate: endDate,
      type: type,
      category: category,
      paymentMethod: paymentMethod,
      searchQuery: searchQuery,
    );
  }

  Future<Map<String, double>> getFinancialSummary() {
    return _sqliteService.getFinancialSummary();
  }
}
