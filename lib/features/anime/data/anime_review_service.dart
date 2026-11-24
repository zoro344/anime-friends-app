import '../../../core/services/supabase_service.dart';

class AnimeReviewService {
  Future<List<Map<String, dynamic>>> getReviews(int animeId) async {
    final rows = await SupabaseService.client
        .from('anime_reviews')
        .select(
          'id, anime_id, user_id, rating, review_text, created_at, '
          'updated_at, profiles!anime_reviews_user_id_fkey('
          'username, display_name, avatar_url)',
        )
        .eq('anime_id', animeId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> addReview({
    required int animeId,
    required int rating,
    required String reviewText,
  }) async {
    await SupabaseService.client.from('anime_reviews').insert({
      'anime_id': animeId,
      'rating': rating,
      'review_text': reviewText.trim(),
    });
  }

  Future<void> updateReview({
    required String reviewId,
    required String userId,
    required int rating,
    required String reviewText,
  }) async {
    await SupabaseService.client
        .from('anime_reviews')
        .update({
          'rating': rating,
          'review_text': reviewText.trim(),
        })
        .eq('id', reviewId)
        .eq('user_id', userId);
  }

  Future<void> deleteReview({
    required String reviewId,
    required String userId,
  }) async {
    await SupabaseService.client
        .from('anime_reviews')
        .delete()
        .eq('id', reviewId)
        .eq('user_id', userId);
  }
}
