import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('an API timestamp (UTC) renders as Indonesian local time, not ISO', () {
    const iso = '2026-11-10T23:11:51.000000Z';
    final local = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    expect(
      DateFormatter.format(iso, pattern: 'd MMM yyyy, HH:mm'),
      '${local.day} Nov 2026, ${two(local.hour)}:${two(local.minute)}',
    );
    expect(DateFormatter.format(iso), matches(RegExp(r'^\d{2} Nov 2026$')));
  });

  test('null and unparsable input keep their fallbacks', () {
    expect(DateFormatter.format(null), '-');
    expect(DateFormatter.format('bukan tanggal'), 'bukan tanggal');
  });
}
