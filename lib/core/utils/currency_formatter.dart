import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
    locale: 'en_IN',
  );

  /// Converts price in paise (integer) to formatted currency string (e.g. ₹280.00)
  static String formatPaise(int paise) {
    double amount = paise / 100.0;
    return _currencyFormat.format(amount);
  }
}
