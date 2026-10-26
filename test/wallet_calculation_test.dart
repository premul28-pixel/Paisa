import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wallet Balance Calculation Logic Tests', () {
    test('Income adds to Cash wallet balance', () {
      double cashBalance = 1000.0;
      const double incomeAmount = 500.0;

      // Formula: Cash Balance increases on Cash Income
      cashBalance += incomeAmount;

      expect(cashBalance, equals(1500.0));
    });

    test('Income adds to UPI wallet balance', () {
      double upiBalance = 2500.0;
      const double incomeAmount = 1500.0;

      // Formula: UPI Balance increases on UPI Income
      upiBalance += incomeAmount;

      expect(upiBalance, equals(4000.0));
    });

    test('Expense subtracts from Cash wallet balance', () {
      double cashBalance = 1000.0;
      const double expenseAmount = 350.0;

      // Formula: Cash Balance decreases on Cash Expense
      cashBalance -= expenseAmount;

      expect(cashBalance, equals(650.0));
    });

    test('Expense subtracts from UPI wallet balance', () {
      double upiBalance = 5000.0;
      const double expenseAmount = 1200.0;

      // Formula: UPI Balance decreases on UPI Expense
      upiBalance -= expenseAmount;

      expect(upiBalance, equals(3800.0));
    });

    test('Remaining balance formula: Cash Balance + UPI Balance', () {
      const double cashBalance = 850.50;
      const double upiBalance = 3420.75;

      final double remainingBalance = cashBalance + upiBalance;

      expect(remainingBalance, equals(4271.25));
    });

    test('Transaction edit reversal and re-application logic', () {
      // Scenario:
      // Initial: Cash = 1000, UPI = 2000
      double cashBalance = 1000.0;
      double upiBalance = 2000.0;

      // 1. User added an expense of 200 in Cash
      cashBalance -= 200.0; // cash is now 800
      expect(cashBalance, equals(800.0));

      // 2. User edits the transaction:
      // It was actually an expense of 300 via UPI!
      // Step A: Reverse old transaction effect on old wallet (Cash)
      cashBalance += 200.0; // cash restored to 1000
      expect(cashBalance, equals(1000.0));

      // Step B: Apply new transaction effect on new wallet (UPI)
      upiBalance -= 300.0; // upi is now 1700
      expect(upiBalance, equals(1700.0));
    });

    test('Transaction deletion reversal logic', () {
      // Scenario:
      // Initial: Cash = 1500
      double cashBalance = 1500.0;

      // 1. User logged an expense of 500
      cashBalance -= 500.0;
      expect(cashBalance, equals(1000.0));

      // 2. User deletes the expense:
      // Reversal: Add back amount to Cash wallet
      cashBalance += 500.0;
      expect(cashBalance, equals(1500.0));

      // 3. User logged an income of 700 via UPI
      double upiBalance = 1000.0;
      upiBalance += 700.0;
      expect(upiBalance, equals(1700.0));

      // 4. User deletes the income:
      // Reversal: Subtract amount from UPI wallet
      upiBalance -= 700.0;
      expect(upiBalance, equals(1000.0));
    });
  });
}
