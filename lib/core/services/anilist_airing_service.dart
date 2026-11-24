import 'package:dio/dio.dart';

import '../models/anime_item.dart';

class AniListAiringService {
  AniListAiringService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://graphql.anilist.co',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 15),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final Dio _dio;

  List<Map<String, dynamic>>? _scheduleCache;
  DateTime? _cacheTime;

  static const String _query = r"""
    query (
      $page: Int!,
      $airingAtGreater: Int,
      $airingAtLesser: Int
    ) {
      Page(page: $page, perPage: 50) {
        pageInfo {
          hasNextPage
        }
        airingSchedules(
          airingAt_greater: $airingAtGreater
          airingAt_lesser: $airingAtLesser
          sort: TIME
        ) {
          airingAt
          episode
          media {
            id
            isAdult
            title { romaji english native }
            coverImage { large medium }
            averageScore
            episodes
            status
            siteUrl
            genres
            format
            seasonYear
          }
        }
      }
    }
  """;

  Future<List<AnimeItem>> getSchedule(String day) async {
    final now = DateTime.now().toUtc();
    final start = now.millisecondsSinceEpoch ~/ 1000;
    final end = start + const Duration(days: 14).inSeconds;

    var allSchedules = _scheduleCache;

    final cacheExpired = _cacheTime == null ||
        DateTime.now().difference(_cacheTime!) >=
            const Duration(minutes: 5);

    if (allSchedules == null || cacheExpired) {
      allSchedules = <Map<String, dynamic>>[];
      var pageNumber = 1;
      var hasNextPage = true;

      while (hasNextPage && pageNumber <= 10) {
      final response = await _dio.post<Map<String, dynamic>>(
        '',
        data: {
          'query': _query,
          'variables': {
            'page': pageNumber,
            'airingAtGreater': start,
            'airingAtLesser': end,
          },
        },
      );

      final body = response.data;
      if (body == null) {
        throw Exception('AniList returned an empty response.');
      }

      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        final message = first is Map
            ? '${first['message'] ?? 'Unknown GraphQL error'}'
            : 'Unknown GraphQL error';
        throw Exception('AniList: $message');
      }

      final data = body['data'];
      final page = data is Map ? data['Page'] : null;
      final schedules =
          page is Map ? page['airingSchedules'] : null;
      final pageInfo =
          page is Map ? page['pageInfo'] : null;

      if (schedules is! List || pageInfo is! Map) {
        throw Exception('AniList returned an invalid airing schedule.');
      }

      allSchedules.addAll(
        schedules
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry)),
      );

      hasNextPage = pageInfo['hasNextPage'] == true;
        pageNumber++;
      }

      if (hasNextPage) {
        throw Exception(
          'The airing schedule is too large to load completely. Please retry.',
        );
      }

      _scheduleCache = allSchedules;
      _cacheTime = DateTime.now();
    }

    final selectedDay = day.toLowerCase();

    return allSchedules.where((entry) {
      final media = entry['media'];
      if (media is! Map || media['isAdult'] == true) return false;

      final timestamp = entry['airingAt'];
      if (timestamp is! num) return false;

      final airingDate = DateTime.fromMillisecondsSinceEpoch(
        timestamp.toInt() * 1000,
        isUtc: true,
      ).toLocal();

      final weekday = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ][airingDate.weekday - 1];

      return weekday == selectedDay;
    }).map((entry) {
      return AnimeItem.fromAniListSchedule(entry);
    }).toList();
  }

  void dispose() {
    _dio.close();
  }
}
