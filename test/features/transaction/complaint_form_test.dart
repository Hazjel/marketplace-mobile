import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/transaction/data/transaction_repository.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/features/transaction/screens/complaint_form_screen.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockImagePicker extends Mock implements ImagePicker {}

// On io, XFile.name comes from the path.
XFile _photo(String name, int bytes) => XFile.fromData(Uint8List(bytes), path: name);

void main() {
  group('validation', () {
    test('reason is required', () {
      expect(complaintReasonError(null), 'Pilih alasan komplain');
      expect(complaintReasonError('bogus'), 'Pilih alasan komplain');
      expect(complaintReasonError('not_received'), isNull);
    });

    test('description must be 10 to 1000 characters after trimming', () {
      expect(complaintDescriptionError('   pendek   '), 'Keterangan minimal 10 karakter');
      expect(complaintDescriptionError('a' * 10), isNull);
      expect(complaintDescriptionError('a' * 1000), isNull);
      expect(complaintDescriptionError('a' * 1001), 'Keterangan maksimal 1000 karakter');
    });

    test('at most 3 photos in total', () async {
      expect(await complaintPhotosError(2, [_photo('a.jpg', 10), _photo('b.jpg', 10)]),
          'Maksimal 3 foto');
      expect(await complaintPhotosError(1, [_photo('a.jpg', 10), _photo('b.jpg', 10)]), isNull);
    });

    test('only jpg, png or webp', () async {
      expect(await complaintPhotosError(0, [_photo('a.gif', 10)]),
          'Foto harus berformat JPG, PNG, atau WEBP');
      expect(await complaintPhotosError(0, [_photo('a.HEIC', 10)]),
          'Foto harus berformat JPG, PNG, atau WEBP');
      expect(await complaintPhotosError(0, [_photo('a.WEBP', 10), _photo('b.jpeg', 10)]), isNull);
    });

    test('each photo at most 2 MB', () async {
      expect(await complaintPhotosError(0, [_photo('a.png', 2 * 1024 * 1024)]), isNull);
      expect(await complaintPhotosError(0, [_photo('a.png', 2 * 1024 * 1024 + 1)]),
          'Ukuran tiap foto maksimal 2 MB');
    });
  });

  group('ComplaintFormScreen', () {
    late MockTransactionRepository repository;
    late MockImagePicker picker;

    setUpAll(() => registerFallbackValue(ImageSource.gallery));

    setUp(() {
      repository = MockTransactionRepository();
      picker = MockImagePicker();
    });

    Future<void> pumpForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3600);
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/form',
        routes: [
          GoRoute(
            path: '/form',
            builder: (_, __) => ComplaintFormScreen(transactionId: 't1', picker: picker),
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [transactionRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    void stubCreate(Future<TransactionModel> Function() answer) {
      when(() => repository.createComplaint(
            id: any(named: 'id'),
            reason: any(named: 'reason'),
            description: any(named: 'description'),
            photoPaths: any(named: 'photoPaths'),
          )).thenAnswer((_) => answer());
    }

    testWidgets('does not send without a reason or with a short description', (tester) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextFormField), 'pendek');
      await tester.tap(find.text('Kirim Komplain'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih alasan komplain'), findsOneWidget);
      expect(find.text('Keterangan minimal 10 karakter'), findsOneWidget);
      verifyNever(() => repository.createComplaint(
            id: any(named: 'id'),
            reason: any(named: 'reason'),
            description: any(named: 'description'),
            photoPaths: any(named: 'photoPaths'),
          ));
    });

    testWidgets('sends once, disabled while sending, and shows the server 422', (tester) async {
      final reply = Completer<TransactionModel>();
      stubCreate(() => reply.future);
      when(() => repository.getTransactionDetail('t1')).thenThrow(Exception('offline'));
      await pumpForm(tester);

      await tester.tap(find.text('Barang rusak'));
      await tester.enterText(find.byType(TextFormField), '  Kemasan penyok parah  ');
      await tester.tap(find.text('Kirim Komplain'));
      await tester.pump();

      expect(find.text('Mengirim...'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Mengirim...'));
      await tester.pump();

      // Real Laravel 422 body: the top message is a summary, the field
      // message is what the buyer should read.
      reply.completeError(ValidationException.fromBody(const {
        'message': 'Foto harus berupa gambar. (dan 1 kesalahan lainnya)',
        'errors': {
          'photos.0': ['Foto harus berupa gambar.'],
          'photos.1': ['Foto harus berupa gambar.'],
        },
      }));
      await tester.pumpAndSettle();

      verify(() => repository.createComplaint(
            id: 't1',
            reason: 'damaged',
            description: 'Kemasan penyok parah',
            photoPaths: const [],
          )).called(1);
      expect(find.text('Foto harus berupa gambar.'), findsOneWidget);
      expect(find.textContaining('kesalahan lainnya'), findsNothing);
      expect(find.text('Kirim Komplain'), findsOneWidget);
    });

    testWidgets('with one slot left it picks a single image, never a 4th', (tester) async {
      when(() => picker.pickMultiImage(
            imageQuality: any(named: 'imageQuality'),
            limit: 3,
          )).thenAnswer((_) async => [_photo('a.jpg', 10), _photo('b.png', 10)]);
      when(() => picker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => _photo('c.webp', 10));
      await pumpForm(tester);

      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      verifyNever(() => picker.pickMultiImage(
            imageQuality: any(named: 'imageQuality'),
            limit: 1,
          ));
      verify(() => picker.pickImage(source: ImageSource.gallery, imageQuality: 85)).called(1);
      expect(find.byTooltip('Hapus foto 3'), findsOneWidget);
      expect(find.text('Tambah'), findsNothing);
      expect(find.text('Maksimal 3 foto. Hapus salah satu untuk menggantinya.'), findsOneWidget);
    });

    testWidgets('a picker that ignores the limit cannot add a 4th photo', (tester) async {
      when(() => picker.pickMultiImage(
            imageQuality: any(named: 'imageQuality'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [for (final n in 'abcd'.split('')) _photo('$n.jpg', 10)]);
      await pumpForm(tester);

      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      expect(find.text('Maksimal 3 foto'), findsOneWidget);
      expect(find.byTooltip('Hapus foto 1'), findsNothing);
    });
  });
}
