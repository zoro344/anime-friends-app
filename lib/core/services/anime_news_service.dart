import 'dart:io';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

class AnimeNewsService {
  AnimeNewsService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 18),
                sendTimeout: const Duration(seconds: 12),
                headers: const {
                  'Accept':
                      'application/rss+xml, application/xml, text/xml, */*',
                  'User-Agent': 'AnimeFriends/1.0',
                },
              ),
            );

  final Dio _dio;

  static const _feeds = <Map<String, String>>[
    {
      'name': 'Anime News Network',
      'url': 'https://www.animenewsnetwork.com/all/rss.xml?ann-edition=us',
    },
    {
      'name': 'Anime Corner',
      'url': 'https://animecorner.me/feed/',
    },
    {
      'name': 'Anime Trending',
      'url': 'https://anitrendz.net/news/feed/',
    },
  ];

  List<Map<String, dynamic>>? _cache;
  DateTime? _cacheTime;

  Future<List<Map<String, dynamic>>> getNews({
    String query = '',
    String category = '',
  }) async {
    final expired = _cacheTime == null ||
        DateTime.now().difference(_cacheTime!) >
            const Duration(minutes: 5);

    if (_cache == null || expired) {
      final results = await Future.wait(
        _feeds.map(_loadFeed),
      );

      final articles = results.expand((items) => items).toList();

      final unique = <String, Map<String, dynamic>>{};
      for (final article in articles) {
        final url = '${article['url'] ?? ''}';
        if (url.isNotEmpty) unique.putIfAbsent(url, () => article);
      }

      if (unique.isEmpty) {
        throw Exception('No anime news feeds could be reached.');
      }

      _cache = unique.values.toList()
        ..sort((a, b) {
          final dateA =
              DateTime.tryParse('${a['publishedAt'] ?? ''}') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
          final dateB =
              DateTime.tryParse('${b['publishedAt'] ?? ''}') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });

      _cacheTime = DateTime.now();
    }

    final normalizedQuery = query.trim().toLowerCase();

    return _cache!.where((article) {
      final title = '${article['title'] ?? ''}'.toLowerCase();
      final summary = '${article['summary'] ?? ''}'.toLowerCase();
      final source = '${article['source'] ?? ''}'.toLowerCase();

      final matchesQuery = normalizedQuery.isEmpty ||
          title.contains(normalizedQuery) ||
          summary.contains(normalizedQuery) ||
          source.contains(normalizedQuery);

      final matchesCategory =
          category.isEmpty || _matchesCategory(article, category);

      return matchesQuery && matchesCategory;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadFeed(
    Map<String, String> feed,
  ) async {
    try {
      final response = await _dio.get<String>(feed['url']!);
      final body = response.data;

      if (body == null || body.isEmpty) return [];

      final document = XmlDocument.parse(body);
      final items = document.findAllElements('item');

      return items.map((item) {
        final title = _elementText(item, 'title');
        final link = _elementText(item, 'link');
        final description = _elementText(item, 'description');
        final pubDate = _elementText(item, 'pubDate');

        final safeUrl = _httpsUrl(link);
        if (title.isEmpty || safeUrl.isEmpty) {
          return <String, dynamic>{};
        }

        final cleanDescription = _cleanHtml(description);
        final imageUrl = _findImage(item, description);
        final publishedAt = _parseDate(pubDate);

        return <String, dynamic>{
          'title': title,
          'source': feed['name']!,
          'summary': cleanDescription,
          'description': cleanDescription,
          'imageUrl': imageUrl,
          'url': safeUrl,
          'publishedAt': publishedAt?.toIso8601String() ?? '',
        };
      }).where((item) => item.isNotEmpty).toList();
    } catch (_) {
      // A failed publisher must not prevent other feeds from loading.
      return [];
    }
  }

  String _elementText(XmlElement parent, String name) {
    for (final element in parent.childElements) {
      if (element.name.local == name) return element.innerText.trim();
    }
    return '';
  }

  String _findImage(XmlElement item, String description) {
    for (final element in item.descendants.whereType<XmlElement>()) {
      final localName = element.name.local.toLowerCase();

      if (localName == 'thumbnail' || localName == 'content') {
        final url = element.getAttribute('url');
        final safe = _httpsUrl(url ?? '');
        if (safe.isNotEmpty) return safe;
      }

      if (localName == 'enclosure') {
        final type = element.getAttribute('type') ?? '';
        if (type.startsWith('image/')) {
          final safe = _httpsUrl(element.getAttribute('url') ?? '');
          if (safe.isNotEmpty) return safe;
        }
      }
    }

    final match = RegExp(
      r'''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(description);

    return _httpsUrl(match?.group(1) ?? '');
  }

  String _httpsUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      return '';
    }
    return uri.toString();
  }

  String _cleanHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;

    final isoDate = DateTime.tryParse(value);
    if (isoDate != null) return isoDate;

    try {
      return HttpDate.parse(value).toUtc();
    } catch (_) {
      return null;
    }
  }

  bool _matchesCategory(
    Map<String, dynamic> article,
    String category,
  ) {
    final text =
        '${article['title'] ?? ''} ${article['summary'] ?? ''}'
            .toLowerCase();

    switch (category) {
      case 'announcements':
        return RegExp(
          r'\b(announc|announce|confirmed|official|revealed|new project)\b',
        ).hasMatch(text);

      case 'trailers':
        return RegExp(
          r'\b(trailer|teaser|pv\b|preview|promotional video)\b',
        ).hasMatch(text);

      case 'release_date':
        return RegExp(
          r'\b(release date|premiere date|airing date|premieres|airs on)\b',
        ).hasMatch(text);

      default:
        return true;
    }
  }

  void dispose() {
    _dio.close();
  }
}
