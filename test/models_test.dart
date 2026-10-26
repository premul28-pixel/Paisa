import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/models/transaction_model.dart';
import 'package:paisa/models/wallet_model.dart';
import 'package:paisa/models/user_model.dart';
import 'package:paisa/models/app_settings_model.dart';

void main() {
  group('TransactionModel Tests', () {
    test('Correctly identifies income and expense types', () {
      final incomeTx = TransactionModel(
        id: 1,
        type: 'income',
        amount: 5000.0,
        date: DateTime(2026, 9, 20),
        source: 'Salary',
        paymentMethod: 'UPI',
        createdAt: DateTime(2026, 9, 20),
      );

      final expenseTx = TransactionModel(
        id: 2,
        type: 'expense',
        amount: 250.0,
        date: DateTime(2026, 9, 20),
        category: 'Food',
        paymentMethod: 'Cash',
        createdAt: DateTime(2026, 9, 20),
      );

      expect(incomeTx.isIncome, isTrue);
      expect(incomeTx.isExpense, isFalse);
      expect(incomeTx.source, equals('Salary'));
      expect(incomeTx.category, isNull);

      expect(expenseTx.isIncome, isFalse);
      expect(expenseTx.isExpense, isTrue);
      expect(expenseTx.category, equals('Food'));
      expect(expenseTx.source, isNull);
    });

    test('toMap and fromMap serialization round-trip', () {
      final date = DateTime(2026, 9, 15, 10, 30);
      final tx = TransactionModel(
        id: 10,
        type: 'expense',
        amount: 1200.50,
        date: date,
        category: 'Shopping',
        paymentMethod: 'UPI',
        notes: 'Groceries and snacks',
        createdAt: date,
        updatedAt: date,
      );

      final map = tx.toMap();
      expect(map['id'], equals(10));
      expect(map['type'], equals('expense'));
      expect(map['amount'], equals(1200.50));
      expect(map['category'], equals('Shopping'));
      expect(map['payment_method'], equals('UPI'));
      expect(map['notes'], equals('Groceries and snacks'));

      final restored = TransactionModel.fromMap(map);
      expect(restored.id, equals(tx.id));
      expect(restored.type, equals(tx.type));
      expect(restored.amount, equals(tx.amount));
      expect(restored.date, equals(tx.date));
      expect(restored.category, equals(tx.category));
      expect(restored.paymentMethod, equals(tx.paymentMethod));
      expect(restored.notes, equals(tx.notes));
    });

    test('copyWith properly copies updated fields', () {
      final tx = TransactionModel(
        id: 1,
        type: 'income',
        amount: 1000.0,
        date: DateTime(2026, 1, 1),
        source: 'Freelance',
        paymentMethod: 'Cash',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = tx.copyWith(
        amount: 1500.0,
        paymentMethod: 'UPI',
      );

      expect(updated.id, equals(1));
      expect(updated.amount, equals(1500.0));
      expect(updated.paymentMethod, equals('UPI'));
      expect(updated.source, equals('Freelance'));
    });
  });

  group('WalletModel Tests', () {
    test('Initializes with balance and serialization round-trip', () {
      const wallet = WalletModel(name: 'Cash', balance: 0.0);
      expect(wallet.balance, equals(0.0));

      final map = wallet.toMap();
      expect(map['name'], equals('Cash'));
      expect(map['balance'], equals(0.0));

      final restored = WalletModel.fromMap({
        'id': 1,
        'name': 'UPI',
        'balance': 2450.75,
      });

      expect(restored.id, equals(1));
      expect(restored.name, equals('UPI'));
      expect(restored.balance, equals(2450.75));
    });

    test('copyWith updates balance', () {
      const wallet = WalletModel(id: 2, name: 'UPI', balance: 500.0);
      final updated = wallet.copyWith(balance: 1200.0);

      expect(updated.id, equals(2));
      expect(updated.name, equals('UPI'));
      expect(updated.balance, equals(1200.0));
    });
  });

  group('UserModel Tests', () {
    test('toMap and fromMap serialization round-trip', () {
      final user = UserModel(
        id: 1,
        userId: 'john_doe',
        passwordHash: 'hash123456',
        recoveryPin: '123456',
        profileName: 'John Doe',
        dob: '1995-05-12',
        email: 'john@example.com',
        phone: '9876543210',
      );

      final map = user.toMap();
      expect(map['user_id'], equals('john_doe'));
      expect(map['recovery_pin'], equals('123456'));

      final restored = UserModel.fromMap(map);
      expect(restored.userId, equals('john_doe'));
      expect(restored.profileName, equals('John Doe'));
      expect(restored.email, equals('john@example.com'));
      expect(restored.phone, equals('9876543210'));
    });
  });

  group('AppSettingsModel Tests', () {
    test('Serialization round-trip and common keys', () {
      const settings = AppSettingsModel(
        key: AppSettingsModel.keyDarkMode,
        value: 'false',
      );
      expect(settings.key, equals('is_dark_mode'));
      expect(settings.value, equals('false'));

      final map = settings.toMap();
      expect(map['key'], equals('is_dark_mode'));
      expect(map['value'], equals('false'));

      final restored = AppSettingsModel.fromMap(map);
      expect(restored.key, equals(settings.key));
      expect(restored.value, equals(settings.value));
    });
  });
}
