enum AnimeStreamType {
  hls,
  dash,
  mp4,
  unknown,
}

class SourceAnime {
  final String sourceId;
  final String title;
  final String? imageUrl;
  final String? description;

  const SourceAnime({
    required this.sourceId,
    required this.title,
    this.imageUrl,
    this.description,
  });
}

class SourceAnimeDetails extends SourceAnime {
  final String? status;
  final String? genres;
  final int? episodeCount;

  const SourceAnimeDetails({
    required super.sourceId,
    required super.title,
    super.imageUrl,
    super.description,
    this.status,
    this.genres,
    this.episodeCount,
  });
}

class SourceEpisode {
  final String sourceEpisodeId;
  final String animeSourceId;
  final String title;
  final int episodeNumber;
  final String? thumbnailUrl;

  const SourceEpisode({
    required this.sourceEpisodeId,
    required this.animeSourceId,
    required this.title,
    required this.episodeNumber,
    this.thumbnailUrl,
  });
}

class AnimeVideoVariant {
  final String id;
  final String url;
  final String quality;
  final AnimeStreamType type;
  final Map<String, String> headers;

  AnimeVideoVariant({
    required this.id,
    required this.url,
    required this.quality,
    required this.type,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable(headers);
}

class AnimeSubtitleTrack {
  final String id;
  final String language;
  final String label;
  final String url;
  final bool isDefault;
  final Map<String, String> headers;

  AnimeSubtitleTrack({
    required this.id,
    required this.language,
    required this.label,
    required this.url,
    this.isDefault = false,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable(headers);
}

class AnimeAudioTrack {
  final String id;
  final String language;
  final String label;

  const AnimeAudioTrack({
    required this.id,
    required this.language,
    required this.label,
  });
}

class ResolvedAnimeEpisode {
  final SourceEpisode episode;
  final List<AnimeVideoVariant> videos;
  final List<AnimeSubtitleTrack> subtitles;
  final List<AnimeAudioTrack> audioTracks;

  ResolvedAnimeEpisode({
    required this.episode,
    required List<AnimeVideoVariant> videos,
    List<AnimeSubtitleTrack> subtitles = const [],
    List<AnimeAudioTrack> audioTracks = const [],
  })  : videos = List.unmodifiable(videos),
        subtitles = List.unmodifiable(subtitles),
        audioTracks = List.unmodifiable(audioTracks);
}
