import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatRupiah(dynamic amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount ?? 0);
  }
}
