import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/features/ai_chat/data/ai_chat_repository.dart';
import 'package:blukios_marketplace/features/ai_chat/models/ai_chat_models.dart';
import 'package:blukios_marketplace/features/ai_chat/viewmodels/ai_chat_viewmodel.dart';

class MockAiChatRepository extends Mock implements AiChatRepository {}

AiChatReply _reply({String text = 'jawaban', String session = 'sess-1'}) {
  return AiChatReply(reply: text, status: 'success', sessionId: session);
}

void main() {
  late MockAiChatRepository repository;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [aiChatRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repository = MockAiChatRepository();
  });

  test('mulai dengan satu sapaan dari bot dan tanpa sesi', () {
    final state = container().read(aiChatProvider);

    expect(state.messages, hasLength(1));
    expect(state.messages.single.isBot, isTrue);
    expect(state.sessionId, isNull);
    expect(state.isSending, isFalse);
  });

  test('send menambah bubble pengguna lalu balasan bot', () async {
    when(() => repository.ask(
          message: any(named: 'message'),
          sessionId: any(named: 'sessionId'),
        )).thenAnswer((_) async => _reply(text: 'ada sepatu lari'));

    final c = container();
    await c.read(aiChatProvider.notifier).send('cari sepatu');

    final state = c.read(aiChatProvider);
    expect(state.messages.map((m) => m.isBot), [true, false, true]);
    expect(state.messages.last.text, 'ada sepatu lari');
    expect(state.isSending, isFalse);
    expect(state.error, isNull);
  });

  test('session_id dari balasan pertama dipakai di pesan berikutnya', () async {
    when(() => repository.ask(
          message: any(named: 'message'),
          sessionId: any(named: 'sessionId'),
        )).thenAnswer((_) async => _reply(session: 'sess-42'));

    final c = container();
    final notifier = c.read(aiChatProvider.notifier);
    await notifier.send('pertama');
    await notifier.send('kedua');

    verify(() => repository.ask(message: 'pertama', sessionId: null)).called(1);
    verify(() => repository.ask(message: 'kedua', sessionId: 'sess-42'))
        .called(1);
  });

  test('pesan kosong atau hanya spasi tidak dikirim', () async {
    final c = container();
    await c.read(aiChatProvider.notifier).send('   ');

    expect(c.read(aiChatProvider).messages, hasLength(1));
    verifyNever(() => repository.ask(
          message: any(named: 'message'),
          sessionId: any(named: 'sessionId'),
        ));
  });

  test('kegagalan jaringan mengisi error dan bubble pengguna tetap ada',
      () async {
    when(() => repository.ask(
          message: any(named: 'message'),
          sessionId: any(named: 'sessionId'),
        )).thenThrow(ApiException(message: 'Tidak ada koneksi internet'));

    final c = container();
    await c.read(aiChatProvider.notifier).send('cari sepatu');

    final state = c.read(aiChatProvider);
    expect(state.error, 'Tidak ada koneksi internet');
    expect(state.isSending, isFalse);
    expect(state.messages.last.isBot, isFalse);
    expect(state.messages.last.text, 'cari sepatu');
  });

  test('retry mengirim ulang pertanyaan yang sama tanpa bubble baru', () async {
    var attempt = 0;
    when(() => repository.ask(
          message: any(named: 'message'),
          sessionId: any(named: 'sessionId'),
        )).thenAnswer((_) async {
      attempt++;
      if (attempt == 1) throw ApiException(message: 'Server tidak merespons');
      return _reply(text: 'akhirnya jawab');
    });

    final c = container();
    final notifier = c.read(aiChatProvider.notifier);
    await notifier.send('cari sepatu');
    await notifier.retry();

    final state = c.read(aiChatProvider);
    expect(state.error, isNull);
    // Sapaan, pertanyaan sekali saja, lalu jawaban.
    expect(state.messages.map((m) => m.isBot), [true, false, true]);
    expect(state.messages.last.text, 'akhirnya jawab');
    verify(() => repository.ask(
          message: 'cari sepatu',
          sessionId: any(named: 'sessionId'),
        )).called(2);
  });

  test('retry tanpa kegagalan sebelumnya tidak melakukan apa-apa', () async {
    final c = container();
    await c.read(aiChatProvider.notifier).retry();

    verifyNever(() => repository.ask(
          message: any(named: 'message'),
          sessionId: any(named: 'sessionId'),
        ));
  });
}
