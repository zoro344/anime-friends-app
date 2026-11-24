class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
  });

  factory PostComment.fromSupabase(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};

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
    );
  }

  bool isMine(String currentUserId) => userId == currentUserId;
}
