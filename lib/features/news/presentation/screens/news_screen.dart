import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/empty_view.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _category = '';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      AppStateScope.of(context).loadNews();
    }
  }

  void _search(String value) {
    AppStateScope.of(context).loadNews(query: value, category: _category);
  }

  void _setCategory(String value) {
    setState(() => _category = value);
    AppStateScope.of(context).loadNews(
      query: _searchController.text,
      category: value,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Anime News')),
      body: RefreshIndicator(
        onRefresh: () => state.loadNews(
          query: _searchController.text,
          category: _category,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Search anime news...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _categoryChip('All', ''),
                _categoryChip('Announcements', 'announcements'),
                _categoryChip('Trailers', 'trailers'),
                _categoryChip('Release dates', 'release_date'),
              ],
            ),
            if (state.newsError.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                state.newsError,
                style: const TextStyle(color: AppColors.error),
              ),
              TextButton(
                onPressed: () => state.loadNews(
                  query: _searchController.text,
                  category: _category,
                ),
                child: const Text('Retry'),
              ),
            ],
            const SizedBox(height: 14),
            if (state.newsItems.isEmpty)
              const EmptyView(
                title: 'No news available',
                message: 'Check your internet connection or try again later.',
                icon: Icons.newspaper_outlined,
              ),
            ...state.newsItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AFCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NewsDetailScreen(article: item),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ('${item['imageUrl'] ?? ''}'.startsWith('https://'))
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              '${item['imageUrl']}',
                              height: 170,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          '${item['title'] ?? 'Anime news'}',
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item['source'] ?? ''}',
                          style: AppTypography.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item['summary'] ?? ''}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.arrow_forward,
                            color: AppColors.iconMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _category == value,
      onSelected: (_) => _setCategory(value),
    );
  }
}
