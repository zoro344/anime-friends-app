import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import 'chat_thread_screen.dart';
import '../../../../core/widgets/af_avatar.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/af_text_field.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/section_title.dart';

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

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    final conversations = appState.conversations.where((chat) {
      final searchQuery = query.trim().toLowerCase();

      return chat.name.toLowerCase().contains(searchQuery) ||
          chat.message.toLowerCase().contains(searchQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AFCard(
          child: AFTextField(
            controller: searchController,
            hintText: 'Search conversations...',
            prefixIcon: Icons.search,
            onChanged: (value) {
              setState(() => query = value);
            },
          ),
        ),

        const SizedBox(height: 8),

        SectionTitle(
          title: 'Recent Chats',
        ),

        if (conversations.isEmpty)
          const EmptyView(
            title: 'No conversations found',
            message: 'Try another name or message.',
            icon: Icons.chat_bubble_outline,
          )
        else
          ...conversations.map((chat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AFCard(
                padding: const EdgeInsets.all(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
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
                  child: Row(
                  children: [
                    AFAvatar(
                      label: chat.name,
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat.name,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            chat.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      chat.time,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        AFCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.iconMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Messaging is available with accepted friends. Add friends from the social tools when those controls are enabled.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
