import 'package:dio/dio.dart';

class ResolvedVideoSource {
  final String url;
  final String label;
  final String type;

  const ResolvedVideoSource({
    required this.url,
    required this.label,
    required this.type,
  });

  factory ResolvedVideoSource.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] ?? json['src'] ?? '').toString().trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !const ['http', 'https'].contains(uri.scheme)) {
      throw const FormatException('Resolver returned an invalid video URL.');
    }
    return ResolvedVideoSource(
      url: url,
      label: (json['label'] ?? json['quality'] ?? 'Auto').toString(),
      type: (json['type'] ?? json['format'] ?? '').toString(),
    );
  }
}

/// Connects to a video resolver that you own or are authorized to use.
///
/// GET {endpoint}?animeSession=...&episodeSession=...&episode=...&title=...
/// Expected JSON: {"sources":[{"url":"https://.../master.m3u8",
/// "label":"1080p","type":"hls"}]}
class VideoSourceResolver {
  VideoSourceResolver({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              headers: {'Accept': 'application/json'},
            ));

  final Dio _dio;

  Future<List<ResolvedVideoSource>> resolve({
    required String endpoint,
    required String animeSession,
    required String episodeSession,
    required int episodeNumber,
    required String animeTitle,
  }) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        !const ['http', 'https'].contains(uri.scheme)) {
      throw const FormatException('Set a valid HTTPS resolver endpoint first.');
    }

    final response = await _dio.getUri(
      uri.replace(queryParameters: {
        ...uri.queryParameters,
        'animeSession': animeSession,
        'episodeSession': episodeSession,
        'episode': '$episodeNumber',
        'title': animeTitle,
      }),
    );

    final body = response.data;
    final rawSources = body is List
        ? body
        : body is Map
            ? (body['sources'] ?? body['data'])
            : null;

    if (rawSources is! List) {
      throw const FormatException(
        'Resolver response must contain a "sources" list.',
      );
    }

    final sources = rawSources
        .whereType<Map>()
        .map((item) => ResolvedVideoSource.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();

    if (sources.isEmpty) {
      throw const FormatException('No playable sources were returned.');
    }
    return sources;
  }

  void dispose() => _dio.close();
}
