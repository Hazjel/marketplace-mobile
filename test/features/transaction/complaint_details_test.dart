import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/transaction/widgets/complaint_details.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 8);

  String left(Duration d) => complaintTimeLeft(now.add(d), now);

  test('past the deadline', () {
    expect(left(const Duration(minutes: -1)),
        'Batas waktu lewat, komplain segera diteruskan ke admin.');
  });

  test('under an hour', () {
    expect(left(const Duration(minutes: 59)), 'Sisa kurang dari 1 jam.');
    expect(left(Duration.zero), 'Sisa kurang dari 1 jam.');
  });

  test('hours', () {
    expect(left(const Duration(minutes: 60)), 'Sisa 1 jam.');
    expect(left(const Duration(hours: 23, minutes: 59)), 'Sisa 23 jam.');
  });

  test('days', () {
    expect(left(const Duration(hours: 24)), 'Sisa 1 hari 0 jam.');
    expect(left(const Duration(days: 1, hours: 23, minutes: 30)), 'Sisa 1 hari 23 jam.');
  });
}
