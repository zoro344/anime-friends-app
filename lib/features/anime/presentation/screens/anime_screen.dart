import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/af_text_field.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../news/presentation/screens/news_screen.dart';

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  final TextEditingController searchController =
      TextEditingController();

  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    final filtered = appState.anime;
    final watchlist = appState.watchlist;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AFTextField(
          controller: searchController,
          hintText: 'Search anime...',
          prefixIcon: Icons.search,
          onChanged: (value) {
            setState(() => query = value);
            appState.searchAnime(value);
          },
        ),

        const SizedBox(height: 12),

        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewsScreen()),
            ),
            icon: const Icon(Icons.newspaper_outlined),
            label: const Text('Anime News'),
          ),
        ),

        const SizedBox(height: 16),

        const SectionTitle(title: 'Discover'),

        const SizedBox(height: 12),

        AFCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR NEXT ANIME STARTS HERE',
                style: AppTypography.label,
              ),
              const SizedBox(height: 9),
              const Text(
                'Find your next favourite story.',
                style: AppTypography.headingMedium,
              ),
              const SizedBox(height: 7),
              const Text(
                'Explore anime and build your personal library.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(
                    Icons.bookmarks_outlined,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${watchlist.length} anime saved',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        const SectionTitle(title: 'Search Results'),

        const SizedBox(height: 12),

        if (appState.animeError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              appState.animeError,
              style: const TextStyle(color: AppColors.error),
            ),
          ),

        if (filtered.isEmpty)
          EmptyView(
            title: query.trim().isEmpty ? 'Search for anime' : 'No anime found',
            message: query.trim().isEmpty
                ? 'Search the AniList catalogue to discover anime.'
                : 'Try another anime title.',
            icon: Icons.search_off,
          ),

        ...filtered.map((item) {
          final saved = watchlist.contains(item.name);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AFCard(
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: item.coverUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.network(
                              item.coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.movie_outlined,
                                size: 30,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.movie_outlined,
                            size: 30,
                            color: AppColors.textPrimary,
                          ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.genre,
                          style: AppTypography.bodySmall,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          saved ? 'IN YOUR WATCHLIST' : 'DISCOVER',
                          style: AppTypography.label.copyWith(
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    tooltip: saved
                        ? 'Remove from watchlist'
                        : 'Add to watchlist',
                    onPressed: () {
                      appState.toggleWatchlist(item);
                    },
                    icon: Icon(
                      saved
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 18),

        const SectionTitle(title: 'My Watchlist'),

        const SizedBox(height: 12),

        if (watchlist.isEmpty)
          const EmptyView(
            title: 'Your watchlist is empty',
            message: 'Save anime from the collection to see them here.',
            icon: Icons.bookmark_border,
          )
        else
          AFCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...watchlist.map((name) {
                  return ListTile(
                    leading: const Icon(
                      Icons.bookmark,
                      color: AppColors.textPrimary,
                    ),
                    title: Text(name),
                    trailing: IconButton(
                      tooltip: 'Remove from watchlist',
                      onPressed: () {
                        appState.removeFromWatchlist(name);
                      },
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

        const SizedBox(height: 30),
      ],
    );
  }
}
