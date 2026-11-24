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

  factory AnimeItem.fromMal(Map<String, dynamic> json) {
    final picture = json['main_picture'];
    final alternativeTitles = json['alternative_titles'];
    final englishTitle = alternativeTitles is Map
        ? alternativeTitles['en']?.toString()
        : null;

    final genres = <String>[];
    final genreValues = json['genres'];
    if (genreValues is List) {
      for (final value in genreValues) {
        if (value is Map && value['name'] != null) {
          genres.add(value['name'].toString());
        }
      }
    }

    final startSeason = json['start_season'];
    final broadcast = json['broadcast'];
    final startDate = json['start_date']?.toString() ?? '';

    final mean = json['mean'];
    final score = mean is num ? mean.toStringAsFixed(2) : '—';

    final statusValue = json['status']?.toString() ?? 'Unknown';
    final readableStatus = statusValue.replaceAll('_', ' ');

    return AnimeItem(
      id: '${json['id'] ?? ''}',
      name: (englishTitle != null && englishTitle.isNotEmpty)
          ? englishTitle
          : '${json['title'] ?? 'Untitled'}',
      genre: genres.isEmpty
          ? '${json['media_type'] ?? 'Anime'}'
          : genres.join(' • '),
      coverUrl: picture is Map
          ? '${picture['large'] ?? picture['medium'] ?? ''}'
          : '',
      description: '${json['synopsis'] ?? 'No synopsis is available.'}',
      status: readableStatus,
      score: score,
      url: 'https://myanimelist.net/anime/${json['id'] ?? ''}',
      type: '${json['media_type'] ?? ''}',
      episodes: json['num_episodes'] == null
          ? 'Unknown'
          : '${json['num_episodes']}',
      year: startDate.length >= 4 ? startDate.substring(0, 4) : '',
      season: startSeason is Map
          ? '${startSeason['season'] ?? ''}'
          : '',
      broadcastDay: broadcast is Map
          ? '${broadcast['day_of_the_week'] ?? ''}'
          : '',
      broadcastTime: broadcast is Map
          ? '${broadcast['start_time'] ?? ''}'
          : '',
    );
  }

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
    final airedProp = aired is Map ? aired['prop'] : null;
    final airedFrom = airedProp is Map ? airedProp['from'] : null;
    final airedYear = airedFrom is Map ? airedFrom['year'] : null;
    final yearValue = json['year'] ?? airedYear;

    return AnimeItem(
      id: '${json['mal_id'] ?? ''}',
      name: '${json['title_english'] ?? json['title'] ?? 'Untitled'}',
      genre: genres.isEmpty
          ? '${json['type'] ?? 'Anime'}'
          : genres.join(' • '),
      coverUrl: imageUrl,
      description: '${json['synopsis'] ?? 'No synopsis is available.'}',
      status: '${json['status'] ?? 'Unknown'}',
      score: json['score'] == null ? '—' : '${json['score']}',
      url: '${json['url'] ?? ''}',
      type: '${json['type'] ?? ''}',
      episodes:
          json['episodes'] == null ? 'Unknown' : '${json['episodes']}',
      year: yearValue?.toString() ?? '',
      season: seasonName,
      broadcastDay: broadcast is Map ? '${broadcast['day'] ?? ''}' : '',
      broadcastTime: broadcast is Map ? '${broadcast['time'] ?? ''}' : '',
    );
  }
}
