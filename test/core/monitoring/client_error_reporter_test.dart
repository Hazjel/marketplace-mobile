import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blukios_marketplace/core/monitoring/client_error_reporter.dart';

void main() {
  late List<Map<String, dynamic>> sent;

  setUp(() {
    ClientErrorReporter.resetForTest();
    sent = [];
    ClientErrorReporter.enabledOverride = true;
    ClientErrorReporter.sendOverride = (body) async => sent.add(body);
  });

  tearDown(ClientErrorReporter.resetForTest);

  test('reports a crash as a mobile client error', () {
    ClientErrorReporter.report(StateError('cart is empty'), StackTrace.current, context: 'building CheckoutScreen');

    expect(sent, hasLength(1));
    expect(sent.single['source'], 'mobile');
    expect(sent.single['message'], 'Bad state: cart is empty (building CheckoutScreen)');
    expect(sent.single['stack'], isA<String>());
  });

  test('sends the same message only once per session', () {
    ClientErrorReporter.report(StateError('boom'), null);
    ClientErrorReporter.report(StateError('boom'), null);

    expect(sent, hasLength(1));
  });

  test('caps reports per session', () {
    for (var i = 0; i < 20; i++) {
      ClientErrorReporter.report(StateError('boom $i'), null);
    }

    expect(sent, hasLength(10));
  });

  test('skips API failures, which the server already counts', () {
    ClientErrorReporter.report(
      DioException(requestOptions: RequestOptions(path: '/transaction')),
      null,
    );

    expect(sent, isEmpty);
  });

  test('stays silent when disabled (debug builds)', () {
    ClientErrorReporter.enabledOverride = false;

    ClientErrorReporter.report(StateError('boom'), null);

    expect(sent, isEmpty);
  });

  test('truncates long messages to what the API accepts', () {
    ClientErrorReporter.report(StateError('x' * 1000), null);

    expect((sent.single['message'] as String).length, 500);
  });

  test('a failing report never throws', () async {
    ClientErrorReporter.sendOverride = (_) async => throw Exception('offline');

    expect(() => ClientErrorReporter.report(StateError('boom'), null), returnsNormally);
    await Future<void>.delayed(Duration.zero);
  });
}
