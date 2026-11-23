import 'models/anime_source_models.dart';

abstract interface class AnimeSource {
  String get id;

  String get name;

  String get version;

  Future<List<SourceAnime>> searchAnime(String query);

  Future<SourceAnimeDetails?> getAnimeDetails(
    String animeSourceId,
  );

  Future<List<SourceEpisode>> getEpisodes(
    String animeSourceId,
  );

  Future<ResolvedAnimeEpisode> resolveEpisode(
    SourceEpisode episode,
  );
}

class AnimeSourceException implements Exception {
  final String sourceId;
  final String message;
  final Object? cause;

  const AnimeSourceException({
    required this.sourceId,
    required this.message,
    this.cause,
  });

  @override
  String toString() {
    return 'AnimeSourceException($sourceId): $message';
  }
}
