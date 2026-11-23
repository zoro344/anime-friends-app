import 'anime_source.dart';

class AnimeSourceRegistry {
  final Map<String, AnimeSource> _sources = {};

  List<AnimeSource> get sources =>
      List.unmodifiable(_sources.values);

  bool get isEmpty => _sources.isEmpty;

  bool get isNotEmpty => _sources.isNotEmpty;

  void register(AnimeSource source) {
    final id = source.id.trim();

    if (id.isEmpty) {
      throw ArgumentError('Source ID cannot be empty.');
    }

    if (_sources.containsKey(id)) {
      throw StateError('Source already registered: $id');
    }

    _sources[id] = source;
  }

  void unregister(String sourceId) {
    _sources.remove(sourceId);
  }

  AnimeSource? getSource(String sourceId) {
    return _sources[sourceId];
  }

  void clear() {
    _sources.clear();
  }

  Future<Map<String, Object>> searchAll(String query) async {
    final results = <String, Object>{};

    if (query.trim().isEmpty) {
      return results;
    }

    final tasks = _sources.values.map((source) async {
      try {
        final anime = await source.searchAnime(query);
        results[source.id] = anime;
      } catch (error) {
        results[source.id] = AnimeSourceException(
          sourceId: source.id,
          message: 'Search failed.',
          cause: error,
        );
      }
    });

    await Future.wait(tasks);

    return results;
  }
}
