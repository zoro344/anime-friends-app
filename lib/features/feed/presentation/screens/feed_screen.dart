import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_avatar.dart';
import '../../../../core/widgets/af_button.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/af_text_field.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/section_title.dart';
import '../widgets/post_comments_sheet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final TextEditingController postController =
      TextEditingController();

  void createPost() {
    if (postController.text.trim().isEmpty) return;

    AppStateScope.of(context).createPost(postController.text);

    postController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _editPost(String postId, String initialText) async {
    final controller = TextEditingController(text: initialText);

    try {
      final updatedText = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit post'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            maxLength: 4000,
            decoration: const InputDecoration(
              hintText: 'Write your post...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, controller.text);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (!mounted || updatedText == null) return;

      final success =
          await AppStateScope.of(context).editPost(postId, updatedText);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Post updated.' : 'Could not update the post.',
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'This post will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final success = await AppStateScope.of(context).deletePost(postId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Post deleted.' : 'Could not delete the post.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final posts = appState.posts;

    return RefreshIndicator(
      onRefresh: appState.loadFeed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // CREATE POST
          AFCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share something with the community',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                AFTextField(
                  controller: postController,
                  hintText: 'What is on your mind?',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: AFButton(
                    label: 'Post',
                    icon: Icons.send,
                    onPressed: createPost,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // COMMUNITY FEED
          const SectionTitle(title: 'Community Feed'),

          const SizedBox(height: 14),

          if (appState.feedError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                appState.feedError,
                style: const TextStyle(
                  color: AppColors.error,
                ),
              ),
            ),

          if (posts.isEmpty)
            const EmptyView(
              title: 'No posts yet',
              message:
                  'Be the first to share something with the community.',
              icon: Icons.forum_outlined,
            ),

          ...posts.map((post) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AFCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // USER INFORMATION
                    Row(
                      children: [
                        AFAvatar(
                          label: post.user,
                          radius: 21,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.user,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                post.time,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (post.userId != null &&
                            post.userId == appState.userId)
                          PopupMenuButton<String>(
                            tooltip: 'Post options',
                            icon: const Icon(
                              Icons.more_horiz,
                              color: AppColors.iconMuted,
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editPost(post.id, post.text);
                              } else if (value == 'delete') {
                                _deletePost(post.id);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined),
                                    SizedBox(width: 10),
                                    Text('Edit post'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline),
                                    SizedBox(width: 10),
                                    Text('Delete post'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 17),

                    // POST CONTENT
                    Text(
                      post.text,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(
                        color: AppColors.divider,
                        height: 1,
                      ),
                    ),

                    // POST ACTIONS
                    Row(
                      children: [
                        IconButton(
                          tooltip: post.liked ? 'Unlike' : 'Like',
                          onPressed: () {
                            appState.toggleLike(post.id);
                          },
                          icon: Icon(
                            post.liked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: AppColors.textPrimary,
                            size: 21,
                          ),
                        ),

                        Text(
                          '${post.likes}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(width: 20),

                        // OPEN COMMENTS
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: AppColors.surface,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (_) => PostCommentsSheet(
                                postId: post.id,
                                state: appState,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mode_comment_outlined,
                                  size: 20,
                                  color: AppColors.iconMuted,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '${post.comments}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        const Icon(
                          Icons.share_outlined,
                          color: AppColors.iconMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
