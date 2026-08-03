import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/chat/data/chat_repository.dart';
import 'package:blukios_marketplace/features/chat/data/reverb_service.dart';
import 'package:blukios_marketplace/features/chat/models/chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

/// One socket for the whole app — every thread reads from the same
/// private channel, so opening a second connection per screen would be
/// wasteful and would duplicate events.
final reverbServiceProvider = Provider<ReverbService>((ref) {
  final service = ReverbService(ref.watch(apiClientProvider));
  ref.onDispose(service.disconnect);
  return service;
});

// ── Contacts ────────────────────────────────────────────────────────

class ContactsData {
  final List<ChatContact> contacts;
  final bool isLoading;
  final String? error;

  const ContactsData({
    this.contacts = const [],
    this.isLoading = true,
    this.error,
  });

  int get totalUnread =>
      contacts.fold<int>(0, (sum, c) => sum + c.unreadCount);

  ContactsData copyWith({
    List<ChatContact>? contacts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ContactsData(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ContactsNotifier extends Notifier<ContactsData> {
  @override
  ContactsData build() => const ContactsData();

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final contacts = await ref.read(chatRepositoryProvider).getContacts();
      state = state.copyWith(contacts: contacts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final contactsProvider =
    NotifierProvider<ContactsNotifier, ContactsData>(ContactsNotifier.new);

// ── Thread ──────────────────────────────────────────────────────────

class ThreadData {
  final List<MessageModel> messages;
  final ChatContact? partner;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const ThreadData({
    this.messages = const [],
    this.partner,
    this.isLoading = true,
    this.isSending = false,
    this.error,
  });

  ThreadData copyWith({
    List<MessageModel>? messages,
    ChatContact? partner,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return ThreadData(
      messages: messages ?? this.messages,
      partner: partner ?? this.partner,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Keyed by the partner's user id.
class ThreadNotifier extends AutoDisposeFamilyNotifier<ThreadData, String> {
  @override
  ThreadData build(String partnerId) => const ThreadData();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final results = await Future.wait([
        repo.getMessages(arg),
        // Partner info is cosmetic (header name/avatar) — a failure here
        // shouldn't block the thread itself.
        repo.getUserInfo(arg).then<Object?>((v) => v).catchError((_) => null),
      ]);

      state = state.copyWith(
        messages: results[0] as List<MessageModel>,
        partner: results[1] as ChatContact?,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Appends a message that arrived over the websocket, ignoring ones
  /// belonging to other conversations and duplicates.
  void receiveMessage(MessageModel message) {
    final isThisThread = message.senderId == arg || message.receiverId == arg;
    if (!isThisThread) return;
    if (state.messages.any((m) => m.id == message.id)) return;

    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Returns null on success, or an error message.
  Future<String?> send(String text) async {
    if (text.trim().isEmpty || state.isSending) return null;

    state = state.copyWith(isSending: true, clearError: true);

    try {
      final message = await ref.read(chatRepositoryProvider).sendMessage(
            receiverId: arg,
            message: text.trim(),
            socketId: ref.read(reverbServiceProvider).socketId,
          );
      state = state.copyWith(
        messages: [...state.messages, message],
        isSending: false,
      );
      return null;
    } catch (e) {
      state = state.copyWith(isSending: false);
      return e.toString();
    }
  }
}

final threadProvider =
    AutoDisposeNotifierProviderFamily<ThreadNotifier, ThreadData, String>(
  ThreadNotifier.new,
);

/// Starts the websocket once the user is authenticated and routes each
/// inbound message to the matching thread notifier.
final chatRealtimeProvider = Provider<void>((ref) {
  ref.listen<AuthData>(authProvider, (previous, next) async {
    final service = ref.read(reverbServiceProvider);

    if (next.state != AuthState.authenticated) {
      await service.disconnect();
      return;
    }

    final userId = next.currentUser?.id;
    if (userId == null || service.isConnected) return;

    await service.connect(
      userId: userId,
      onMessage: (message) {
        // The partner is whichever end of the message isn't us.
        final partnerId =
            message.senderId == userId ? message.receiverId : message.senderId;
        ref.read(threadProvider(partnerId).notifier).receiveMessage(message);
        // Refresh the contact list so unread badges and previews follow.
        ref.read(contactsProvider.notifier).loadContacts();
      },
    );
  }, fireImmediately: true);
});
