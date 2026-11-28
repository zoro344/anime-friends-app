import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_avatar.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/af_text_field.dart';
import '../../../../core/widgets/empty_view.dart';
import 'chat_thread_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final TextEditingController searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    searchController.clear();
    setState(() => query = '');
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final searchQuery = query.trim().toLowerCase();

    final conversations = appState.conversations.where((chat) {
      return chat.name.toLowerCase().contains(searchQuery) ||
          chat.message.toLowerCase().contains(searchQuery);
    }).toList();

    final unreadCount = appState.conversations.fold<int>(
      0,
      (total, chat) => total + chat.unreadCount,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR INBOX',
                    style: AppTypography.label.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Chats',
                    style: AppTypography.headingLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    searchQuery.isEmpty
    ? '${conversations.length} conversations'
    : '${conversations.length} results',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_chat_unread_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$unreadCount unread',
                      style: AppTypography.label.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),

        AFCard(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 3,
          ),
          child: AFTextField(
            controller: searchController,
            hintText: 'Search people or messages...',
            prefixIcon: Icons.search_rounded,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
            onChanged: (value) {
              setState(() => query = value);
            },
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Text(
              searchQuery.isEmpty ? 'Recent conversations' : 'Search results',
              style: AppTypography.headingSmall,
            ),
            const Spacer(),
            Text(
              '${conversations.length}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (conversations.isEmpty)
          EmptyView(
            title: searchQuery.isNotEmpty
                ? 'No matching conversations'
                : 'No chats yet',
            message: searchQuery.isNotEmpty
                ? 'Try searching with another name or message.'
                : 'When you start messaging your friends, your conversations will appear here.',
            icon: searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.chat_bubble_outline_rounded,
            actionLabel: searchQuery.isNotEmpty ? 'Clear search' : null,
            onAction: searchQuery.isNotEmpty ? _clearSearch : null,
          )
        else
          ...conversations.map((chat) {
            final hasUnread = chat.unreadCount > 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AFCard(
                padding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatThreadScreen(
                        userId: chat.userId,
                        username: chat.name,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AFAvatar(
                            label: chat.name,
                            radius: 25,
                          ),
                          if (hasUnread)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              chat.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: hasUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (chat.time.isNotEmpty)
                            Text(
                              chat.time,
                              style: AppTypography.bodySmall.copyWith(
                                color: hasUnread
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          if (hasUnread) ...[
                            const SizedBox(height: 7),
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                chat.unreadCount > 99
                                    ? '99+'
                                    : '${chat.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
