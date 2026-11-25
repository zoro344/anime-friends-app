import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../chats/presentation/screens/chat_thread_screen.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/section_title.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _sending = false;

  Future<void> _addFriend() async {
    final value = _usernameController.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await AppStateScope.of(context).sendFriendRequest(value);
    if (!mounted) return;
    if (sent) _usernameController.clear();
    setState(() => _sending = false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: RefreshIndicator(
        onRefresh: state.loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            AFCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addFriend(),
                    decoration: const InputDecoration(
                      labelText: 'Add friend by username',
                      prefixIcon: Icon(Icons.person_add_alt_1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _sending ? null : _addFriend,
                    child: const Text('Send friend request'),
                  ),
                  if (state.friendError.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.friendError,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionTitle(
              title: 'Requests',
              actionLabel: '${state.friendRequests.length}',
            ),
            const SizedBox(height: 10),
            if (state.friendRequests.isEmpty)
              const EmptyView(
                title: 'No pending requests',
                message: 'Friend requests will appear here.',
                icon: Icons.person_add_alt,
              ),
            ...state.friendRequests.map((request) {
              final user = request['user'] is Map<String, dynamic>
                  ? request['user'] as Map<String, dynamic>
                  : <String, dynamic>{};
              final requestId = '${request['id'] ?? ''}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AFCard(
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${user['username'] ?? 'Anime Friend'}',
                          style: AppTypography.bodyLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Accept',
                        onPressed: () => state.respondToFriendRequest(
                          requestId,
                          accept: true,
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                      ),
                      IconButton(
                        tooltip: 'Reject',
                        onPressed: () => state.respondToFriendRequest(
                          requestId,
                          accept: false,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 22),
            SectionTitle(
              title: 'Your Friends',
              actionLabel: '${state.friends.length}',
            ),
            const SizedBox(height: 10),
            if (state.friends.isEmpty)
              const EmptyView(
                title: 'No friends yet',
                message: 'Send a request to connect with another anime fan.',
                icon: Icons.people_outline,
              ),
            ...state.friends.map((friend) {
              final id = '${friend['id'] ?? ''}';
              final name = '${friend['username'] ?? 'Anime Friend'}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AFCard(
                  child: Row(
                    children: [
                      const Icon(Icons.person),
                      const SizedBox(width: 10),
                      Expanded(child: Text(name)),
                      IconButton(
                        tooltip: 'Message',
                        onPressed: id.isEmpty
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatThreadScreen(
                                      userId: id,
                                      username: name,
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.chat_bubble_outline),
                      ),
                      IconButton(
                        tooltip: 'Remove friend',
                        onPressed: () => state.removeFriend(id),
                        icon: const Icon(Icons.person_remove_outlined),
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
