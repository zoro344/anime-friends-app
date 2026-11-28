import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_avatar.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../chats/presentation/screens/chat_thread_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _usernameController =
      TextEditingController();

  bool _sending = false;
  final Set<String> _processingRequests = {};
  final Set<String> _removingFriends = {};

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final value = _usernameController.text.trim();

    if (value.isEmpty || _sending) return;

    setState(() => _sending = true);

    final sent = await AppStateScope.of(context).sendFriendRequest(value);

    if (!mounted) return;

    if (sent) {
      _usernameController.clear();
    }

    setState(() => _sending = false);
  }

  Future<void> _respondToRequest(
    String requestId, {
    required bool accept,
  }) async {
    if (requestId.isEmpty || _processingRequests.contains(requestId)) {
      return;
    }

    setState(() => _processingRequests.add(requestId));

    await AppStateScope.of(context).respondToFriendRequest(
      requestId,
      accept: accept,
    );

    if (!mounted) return;

    setState(() => _processingRequests.remove(requestId));
  }

  Future<void> _removeFriend(String friendId, String name) async {
    if (friendId.isEmpty || _removingFriends.contains(friendId)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove friend?'),
          content: Text(
            'Remove $name from your friends list? '
            'You can send another request later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _removingFriends.add(friendId));

    await AppStateScope.of(context).removeFriend(friendId);

    if (!mounted) return;

    setState(() => _removingFriends.remove(friendId));
  }

  void _openChat(String id, String name) {
    if (id.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          userId: id,
          username: name,
        ),
      ),
    );
  }

  Widget _sectionHeading(
    String title,
    int count, {
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.headingSmall,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: RefreshIndicator(
        onRefresh: state.loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Text(
              'YOUR COMMUNITY',
              style: AppTypography.label.copyWith(
                color: AppColors.primary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Find your people.',
              style: AppTypography.headingLarge,
            ),
            const SizedBox(height: 5),
            Text(
              'Connect with anime fans and keep the conversations going.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),

            AFCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add a friend',
                              style: AppTypography.headingSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Enter their exact username.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.send,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => _addFriend(),
                    decoration: InputDecoration(
                      hintText: 'Enter username',
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _addFriend,
                      icon: _sending
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _sending ? 'Sending...' : 'Send friend request',
                      ),
                    ),
                  ),
                  if (state.friendError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        state.friendError,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            _sectionHeading(
              'Pending requests',
              state.friendRequests.length,
              subtitle: 'People who want to connect with you',
            ),
            const SizedBox(height: 12),

            if (state.friendRequests.isEmpty)
              const EmptyView(
                title: 'All caught up',
                message: 'New friend requests will appear here.',
                icon: Icons.mark_email_read_outlined,
              )
            else
              ...state.friendRequests.map((request) {
                final user = request['user'] is Map
                    ? Map<String, dynamic>.from(request['user'] as Map)
                    : <String, dynamic>{};

                final requestId = '${request['id'] ?? ''}';
                final name = '${user['username'] ?? 'Anime Friend'}';
                final processing =
                    _processingRequests.contains(requestId);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AFCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AFAvatar(
                              label: name,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Wants to be your friend',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: processing || requestId.isEmpty
                                    ? null
                                    : () => _respondToRequest(
                                          requestId,
                                          accept: true,
                                        ),
                                icon: const Icon(
                                  Icons.check_rounded,
                                  size: 17,
                                ),
                                label: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: processing || requestId.isEmpty
                                    ? null
                                    : () => _respondToRequest(
                                          requestId,
                                          accept: false,
                                        ),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 17,
                                ),
                                label: const Text('Decline'),
                              ),
                            ),
                          ],
                        ),
                        if (processing) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 24),

            _sectionHeading(
              'Your friends',
              state.friends.length,
              subtitle: 'Your connections on Anime Friends',
            ),
            const SizedBox(height: 12),

            if (state.friends.isEmpty)
              const EmptyView(
                title: 'Your list is waiting',
                message: 'Find other anime fans and send them a friend request.',
                icon: Icons.people_outline_rounded,
              )
            else
              ...state.friends.map((friend) {
                final id = '${friend['id'] ?? ''}';
                final name = '${friend['username'] ?? 'Anime Friend'}';
                final removing = _removingFriends.contains(id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AFCard(
                    child: Row(
                      children: [
                        AFAvatar(
                          label: name,
                          radius: 25,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Anime Friends member',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Message',
                          onPressed: id.isEmpty
                              ? null
                              : () => _openChat(id, name),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        PopupMenuButton<String>(
                          enabled: !removing && id.isNotEmpty,
                          tooltip: 'Friend options',
                          onSelected: (value) {
                            if (value == 'remove') {
                              _removeFriend(id, name);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_remove_outlined,
                                    size: 19,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Remove friend'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (removing)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
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
