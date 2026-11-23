class Conversation {
  final String userId;
  final String name;
  final String message;
  final String time;

  const Conversation({
    required this.userId,
    required this.name,
    required this.message,
    required this.time,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final last = json['lastMessage'] is Map<String, dynamic>
        ? json['lastMessage'] as Map<String, dynamic>
        : <String, dynamic>{};
    final createdAt = DateTime.tryParse('${last['createdAt'] ?? ''}');
    return Conversation(
      userId: '${user['id'] ?? ''}',
      name: '${user['username'] ?? 'Friend'}',
      message: '${last['text'] ?? 'Start a conversation'}',
      time: createdAt == null ? '' : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
    );
  }
}
