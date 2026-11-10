import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
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

  test('getTransactions forwards mode as a query parameter, and omits it when null', () async {
    when(() => api.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(requestOptions: RequestOptions(), data: {'data': {'data': []}}),
    );

    await repository.getTransactions(mode: 'buyer');
    await repository.getTransactions(mode: 'store', rowPerPage: 50);
    await repository.getTransactions();

    final queries = verify(
      () => api.get('/transaction/all/paginated', queryParameters: captureAny(named: 'queryParameters')),
    ).captured.cast<Map<String, dynamic>>();
    expect(queries[0]['mode'], 'buyer');
    expect(queries[1]['mode'], 'store');
    expect(queries[2].containsKey('mode'), isFalse);
  });

  group('cancel unpaid', () {
    Map<String, dynamic> order(String id, String store) => {
          'id': id,
          'code': 'TRX-$id',
          'store': {'id': 's-$id', 'name': store},
          'shipping_cost': 0,
          'tax': 0,
          'grand_total': 10000,
          'discount_amount': 0,
          'delivery_status': 'pending',
          'payment_status': 'unpaid',
        };

    Response<dynamic> body(Map<String, dynamic> data) =>
        Response(requestOptions: RequestOptions(), data: data);

    test('preview returns every order of the payment', () async {
      when(() => api.get('/transaction/t1/cancel-unpaid')).thenAnswer((_) async => body({
            'message': 'Pesanan dalam pembayaran ini',
            'data': [order('t1', 'Toko Satu'), order('t2', 'Toko Dua')],
          }));

      final orders = await repository.previewCancelUnpaid('t1');

      expect(orders.map((o) => o.code), ['TRX-t1', 'TRX-t2']);
      expect(orders.map((o) => o.storeName), ['Toko Satu', 'Toko Dua']);
    });

    test('cancel posts once and returns the message and the cancelled orders', () async {
      when(() => api.post('/transaction/t1/cancel-unpaid')).thenAnswer((_) async => body({
            'message': 'Pesanan dibatalkan.',
            'data': {
              'payment_status': 'failed',
              'cancelled_orders': [order('t1', 'Toko Satu'), order('t2', 'Toko Dua')],
            },
          }));

      final result = await repository.cancelUnpaid('t1');

      expect(result.message, 'Pesanan dibatalkan.');
      expect(result.orders, hasLength(2));
      verify(() => api.post('/transaction/t1/cancel-unpaid')).called(1);
    });

    test('cancel keeps the Saldo Blukios message when Saldo was used', () async {
      when(() => api.post('/transaction/t1/cancel-unpaid')).thenAnswer((_) async => body({
            'message': 'Pesanan dibatalkan. Saldo Blukios yang digunakan sudah dikembalikan.',
            'data': {'payment_status': 'failed', 'cancelled_orders': [order('t1', 'Toko Satu')]},
          }));

      final result = await repository.cancelUnpaid('t1');

      expect(result.message, 'Pesanan dibatalkan. Saldo Blukios yang digunakan sudah dikembalikan.');
    });

    // ApiClient turns every failed response into one of these (see
    // ApiException.fromDioError); the repository must not swallow or reword it.
    final failures = <String, ApiException>{
      '403': ApiException(
        message: 'Anda tidak memiliki izin untuk membatalkan pesanan ini',
        statusCode: 403,
      ),
      '404': NotFoundException(message: 'Data Transaksi Tidak Ditemukan'),
      '429 throttled': ApiException(message: 'Too Many Attempts.', statusCode: 429),
      '422 validation': ValidationException(
        message: 'Validasi gagal',
        fieldErrors: {'id': ['Pesanan sudah dibayar']},
      ),
      'domain error': ApiException(message: 'Pesanan sudah dibayar', statusCode: 400),
    };
    for (final failure in failures.entries) {
      test('${failure.key} reaches the caller as returned, from preview and cancel', () async {
        when(() => api.get(any())).thenThrow(failure.value);
        when(() => api.post(any())).thenThrow(failure.value);

        await expectLater(
          repository.previewCancelUnpaid('t1'),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', failure.value.message)),
        );
        await expectLater(
          repository.cancelUnpaid('t1'),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', failure.value.message)
              .having((e) => e.statusCode, 'statusCode', failure.value.statusCode)),
        );
      });
    }
  });
}
