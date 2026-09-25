import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/network/api_exceptions.dart';
import 'package:blukios_marketplace/features/ai_chat/data/ai_chat_repository.dart';
import 'package:blukios_marketplace/features/ai_chat/models/ai_chat_models.dart';

final aiChatRepositoryProvider =
    Provider<AiChatRepository>((ref) => AiChatRepository());

/// Sapaan pembuka. Ditulis lokal, bukan hasil panggilan API: tidak ada
/// gunanya membakar satu putaran LLM untuk kalimat yang selalu sama.
const _greeting = 'Hai! Aku Ri, asisten Blukios. Mau cari produk apa hari ini?';

class AiChatState {
  final List<AiChatMessage> messages;
  final bool isSending;

  /// Kegagalan jaringan atau HTTP. Berbeda dari `AiChatMessage.isError`, yang
  /// menandai balasan yang tetap datang tapi LLM-nya gagal di sisi server.
  final String? error;
  final String? sessionId;

  const AiChatState({
    this.messages = const [AiChatMessage(text: _greeting, isBot: true)],
    this.isSending = false,
    this.error,
    this.sessionId,
  });

  /// `error` sengaja tidak ikut pola `??`: pemanggil harus bisa membersihkannya
  /// dengan mengirim null, dan itu mustahil kalau null berarti "pertahankan".
  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isSending,
    String? error,
    String? sessionId,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: error,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class AiChatNotifier extends AutoDisposeNotifier<AiChatState> {
  /// Pertanyaan terakhir yang belum terjawab, dipakai [retry].
  String? _pendingMessage;

  @override
  AiChatState build() => const AiChatState();

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.isSending) return;

    _pendingMessage = message;
    state = state.copyWith(
      messages: [...state.messages, AiChatMessage.user(message)],
      isSending: true,
    );
    await _ask(message);
  }

  /// Mengulang pertanyaan yang gagal tanpa menambah bubble baru: bubble
  /// pengguna sudah ada di layar sejak percobaan pertama.
  Future<void> retry() async {
    final message = _pendingMessage;
    if (message == null || state.isSending) return;

    state = state.copyWith(isSending: true);
    await _ask(message);
  }

  Future<void> _ask(String message) async {
    try {
      final reply = await ref.read(aiChatRepositoryProvider).ask(
            message: message,
            sessionId: state.sessionId,
          );
      _pendingMessage = null;
      state = state.copyWith(
        messages: [...state.messages, AiChatMessage.bot(reply)],
        isSending: false,
        // session_id dari balasan pertama harus dipakai untuk pesan
        // berikutnya, itu yang menyambung riwayat di chat-service.
        sessionId:
            reply.sessionId.isNotEmpty ? reply.sessionId : state.sessionId,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isSending: false, error: e.message);
    }
  }
}

final aiChatProvider = AutoDisposeNotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);
