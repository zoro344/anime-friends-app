import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/models/manga_item.dart';
import '../../../../core/services/mal_manga_service.dart';
import '../../../../core/state/app_state_scope.dart';

const _purple = Color(0xFF9B6DFF);
const _blue = Color(0xFF579BFF);
const _orange = Color(0xFFFFB45E);
const _background = Color(0xFF08060D);
const _surface = Color(0xFF171220);

class MangaScreen extends StatefulWidget {
  const MangaScreen({super.key});

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen> {
  final MalMangaService _mal = MalMangaService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchTimer;
  List<MangaItem> _popular = [];
  List<MangaItem> _searchResults = [];

  bool _loadingPopular = true;
  bool _loadingSearch = false;
  String _error = '';
  String _searchError = '';

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _mal.dispose();
    super.dispose();
  }

  Future<void> _loadPopular() async {
    setState(() {
      _loadingPopular = true;
      _error = '';
    });

    try {
      final results = await _mal.getPopularManga();
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

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = '';
        _loadingSearch = false;
      });
      return;
    }

    _searchTimer = Timer(
      const Duration(milliseconds: 550),
      () => _searchManga(value.trim()),
    );
  }

  Future<void> _searchManga(String query) async {
    setState(() {
      _loadingSearch = true;
      _searchError = '';
    });

    try {
      final results = await _mal.searchManga(query);
      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _searchResults = results;
        _loadingSearch = false;
      });
    } catch (error) {
      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _searchError = _cleanError(error);
        _loadingSearch = false;
      });
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _addToLibrary(MangaItem manga) async {
    final state = AppStateScope.of(context);
    final success = await state.addMangaToLibrary(manga);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${manga.name} added to your manga library.'
              : state.mangaError,
        ),
      ),
    );

    setState(() {});
  }

  Future<void> _openDetails(MangaItem manga) async {
    MangaItem details = manga;
    final malId = int.tryParse(manga.id);

    if (malId != null) {
      try {
        details = await _mal.getMangaDetails(malId);
      } catch (_) {
        // Use the list information if details cannot be loaded.
      }
    }

    if (!mounted) return;

    final state = AppStateScope.of(context);
    final alreadySaved = state.mangaLibraryEntries.any(
      (entry) => '${entry['manga_id']}' == details.id,
    );

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
                      _MangaPoster(
                        manga: details,
                        width: 112,
                        height: 154,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 9),
                            _InfoChip(
                              icon: Icons.star_rounded,
                              label: details.score,
                              color: _orange,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                details.type,
                                '${details.chapters} chapters',
                                '${details.volumes} volumes',
                                details.status,
                              ].where((value) => value.isNotEmpty).join(' • '),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            if (details.year.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                details.year,
                                style: const TextStyle(
                                  color: _blue,
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
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: alreadySaved
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _addToLibrary(details);
                            },
                      icon: Icon(
                        alreadySaved
                            ? Icons.check
                            : Icons.bookmark_add_outlined,
                      ),
                      label: Text(
                        alreadySaved
                            ? 'Already in your library'
                            : 'Add to manga library',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Manga information provided by MyAnimeList.',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final searchActive = _searchController.text.trim().isNotEmpty;
    final savedIds = state.mangaLibraryEntries
        .map((entry) => '${entry['manga_id']}')
        .toSet();

    return Container(
      color: _background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const Text(
            'Manga Universe',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Discover your next favourite story.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search manga titles...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: _purple),
              suffixIcon: IconButton(
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                  setState(() {});
                },
                icon: const Icon(
                  Icons.close,
                  color: Colors.white54,
                ),
              ),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (searchActive) ...[
            _sectionTitle('Search results', _blue),
            const SizedBox(height: 12),
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
                onRetry: () => _searchManga(
                  _searchController.text.trim(),
                ),
              )
            else if (_searchResults.isEmpty)
              const _EmptyPanel(
                icon: Icons.search_off,
                title: 'No results yet',
                message: 'Try another title or spelling.',
              )
            else
              ..._searchResults.map(
                (manga) => _MangaTile(
                  manga: manga,
                  saved: savedIds.contains(manga.id),
                  onTap: () => _openDetails(manga),
                  onAdd: () => _addToLibrary(manga),
                ),
              ),
          ] else ...[
            _sectionTitle('Popular manga', const Color(0xFFFF70B8)),
            const SizedBox(height: 12),
            if (_loadingPopular)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _purple),
                ),
              )
            else if (_error.isNotEmpty)
              _ErrorPanel(
                message: _error,
                onRetry: _loadPopular,
              )
            else if (_popular.isEmpty)
              const _EmptyPanel(
                icon: Icons.menu_book_outlined,
                title: 'No manga available',
                message: 'MyAnimeList did not return any popular manga.',
              )
            else
              ..._popular.map(
                (manga) => _MangaTile(
                  manga: manga,
                  saved: savedIds.contains(manga.id),
                  onTap: () => _openDetails(manga),
                  onAdd: () => _addToLibrary(manga),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MangaTile extends StatelessWidget {
  const _MangaTile({
    required this.manga,
    required this.saved,
    required this.onTap,
    required this.onAdd,
  });

  final MangaItem manga;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _surface,
      margin: const EdgeInsets.only(bottom: 11),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _MangaPoster(
                manga: manga,
                width: 72,
                height: 94,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      manga.genre.isEmpty ? manga.type : manga.genre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _InfoChip(
                          icon: Icons.star_rounded,
                          label: manga.score,
                          color: _orange,
                        ),
                        if (manga.chapters != 'Unknown')
                          _InfoChip(
                            icon: Icons.menu_book_outlined,
                            label: '${manga.chapters} ch.',
                            color: _blue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: saved ? 'Already saved' : 'Add to library',
                onPressed: saved ? null : onAdd,
                icon: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_border,
                  color: saved ? _orange : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MangaPoster extends StatelessWidget {
  const _MangaPoster({
    required this.manga,
    required this.width,
    required this.height,
  });

  final MangaItem manga;
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
      child: manga.coverUrl.isEmpty
          ? const Icon(
              Icons.menu_book_outlined,
              color: Colors.white54,
              size: 30,
            )
          : Image.network(
              manga.coverUrl,
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
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: _purple, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
