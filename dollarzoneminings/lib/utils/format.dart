// lib/utils/format.dart
import 'package:intl/intl.dart';

class FormatHelper {
  /// Formats a number as coins with 2 decimals
  static String coins(double coins) {
    return "${coins.toStringAsFixed(2)} Coins";
  }

  /// Formats balance to $ sign
  static String currency(double value) {
    final NumberFormat formatter = NumberFormat.currency(symbol: "\$");
    return formatter.format(value);
  }

  /// Formats date or timestamp to readable time
  static String dateTime(DateTime date) {
    return DateFormat("MMM dd, yyyy - hh:mm a").format(date);
  }

  /// Converts Firebase timestamp to readable string
  static String timestamp(dynamic ts) {
    if (ts == null) return "--";
    try {
      final dt = (ts as DateTime);
      return dateTime(dt);
    } catch (_) {
      return ts.toString();
    }
  }
}