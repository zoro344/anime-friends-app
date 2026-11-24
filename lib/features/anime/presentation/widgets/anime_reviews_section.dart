import 'package:flutter/material.dart';

import '../../data/anime_review_service.dart';

const _reviewPurple = Color(0xFF9B6DFF);
const _reviewOrange = Color(0xFFFFB45E);
const _reviewSurface = Color(0xFF211A2D);

class AnimeReviewsSection extends StatefulWidget {
  const AnimeReviewsSection({
    super.key,
    required this.animeId,
    required this.isAuthenticated,
    required this.currentUserId,
  });

  final int animeId;
  final bool isAuthenticated;
  final String currentUserId;

  @override
  State<AnimeReviewsSection> createState() =>
      _AnimeReviewsSectionState();
}

class _AnimeReviewsSectionState
    extends State<AnimeReviewsSection> {
  final AnimeReviewService _service = AnimeReviewService();

  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  bool _saving = false;
  String _error = '';

  Map<String, dynamic>? get _myReview {
    for (final review in _reviews) {
      if (review['user_id']?.toString() ==
          widget.currentUserId) {
        return review;
      }
    }
    return null;
  }

  double get _average {
    if (_reviews.isEmpty) return 0;

    final total = _reviews.fold<int>(
      0,
      (sum, review) =>
          sum + ((review['rating'] as num?)?.toInt() ?? 0),
    );

    return total / _reviews.length;
  }

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    if (widget.animeId <= 0) {
      setState(() {
        _loading = false;
        _error = 'Invalid anime ID.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final reviews = await _service.getReviews(widget.animeId);

      if (!mounted) return;

      setState(() {
        _reviews = reviews;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load community reviews. '
            'Please check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _openReviewEditor({
    Map<String, dynamic>? existing,
  }) async {
    if (!widget.isAuthenticated) return;

    final controller = TextEditingController(
      text: existing?['review_text']?.toString() ?? '',
    );

    int rating =
        (existing?['rating'] as num?)?.toInt() ?? 8;
    String? validationError;

    final draft = await showDialog<_ReviewDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _reviewSurface,
              title: Text(
                existing == null
                    ? 'Write your review'
                    : 'Edit your review',
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your rating',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: rating.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            activeColor: _reviewPurple,
                            label: '$rating/10',
                            onChanged: (value) {
                              setDialogState(() {
                                rating = value.round();
                              });
                            },
                          ),
                        ),
                        Text(
                          '$rating/10',
                          style: const TextStyle(
                            color: _reviewOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLength: 1500,
                      maxLines: 5,
                      minLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'What did you think of this anime?',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF15111C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: validationError,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _reviewPurple,
                  ),
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      setDialogState(() {
                        validationError =
                            'Please write your review.';
                      });
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      _ReviewDraft(
                        rating: rating,
                        text: controller.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Save review'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (draft == null || !mounted) return;

    await _saveReview(
      draft,
      existing: existing,
    );
  }

  Future<void> _saveReview(
    _ReviewDraft draft, {
    Map<String, dynamic>? existing,
  }) async {
    setState(() => _saving = true);

    try {
      if (existing == null) {
        await _service.addReview(
          animeId: widget.animeId,
          rating: draft.rating,
          reviewText: draft.text,
        );
      } else {
        await _service.updateReview(
          reviewId: existing['id'].toString(),
          userId: widget.currentUserId,
          rating: draft.rating,
          reviewText: draft.text,
        );
      }

      await _loadReviews();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your review. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteReview(
    Map<String, dynamic> review,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _reviewSurface,
        title: const Text(
          'Delete review?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete your review.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    try {
      await _service.deleteReview(
        reviewId: review['id'].toString(),
        userId: widget.currentUserId,
      );

      await _loadReviews();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete your review.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _authorName(Map<String, dynamic> review) {
    final profile = review['profiles'];

    if (profile is Map) {
      final displayName =
          profile['display_name']?.toString().trim() ?? '';
      final username =
          profile['username']?.toString().trim() ?? '';

      if (displayName.isNotEmpty) return displayName;
      if (username.isNotEmpty) return '@$username';
    }

    return 'Anime Friend';
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ownReview = _myReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Community reviews',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_reviews.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: _reviewOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _average.toStringAsFixed(1),
                    style: const TextStyle(
                      color: _reviewOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    ' (${_reviews.length})',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(
                color: _reviewPurple,
              ),
            ),
          )
        else if (_error.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _error,
                style: const TextStyle(color: Colors.white60),
              ),
              TextButton.icon(
                onPressed: _loadReviews,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          )
        else ...[
          if (widget.isAuthenticated)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _openReviewEditor(
                          existing: ownReview,
                        ),
                icon: Icon(
                  ownReview == null
                      ? Icons.rate_review_outlined
                      : Icons.edit_outlined,
                ),
                label: Text(
                  ownReview == null
                      ? 'Write a review'
                      : 'Edit your review',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _reviewPurple,
                  side: const BorderSide(
                    color: _reviewPurple,
                  ),
                ),
              ),
            )
          else
            const Text(
              'Sign in to rate and review this anime.',
              style: TextStyle(color: Colors.white54),
            ),

          if (_saving)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(
                color: _reviewPurple,
              ),
            ),

          if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No community reviews yet. Be the first to review!',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ..._reviews.map((review) {
              final isMine =
                  review['user_id']?.toString() ==
                      widget.currentUserId;

              final rating =
                  (review['rating'] as num?)?.toInt() ?? 0;

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _reviewSurface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isMine
                        ? _reviewPurple.withValues(alpha: 0.55)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _authorName(review),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          color: _reviewOrange,
                          size: 17,
                        ),
                        Text(
                          ' $rating/10',
                          style: const TextStyle(
                            color: _reviewOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _dateLabel(review['created_at']),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      review['review_text']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _openReviewEditor(
                                      existing: review,
                                    ),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                            ),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _deleteReview(review),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 16,
                            ),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }
}

class _ReviewDraft {
  const _ReviewDraft({
    required this.rating,
    required this.text,
  });

  final int rating;
  final String text;
}
