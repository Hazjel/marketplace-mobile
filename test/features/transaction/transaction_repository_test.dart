import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _ok() => Response(
      requestOptions: RequestOptions(),
      data: {
        'data': {
          'id': 't1',
          'code': 'TRX-t1',
          'shipping_cost': 0,
          'tax': 0,
          'grand_total': 26000,
          'discount_amount': 0,
          'delivery_status': 'delivering',
          'payment_status': 'paid',
          'complaint': {'id': 'c1', 'status': 'open'},
        },
      },
    );

void main() {
  late MockApiClient api;
  late TransactionRepository repository;

  setUp(() {
    api = MockApiClient();
    repository = TransactionRepository(api);
    when(() => api.post(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok());
  });

  test('createComplaint posts multipart reason, description and photos[]', () async {
    final dir = Directory.systemTemp.createTempSync('complaint');
    addTearDown(() => dir.deleteSync(recursive: true));
    final a = File('${dir.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
    final b = File('${dir.path}/b.png')..writeAsBytesSync([4, 5]);

    final trx = await repository.createComplaint(
      id: 't1',
      reason: 'damaged',
      description: 'Kemasan penyok parah',
      photoPaths: [a.path, b.path],
    );

    final captured =
        verify(() => api.post('/transaction/t1/complaint', data: captureAny(named: 'data'))).captured;
    final form = captured.single as FormData;
    expect(Map.fromEntries(form.fields), {'reason': 'damaged', 'description': 'Kemasan penyok parah'});
    expect(form.files.map((f) => f.key), ['photos[]', 'photos[]']);
    expect(trx.complaint?.id, 'c1');
  });

  test('createComplaint without photos sends no files', () async {
    await repository.createComplaint(id: 't1', reason: 'other', description: 'Tidak sesuai deskripsi');

    final form =
        verify(() => api.post(any(), data: captureAny(named: 'data'))).captured.single as FormData;
    expect(form.files, isEmpty);
  });

  test('withdraw, accept and reject hit the complaint endpoints', () async {
    await repository.withdrawComplaint('c1');
    await repository.acceptComplaint('c1');
    await repository.rejectComplaint('c1', 'Barang sudah sesuai foto');

    verify(() => api.post('/complaint/c1/withdraw')).called(1);
    verify(() => api.post('/complaint/c1/accept')).called(1);
    verify(() => api.post('/complaint/c1/reject', data: {'response': 'Barang sudah sesuai foto'}))
        .called(1);
  });
}
