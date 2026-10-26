import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet_model.dart';
import '../repositories/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository();
});

/// Fetches the latest list of wallets (Cash & UPI) from SQLite
final walletsProvider = FutureProvider<List<WalletModel>>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  return repo.getWallets();
});

/// Alias for backwards compatibility
final walletsStreamProvider = walletsProvider;

/// Provider specifically for the Cash wallet
final cashWalletProvider = Provider<AsyncValue<WalletModel?>>((ref) {
  final walletsAsync = ref.watch(walletsProvider);
  return walletsAsync.whenData((wallets) {
    try {
      return wallets.firstWhere((w) => w.name.toLowerCase() == 'cash');
    } catch (_) {
      return null;
    }
  });
});

/// Provider specifically for the UPI wallet
final upiWalletProvider = Provider<AsyncValue<WalletModel?>>((ref) {
  final walletsAsync = ref.watch(walletsProvider);
  return walletsAsync.whenData((wallets) {
    try {
      return wallets.firstWhere((w) => w.name.toLowerCase() == 'upi');
    } catch (_) {
      return null;
    }
  });
});
