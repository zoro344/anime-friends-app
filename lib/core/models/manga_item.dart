class MangaItem {
  final String id;
  final String name;
  final String coverUrl;
  final String description;
  final String genre;
  final String status;
  final String score;
  final String type;
  final String chapters;
  final String volumes;
  final String year;
  final String url;

  const MangaItem({
    required this.id,
    required this.name,
    this.coverUrl = '',
    this.description = '',
    this.genre = '',
    this.status = '',
    this.score = '—',
    this.type = '',
    this.chapters = 'Unknown',
    this.volumes = 'Unknown',
    this.year = '',
    this.url = '',
  });

  factory MangaItem.fromMal(Map<String, dynamic> json) {
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

    final mean = json['mean'];
    final score = mean is num ? mean.toStringAsFixed(2) : '—';
    final startDate = json['start_date']?.toString() ?? '';
    final statusValue = json['status']?.toString() ?? 'Unknown';

    final id = '${json['id'] ?? ''}';

    return MangaItem(
      id: id,
      name: englishTitle != null && englishTitle.isNotEmpty
          ? englishTitle
          : '${json['title'] ?? 'Untitled'}',
      coverUrl: picture is Map
          ? '${picture['large'] ?? picture['medium'] ?? ''}'
          : '',
      description: '${json['synopsis'] ?? 'No synopsis is available.'}',
      genre: genres.join(' • '),
      status: statusValue.replaceAll('_', ' '),
      score: score,
      type: '${json['media_type'] ?? ''}',
      chapters: json['num_chapters'] == null
          ? 'Unknown'
          : '${json['num_chapters']}',
      volumes: json['num_volumes'] == null
          ? 'Unknown'
          : '${json['num_volumes']}',
      year: startDate.length >= 4 ? startDate.substring(0, 4) : '',
      url: 'https://myanimelist.net/manga/$id',
    );
  }
}
