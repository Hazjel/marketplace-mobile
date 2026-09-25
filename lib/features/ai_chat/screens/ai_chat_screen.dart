import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/utils/currency_formatter.dart';
import 'package:blukios_marketplace/features/ai_chat/models/ai_chat_models.dart';
import 'package:blukios_marketplace/features/ai_chat/viewmodels/ai_chat_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

/// Chatbot RAG. Padanan `Chatbot.vue` di web, dengan satu perbedaan yang
/// disengaja: jawaban datang utuh lewat `/predict`, bukan menetes lewat
/// `/predict/stream`.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(aiChatProvider.notifier).send(text);
  }

  /// Dijalankan setelah frame terpasang: panjang daftar baru diketahui sesudah
  /// build, jadi scroll di dalam build akan memakai ukuran yang basi.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatProvider);
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(title: const Text('Tanya Ri')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                itemCount: state.messages.length + (state.isSending ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppTheme.spacingMD),
                itemBuilder: (context, index) {
                  if (index >= state.messages.length) {
                    return const _TypingBubble();
                  }
                  return _MessageBubble(message: state.messages[index]);
                },
              ),
            ),
            if (state.error != null)
              _ErrorBar(
                message: state.error!,
                onRetry: () => ref.read(aiChatProvider.notifier).retry(),
              ),
            _Composer(
              controller: _input,
              enabled: !state.isSending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBot = message.isBot;

    final background = isBot
        ? (isDark ? AppTheme.darkCard : AppTheme.cardWhite)
        : AppTheme.primary;
    final foreground = isBot
        ? (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)
        : Colors.white;

    return Column(
      crossAxisAlignment:
          isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment:
              isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBot) ...[
              const AppIcon(
                AppIcons.bot,
                size: AppIconSize.md,
                color: AppTheme.primary,
                semanticsLabel: 'Asisten Ri',
              ),
              const SizedBox(width: AppTheme.spacingSM),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                  vertical: AppTheme.spacingSM,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: isBot
                      ? Border.all(
                          color: message.isError
                              ? AppTheme.warning
                              : (isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.border),
                        )
                      : null,
                ),
                child: Text(
                  message.text,
                  style: TextStyle(color: foreground, height: 1.4),
                ),
              ),
            ),
          ],
        ),
        if (message.products.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            '${message.products.length} produk relevan',
            style: TextStyle(
              fontSize: 11,
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          ...message.products.map((p) => _ProductCard(product: p)),
        ],
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final AiChatProduct product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
        onTap: () => context.push('/product/${product.routeKey}'),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingSM),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkMuted : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: product.thumbnail != null
                      ? Image.network(
                          product.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _Thumb(),
                        )
                      : const _Thumb(),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatRupiah(product.price),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                AppIcons.chevronRight,
                size: AppIconSize.sm,
                color:
                    isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkIconBackground
          : AppTheme.iconBackground,
      child: const Center(
        child: AppIcon(AppIcons.package, size: AppIconSize.md),
      ),
    );
  }
}

/// Penanda "sedang menulis". Sengaja teks statis, bukan animasi: jawaban LLM
/// bisa puluhan detik, dan animasi sepanjang itu lebih mengganggu dari menolong.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        const AppIcon(
          AppIcons.bot,
          size: AppIconSize.md,
          color: AppTheme.primary,
        ),
        const SizedBox(width: AppTheme.spacingSM),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMD,
            vertical: AppTheme.spacingSM,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.border,
            ),
          ),
          child: Text(
            'Ri sedang menulis...',
            style: TextStyle(
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBar({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.error.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLG,
        vertical: AppTheme.spacingSM,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              // chat-service menolak pesan di atas 1000 karakter, jadi batasnya
              // ditegakkan di sini daripada menunggu 422 dari server.
              maxLength: 1000,
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Tulis pertanyaan...',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSM),
          IconButton(
            onPressed: enabled ? onSend : null,
            icon: const AppIcon(
              AppIcons.send,
              size: AppIconSize.lg,
              color: AppTheme.primary,
              semanticsLabel: 'Kirim',
            ),
            tooltip: 'Kirim',
          ),
        ],
      ),
    );
  }
}
