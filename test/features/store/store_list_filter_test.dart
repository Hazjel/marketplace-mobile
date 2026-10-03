import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/features/store/models/store_model.dart';
import 'package:blukios_marketplace/features/store/screens/store_list_screen.dart';

StoreModel _store(String name, {String? city, String? address}) =>
    StoreModel.fromJson({
      'id': name,
      'name': name,
      'username': name.toLowerCase(),
      'city': city,
      'address': address,
      'is_verified': false,
      'product_count': 0,
      'transaction_count': 0,
    });

void main() {
  final stores = [
    _store('Toko Gadget', city: 'JAKARTA BARAT'),
    _store('Kios Baju', city: 'Bandung', address: 'Jl. Dago 1'),
    _store('Tanpa Kota'),
  ];

  List<String> names(String q) => filterStores(stores, q).map((s) => s.name).toList();

  test('empty query keeps every store', () {
    expect(names('  '), hasLength(3));
  });

  test('matches name, city or address, case-insensitively', () {
    expect(names('gadget'), ['Toko Gadget']);
    expect(names('jakarta'), ['Toko Gadget']);
    expect(names('dago'), ['Kios Baju']);
  });

  test('a store without a city is not an error, just no match', () {
    expect(names('surabaya'), isEmpty);
  });
}
