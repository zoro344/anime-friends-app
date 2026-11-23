import '../../anime/domain/models/anime_source_models.dart';

enum AnimePlayerStatus {
  idle,
  loading,
  playing,
  paused,
  completed,
  error,
}

class AnimePlayerState {
  final AnimePlayerStatus status;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  const AnimePlayerState({
    this.status = AnimePlayerStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  double get progress {
    if (duration.inMilliseconds <= 0) {
      return 0;
    }

    return (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }
}

abstract interface class AnimePlayer {
  Stream<AnimePlayerState> get states;

  AnimePlayerState get currentState;

  Future<void> initialize(
    ResolvedAnimeEpisode episode,
    AnimeVideoVariant selectedVideo,
  );

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setVolume(double volume);

  Future<void> setPlaybackSpeed(double speed);

  Future<void> dispose();
}
