import 'package:dio/dio.dart';

const String animePaheBaseUrl = 'https://animepahe.pw';

class AnimeResult {
  final int id;
  final String title;
  final String type;
  final int episodes;
  final String status;
  final String season;
  final int year;
  final double score;
  final String poster;
  final String session;

  const AnimeResult({
    required this.id,
    required this.title,
    required this.type,
    required this.episodes,
    required this.status,
    required this.season,
    required this.year,
    required this.score,
    required this.poster,
    required this.session,
  });

  factory AnimeResult.fromJson(Map<String, dynamic> json) {
    return AnimeResult(
      id: _toInt(json['id']),
      title: json['title']?.toString() ?? 'Unknown',
      type: json['type']?.toString() ?? '',
      episodes: _toInt(json['episodes']),
      status: json['status']?.toString() ?? '',
      season: json['season']?.toString() ?? '',
      year: _toInt(json['year']),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      poster: json['poster']?.toString() ?? '',
      session: json['session']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AnimeSearchPage {
  final List<AnimeResult> items;
  final int currentPage;
  final int totalPages;
  final int perPage;

  const AnimeSearchPage({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.perPage,
  });

  bool get hasNextPage => currentPage < totalPages;
}

class AnimeEpisode {
  final String session;
  final int number;

  const AnimeEpisode({required this.session, required this.number});

  factory AnimeEpisode.fromJson(Map<String, dynamic> json) {
    return AnimeEpisode(
      session: json['session']?.toString() ?? '',
      number: _toInt(json['episode']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AnimePaheException implements Exception {
  final String message;
  final int? statusCode;

  const AnimePaheException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP $statusCode)';
}

class AnimePaheScraper {
  AnimePaheScraper({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: animePaheBaseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 25),
                headers: {
                  'Accept': 'application/json, text/plain, */*',
                  'User-Agent': 'Mozilla/5.0',
                },
              ),
            );

  final Dio _dio;

  Future<AnimeSearchPage> search({
    required String query,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    if (query.trim().isEmpty) {
      return AnimeSearchPage(
        items: const [],
        currentPage: page,
        totalPages: page,
        perPage: 0,
      );
    }

    try {
      final response = await _dio.get(
        '/api',
        queryParameters: {
          'm': 'search',
          'q': query.trim(),
          'page': page,
        },
        cancelToken: cancelToken,
      );

      final json = _asMap(response.data);
      final rawItems = json['data'];
      if (rawItems is! List) {
        throw const FormatException('Search response has no data list.');
      }

      final items = rawItems
          .whereType<Map>()
          .map((item) => AnimeResult.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();

      return AnimeSearchPage(
        items: items,
        currentPage: _toInt(json['current_page'], fallback: page),
        totalPages: _toInt(json['total'], fallback: page),
        perPage: _toInt(json['per_page']),
      );
    } on DioException catch (error) {
      throw AnimePaheException(
        'Anime search failed: ${error.message ?? error.type.name}',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<List<AnimeEpisode>> getEpisodePage({
    required String animeSession,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    if (animeSession.trim().isEmpty) {
      throw ArgumentError('Anime session cannot be empty.');
    }

    try {
      final response = await _dio.get(
        '/api',
        queryParameters: {
          'm': 'release',
          'id': animeSession,
          'sort': 'episode_asc',
          'page': page,
        },
        cancelToken: cancelToken,
      );

      final json = _asMap(response.data);
      final rawItems = json['data'];
      if (rawItems is! List) {
        throw const FormatException('Episode response has no data list.');
      }

      return rawItems
          .whereType<Map>()
          .map((item) => AnimeEpisode.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((episode) =>
              episode.session.isNotEmpty && episode.number > 0)
          .toList();
    } on DioException catch (error) {
      throw AnimePaheException(
        'Episode retrieval failed: ${error.message ?? error.type.name}',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<List<AnimeEpisode>> getAllEpisodes({
    required String animeSession,
    CancelToken? cancelToken,
  }) async {
    final episodes = <AnimeEpisode>[];
    for (var page = 1; page <= 500; page++) {
      final current = await getEpisodePage(
        animeSession: animeSession,
        page: page,
        cancelToken: cancelToken,
      );
      if (current.isEmpty) break;
      episodes.addAll(current);
    }
    return episodes;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Unexpected API response format.');
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void dispose() => _dio.close();
}
