import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_avatar.dart';
import '../../../../core/widgets/af_button.dart';
import '../../../../core/widgets/af_text_field.dart';
import '../../../../core/widgets/empty_view.dart';
import '../widgets/post_comments_sheet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final TextEditingController postController = TextEditingController();

  void createPost() {
    final text = postController.text.trim();
    if (text.isEmpty) return;

    AppStateScope.of(context).createPost(text);

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

  void _openComments(String postId, dynamic appState) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (_) => PostCommentsSheet(
        postId: postId,
        state: appState,
      ),
    );
  }

  Widget _sectionHeading(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headingMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildComposer(dynamic appState) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF211832),
            Color(0xFF15111F),
            Color(0xFF15111F),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'CREATE A POST',
                    style: AppTypography.label,
                  ),
                ),
                Icon(
                  Icons.auto_awesome,
                  size: 17,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AFAvatar(
                  label: 'You',
                  radius: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AFTextField(
                    controller: postController,
                    hintText: 'Share your anime thoughts...',
                    maxLines: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your community is listening.',
                    style: AppTypography.bodySmall,
                  ),
                ),
                AFButton(
                  label: 'Post',
                  icon: Icons.send_rounded,
                  onPressed: createPost,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(dynamic post, dynamic appState) {
    final isOwnPost =
        post.userId != null && post.userId == appState.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AFAvatar(
                  label: post.user,
                  radius: 22,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.user,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            post.time,
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(width: 7),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.public,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Community',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwnPost)
                  PopupMenuButton<String>(
                    tooltip: 'Post options',
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppColors.textSecondary,
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
            Text(
              post.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 17),
            Container(
              height: 1,
              color: AppColors.divider,
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                _PostAction(
                  icon: post.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${post.likes}',
                  active: post.liked,
                  activeColor: AppColors.tertiary,
                  tooltip: post.liked ? 'Unlike' : 'Like',
                  onTap: () => appState.toggleLike(post.id),
                ),
                const SizedBox(width: 20),
                _PostAction(
                  icon: Icons.mode_comment_outlined,
                  label: '${post.comments}',
                  tooltip: 'Comments',
                  onTap: () => _openComments(post.id, appState),
                ),
                const Spacer(),
                const Icon(
                  Icons.forum_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
                const Text(
                  'Discuss',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ],
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
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: appState.loadFeed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildComposer(appState),
          const SizedBox(height: 27),
          Row(
            children: [
              Expanded(
                child: _sectionHeading(
                  'Community',
                  subtitle: 'See what everyone is watching and talking about',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'FEED',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (appState.feedError.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      appState.feedError,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (posts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: EmptyView(
                title: 'Your feed is waiting',
                message:
                    'Be the first to share an anime recommendation, '
                    'thought or update with the community.',
                icon: Icons.forum_outlined,
              ),
            )
          else
            ...posts.map((post) => _buildPostCard(post, appState)),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tooltip,
    this.active = false,
    this.activeColor = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.textSecondary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? activeColor : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
