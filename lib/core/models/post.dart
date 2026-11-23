class Post {
  final String id;
  final String user;
  final String time;
  final String text;
  final int likes;
  final int comments;
  final bool liked;
  final String? userId;
  final String? imageUrl;

  const Post({
    required this.id,
    required this.user,
    required this.time,
    required this.text,
    this.likes = 0,
    this.comments = 0,
    this.liked = false,
    this.userId,
    this.imageUrl,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse('${json['createdAt'] ?? ''}');
    return Post(
      id: '${json['id'] ?? ''}',
      user: '${json['username'] ?? 'Anime Friend'}',
      time: createdAt == null ? 'Recently' : _relativeTime(createdAt),
      text: '${json['text'] ?? ''}',
      likes: (json['score'] as num?)?.toInt() ?? 0,
      comments: (json['commentCount'] as num?)?.toInt() ?? 0,
      liked: (json['myVote'] as num?)?.toInt() == 1,
      userId: json['userId']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  factory Post.fromSupabase(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse('${json['created_at'] ?? ''}');
    final displayName = '${json['display_name'] ?? ''}'.trim();
    final username = '${json['username'] ?? 'Anime Friend'}';

    return Post(
      id: '${json['id'] ?? ''}',
      user: displayName.isNotEmpty ? displayName : username,
      time: createdAt == null ? 'Recently' : _relativeTime(createdAt),
      text: '${json['content'] ?? ''}',
      likes: (json['like_count'] as num?)?.toInt() ?? 0,
      comments: (json['comment_count'] as num?)?.toInt() ?? 0,
      liked: json['liked'] == true,
      userId: json['user_id']?.toString(),
      imageUrl: json['image_url']?.toString(),
    );
  }

  static String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${value.day}/${value.month}/${value.year}';
  }

  Post copyWith({
    String? id,
    String? user,
    String? time,
    String? text,
    int? likes,
    int? comments,
    bool? liked,
    String? userId,
    String? imageUrl,
  }) {
    return Post(
      id: id ?? this.id,
      user: user ?? this.user,
      time: time ?? this.time,
      text: text ?? this.text,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      liked: liked ?? this.liked,
      userId: userId ?? this.userId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
