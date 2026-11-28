import 'package:flutter/material.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/state/app_state_scope.dart';

const _purple = Color(0xFF9B6DFF);
const _surface = Color(0xFF171220);

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _animeStatuses = [
    'watching',
    'completed',
    'on_hold',
    'dropped',
    'plan_to_watch',
  ];

  static const _mangaStatuses = [
    'reading',
    'completed',
    'on_hold',
    'dropped',
    'plan_to_read',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _prettyStatus(String status) {
    return status
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  Future<void> _editAnime(
    AppState state,
    Map<String, dynamic> entry,
  ) async {
    final id = '${entry['anime_id'] ?? ''}';
    if (id.isEmpty) return;

    var status = '${entry['status'] ?? 'plan_to_watch'}';
    final episodes = TextEditingController(
      text: '${entry['episodes_watched'] ?? 0}',
    );
    final totalValue = entry['total_episodes'];
    final total = TextEditingController(
      text: totalValue == null ? '' : '$totalValue',
    );
    final ratingValue = entry['personal_rating'];
    final rating = TextEditingController(
      text: ratingValue == null ? '' : '$ratingValue',
    );
    final rewatchCount = TextEditingController(
      text: '${entry['rewatch_count'] ?? 0}',
    );
    final priority = TextEditingController(
      text: '${entry['priority'] ?? 2}',
    );
    final notes = TextEditingController(
      text: '${entry['notes'] ?? ''}',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          backgroundColor: _surface,
          title: Text(
            '${entry['anime_title'] ?? 'Anime'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _animeStatuses.contains(status)
                      ? status
                      : 'plan_to_watch',
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _animeStatuses
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_prettyStatus(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) refresh(() => status = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: episodes,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Episodes watched'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: total,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total episodes (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rating,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Your rating (1–10, optional)',
                  ),
                ),
                const SizedBox(height: 12),
                _numberField(rewatchCount, 'Rewatch count'),
                _numberField(
                  priority,
                  'Priority (1 = low, 2 = normal, 3 = high)',
                ),
                TextField(
                  controller: notes,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final watched = int.tryParse(episodes.text.trim());
                final totalEpisodes = total.text.trim().isEmpty
                    ? null
                    : int.tryParse(total.text.trim());
                final personalRating = rating.text.trim().isEmpty
                    ? null
                    : int.tryParse(rating.text.trim());
                final rewatch = int.tryParse(rewatchCount.text.trim());
                final priorityValue = int.tryParse(priority.text.trim());
                final notesValue = notes.text.trim();

                if (watched == null ||
                    (total.text.trim().isNotEmpty &&
                        totalEpisodes == null) ||
                    (rating.text.trim().isNotEmpty &&
                        personalRating == null) ||
                    rewatch == null ||
                    rewatch < 0 ||
                    priorityValue == null ||
                    priorityValue < 1 ||
                    priorityValue > 3 ||
                    notesValue.length > 500) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter valid whole numbers.'),
                    ),
                  );
                  return;
                }

                await state.updateAnimeLibraryEntry(
                  animeId: id,
                  status: status,
                  episodesWatched: watched,
                  totalEpisodes: totalEpisodes,
                  personalRating: personalRating,
                  rewatchCount: rewatch,
                  priority: priorityValue,
                  notes: notesValue,
                );

                if (!mounted) return;

                if (state.animeError.isNotEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(state.animeError)),
                  );
                  return;
                }

                Navigator.pop(dialogContext);
                setState(() {});
                _showMessage('Anime entry updated.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    episodes.dispose();
    total.dispose();
    rating.dispose();
    rewatchCount.dispose();
    priority.dispose();
    notes.dispose();
  }

  Future<void> _editManga(
    AppState state,
    Map<String, dynamic> entry,
  ) async {
    final id = '${entry['manga_id'] ?? ''}';
    if (id.isEmpty) return;

    var status = '${entry['status'] ?? 'plan_to_read'}';
    final chapters = TextEditingController(
      text: '${entry['chapters_read'] ?? 0}',
    );
    final totalChapters = TextEditingController(
      text: entry['total_chapters'] == null
          ? ''
          : '${entry['total_chapters']}',
    );
    final volumes = TextEditingController(
      text: '${entry['volumes_read'] ?? 0}',
    );
    final totalVolumes = TextEditingController(
      text: entry['total_volumes'] == null
          ? ''
          : '${entry['total_volumes']}',
    );
    final rating = TextEditingController(
      text: entry['personal_rating'] == null
          ? ''
          : '${entry['personal_rating']}',
    );
    final rereadCount = TextEditingController(
      text: '${entry['reread_count'] ?? 0}',
    );
    final priority = TextEditingController(
      text: '${entry['priority'] ?? 2}',
    );
    final notes = TextEditingController(
      text: '${entry['notes'] ?? ''}',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          backgroundColor: _surface,
          title: Text(
            '${entry['manga_title'] ?? 'Manga'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _mangaStatuses.contains(status)
                      ? status
                      : 'plan_to_read',
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _mangaStatuses
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_prettyStatus(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) refresh(() => status = value);
                  },
                ),
                const SizedBox(height: 12),
                _numberField(chapters, 'Chapters read'),
                _numberField(totalChapters, 'Total chapters (optional)'),
                _numberField(volumes, 'Volumes read'),
                _numberField(totalVolumes, 'Total volumes (optional)'),
                _numberField(rating, 'Your rating (1–10, optional)'),
                const SizedBox(height: 12),
                _numberField(rereadCount, 'Reread count'),
                _numberField(
                  priority,
                  'Priority (1 = low, 2 = normal, 3 = high)',
                ),
                TextField(
                  controller: notes,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                int? parseOptional(TextEditingController controller) {
                  if (controller.text.trim().isEmpty) return null;
                  return int.tryParse(controller.text.trim());
                }

                final chapterCount = parseOptional(chapters);
                final chapterTotal = parseOptional(totalChapters);
                final volumeCount = parseOptional(volumes);
                final volumeTotal = parseOptional(totalVolumes);
                final personalRating = parseOptional(rating);
                final reread = int.tryParse(rereadCount.text.trim());
                final priorityValue = int.tryParse(priority.text.trim());
                final notesValue = notes.text.trim();

                if (chapterCount == null ||
                    volumeCount == null ||
                    (totalChapters.text.trim().isNotEmpty &&
                        chapterTotal == null) ||
                    (totalVolumes.text.trim().isNotEmpty &&
                        volumeTotal == null) ||
                    (rating.text.trim().isNotEmpty &&
                        personalRating == null) ||
                    reread == null ||
                    reread < 0 ||
                    priorityValue == null ||
                    priorityValue < 1 ||
                    priorityValue > 3 ||
                    notesValue.length > 500) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter valid whole numbers.'),
                    ),
                  );
                  return;
                }

                final success = await state.updateMangaLibraryEntry(
                  mangaId: id,
                  status: status,
                  chaptersRead: chapterCount,
                  totalChapters: chapterTotal,
                  volumesRead: volumeCount,
                  totalVolumes: volumeTotal,
                  personalRating: personalRating,
                  rereadCount: reread,
                  priority: priorityValue,
                  notes: notesValue,
                );

                if (!mounted) return;

                if (!success) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.mangaError.isEmpty
                            ? 'Could not update manga. Please try again.'
                            : state.mangaError,
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext);
                setState(() {});
                _showMessage('Manga entry updated.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    chapters.dispose();
    totalChapters.dispose();
    volumes.dispose();
    totalVolumes.dispose();
    rating.dispose();
    rereadCount.dispose();
    priority.dispose();
    notes.dispose();
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _removeAnime(
    AppState state,
    Map<String, dynamic> entry,
  ) async {
    final title = '${entry['anime_title'] ?? 'this anime'}';
    final confirmed = await _confirmRemoval(title);
    if (!confirmed || !mounted) return;

    await state.removeFromWatchlist(title);
    if (mounted) setState(() {});
    _showMessage(state.animeError.isEmpty
        ? 'Anime removed from your library.'
        : state.animeError);
  }

  Future<void> _removeManga(
    AppState state,
    Map<String, dynamic> entry,
  ) async {
    final title = '${entry['manga_title'] ?? 'this manga'}';
    final id = '${entry['manga_id'] ?? ''}';
    final confirmed = await _confirmRemoval(title);
    if (!confirmed || !mounted) return;

    final success = await state.removeMangaFromLibrary(id);
    if (mounted) setState(() {});
    _showMessage(success
        ? 'Manga removed from your library.'
        : state.mangaError);
  }

  Future<bool> _confirmRemoval(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: _surface,
            title: const Text('Remove from library?'),
            content: Text('Remove "$title" from your library?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _poster(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        width: 66,
        height: 92,
        color: _surface,
        child: const Icon(Icons.book_outlined, color: Colors.white38),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 66,
        height: 92,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 66,
          height: 92,
          color: _surface,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }

  Widget _empty(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.library_books_outlined,
              size: 48,
              color: _purple,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }


  Color _statusColor(String status) {
    switch (status) {
      case 'watching':
      case 'reading':
        return const Color(0xFF65D6A3);
      case 'completed':
        return const Color(0xFF9B6DFF);
      case 'on_hold':
        return const Color(0xFFFFC66D);
      case 'dropped':
        return const Color(0xFFFF7777);
      default:
        return const Color(0xFF83B8FF);
    }
  }

  Widget _libraryError(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.redAccent,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _libraryHeader(int animeCount, int mangaCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Library',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Keep track of your anime and manga journey.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _libraryCountCard(
                  icon: Icons.movie_outlined,
                  label: 'ANIME',
                  count: animeCount,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _libraryCountCard(
                  icon: Icons.menu_book_outlined,
                  label: 'MANGA',
                  count: mangaCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _libraryCountCard({
    required IconData icon,
    required String label,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: _purple, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animeList(AppState state) {
    final entries = state.animeLibraryEntries;
    final error = state.animeError;

    if (entries.isEmpty) {
      return Column(
        children: [
          if (error.isNotEmpty) _libraryError(error),
          Expanded(
            child: _empty(
              'Your anime library is empty',
              'Add anime from Discover Anime to track your watching progress.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (error.isNotEmpty) _libraryError(error),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 11),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final watched = _number(entry['episodes_watched']);
              final total = entry['total_episodes'] == null
                  ? null
                  : _number(entry['total_episodes']);
              final status = '${entry['status'] ?? 'plan_to_watch'}';

              final progressValue = total != null && total > 0
                  ? (watched / total).clamp(0.0, 1.0).toDouble()
                  : null;

              return _entryCard(
                title: '${entry['anime_title'] ?? 'Untitled anime'}',
                image: entry['cover_url']?.toString(),
                status: status,
                progress: total == null
                    ? '$watched episodes watched'
                    : '$watched / $total episodes',
                progressValue: progressValue,
                progressAction: 'Episode',
                progressEnabled: total == null || watched < total,
                onEdit: () => _editAnime(state, entry),
                onRemove: () => _removeAnime(state, entry),
                onProgress: () {
                  state.markNextEpisodeWatched(
                    '${entry['anime_id'] ?? ''}',
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _mangaList(AppState state) {
    final entries = state.mangaLibraryEntries;
    final error = state.mangaError;

    if (entries.isEmpty) {
      return Column(
        children: [
          if (error.isNotEmpty) _libraryError(error),
          Expanded(
            child: _empty(
              'Your manga library is empty',
              'Find manga in the Manga section and add it to your library.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (error.isNotEmpty) _libraryError(error),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 11),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final chapters = _number(entry['chapters_read']);
              final total = entry['total_chapters'] == null
                  ? null
                  : _number(entry['total_chapters']);
              final volumes = _number(entry['volumes_read']);
              final status = '${entry['status'] ?? 'plan_to_read'}';

              final progressValue = total != null && total > 0
                  ? (chapters / total).clamp(0.0, 1.0).toDouble()
                  : null;

              final progress = total == null
                  ? '$chapters chapters · $volumes volumes'
                  : '$chapters / $total chapters · $volumes volumes';

              return _entryCard(
                title: '${entry['manga_title'] ?? 'Untitled manga'}',
                image: entry['cover_url']?.toString(),
                status: status,
                progress: progress,
                progressValue: progressValue,
                progressAction: 'Chapter',
                progressEnabled: total == null || chapters < total,
                onEdit: () => _editManga(state, entry),
                onRemove: () => _removeManga(state, entry),
                onProgress: () {
                  state.markNextChapterRead(
                    '${entry['manga_id'] ?? ''}',
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _entryCard({
    required String title,
    required String? image,
    required String status,
    required String progress,
    required double? progressValue,
    required String progressAction,
    required bool progressEnabled,
    required VoidCallback onEdit,
    required VoidCallback onRemove,
    required VoidCallback onProgress,
  }) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: _poster(image),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _prettyStatus(status),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  progress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (progressValue != null) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 5,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 5),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: progressEnabled
                    ? 'Mark next $progressAction'
                    : 'Progress complete',
                onPressed: progressEnabled ? onProgress : null,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.add_circle,
                  color: progressEnabled ? _purple : Colors.white24,
                  size: 27,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Library actions',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'remove') onRemove();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit progress'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18),
                        SizedBox(width: 10),
                        Text('Remove'),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white70,
                  size: 21,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final animeCount = state.animeLibraryEntries.length;
        final mangaCount = state.mangaLibraryEntries.length;

        return Column(
          children: [
            _libraryHeader(animeCount, mangaCount),
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: _purple.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                tabs: [
                  Tab(text: 'Anime ($animeCount)'),
                  Tab(text: 'Manga ($mangaCount)'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _animeList(state),
                  _mangaList(state),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

}
