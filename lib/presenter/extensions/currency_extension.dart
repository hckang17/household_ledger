// """ 계층: Presenter Utility Extension """
// """ 역할: 화면 표시용 금액 천 단위 포맷 제공 """

import 'package:intl/intl.dart';

extension CurrencyFormatter on num {
  String toCurrency() {
    return NumberFormat('#,###').format(this);
  }
}
