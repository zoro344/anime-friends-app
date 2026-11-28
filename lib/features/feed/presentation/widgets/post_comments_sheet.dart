import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../core/models/post_comment.dart';
import '../../../../core/state/app_state.dart';

class PostCommentsSheet extends StatefulWidget {
  const PostCommentsSheet({
    super.key,
    required this.postId,
    required this.state,
  });

  final String postId;
  final AppState state;

  @override
  State<PostCommentsSheet> createState() =>
      _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  bool _started = false;

  PostComment? _replyingTo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    await widget.state.loadComments(widget.postId);

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  void _startReply(PostComment comment) {
    setState(() {
      _replyingTo = comment;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _sendComment() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    final succeeded = await widget.state.addComment(
      widget.postId,
      value,
      parentCommentId: _replyingTo?.id,
    );

    if (!mounted) return;

    if (succeeded) {
      _controller.clear();
      setState(() {
        _replyingTo = null;
      });
    }

    setState(() {
      _sending = false;
    });

    if (!succeeded) {
      _showCommentActionResult(
        false,
        '',
        'Could not add your comment. Please try again.',
      );
    }
  }

  void _showCommentActionResult(
    bool succeeded,
    String successMessage,
    String fallbackMessage,
  ) {
    if (!mounted) return;

    final message = succeeded
        ? successMessage
        : (widget.state.commentError.isNotEmpty
            ? widget.state.commentError
            : fallbackMessage);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _editComment(PostComment comment) async {
    final controller = TextEditingController(
      text: comment.content,
    );

    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit comment'),
          content: TextField(
            controller: controller,
            maxLength: 1500,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write a comment...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (edited == null || edited.trim().isEmpty || !mounted) {
      return;
    }

    final succeeded = await widget.state.editComment(
      comment.id,
      widget.postId,
      edited,
    );

    _showCommentActionResult(
      succeeded,
      'Comment updated.',
      'Could not update the comment.',
    );
  }

  Future<void> _deleteComment(PostComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete comment?'),
          content: const Text(
            'This comment and its replies will be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final succeeded = await widget.state.deleteComment(
      comment.id,
      widget.postId,
    );

    _showCommentActionResult(
      succeeded,
      'Comment deleted.',
      'Could not delete the comment.',
    );

    if (succeeded &&
        mounted &&
        (_replyingTo?.id == comment.id ||
            _replyingTo?.parentCommentId == comment.id)) {
      setState(() {
        _replyingTo = null;
      });
    }
  }

  String _relativeTime(PostComment comment) {
    final createdAt = DateTime.tryParse(comment.createdAt.toString());
    if (createdAt == null) return '';

    final difference = DateTime.now().difference(createdAt);
    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  Widget _buildCommentTile(
    PostComment comment, {
    required bool isReply,
  }) {
    final isMine = comment.isMine(widget.state.userId);
    final timestamp = _relativeTime(comment);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isReply ? 14 : 19,
          backgroundColor: AppColors.surfaceElevated,
          child: Text(
            comment.username.isEmpty
                ? '?'
                : comment.username[0].toUpperCase(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isReply ? 12 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (timestamp.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      timestamp,
                      style: const TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                comment.content,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (!isReply)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _startReply(comment),
                    icon: const Icon(Icons.reply, size: 15),
                    label: const Text('Reply'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      minimumSize: const Size(40, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (isMine)
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            color: AppColors.surfaceElevated,
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.iconMuted,
              size: 20,
            ),
            onSelected: (action) {
              if (action == 'edit') {
                _editComment(comment);
              } else if (action == 'delete') {
                _deleteComment(comment);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildThread(
    PostComment comment,
    List<PostComment> replies,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentTile(comment, isReply: false),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: 28,
                top: 10,
              ),
              child: Column(
                children: [
                  for (final reply in replies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCommentTile(
                        reply,
                        isReply: true,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final comments = state.commentsForPost(widget.postId);

    final rootComments = comments
        .where((comment) => !comment.isReply)
        .toList();

    final replies = comments
        .where((comment) => comment.isReply)
        .toList();

    final visibleIds = rootComments.map((comment) => comment.id).toSet();

    // Keep orphaned replies visible rather than silently hiding them.
    final orphanedReplies = replies
        .where((reply) => !visibleIds.contains(reply.parentCommentId))
        .toList();

    final replyingTo = _replyingTo;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.78,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${comments.length}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close comments',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.iconMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              color: AppColors.divider,
              height: 1,
            ),
            if (state.commentError.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
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
                        state.commentError,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                        });
                        _loadComments();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : rootComments.isEmpty && orphanedReplies.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 42,
                                  color: AppColors.iconMuted,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Start the conversation',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Be the first to share your thoughts.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                          children: [
                            for (final comment in rootComments)
                              _buildThread(
                                comment,
                                replies
                                    .where(
                                      (reply) =>
                                          reply.parentCommentId == comment.id,
                                    )
                                    .toList(),
                              ),
                            for (final reply in orphanedReplies)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildCommentTile(
                                  reply,
                                  isReply: true,
                                ),
                              ),
                          ],
                        ),
            ),
            const Divider(
              color: AppColors.divider,
              height: 1,
            ),
            if (replyingTo != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply,
                      color: AppColors.iconMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to ${replyingTo.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      visualDensity: VisualDensity.compact,
                      onPressed: _cancelReply,
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.iconMuted,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                bottomInset + 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.border,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLength: 1500,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: replyingTo == null
                              ? 'Write a comment...'
                              : 'Write a reply...',
                          hintStyle: const TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 13,
                          ),
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: FilledButton(
                      onPressed: _sending ? null : _sendComment,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.background,
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              size: 19,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
