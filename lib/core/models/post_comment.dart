class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;
  final String? parentCommentId;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
    this.parentCommentId,
  });

  factory PostComment.fromSupabase(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};
    final parentId = json['parent_comment_id']?.toString();

    return PostComment(
      id: json['id'].toString(),
      postId: json['post_id'].toString(),
      userId: json['user_id'].toString(),
      username: (profile['display_name']?.toString().trim().isNotEmpty == true)
          ? profile['display_name'].toString()
          : (profile['username']?.toString() ?? 'Anime Friend'),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      parentCommentId:
          parentId == null || parentId.isEmpty ? null : parentId,
    );
  }

  bool isMine(String currentUserId) => userId == currentUserId;

  bool get isReply => parentCommentId != null;
}
