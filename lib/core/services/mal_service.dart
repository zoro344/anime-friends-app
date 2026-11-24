import 'package:dio/dio.dart';

import '../models/anime_item.dart';

class MalService {
  MalService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.myanimelist.net/v2',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 18),
                sendTimeout: const Duration(seconds: 12),
                headers: {
                  'Accept': 'application/json',
                  'X-MAL-CLIENT-ID': _clientId,
                },
              ),
            );

  static const String _clientId =
      String.fromEnvironment('MAL_CLIENT_ID');

  static const String _fields =
      'id,title,main_picture,alternative_titles,synopsis,mean,rank,'
      'popularity,num_episodes,status,genres,media_type,start_date,'
      'start_season,broadcast';

  final Dio _dio;
  DateTime? _lastRequest;
  Future<void> _requestQueue = Future<void>.value();

  Future<void> _waitForRequestSlot() {
    final nextRequest = _requestQueue.then((_) async {
      final previous = _lastRequest;
      if (previous != null) {
        final elapsed = DateTime.now().difference(previous);
        const minimumGap = Duration(seconds: 1);
        if (elapsed < minimumGap) {
          await Future<void>.delayed(minimumGap - elapsed);
        }
      }
      _lastRequest = DateTime.now();
    });

    _requestQueue = nextRequest.catchError((Object _) {});
    return nextRequest;
  }

  void _checkConfiguration() {
    if (_clientId.trim().isEmpty) {
      throw Exception(
        'MAL Client ID is missing. Check the MAL_CLIENT_ID GitHub secret '
        'and Android build configuration.',
      );
    }
  }

  Future<List<AnimeItem>> _getAnimeList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    _checkConfiguration();
    await _waitForRequestSlot();

    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Invalid MyAnimeList response.');
      }

      final data = body['data'];
      if (data is! List) return [];

      final results = <AnimeItem>[];
      for (final entry in data) {
        if (entry is! Map) continue;

        final node = entry['node'];
        if (node is Map) {
          results.add(
            AnimeItem.fromMal(Map<String, dynamic>.from(node)),
          );
        } else {
          results.add(
            AnimeItem.fromMal(Map<String, dynamic>.from(entry)),
          );
        }
      }
      return results;
    } on DioException catch (error) {
      _handleDioError(error);
    } on FormatException {
      throw Exception('MyAnimeList returned an unexpected response.');
    }
  }

  Never _handleDioError(DioException error) {
    final status = error.response?.statusCode;

    if (status == 401 || status == 403) {
      throw Exception(
        'MyAnimeList rejected the Client ID. Check your MAL_CLIENT_ID secret.',
      );
    }
    if (status == 429) {
      throw Exception(
        'MyAnimeList is receiving too many requests. Please wait and retry.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      throw Exception('MyAnimeList took too long to respond. Try again.');
    }
    if (error.type == DioExceptionType.connectionError) {
      throw Exception(
        'Could not connect to MyAnimeList. Check your internet connection.',
      );
    }
    throw Exception('Could not load anime from MyAnimeList.');
  }

  Future<List<AnimeItem>> getPopularAnime() {
    return _getAnimeList(
      '/anime/ranking',
      query: {
        'ranking_type': 'bypopularity',
        'limit': 18,
        'fields': _fields,
      },
    );
  }

  Future<List<AnimeItem>> searchAnime(String query) {
    return _getAnimeList(
      '/anime',
      query: {
        'q': query.trim(),
        'limit': 20,
        'fields': _fields,
      },
    );
  }

  Future<AnimeItem> getAnimeDetails(int malId) async {
    _checkConfiguration();
    await _waitForRequestSlot();

    try {
      final response = await _dio.get<dynamic>(
        '/anime/$malId',
        queryParameters: {'fields': _fields},
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw Exception('Anime details were not available.');
      }
      return AnimeItem.fromMal(body);
    } on DioException catch (error) {
      _handleDioError(error);
    }
  }

  void dispose() {
    _dio.close();
  }
}
