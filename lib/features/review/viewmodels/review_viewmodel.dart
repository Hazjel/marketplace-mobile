import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/review/models/review_model.dart';

/// Identifies which order-line is being reviewed — a product can only be
/// reviewed once per transaction, so both ids are needed.
class ReviewTarget {
  final String transactionId;
  final String productId;

  const ReviewTarget({required this.transactionId, required this.productId});

  @override
  bool operator ==(Object other) =>
      other is ReviewTarget &&
      other.transactionId == transactionId &&
      other.productId == productId;

  @override
  int get hashCode => Object.hash(transactionId, productId);
}

class ReviewFormData {
  final int rating;
  final String review;
  final bool isAnonymous;
  final bool isSubmitting;
  final String? error;
  final ReviewModel? submitted;

  const ReviewFormData({
    this.rating = 5,
    this.review = '',
    this.isAnonymous = false,
    this.isSubmitting = false,
    this.error,
    this.submitted,
  });

  ReviewFormData copyWith({
    int? rating,
    String? review,
    bool? isAnonymous,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    ReviewModel? submitted,
  }) {
    return ReviewFormData(
      rating: rating ?? this.rating,
      review: review ?? this.review,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      submitted: submitted ?? this.submitted,
    );
  }
}

class ReviewFormNotifier
    extends AutoDisposeFamilyNotifier<ReviewFormData, ReviewTarget> {
  bool _disposed = false;

  @override
  ReviewFormData build(ReviewTarget arg) {
    ref.onDispose(() => _disposed = true);
    return const ReviewFormData();
  }

  void setRating(int rating) => state = state.copyWith(rating: rating);

  void setReview(String review) => state = state.copyWith(review: review);

  void setAnonymous(bool value) => state = state.copyWith(isAnonymous: value);

  Future<bool> submit() async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final result = await ref.read(reviewRepositoryProvider).submitReview(
            transactionId: arg.transactionId,
            productId: arg.productId,
            rating: state.rating,
            review: state.review.trim().isEmpty ? null : state.review.trim(),
            isAnonymous: state.isAnonymous,
          );
      if (_disposed) return false;
      state = state.copyWith(isSubmitting: false, submitted: result);
      return true;
    } catch (e) {
      if (_disposed) return false;
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}

final reviewFormProvider = AutoDisposeNotifierProviderFamily<ReviewFormNotifier,
    ReviewFormData, ReviewTarget>(
  ReviewFormNotifier.new,
);
