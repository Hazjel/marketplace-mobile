import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/features/chat/models/chat_models.dart';
import 'package:blukios_marketplace/features/chat/viewmodels/chat_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String partnerId;

  const ChatThreadScreen({super.key, required this.partnerId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(threadProvider(widget.partnerId).notifier).load();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    _controller.clear();
    final error =
        await ref.read(threadProvider(widget.partnerId).notifier).send(text);

    if (!mounted) return;
    if (error != null) {
      // Put the text back so a failed send isn't silently lost.
      _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(threadProvider(widget.partnerId));
    final notifier = ref.read(threadProvider(widget.partnerId).notifier);
    final currentUserId = ref.watch(authProvider).currentUser?.id;

    // New messages arriving over the socket should keep the view pinned
    // to the latest.
    ref.listen(threadProvider(widget.partnerId), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return AppScaffold(
      title: state.partner?.name ?? 'Chat',
      bottomBar: _Composer(
        controller: _controller,
        isSending: state.isSending,
        onSend: _send,
      ),
      body: state.isLoading
          ? const ListSkeleton()
          : state.error != null && state.messages.isEmpty
              ? ErrorState(message: state.error!, onRetry: notifier.load)
              : state.messages.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.inbox,
                      title: 'Belum ada pesan',
                      message: 'Kirim pesan pertamamu',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppTheme.spacingLG),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        return _MessageBubble(
                          message: message,
                          isMine: message.senderId == currentUserId,
                        );
                      },
                    ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.primary;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMD,
          vertical: AppTheme.spacingSM,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? primary
              : (isDark ? AppTheme.darkMuted : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTheme.radius2XL),
            topRight: const Radius.circular(AppTheme.radius2XL),
            bottomLeft: Radius.circular(isMine ? AppTheme.radius2XL : 4),
            bottomRight: Radius.circular(isMine ? 4 : AppTheme.radius2XL),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isAiReply) ...[
              Text(
                'Asisten Ri',
                style: AppTheme.labelSm.copyWith(
                  color: isMine ? Colors.white70 : primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              message.message,
              style: AppTheme.bodyMd.copyWith(
                color: isMine ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Tulis pesan…',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLG,
                    vertical: AppTheme.spacingMD,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const AppIcon(
                        AppIcons.chevronRight,
                        size: AppIconSize.md,
                        color: Colors.white,
                        semanticsLabel: 'Kirim',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
