import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../repositories/profile_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ProfileRepository(authService: authService);
});

/// StateNotifier to manage user authentication state across the app
class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthService _authService;
  final ProfileRepository _profileRepo;

  AuthNotifier(this._authService, this._profileRepo)
      : super(const AsyncValue.loading()) {
    init();
  }

  Future<void> init() async {
    try {
      final user = await _authService.restoreSession();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signup({
    required String userId,
    required String password,
    required String recoveryPin,
    required String name,
    required String dob,
    required String email,
    required String phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signup(
        userId: userId,
        password: password,
        recoveryPin: recoveryPin,
        name: name,
        dob: dob,
        email: email,
        phone: phone,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> login({
    required String userId,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.login(
        userId: userId,
        password: password,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> forgotPassword({
    required String userId,
    required String recoveryPin,
    required String newPassword,
  }) async {
    await _authService.forgotPassword(
      userId: userId,
      recoveryPin: recoveryPin,
      newPassword: newPassword,
    );
  }

  Future<void> updateProfile({
    required String userId,
    required String name,
    required String dob,
    required String email,
    required String phone,
  }) async {
    try {
      final updatedUser = await _profileRepo.updateProfile(
        userId: userId,
        name: name,
        dob: dob,
        email: email,
        phone: phone,
      );
      state = AsyncValue.data(updatedUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  return AuthNotifier(authService, profileRepo);
});
