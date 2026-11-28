import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../news/presentation/screens/news_detail_screen.dart';

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
      final state = AppStateScope.of(context);
      state.loadNotifications();
      state.loadNotificationNews();
    }
  }

  Future<void> _refresh() async {
    final state = AppStateScope.of(context);
    await Future.wait([
      state.loadNotifications(),
      state.loadNotificationNews(),
    ]);
  }

  String _label(Map<String, dynamic> item) {
    switch ('${item['type'] ?? ''}') {
      case 'friend_request':
        return 'New friend request';
      case 'friend_accepted':
        return 'Friend request accepted';
      default:
        return 'Friend activity';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final notifications = state.notifications.where((item) {
      final type = '${item['type'] ?? ''}';
      return type == 'friend_request' || type == 'friend_accepted';
    }).toList();

    final news = state.notificationNewsItems;

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
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(
                  Icons.people_alt_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Text(
                  'Friend activity',
                  style: AppTypography.headingSmall,
                ),
                const Spacer(),
                Text(
                  '${notifications.length}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.notificationsLoading && notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.notificationError.isNotEmpty &&
                notifications.isEmpty)
              AFCard(
                child: Column(
                  children: [
                    Text(
                      state.notificationError,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: state.loadNotifications,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (notifications.isEmpty)
              const EmptyView(
                title: 'No friend requests',
                message:
                    'New friend requests and responses will appear here.',
                icon: Icons.person_add_alt_1_outlined,
              ),
            ...notifications.map((item) {
              final unread = item['readAt'] == null;
              final isRequest = item['type'] == 'friend_request';
              final relatedId = '${item['relatedId'] ?? ''}';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AFCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          isRequest
                              ? Icons.person_add_alt_1_rounded
                              : Icons.people_alt_rounded,
                          color: AppColors.primary,
                        ),
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
                            const SizedBox(height: 5),
                            Text(
                              isRequest
                                  ? '@${item['actorUsername'] ?? 'Anime Friend'} sent you a friend request.'
                                  : '@${item['actorUsername'] ?? 'Anime Friend'} accepted your friend request.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item['createdAt'] ?? ''}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            if (isRequest && relatedId.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: () =>
                                        state.respondToFriendRequest(
                                      relatedId,
                                      accept: true,
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () =>
                                        state.respondToFriendRequest(
                                      relatedId,
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
                        const Padding(
                          padding: EdgeInsets.only(left: 8, top: 5),
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 22),
            Row(
              children: [
                const Icon(
                  Icons.newspaper_rounded,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Text(
                  'Anime news',
                  style: AppTypography.headingSmall,
                ),
                const Spacer(),
                Text(
                  'LATEST',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.notificationNewsLoading && news.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.notificationNewsError.isNotEmpty && news.isEmpty)
              AFCard(
                child: Column(
                  children: [
                    Text(
                      'Could not load anime news.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: state.loadNotificationNews,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (news.isEmpty)
              const EmptyView(
                title: 'No anime news yet',
                message: 'The latest anime announcements will appear here.',
                icon: Icons.newspaper_outlined,
              ),
            ...news.take(8).map((article) {
              final imageUrl = '${article['imageUrl'] ?? ''}';

              return Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: AFCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NewsDetailScreen(article: article),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.startsWith('https://'))
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.network(
                              imageUrl,
                              height: 155,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          '${article['title'] ?? 'Anime news'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${article['source'] ?? 'Anime news'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${article['summary'] ?? ''}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.iconMuted,
                          ),
                        ),
                      ],
                    ),
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
