import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/anime_reviews_section.dart';

import '../../../../core/models/anime_item.dart';
import '../../../../core/services/anilist_airing_service.dart';
import '../../../../core/services/mal_service.dart';
import '../../../../core/state/app_state_scope.dart';

const _purple = Color(0xFF9B6DFF);
const _blue = Color(0xFF579BFF);
const _pink = Color(0xFFFF70B8);
const _teal = Color(0xFF48DCC5);
const _orange = Color(0xFFFFB45E);
const _background = Color(0xFF08060D);
const _surface = Color(0xFF171220);

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  final AniListAiringService _airingService = AniListAiringService();
  final MalService _mal = MalService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchTimer;

  List<AnimeItem> _popular = [];
  List<AnimeItem> _searchResults = [];
  List<AnimeItem> _schedule = [];
  List<AnimeItem> _discoveryResults = [];
  bool _loadingDiscovery = false;
  String _discoveryError = '';
  int _selectedDiscovery = 0;

  static const _discoveryCategories = [
    'Popular anime',
    'Top rated',
    'Currently airing',
    'Upcoming',
    'This season',
  ];

  bool _loadingPopular = true;
  bool _loadingSearch = false;
  bool _loadingSchedule = false;
  String _scheduleError = '';
  int _scheduleRequestGeneration = 0;
  int _discoveryRequestGeneration = 0;
  int _searchRequestGeneration = 0;

  String _error = '';
  String _searchError = '';
  String _selectedDay = _todayName();
  int _selectedTab = 0;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _todayName() {
    return _days[DateTime.now().weekday - 1];
  }

  @override
  void initState() {
    super.initState();
    _loadPopular();
    _loadSchedule(_selectedDay);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _airingService.dispose();
    _mal.dispose();
    super.dispose();
  }

  Future<void> _loadPopular() async {
    setState(() {
      _loadingPopular = true;
      _error = '';
    });

    try {
      final results = await _mal.getPopularAnime();
      if (!mounted) return;

      setState(() {
        _popular = results;
        _loadingPopular = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
        _loadingPopular = false;
      });
    }
  }

  Future<void> _loadSchedule(String day) async {
    final requestId = ++_scheduleRequestGeneration;

    setState(() {
      _loadingSchedule = true;
      _scheduleError = '';
    });

    try {
      final results = await _airingService.getSchedule(day);
      if (!mounted || requestId != _scheduleRequestGeneration) return;

      setState(() {
        _schedule = results;
        _loadingSchedule = false;
        _scheduleError = '';
      });
    } catch (error) {
      if (!mounted || requestId != _scheduleRequestGeneration) return;

      setState(() {
        _schedule = [];
        _loadingSchedule = false;
        _scheduleError = _cleanError(error);
      });
    }
  }

  Future<void> _loadDiscovery(int category) async {
    if (category < 1 || category >= _discoveryCategories.length) return;

    final requestId = ++_discoveryRequestGeneration;

    setState(() {
      _loadingDiscovery = true;
      _discoveryError = '';
    });

    try {
      late final List<AnimeItem> results;

      switch (category) {
        case 1:
          results = await _mal.getTopRatedAnime();
          break;
        case 2:
          results = await _mal.getCurrentlyAiringAnime();
          break;
        case 3:
          results = await _mal.getUpcomingAnime();
          break;
        case 4:
          results = await _mal.getSeasonalAnime();
          break;
        default:
          return;
      }

      if (!mounted ||
          requestId != _discoveryRequestGeneration ||
          _selectedDiscovery != category) {
        return;
      }

      setState(() {
        _discoveryResults = results;
        _loadingDiscovery = false;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _discoveryRequestGeneration ||
          _selectedDiscovery != category) {
        return;
      }

      setState(() {
        _discoveryError = _cleanError(error);
        _loadingDiscovery = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    ++_searchRequestGeneration;

    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = '';
        _loadingSearch = false;
      });
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 550), () {
      _searchAnime(value.trim());
    });
  }

  Future<void> _searchAnime(String query) async {
    final requestId = ++_searchRequestGeneration;

    setState(() {
      _loadingSearch = true;
      _searchError = '';
    });

    try {
      final results = await _mal.searchAnime(query);
      if (!mounted ||
          requestId != _searchRequestGeneration ||
          _searchController.text.trim() != query) {
        return;
      }

      setState(() {
        _searchResults = results;
        _loadingSearch = false;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _searchRequestGeneration ||
          _searchController.text.trim() != query) {
        return;
      }

      setState(() {
        _searchError = _cleanError(error);
        _loadingSearch = false;
      });
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _shareAnime(AnimeItem anime) async {
    final details = [
      anime.name,
      if (anime.genre.isNotEmpty) 'Genres: ${anime.genre}',
      if (anime.score.isNotEmpty) 'MAL score: ${anime.score}',
      if (anime.url.isNotEmpty) anime.url,
      'Shared from Anime Friends',
    ].join('\n');

    await SharePlus.instance.share(
      ShareParams(
        text: details,
        subject: 'Check out ${anime.name}',
      ),
    );
  }

  Future<void> _openDetails(AnimeItem anime) async {
    final appState = AppStateScope.of(context);
    AnimeItem details = anime;
    final malId = int.tryParse(anime.id);

    if (malId != null) {
      try {
        details = await _mal.getAnimeDetails(malId);
      } catch (_) {
        // Keep the available list information if details cannot load.
      }
    }

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnimePoster(anime: details, width: 112, height: 154),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 9),
                            _InfoChip(
                              icon: Icons.star_rounded,
                              label: details.score,
                              color: _orange,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              [
                                details.type,
                                if (details.episodes.isNotEmpty)
                                  '${details.episodes} episodes',
                                details.status,
                              ].where((e) => e.isNotEmpty).join(' • '),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            if (details.year.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(
                                [
                                  details.season,
                                  details.year,
                                ].where((e) => e.isNotEmpty).join(' '),
                                style: const TextStyle(
                                  color: _teal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  if (int.tryParse(details.id) != null) ...[
                    const SizedBox(height: 24),
                    AnimeReviewsSection(
                      key: ValueKey('reviews-${details.id}'),
                      animeId: int.parse(details.id),
                      isAuthenticated: appState.isAuthenticated,
                      currentUserId: appState.userId,
                    ),
                  ],

                  if (details.broadcastDay.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _InfoChip(
                      icon: Icons.calendar_month,
                      label: [
                        details.broadcastDay,
                        details.broadcastTime,
                      ].where((e) => e.isNotEmpty).join(' • '),
                      color: _teal,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _shareAnime(details),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share anime'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Anime information provided by MyAnimeList.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final watchlist = appState.watchlist;
    final searchActive = _searchController.text.trim().isNotEmpty;

    return Container(
      color: _background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _purple.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _purple,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANIME FRIENDS',
                      style: TextStyle(
                        color: _purple,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Anime Universe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 55),
            child: Text(
              'Find your next favourite story.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 23),

          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search anime titles...',
                hintStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _purple,
                  size: 22,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 19,
                        ),
                      ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(
                    color: _purple.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          if (!searchActive &&
              _selectedTab == 0 &&
              _selectedDiscovery == 0 &&
              _popular.isNotEmpty) ...[
            _featuredAnimeCard(
              _popular.first,
              onTap: () => _openDetails(_popular.first),
            ),
            const SizedBox(height: 25),
          ],

          if (searchActive) ...[
            _sectionTitle('Search results', _blue),
            const SizedBox(height: 13),
            if (_loadingSearch)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _purple),
                ),
              )
            else if (_searchError.isNotEmpty)
              _ErrorPanel(
                message: _searchError,
                onRetry: () => _searchAnime(_searchController.text.trim()),
              )
            else if (_searchResults.isEmpty)
              const _EmptyPanel(
                icon: Icons.search_off,
                title: 'No results yet',
                message: 'Try another title or spelling.',
              )
            else
              _AnimeGrid(
                items: _searchResults,
                watchlist: watchlist,
                onTap: _openDetails,
                onShare: _shareAnime,
                onBookmark: appState.toggleWatchlist,
              ),
          ] else ...[
            _tabSelector(),
            const SizedBox(height: 23),

            if (_selectedTab == 0) ...[
              _discoverySelector(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _sectionTitle(
                      _discoveryCategories[_selectedDiscovery],
                      _pink,
                    ),
                  ),
                  if (_selectedDiscovery == 0)
                    const Text(
                      'TRENDING',
                      style: TextStyle(
                        color: _pink,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_selectedDiscovery == 0 && _loadingPopular)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _purple),
                  ),
                )
              else if (_selectedDiscovery == 0 && _error.isNotEmpty)
                _ErrorPanel(
                  message: _error,
                  onRetry: _loadPopular,
                )
              else if (_selectedDiscovery != 0 && _loadingDiscovery)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _purple),
                  ),
                )
              else if (_selectedDiscovery != 0 &&
                  _discoveryError.isNotEmpty)
                _ErrorPanel(
                  message: _discoveryError,
                  onRetry: () => _loadDiscovery(_selectedDiscovery),
                )
              else if ((_selectedDiscovery == 0
                      ? _popular
                      : _discoveryResults).isEmpty)
                const _EmptyPanel(
                  icon: Icons.movie_filter_outlined,
                  title: 'No anime available',
                  message: 'No titles were returned for this category.',
                )
              else
                _AnimeGrid(
                  items: _selectedDiscovery == 0
                      ? _popular
                      : _discoveryResults,
                  watchlist: watchlist,
                  onTap: _openDetails,
                  onShare: _shareAnime,
                  onBookmark: appState.toggleWatchlist,
                ),
            ] else ...[
              _sectionTitle('Weekly airing calendar', _teal),
              const SizedBox(height: 7),
              const Text(
                'See what is airing throughout the week.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 17),
              _daySelector(),
              const SizedBox(height: 17),
              if (_loadingSchedule)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _teal),
                  ),
                )
              else if (_scheduleError.isNotEmpty)
                _ErrorPanel(
                  message: _scheduleError,
                  onRetry: () => _loadSchedule(_selectedDay),
                )
              else if (_schedule.isEmpty)
                const _EmptyPanel(
                  icon: Icons.event_busy,
                  title: 'No upcoming episodes',
                  message: 'No episodes are scheduled for this weekday in the next 14 days.',
                )
              else
                ..._schedule.map(
                  (anime) => _AnimeTile(
                    anime: anime,
                    saved: watchlist.contains(anime.name),
                    onTap: () => _openDetails(anime),
                    onShare: () => _shareAnime(anime),
                    onBookmark: () => appState.toggleWatchlist(anime),
                    showBroadcast: true,
                  ),
                ),
            ],
          ],

          if (!searchActive && _selectedTab == 0) ...[
          const SizedBox(height: 27),
          Row(
            children: [
              Expanded(child: _sectionTitle('My watchlist', _orange)),
              Text(
                '${watchlist.length} SAVED',
                style: const TextStyle(
                  color: _orange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (watchlist.isEmpty)
            const _EmptyPanel(
              icon: Icons.bookmark_outline,
              title: 'Your watchlist is empty',
              message: 'Save anime using the bookmark icon.',
            )
          else
            ...watchlist.map(
              (name) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.bookmark_added_rounded,
                        color: _orange,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Saved to your watchlist',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove from watchlist',
                      onPressed: () => appState.removeFromWatchlist(name),
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _featuredAnimeCard(
    AnimeItem anime, {
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: Material(
        color: _surface,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 238,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (anime.coverUrl.isNotEmpty)
                  Image.network(
                    anime.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: _surface),
                  )
                else
                  const ColoredBox(color: _surface),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x2208060D),
                        Color(0x6608060D),
                        Color(0xF508060D),
                      ],
                      stops: [0.0, 0.38, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _purple,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      '✦  FEATURED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 17,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR NEXT OBSESSION STARTS HERE',
                        style: TextStyle(
                          color: Color(0xFFFFA7D0),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.25,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        anime.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          if (anime.score.isNotEmpty)
                            _InfoChip(
                              icon: Icons.star_rounded,
                              label: anime.score,
                              color: _orange,
                            ),
                          if (anime.type.isNotEmpty)
                            _InfoChip(
                              icon: Icons.movie_outlined,
                              label: anime.type.toUpperCase(),
                              color: _blue,
                            ),
                          if (anime.year.isNotEmpty)
                            _InfoChip(
                              icon: Icons.calendar_today,
                              label: anime.year,
                              color: _teal,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Discover',
              icon: Icons.explore_rounded,
              selected: _selectedTab == 0,
              color: _purple,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _TabButton(
              label: 'Airing calendar',
              icon: Icons.calendar_month_rounded,
              selected: _selectedTab == 1,
              color: _teal,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _discoverySelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _discoveryCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _selectedDiscovery == index;
          return ChoiceChip(
            label: Text(_discoveryCategories[index]),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedDiscovery = index);
              if (index != 0) _loadDiscovery(index);
            },
            selectedColor: _purple,
            backgroundColor: _surface,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 7,
            ),
            side: BorderSide(
              color: selected ? _purple : Colors.white12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          );
        },
      ),
    );
  }

  Widget _daySelector() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = _days[index];
          final selected = day == _selectedDay;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() => _selectedDay = day);
              _loadSchedule(day);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              decoration: BoxDecoration(
                color: selected
                    ? _teal.withValues(alpha: 0.17)
                    : _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _teal : Colors.white12,
                  width: selected ? 1.3 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                day.substring(0, 3),
                style: TextStyle(
                  color: selected ? _teal : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 21,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}


class _AnimeGrid extends StatelessWidget {
  const _AnimeGrid({
    required this.items,
    required this.watchlist,
    required this.onTap,
    required this.onShare,
    required this.onBookmark,
  });

  final List<AnimeItem> items;
  final Set<String> watchlist;
  final ValueChanged<AnimeItem> onTap;
  final ValueChanged<AnimeItem> onShare;
  final ValueChanged<AnimeItem> onBookmark;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 13,
        mainAxisSpacing: 16,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) {
        final anime = items[index];

        return _AnimeGridCard(
          anime: anime,
          saved: watchlist.contains(anime.name),
          onTap: () => onTap(anime),
          onShare: () => onShare(anime),
          onBookmark: () => onBookmark(anime),
        );
      },
    );
  }
}

class _AnimeGridCard extends StatelessWidget {
  const _AnimeGridCard({
    required this.anime,
    required this.saved,
    required this.onTap,
    required this.onShare,
    required this.onBookmark,
  });

  final AnimeItem anime;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
            ),
            borderRadius: BorderRadius.circular(19),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (anime.coverUrl.isNotEmpty)
                      Image.network(
                        anime.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFF292033),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 32,
                          ),
                        ),
                      )
                    else
                      const ColoredBox(
                        color: Color(0xFF292033),
                        child: Icon(
                          Icons.movie_outlined,
                          color: Colors.white38,
                          size: 32,
                        ),
                      ),

                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x22000000),
                            Colors.transparent,
                            Color(0x33000000),
                          ],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),

                    if (anime.score.isNotEmpty)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xE6100D17),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _orange.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: _orange,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                anime.score,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    Positioned(
                      top: 7,
                      right: 7,
                      child: Material(
                        color: const Color(0xD9100D17),
                        shape: const CircleBorder(),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 38,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: saved
                              ? 'Remove from watchlist'
                              : 'Add to watchlist',
                          onPressed: onBookmark,
                          icon: Icon(
                            saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: saved ? _pink : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 7, 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            anime.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            [
                              anime.type,
                              anime.year,
                            ].where((value) => value.isNotEmpty).join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Share anime',
                      onPressed: onShare,
                      icon: const Icon(
                        Icons.share_outlined,
                        color: _blue,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimeTile extends StatelessWidget {
  const _AnimeTile({
    required this.anime,
    required this.saved,
    required this.onTap,
    required this.onShare,
    required this.onBookmark,
    this.showBroadcast = false,
  });

  final AnimeItem anime;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onBookmark;
  final bool showBroadcast;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _AnimePoster(
                    anime: anime,
                    width: 76,
                    height: 102,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showBroadcast && anime.broadcastTime.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                color: _teal,
                                size: 12,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  anime.broadcastTime,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _teal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        anime.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (anime.genre.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          anime.genre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (anime.score.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InfoChip(
                          icon: Icons.star_rounded,
                          label: anime.score,
                          color: _orange,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Share anime',
                      onPressed: onShare,
                      icon: const Icon(
                        Icons.share_outlined,
                        color: _blue,
                        size: 19,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: saved ? 'Remove from watchlist' : 'Add to watchlist',
                      onPressed: onBookmark,
                      icon: Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: saved ? _pink : Colors.white70,
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimePoster extends StatelessWidget {
  const _AnimePoster({
    required this.anime,
    required this.width,
    required this.height,
  });

  final AnimeItem anime;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF292033),
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: anime.coverUrl.isEmpty
          ? const Icon(Icons.movie_outlined, color: Colors.white54, size: 30)
          : Image.network(
              anime.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? color : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: selected ? color : Colors.white60),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: _purple, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: _orange.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: _orange,
              size: 22,
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            'Something went wrong',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: _purple,
              backgroundColor: _purple.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 9,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text(
              'Try again',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
