import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';
import 'sqlite_service.dart';

/// Authentication Service managing user registration, secure login,
/// local 6-digit PIN verification, and password resets using SHA-256.
class AuthService {
  final SqliteService _sqliteService;
  UserModel? _currentUser;

  AuthService({SqliteService? sqliteService})
      : _sqliteService = sqliteService ?? SqliteService();

  /// Gets the currently authenticated user in session.
  UserModel? get currentUser => _currentUser;

  /// Returns true if a user is currently logged in.
  bool get isAuthenticated => _currentUser != null;

  static const String _sessionUserKey = 'logged_in_user_id';

  /// Hashes a plaintext password or input using SHA-256.
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Restores session on app startup if a user was previously logged in.
  Future<UserModel?> restoreSession() async {
    final savedUserId = await _sqliteService.getSetting(_sessionUserKey);
    if (savedUserId != null && savedUserId.isNotEmpty) {
      final user = await _sqliteService.getUserByUserId(savedUserId);
      if (user != null) {
        _currentUser = user;
        return user;
      }
    }
    return null;
  }

  // ===========================================================================
  // STEP 2: SIGNUP (ALL FIELDS ARE COMPULSORY AND VALIDATED)
  // ===========================================================================

  /// Registers a new user with compulsory fields:
  /// [userId], [password], [recoveryPin] (6-digit), [name], [dob], [email], [phone].
  Future<UserModel> signup({
    required String userId,
    required String password,
    required String recoveryPin,
    required String name,
    required String dob,
    required String email,
    required String phone,
  }) async {
    // 1. Validation - All fields are COMPULSORY
    _validateCompulsoryFields(
      userId: userId,
      password: password,
      recoveryPin: recoveryPin,
      name: name,
      dob: dob,
      email: email,
      phone: phone,
    );

    final cleanUserId = userId.trim();

    // 2. Check if user_id is already registered
    final existingUser = await _sqliteService.getUserByUserId(cleanUserId);
    if (existingUser != null) {
      throw Exception('User ID "$cleanUserId" is already taken. Please choose another.');
    }

    // 3. Hash password using SHA-256
    final hashedPassword = hashPassword(password);

    // 4. Construct UserModel
    final newUser = UserModel(
      userId: cleanUserId,
      passwordHash: hashedPassword,
      recoveryPin: recoveryPin.trim(),
      profileName: name.trim(),
      dob: dob.trim(),
      email: email.trim(),
      phone: phone.trim(),
    );

    // 5. Insert into SQLite users table
    final insertedId = await _sqliteService.insertUser(newUser);
    final userWithId = newUser.copyWith(id: insertedId);

    // 6. Establish session
    _currentUser = userWithId;
    await _sqliteService.setSetting(_sessionUserKey, cleanUserId);

    return userWithId;
  }

  // ===========================================================================
  // STEP 3: LOGIN (HASH PASSWORD & COMPARE WITH DB)
  // ===========================================================================

  /// Authenticates a user by checking their user_id and SHA-256 hashed password.
  Future<UserModel> login({
    required String userId,
    required String password,
  }) async {
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw ArgumentError('User ID cannot be empty.');
    }
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }

    // 1. Fetch user from local SQLite DB
    final user = await _sqliteService.getUserByUserId(cleanUserId);
    if (user == null) {
      throw Exception('User not found. Please check your User ID or sign up.');
    }

    // 2. Hash input password using SHA-256
    final inputHash = hashPassword(password);

    // 3. Compare hashed password with stored password_hash
    if (inputHash != user.passwordHash) {
      throw Exception('Incorrect password. Please try again or use Forgot Password.');
    }

    // 4. Set current session
    _currentUser = user;
    await _sqliteService.setSetting(_sessionUserKey, cleanUserId);

    return user;
  }

  // ===========================================================================
  // STEP 4: FORGOT PASSWORD & 6-DIGIT PIN VERIFICATION
  // ===========================================================================

  /// Verifies the 6-digit recovery PIN locally for a given [userId].
  Future<bool> verifyRecoveryPin({
    required String userId,
    required String recoveryPin,
  }) async {
    final cleanUserId = userId.trim();
    final cleanPin = recoveryPin.trim();

    if (cleanUserId.isEmpty) {
      throw ArgumentError('User ID cannot be empty.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
      throw ArgumentError('Recovery PIN must be exactly 6 digits.');
    }

    final user = await _sqliteService.getUserByUserId(cleanUserId);
    if (user == null) {
      throw Exception('User "$cleanUserId" not found.');
    }

    // Locally compare the 6-digit recovery PIN
    return user.recoveryPin == cleanPin;
  }

  /// Implements forgotPassword:
  /// Verifies the 6-digit recovery PIN locally. If correct, allows setting a [newPassword].
  Future<void> forgotPassword({
    required String userId,
    required String recoveryPin,
    required String newPassword,
  }) async {
    final cleanUserId = userId.trim();
    final cleanPin = recoveryPin.trim();

    // 1. Verify PIN format
    if (!RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
      throw ArgumentError('Recovery PIN must be exactly 6 digits.');
    }

    // 2. Validate new password
    if (newPassword.length < 6) {
      throw ArgumentError('New password must be at least 6 characters long.');
    }

    // 3. Verify user and recovery PIN
    final isValidPin = await verifyRecoveryPin(
      userId: cleanUserId,
      recoveryPin: cleanPin,
    );

    if (!isValidPin) {
      throw Exception('Invalid 6-digit recovery PIN.');
    }

    // 4. Hash new password with SHA-256
    final newHash = hashPassword(newPassword);

    // 5. Update user password in SQLite database
    final rowsUpdated = await _sqliteService.updateUserPassword(cleanUserId, newHash);
    if (rowsUpdated == 0) {
      throw Exception('Failed to update password. User not found.');
    }

    // Update in-memory user if currently active
    if (_currentUser != null && _currentUser!.userId == cleanUserId) {
      _currentUser = _currentUser!.copyWith(passwordHash: newHash);
    }
  }

  /// Logs out the current user and clears session state.
  Future<void> logout() async {
    _currentUser = null;
    await _sqliteService.setSetting(_sessionUserKey, '');
  }

  // ===========================================================================
  // COMPULSORY VALIDATIONS
  // ===========================================================================

  void _validateCompulsoryFields({
    required String userId,
    required String password,
    required String recoveryPin,
    required String name,
    required String dob,
    required String email,
    required String phone,
  }) {
    // User ID validation
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID is compulsory and cannot be empty.');
    }
    if (userId.trim().length < 3) {
      throw ArgumentError('User ID must be at least 3 characters.');
    }

    // Password validation
    if (password.isEmpty) {
      throw ArgumentError('Password is compulsory.');
    }
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters long.');
    }

    // Recovery PIN validation: exactly 6 digits
    if (!RegExp(r'^\d{6}$').hasMatch(recoveryPin.trim())) {
      throw ArgumentError('Recovery PIN is compulsory and must be exactly 6 digits.');
    }

    // Name validation
    if (name.trim().isEmpty) {
      throw ArgumentError('Full Name is compulsory.');
    }

    // DOB validation
    if (dob.trim().isEmpty) {
      throw ArgumentError('Date of Birth is compulsory.');
    }

    // Email validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email.trim())) {
      throw ArgumentError('A valid Email address is compulsory.');
    }

    // Phone validation (10 to 15 digits, optional leading +)
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(phone.trim().replaceAll(RegExp(r'[\s-]'), ''))) {
      throw ArgumentError('A valid Phone number (10-15 digits) is compulsory.');
    }
  }
}
