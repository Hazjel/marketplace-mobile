import 'package:intl/intl.dart';

/// Needs `initializeDateFormatting('id_ID')` at startup (main.dart); without
/// it [format] returns the raw string.
class DateFormatter {
  static String format(String? dateString, {String pattern = 'dd MMM yyyy'}) {
    if (dateString == null) return '-';
    try {
      // The API sends UTC ("...Z"); show the device's local time.
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat(pattern, 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  static String timeAgo(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 30) return format(dateString);
      if (diff.inDays > 0) return '${diff.inDays} hari lalu';
      if (diff.inHours > 0) return '${diff.inHours} jam lalu';
      if (diff.inMinutes > 0) return '${diff.inMinutes} menit lalu';
      return 'Baru saja';
    } catch (e) {
      return dateString;
    }
  }
}
