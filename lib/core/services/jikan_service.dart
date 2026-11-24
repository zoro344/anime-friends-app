import 'package:dio/dio.dart';

import '../models/anime_item.dart';

class JikanService {
  JikanService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.jikan.moe/v4',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 12),
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent': 'AnimeFriends/1.0',
                },
              ),
            );

  final Dio _dio;
  DateTime? _lastRequest;
  Future<void> _rateLimitQueue = Future<void>.value();

  Future<void> _respectRateLimit() {
    final nextRequest = _rateLimitQueue.then((_) async {
      final previous = _lastRequest;
      if (previous != null) {
        final elapsed = DateTime.now().difference(previous);
        const minimumGap = Duration(milliseconds: 400);
        if (elapsed < minimumGap) {
          await Future<void>.delayed(minimumGap - elapsed);
        }
      }
      _lastRequest = DateTime.now();
    });

    _rateLimitQueue = nextRequest.catchError((Object _) {});
    return nextRequest;
  }

  Future<List<AnimeItem>> _getAnimeList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    await _respectRateLimit();

    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Invalid Jikan response.');
      }

      final data = body['data'];
      if (data is! List) return [];

      return data
          .whereType<Map<String, dynamic>>()
          .map(AnimeItem.fromJikan)
          .toList();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 429) {
        throw Exception(
          'Jikan is receiving too many requests. Please wait a moment.',
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw Exception('Jikan took too long to respond. Try again.');
      }
      if (error.type == DioExceptionType.connectionError) {
        throw Exception('Could not connect to Jikan. Check your internet.');
      }
      throw Exception('Could not load anime from Jikan.');
    } on FormatException {
      throw Exception('Jikan returned an unexpected response.');
    }
  }

  Future<List<AnimeItem>> getPopularAnime() {
    return _getAnimeList(
      '/top/anime',
      query: {
        'limit': 18,
        'filter': 'bypopularity',
        'sfw': true,
      },
    );
  }

  Future<List<AnimeItem>> getTopRatedAnime() {
    return _getAnimeList(
      '/top/anime',
      query: {
        'limit': 18,
        'sfw': true,
      },
    );
  }

  Future<List<AnimeItem>> getCurrentlyAiringAnime() {
    return _getAnimeList(
      '/top/anime',
      query: {
        'filter': 'airing',
        'limit': 18,
        'sfw': true,
      },
    );
  }

  Future<List<AnimeItem>> getUpcomingAnime() {
    return _getAnimeList(
      '/top/anime',
      query: {
        'filter': 'upcoming',
        'limit': 18,
        'sfw': true,
      },
    );
  }

  Future<List<AnimeItem>> getSeasonalAnime() {
    return _getAnimeList(
      '/seasons/now',
      query: {
        'limit': 18,
        'sfw': true,
      },
    );
  }

  Future<List<AnimeItem>> searchAnime(String query) {
    return _getAnimeList(
      '/anime',
      query: {
        'q': query.trim(),
        'limit': 20,
        'sfw': true,
        'order_by': 'popularity',
        'sort': 'asc',
      },
    );
  }

  Future<List<AnimeItem>> getSchedule(String weekday) {
    return _getAnimeList(
      '/schedules',
      query: {
        'filter': weekday.toLowerCase(),
        'limit': 25,
        'sfw': true,
      },
    );
  }

  Future<AnimeItem> getAnimeDetails(int malId) async {
    await _respectRateLimit();

    try {
      final response = await _dio.get<dynamic>('/anime/$malId/full');
      final body = response.data;
      if (body is! Map<String, dynamic> ||
          body['data'] is! Map<String, dynamic>) {
        throw Exception('Anime details were not available.');
      }
      return AnimeItem.fromJikan(
        body['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 429) {
        throw Exception('Jikan rate limit reached. Try again shortly.');
      }
      throw Exception('Could not load anime details.');
    }
  }

  void dispose() {
    _dio.close();
  }
}
