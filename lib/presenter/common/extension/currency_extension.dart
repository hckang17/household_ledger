import 'package:intl/intl.dart';

extension CurrencyFormatter on num {
  String toCurrency() {
    return NumberFormat('#,###').format(this);
  }
}
