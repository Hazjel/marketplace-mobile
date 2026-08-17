import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/review/viewmodels/review_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

class ReviewFormScreen extends ConsumerStatefulWidget {
  final String transactionId;
  final String productId;
  final String productName;
  final String? productThumbnail;

  const ReviewFormScreen({
    super.key,
    required this.transactionId,
    required this.productId,
    required this.productName,
    this.productThumbnail,
  });

  @override
  ConsumerState<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends ConsumerState<ReviewFormScreen> {
  late final _reviewController = TextEditingController();

  ReviewTarget get _target =>
      ReviewTarget(transactionId: widget.transactionId, productId: widget.productId);

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(reviewFormProvider(_target).notifier);
    final ok = await notifier.submit();
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      final error = ref.read(reviewFormProvider(_target)).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Gagal mengirim ulasan'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewFormProvider(_target));
    final notifier = ref.read(reviewFormProvider(_target).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return AppScaffold(
      title: 'Beri Ulasan',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.titleSm,
            ),
            const SizedBox(height: AppTheme.spacingXL),

            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  final filled = starValue <= state.rating;
                  return IconButton(
                    iconSize: 40,
                    onPressed: () => notifier.setRating(starValue),
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled ? AppTheme.warning : muted,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),

            TextField(
              controller: _reviewController,
              maxLines: 4,
              maxLength: 1000,
              onChanged: notifier.setReview,
              decoration: const InputDecoration(
                hintText: 'Ceritakan pengalamanmu dengan produk ini (opsional)',
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),

            CheckboxListTile(
              value: state.isAnonymous,
              onChanged: (v) => notifier.setAnonymous(v ?? false),
              title: Text('Kirim sebagai anonim', style: AppTheme.bodySm),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: AppTheme.spacingLG),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: state.isSubmitting ? null : _submit,
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Kirim Ulasan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
