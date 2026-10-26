import '../models/user_model.dart';
import '../services/sqlite_service.dart';
import '../services/auth_service.dart';

/// Repository managing user profile retrieval and updates
class ProfileRepository {
  final SqliteService _sqliteService;
  final AuthService _authService;

  ProfileRepository({
    SqliteService? sqliteService,
    AuthService? authService,
  })  : _sqliteService = sqliteService ?? SqliteService(),
        _authService = authService ?? AuthService();

  // ===========================================================================
  // STEP 5: GET PROFILE
  // ===========================================================================

  /// Fetches the user profile.
  /// If [userId] is omitted, attempts to fetch the currently authenticated user
  /// or the primary local user.
  Future<UserModel?> getProfile({String? userId}) async {
    final targetId = userId ?? _authService.currentUser?.userId;

    if (targetId != null && targetId.isNotEmpty) {
      final user = await _sqliteService.getUserByUserId(targetId);
      if (user != null) return user;
    }

    // Fallback: fetch first local user if no active session id
    return await _sqliteService.getFirstUser();
  }

  // ===========================================================================
  // STEP 5: UPDATE PROFILE (NAME, DOB, EMAIL, PHONE ARE COMPULSORY)
  // ===========================================================================

  /// Updates mandatory personal profile information:
  /// [name], [dob], [email], and [phone].
  Future<UserModel> updateProfile({
    required String userId,
    required String name,
    required String dob,
    required String email,
    required String phone,
  }) async {
    final cleanUserId = userId.trim();
    final cleanName = name.trim();
    final cleanDob = dob.trim();
    final cleanEmail = email.trim();
    final cleanPhone = phone.trim().replaceAll(RegExp(r'[\s-]'), '');

    // 1. Validate mandatory fields
    if (cleanUserId.isEmpty) {
      throw ArgumentError('User ID is required to update profile.');
    }
    if (cleanName.isEmpty) {
      throw ArgumentError('Full Name is compulsory.');
    }
    if (cleanDob.isEmpty) {
      throw ArgumentError('Date of Birth is compulsory.');
    }

    // Validate email format
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(cleanEmail)) {
      throw ArgumentError('A valid Email address is compulsory.');
    }

    // Validate phone format (10-15 digits)
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(cleanPhone)) {
      throw ArgumentError('A valid Phone number (10-15 digits) is compulsory.');
    }

    // 2. Perform SQLite database update
    final rowsUpdated = await _sqliteService.updateUserProfile(
      userId: cleanUserId,
      profileName: cleanName,
      dob: cleanDob,
      email: cleanEmail,
      phone: cleanPhone,
    );

    if (rowsUpdated == 0) {
      throw Exception('Failed to update profile. User "$cleanUserId" not found.');
    }

    // 3. Fetch and return updated profile
    final updatedUser = await _sqliteService.getUserByUserId(cleanUserId);
    if (updatedUser == null) {
      throw Exception('User profile retrieval failed after update.');
    }

    return updatedUser;
  }
}
