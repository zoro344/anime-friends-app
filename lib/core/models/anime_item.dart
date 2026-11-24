class AnimeItem {
  final String id;
  final String name;
  final String genre;
  final String coverUrl;
  final String description;
  final String status;
  final String score;
  final String url;
  final String type;
  final String episodes;
  final String year;
  final String season;
  final String broadcastDay;
  final String broadcastTime;

  const AnimeItem({
    required this.name,
    required this.genre,
    this.id = '',
    this.coverUrl = '',
    this.description = '',
    this.status = '',
    this.score = '',
    this.url = '',
    this.type = '',
    this.episodes = '',
    this.year = '',
    this.season = '',
    this.broadcastDay = '',
    this.broadcastTime = '',
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

  factory AnimeItem.fromJikan(Map<String, dynamic> json) {
    final images = json['images'];
    final jpg = images is Map ? images['jpg'] : null;
    final webp = images is Map ? images['webp'] : null;

    final imageUrl = jpg is Map
        ? '${jpg['large_image_url'] ?? jpg['image_url'] ?? ''}'
        : webp is Map
            ? '${webp['large_image_url'] ?? webp['image_url'] ?? ''}'
            : '';

    final genres = <String>[];
    for (final key in ['genres', 'themes', 'demographics']) {
      final values = json[key];
      if (values is List) {
        for (final value in values) {
          if (value is Map && value['name'] != null) {
            genres.add(value['name'].toString());
          }
        }
      }
    }

    final broadcast = json['broadcast'];
    final aired = json['aired'];
    final seasonName = json['season']?.toString() ?? '';
    final yearValue = json['year'] ?? (aired is Map ? aired['prop']?['from']?['year'] : null);

    return AnimeItem(
      id: '${json['mal_id'] ?? ''}',
      name: '${json['title_english'] ?? json['title'] ?? 'Untitled'}',
      genre: genres.isEmpty ? '${json['type'] ?? 'Anime'}' : genres.join(' • '),
      coverUrl: imageUrl,
      description: '${json['synopsis'] ?? 'No synopsis is available.'}',
      status: '${json['status'] ?? 'Unknown'}',
      score: json['score'] == null ? '—' : '${json['score']}',
      url: '${json['url'] ?? ''}',
      type: '${json['type'] ?? ''}',
      episodes: json['episodes'] == null ? 'Unknown' : '${json['episodes']}',
      year: yearValue?.toString() ?? '',
      season: seasonName,
      broadcastDay: broadcast is Map ? '${broadcast['day'] ?? ''}' : '',
      broadcastTime: broadcast is Map ? '${broadcast['time'] ?? ''}' : '',
    );
  }
}
