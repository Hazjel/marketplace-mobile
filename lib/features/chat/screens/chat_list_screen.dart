import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/chat/models/chat_models.dart';
import 'package:blukios_marketplace/features/chat/viewmodels/chat_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';
import 'package:blukios_marketplace/shared/widgets/skeletons.dart';
import 'package:blukios_marketplace/shared/widgets/state_views.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactsProvider.notifier).loadContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsProvider);
    final reload = ref.read(contactsProvider.notifier).loadContacts;

    return AppScaffold(
      title: 'Chat',
      body: state.isLoading
          ? const ListSkeleton()
          : state.error != null && state.contacts.isEmpty
              ? ErrorState(message: state.error!, onRetry: reload)
              : state.contacts.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.inbox,
                      title: 'Belum ada percakapan',
                      message: 'Chat dengan penjual akan muncul di sini',
                    )
                  : RefreshIndicator(
                      onRefresh: reload,
                      child: ListView.separated(
                        itemCount: state.contacts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) => _ContactTile(
                          contact: state.contacts[index],
                        ),
                      ),
                    ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ChatContact contact;

  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final hasUnread = contact.unreadCount > 0;

    return InkWell(
      onTap: () => context.push(AppRoutes.chatThreadPath(contact.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLG,
          vertical: AppTheme.spacingMD,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkIconBackground
                    : AppTheme.iconBackground,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: contact.profilePicture != null
                  ? CachedNetworkImage(
                      imageUrl: contact.profilePicture!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _Initial(contact.name),
                    )
                  : _Initial(contact.name),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hasUnread
                        ? AppTheme.titleMd
                        : AppTheme.titleMd.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.lastMessage ?? 'Mulai percakapan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(
                      color: hasUnread ? null : muted,
                      fontWeight: hasUnread ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: AppTheme.spacingSM),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                constraints: const BoxConstraints(minWidth: 20),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  contact.unreadCount > 99 ? '99+' : '${contact.unreadCount}',
                  textAlign: TextAlign.center,
                  style: AppTheme.labelSm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  final String name;

  const _Initial(this.name);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTheme.titleLg.copyWith(
          color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
        ),
      ),
    );
  }
}
