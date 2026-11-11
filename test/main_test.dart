import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/core/utils/date_formatter.dart';
import 'package:blukios_marketplace/main.dart';

// Deliberately does not call initializeDateFormatting itself: this is the one
// test that guards what main() does at startup.
void main() {
  test('initLocale makes DateFormatter print Indonesian dates, not ISO', () async {
    const iso = '2026-11-10T12:00:00.000000Z';
    expect(DateFormatter.format(iso), iso, reason: 'no locale data before initLocale');

    await initLocale();

    expect(DateFormatter.format(iso), matches(RegExp(r'^\d{2} Nov 2026$')));
  });
}
