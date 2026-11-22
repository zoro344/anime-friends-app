import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'animepahe_scraper.dart';
import 'video_source_resolver.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const AnimeStreamingApp());
}

class AnimeStreamingApp extends StatelessWidget {
  const AnimeStreamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anime',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769AA),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1769AA),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class WatchEntry {
  final String title;
  final int episode;
  final String url;
  final DateTime watchedAt;

  const WatchEntry({
    required this.title,
    required this.episode,
    required this.url,
    required this.watchedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'episode': episode,
        'url': url,
        'watchedAt': watchedAt.toIso8601String(),
      };

  factory WatchEntry.fromJson(Map<String, dynamic> json) {
    return WatchEntry(
      title: json['title']?.toString() ?? 'Unknown anime',
      episode: (json['episode'] as num?)?.toInt() ?? 0,
      url: json['url']?.toString() ?? '',
      watchedAt: DateTime.tryParse(
            json['watchedAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AnimePaheScraper _scraper = AnimePaheScraper();
  final VideoSourceResolver _videoResolver = VideoSourceResolver();
  String _resolverEndpoint = '';
  final TextEditingController _searchController = TextEditingController();

  int _selectedTab = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String _message = '';
  AnimeSearchPage? _searchPage;

  final List<AnimeResult> _animeResults = [];
  List<WatchEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadResolverEndpoint();
  }

  Future<void> _loadResolverEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _resolverEndpoint = prefs.getString('video_resolver_endpoint') ?? '';
    });
  }

  Future<void> _configureResolver() async {
    final controller = TextEditingController(text: _resolverEndpoint);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Video resolver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the HTTPS endpoint of a video provider/resolver you own '
              'or are authorized to use. The app sends animeSession, '
              'episodeSession, episode and title as query parameters.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://your-domain.example/resolve',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;

    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      final uri = Uri.tryParse(normalized);
      if (uri == null ||
          !uri.hasAuthority ||
          !const ['https', 'http'].contains(uri.scheme)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid HTTP(S) endpoint.')),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('video_resolver_endpoint', normalized);
    if (!mounted) return;
    setState(() => _resolverEndpoint = normalized);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(normalized.isEmpty
            ? 'Video resolver cleared.'
            : 'Video resolver saved.'),
      ),
    );
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('watch_history');
    if (saved == null) return;

    try {
      final decoded = jsonDecode(saved) as List;
      final entries = decoded
          .whereType<Map>()
          .map((item) => WatchEntry.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();

      if (!mounted) return;
      setState(() => _history = entries);
    } catch (_) {
      if (!mounted) return;
      setState(() => _history = []);
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'watch_history',
      jsonEncode(_history.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _searchAnime() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _animeResults.clear();
        _searchPage = null;
        _message = 'Enter an anime title to search.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadingMore = false;
      _animeResults.clear();
      _searchPage = null;
      _message = '';
    });

    try {
      final result = await _scraper.search(query: query);
      if (!mounted) return;

      setState(() {
        _searchPage = result;
        _animeResults.addAll(result.items);
        _message = result.items.isEmpty
            ? 'No anime found.'
            : '${result.items.length} results found.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Search failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final page = _searchPage;
    if (page == null || !page.hasNextPage || _loadingMore) return;

    setState(() => _loadingMore = true);

    try {
      final result = await _scraper.search(
        query: _searchController.text.trim(),
        page: page.currentPage + 1,
      );

      if (!mounted) return;
      setState(() {
        _searchPage = result;
        _animeResults.addAll(result.items);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load more results: $error')),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openAnime(AnimeResult anime) async {
    setState(() => _loading = true);

    try {
      final episodes = await _scraper.getAllEpisodes(
        animeSession: anime.session,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (episodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No episodes returned by the source.')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          anime.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text('${episodes.length} episodes'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: episodes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final episode = episodes[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.play_circle_outline,
                          color: Color(0xFF1769AA),
                        ),
                        title: Text('Episode ${episode.number}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _resolveAndPlay(anime, episode);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Episode loading failed: $error')),
      );
    }
  }

  Future<void> _resolveAndPlay(
    AnimeResult anime,
    AnimeEpisode episode,
  ) async {
    if (_resolverEndpoint.trim().isEmpty) {
      await _configureResolver();
      if (_resolverEndpoint.trim().isEmpty) return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 18),
            Expanded(child: Text('Finding playable video sources...')),
          ],
        ),
      ),
    );

    try {
      final sources = await _videoResolver.resolve(
        endpoint: _resolverEndpoint,
        animeSession: anime.session,
        episodeSession: episode.session,
        episodeNumber: episode.number,
        animeTitle: anime.title,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final source = sources.first;
      if (sources.length > 1) {
        final selected = await showModalBottomSheet<ResolvedVideoSource>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('Choose video quality'),
                  subtitle: Text('Sources supplied by your configured provider'),
                ),
                ...sources.map((item) => ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(item.label),
                      subtitle: Text(item.type),
                      onTap: () => Navigator.pop(sheetContext, item),
                    )),
              ],
            ),
          ),
        );
        if (selected == null || !mounted) return;
        await _saveAndPlay(anime, episode.number, selected);
      } else {
        await _saveAndPlay(anime, episode.number, source);
      }
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resolve this episode: $error')),
      );
    }
  }

  Future<void> _saveAndPlay(
    AnimeResult anime,
    int episodeNumber,
    ResolvedVideoSource source,
  ) async {
    final entry = WatchEntry(
      title: anime.title,
      episode: episodeNumber,
      url: source.url,
      watchedAt: DateTime.now(),
    );
    setState(() {
      _history.removeWhere(
        (item) => item.title == anime.title && item.episode == episodeNumber,
      );
      _history.insert(0, entry);
    });
    await _saveHistory();
    if (mounted) _openPlayer(entry);
  }

  void _openPlayer(WatchEntry entry) {
    if (entry.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video URL saved for this entry.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerPage(entry: entry)),
    );
  }

  Future<void> _removeHistory(int index) async {
    setState(() => _history.removeAt(index));
    await _saveHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scraper.dispose();
    _videoResolver.dispose();
    super.dispose();
  }

  Widget _buildAnimePage() {
    return Column(
      children: [
        Container(
          color: const Color(0xFF1769AA),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchAnime(),
                  decoration: InputDecoration(
                    hintText: 'Search anime...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loading ? null : _searchAnime,
                icon: const Icon(Icons.search, color: Colors.white),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _message,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _animeResults.length +
                (_searchPage?.hasNextPage == true ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _animeResults.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: _loadMore,
                            child: const Text('Load more'),
                          ),
                  ),
                );
              }

              final anime = _animeResults[index];
              return Container(
                color: index.isEven
                    ? Colors.white
                    : const Color(0xFFF0F1F3),
                child: ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 45,
                    height: 60,
                    child: anime.poster.isEmpty
                        ? const Icon(Icons.movie_outlined)
                        : Image.network(
                            anime.poster,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.movie_outlined),
                          ),
                  ),
                  title: Text(
                    anime.title,
                    style: const TextStyle(
                      color: Color(0xFF1769AA),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${anime.type} • ${anime.year} • ${anime.episodes} episodes',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.black45,
                  ),
                  onTap: () => _openAnime(anime),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryPage() {
    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 55, color: Colors.black26),
            SizedBox(height: 10),
            Text(
              'No watch history yet',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _history.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _history[index];
        return ListTile(
          leading: const Icon(
            Icons.play_circle_outline,
            color: Color(0xFF1769AA),
          ),
          title: Text(entry.title),
          subtitle: Text(
            'Episode ${entry.episode} • ${entry.watchedAt.toLocal()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _openPlayer(entry),
          trailing: IconButton(
            tooltip: 'Remove from history',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeHistory(index),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTab == 0 ? 'Anime Directory' : 'Watch History',
        ),
        actions: [
          IconButton(
            tooltip: 'Configure video resolver',
            onPressed: _configureResolver,
            icon: const Icon(Icons.settings_ethernet),
          ),
        ],
      ),
      body: _selectedTab == 0 ? _buildAnimePage() : _buildHistoryPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Anime',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Watch History',
          ),
        ],
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  final WatchEntry entry;

  const PlayerPage({super.key, required this.entry});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    unawaited(_player.open(Media(widget.entry.url)));
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.entry.title} - Episode ${widget.entry.episode}',
        ),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Video(
          controller: _controller,
          controls: MaterialVideoControls,
        ),
      ),
    );
  }
}
