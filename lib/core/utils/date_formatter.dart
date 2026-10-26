import 'package:intl/intl.dart';

/// Utility functions for date, time, and currency formatting
class DateFormatter {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  static String toIsoDate(DateTime date) => _dateFormat.format(date);
  static String toDisplayDate(DateTime date) => _displayFormat.format(date);
  static String toDisplayTime(DateTime date) => _timeFormat.format(date);

  static DateTime parseIsoDate(String str) => _dateFormat.parse(str);
}

class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
    locale: 'en_IN',
  );

  static String format(double amount, {String symbol = '₹'}) {
    return _currencyFormat.format(amount).replaceFirst('₹', symbol);
  }
}
