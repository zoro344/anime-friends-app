class AnimeItem {
  final String id;
  final String name;
  final String genre;
  final String coverUrl;
  final String description;
  final String status;
  final String score;

  const AnimeItem({
    required this.name,
    required this.genre,
    this.id = '',
    this.coverUrl = '',
    this.description = '',
    this.status = '',
    this.score = '',
  });

  factory AnimeItem.fromJson(Map<String, dynamic> json) => AnimeItem(
        id: '${json['id'] ?? ''}',
        name: '${json['title'] ?? 'Untitled'}',
        genre: '${json['format'] ?? ''} • ${json['status'] ?? ''}',
        coverUrl: '${json['cover'] ?? ''}',
        description: '${json['description'] ?? ''}',
        status: '${json['status'] ?? ''}',
        score: '${json['score'] ?? '—'}',
      );
}
