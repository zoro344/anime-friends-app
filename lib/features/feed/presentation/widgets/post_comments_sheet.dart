import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/models/post_comment.dart';

class PostCommentsSheet extends StatefulWidget {
  const PostCommentsSheet({
    super.key,
    required this.postId,
  });

  final String postId;

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    final state = AppStateScope.of(context);
    await state.loadComments(widget.postId);

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    final value = _controller.text.trim();

    if (value.isEmpty || _sending) return;

    setState(() => _sending = true);

    final state = AppStateScope.of(context);
    final succeeded = await state.addComment(widget.postId, value);

    if (!mounted) return;

    if (succeeded) {
      _controller.clear();
    }

    setState(() => _sending = false);
  }

  Future<void> _editComment(PostComment comment) async {
    final controller = TextEditingController(text: comment.content);

    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Text(
            'Edit comment',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            maxLength: 1500,
            maxLines: 4,
            style: const TextStyle(color: AppColors.textPrimary),
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
              onPressed: () => Navigator.pop(
                dialogContext,
                controller.text,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (edited == null || edited.trim().isEmpty || !mounted) return;

    await AppStateScope.of(context).editComment(
      comment.id,
      widget.postId,
      edited,
    );
  }

  Future<void> _deleteComment(PostComment comment) async {
    await AppStateScope.of(context).deleteComment(
      comment.id,
      widget.postId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final comments = state.commentsForPost(widget.postId);

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
            const Divider(color: AppColors.divider, height: 1),
            if (state.commentError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.commentError,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                      ? const Center(
                          child: Text(
                            'No comments yet. Start the conversation!',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        AppColors.surfaceElevated,
                                    child: Text(
                                      comment.username.isEmpty
                                          ? '?'
                                          : comment.username[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                      ],
                                    ),
                                  ),
                                  if (comment.isMine(state.userId))
                                    PopupMenuButton<String>(
                                      color: AppColors.surfaceElevated,
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: AppColors.iconMuted,
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
                              ),
                            );
                          },
                        ),
            ),
            const Divider(color: AppColors.divider, height: 1),
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
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send comment',
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
