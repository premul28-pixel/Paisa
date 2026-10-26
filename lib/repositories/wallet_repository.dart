import '../models/wallet_model.dart';
import '../services/sqlite_service.dart';

/// Repository abstracting data access for Wallets
class WalletRepository {
  final SqliteService _sqliteService;

  WalletRepository({SqliteService? sqliteService})
      : _sqliteService = sqliteService ?? SqliteService();

  Future<List<WalletModel>> getWallets() {
    return _sqliteService.getAllWallets();
  }

  Future<WalletModel?> getWalletByName(String name) {
    return _sqliteService.getWalletByName(name);
  }
}
