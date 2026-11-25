import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/empty_view.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      AppStateScope.of(context).loadNotifications();
    }
  }

  String _label(Map<String, dynamic> item) {
    switch ('${item['type'] ?? ''}') {
      case 'friend_request':
        return 'New friend request';
      case 'friend_accepted':
        return 'Friend request accepted';
      case 'chat_message':
        return 'New message';
      case 'watch_join':
        return 'Someone joined a watch room';
      default:
        return 'Anime Friends update';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: state.unreadNotificationCount == 0
                ? null
                : state.markNotificationsRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.loadNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (state.notifications.isEmpty)
              const EmptyView(
                title: 'You are all caught up',
                message: 'Friend, chat and room updates will appear here.',
                icon: Icons.notifications_none,
              ),
            ...state.notifications.map((item) {
              final unread = item['readAt'] == null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: AFCard(
                  child: Row(
                    children: [
                      Icon(
                      unread
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none,
                      color: unread
                          ? AppColors.textPrimary
                          : AppColors.iconMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _label(item),
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: unread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (item['type'] == 'friend_request')
                            Text(
                              '@${item['actorUsername'] ?? 'Anime Friend'} sent you a request',
                              style: AppTypography.bodySmall,
                            )
                          else if (item['type'] == 'friend_accepted')
                            Text(
                              '@${item['actorUsername'] ?? 'Anime Friend'} accepted your request',
                              style: AppTypography.bodySmall,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '${item['createdAt'] ?? ''}',
                            style: AppTypography.bodySmall,
                          ),
                          if (item['type'] == 'friend_request' &&
                              '${item['relatedId'] ?? ''}'.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => state.respondToFriendRequest(
                                    '${item['relatedId']}',
                                    accept: true,
                                  ),
                                  child: const Text('Accept'),
                                ),
                                TextButton(
                                  onPressed: () => state.respondToFriendRequest(
                                    '${item['relatedId']}',
                                    accept: false,
                                  ),
                                  child: const Text('Decline'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (unread)
                      const Icon(
                        Icons.circle,
                        size: 8,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
