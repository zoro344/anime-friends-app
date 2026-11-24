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

    await widget.state.editComment(
      comment.id,
      widget.postId,
      edited,
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

    await widget.state.deleteComment(
      comment.id,
      widget.postId,
    );

    if (mounted && _replyingTo?.id == comment.id) {
      setState(() {
        _replyingTo = null;
      });
    }
  }

  Widget _buildCommentTile(
    PostComment comment, {
    required bool isReply,
  }) {
    final isMine = comment.isMine(widget.state.userId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isReply ? 14 : 18,
          backgroundColor: AppColors.surfaceElevated,
          child: Text(
            comment.username.isEmpty
                ? '?'
                : comment.username[0].toUpperCase(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isReply ? 12 : 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.username,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                comment.content,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              if (!isReply)
                TextButton(
                  onPressed: () => _startReply(comment),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reply'),
                ),
            ],
          ),
        ),
        if (isMine)
          PopupMenuButton<String>(
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

    // Keep any orphaned replies visible rather than silently hiding them.
    final orphanedReplies = replies
        .where((reply) => !visibleIds.contains(reply.parentCommentId))
        .toList();

    final replyingTo = _replyingTo;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Comments',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(
              color: AppColors.divider,
              height: 1,
            ),
            if (state.commentError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.commentError,
                  style: const TextStyle(
                    color: AppColors.error,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : rootComments.isEmpty && orphanedReplies.isEmpty
                      ? const Center(
                          child: Text(
                            'No comments yet. Start the conversation!',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final comment in rootComments)
                              _buildThread(
                                comment,
                                replies
                                    .where(
                                      (reply) =>
                                          reply.parentCommentId ==
                                          comment.id,
                                    )
                                    .toList(),
                              ),
                            for (final reply in orphanedReplies)
                              _buildCommentTile(
                                reply,
                                isReply: true,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                color: AppColors.surfaceElevated,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${replyingTo.username}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      onPressed: _cancelReply,
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.iconMuted,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                MediaQuery.viewInsetsOf(context).bottom + 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 1500,
                      maxLines: 2,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: replyingTo == null
                            ? 'Write a comment...'
                            : 'Write a reply...',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: replyingTo == null
                        ? 'Send comment'
                        : 'Send reply',
                    onPressed: _sending ? null : _sendComment,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: AppColors.textPrimary,
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
