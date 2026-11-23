import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/widgets/af_card.dart';
import 'article_webview_screen.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.article});

  final Map<String, dynamic> article;

  bool _isSecureUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final title = '${article['title'] ?? 'Anime news'}';
    final description =
        '${article['description'] ?? article['summary'] ?? ''}';
    final url = '${article['url'] ?? ''}';
    final source = '${article['source'] ?? ''}';
    final image = '${article['imageUrl'] ?? ''}';

    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (image.startsWith('https://'))
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            source,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          AFCard(
            child: Text(
              description.isEmpty
                  ? '${article['summary'] ?? 'No article summary is available.'}'
                  : description,
              style: AppTypography.bodyMedium.copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSecureUrl(url)
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ArticleWebViewScreen(
                          title: title,
                          url: url,
                        ),
                      ),
                    )
                : null,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Read full article in Anime Friends'),
          ),
        ],
      ),
    );
  }
}
