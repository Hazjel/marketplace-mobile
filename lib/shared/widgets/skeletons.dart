import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:blukios_marketplace/config/app_theme.dart';

/// Shimmer wrapper — owns the light/dark base colors so the three
/// skeleton shapes below stay consistent.
class _Shimmer extends StatelessWidget {
  final Widget child;

  const _Shimmer({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? AppTheme.darkMuted : AppTheme.border,
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF9FAFB),
      child: child,
    );
  }
}

/// A solid block used as a placeholder. Color is irrelevant — the
/// shimmer gradient paints over it.
class _Block extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _Block({this.width, required this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton for 2-column product grids (home, search, wishlist).
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final EdgeInsets padding;

  const ProductGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.padding = const EdgeInsets.all(AppTheme.spacingMD),
  });

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: GridView.builder(
        padding: padding,
        // shrinkWrap + non-scrolling: these skeletons are placed inside
        // already-scrolling parents (SliverToBoxAdapter on Home), where
        // an unbounded-height GridView would fail layout.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius2XL),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radius2XL),
                    ),
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Block(height: 11),
                      SizedBox(height: 6),
                      _Block(width: 80, height: 11),
                      Spacer(),
                      _Block(width: 100, height: 14),
                      SizedBox(height: 6),
                      _Block(width: 60, height: 9),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for vertical lists (cart, transactions, addresses).
///
/// The old `LoadingWidget` showed a product grid on these screens, which
/// matched nothing that then rendered.
class ListSkeleton extends StatelessWidget {
  final int itemCount;

  const ListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingMD),
        itemBuilder: (_, __) => const Row(
          children: [
            _Block(width: 56, height: 56, radius: AppTheme.radiusXLCard),
            SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Block(height: 12),
                  SizedBox(height: 8),
                  _Block(width: 140, height: 11),
                  SizedBox(height: 8),
                  _Block(width: 90, height: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a single detail page (product detail).
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(color: Colors.white),
            ),
            const Padding(
              padding: EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(width: 160, height: 24),
                  SizedBox(height: AppTheme.spacingMD),
                  _Block(height: 16),
                  SizedBox(height: 8),
                  _Block(width: 220, height: 16),
                  SizedBox(height: AppTheme.spacingXL),
                  _Block(width: 120, height: 13),
                  SizedBox(height: AppTheme.spacingMD),
                  _Block(height: 12),
                  SizedBox(height: 8),
                  _Block(height: 12),
                  SizedBox(height: 8),
                  _Block(width: 200, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
