import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/balance/models/buyer_balance_model.dart';

Map<String, dynamic> _row({String type = 'refund', Object amount = 26000}) => {
      'id': 7,
      'type': type,
      'amount': amount,
      'remarks': 'Refund pesanan TRX-1',
      'reference_code': 'TRX-1',
      'created_at': '2026-10-10T08:00:00.000000Z',
    };

Map<String, dynamic> _data({List<Map<String, dynamic>>? rows, int page = 1, int lastPage = 2}) => {
      'balance': 45000,
      'histories': {
        'data': rows ?? [_row()],
        'meta': {'current_page': page, 'last_page': lastPage, 'per_page': 20, 'total': 21},
      },
    };

void main() {
  group('BuyerBalancePage.fromJson', () {
    test('reads the balance, history rows and pagination', () {
      final page = BuyerBalancePage.fromJson(_data());

      expect(page.balance, 45000);
      expect(page.histories.items, hasLength(1));
      final row = page.histories.items.single;
      expect(row.id, '7');
      expect(row.type, 'refund');
      expect(row.amount, 26000);
      expect(row.referenceCode, 'TRX-1');
      expect(page.histories.meta.currentPage, 1);
      expect(page.histories.hasMore, isTrue);
    });

    test('the last page has no more', () {
      expect(BuyerBalancePage.fromJson(_data(page: 2)).histories.hasMore, isFalse);
    });

    test('rejects a non-integer amount instead of showing a wrong number', () {
      expect(() => BuyerBalancePage.fromJson(_data(rows: [_row(amount: 1.5)])), throwsFormatException);
      expect(() => BuyerBalancePage.fromJson({..._data(), 'balance': '45000'}), throwsFormatException);
    });
  });

  group('BuyerBalanceHistory', () {
    BuyerBalanceHistory row(String type, int amount) =>
        BuyerBalanceHistory.fromJson(_row(type: type, amount: amount));

    test('labels match the web', () {
      expect(row('refund', 1).typeLabel, 'Refund');
      expect(row('payment', -1).typeLabel, 'Dipakai belanja');
      expect(row('payment_returned', 1).typeLabel, 'Dikembalikan');
      expect(row('something_new', 1).typeLabel, 'something_new');
    });

    test('signs: + for credit, − for debit, none at zero', () {
      expect(row('refund', 26000).signedAmount, startsWith('+Rp'));
      expect(row('payment', -26000).signedAmount, startsWith('−Rp'));
      expect(row('payment', -26000).signedAmount, endsWith('26.000'));
      expect(row('refund', 0).signedAmount, startsWith('Rp'));
    });
  });
}
