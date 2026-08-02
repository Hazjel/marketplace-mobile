import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/pagination/paged_notifier.dart';
import 'package:blukios_marketplace/features/search/models/search_filters.dart';
import 'package:blukios_marketplace/features/search/viewmodels/search_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/product_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialCategoryId;
  final String? initialCategoryName;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }

    _scrollController.addListener(_onScroll);

    // Trigger initial search after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialFilters = SearchFilters.empty.copyWith(
        search: widget.initialQuery,
        productCategoryId: widget.initialCategoryId,
      );
      ref.read(searchFilterProvider.notifier).updateFilters(initialFilters);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(searchResultsProvider.notifier).loadNextPage();
    }
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    final current = ref.read(searchFilterProvider);
    ref.read(searchFilterProvider.notifier).updateFilters(
      query.isEmpty
          ? current.copyWith(clearSearch: true)
          : current.copyWith(search: query),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterBottomSheet(ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchResultsProvider);
    final filters = ref.watch(searchFilterProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildSearchBar(),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: _showFilterSheet,
                tooltip: 'Filter',
              ),
              if (filters.hasActiveFilters)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildBody(searchState, filters),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(right: 4),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submitSearch(),
        decoration: InputDecoration(
          hintText: widget.initialCategoryName != null
              ? 'Cari di ${widget.initialCategoryName}...'
              : 'Cari produk...',
          hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _submitSearch();
                  },
                )
              : null,
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildBody(PagedState searchState, SearchFilters filters) {
    // Initial loading state
    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (searchState.error != null && searchState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48,
                  color: AppTheme.error.withValues(alpha: 0.7)),
              const SizedBox(height: 12),
              Text(searchState.error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.read(searchResultsProvider.notifier).loadFirstPage(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (searchState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_off_rounded, size: 40,
                    color: AppTheme.primary.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 16),
              const Text('Tidak ada produk ditemukan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Coba ubah kata kunci atau filter pencarian',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              if (filters.hasActiveFilters) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.read(searchFilterProvider.notifier).clearAll(),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: const Text('Hapus Filter'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Results grid
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Sort chips
        SliverToBoxAdapter(child: _buildSortBar(filters)),

        // Product grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.62,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = searchState.items[index];
                return ProductCard(
                  product: product,
                  onTap: () => context.push(AppRoutes.productDetailPath(product.slug)),
                );
              },
              childCount: searchState.items.length,
            ),
          ),
        ),

        // Loading more indicator
        if (searchState.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),

        // End of results
        if (!searchState.hasMore && searchState.items.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('Semua produk telah ditampilkan',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSortBar(SearchFilters filters) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _SortChip(
            label: 'Terbaru',
            selected: filters.sortBy == 'created_at' || filters.sortBy == null,
            onTap: () => ref.read(searchFilterProvider.notifier).updateFilters(
              filters.copyWith(sortBy: 'created_at', sortDirection: 'desc'),
            ),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Termurah',
            selected: filters.sortBy == 'price' && filters.sortDirection == 'asc',
            onTap: () => ref.read(searchFilterProvider.notifier).updateFilters(
              filters.copyWith(sortBy: 'price', sortDirection: 'asc'),
            ),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Termahal',
            selected: filters.sortBy == 'price' && filters.sortDirection == 'desc',
            onTap: () => ref.read(searchFilterProvider.notifier).updateFilters(
              filters.copyWith(sortBy: 'price', sortDirection: 'desc'),
            ),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Terlaris',
            selected: filters.sortBy == 'sold',
            onTap: () => ref.read(searchFilterProvider.notifier).updateFilters(
              filters.copyWith(sortBy: 'sold', sortDirection: 'desc'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// FILTER BOTTOM SHEET
// ─────────────────────────────────────────────────

class _FilterBottomSheet extends StatefulWidget {
  final WidgetRef ref;

  const _FilterBottomSheet({required this.ref});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late SearchFilters _draft;
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = widget.ref.read(searchFilterProvider);
    _minPriceController.text = _draft.minPrice?.toStringAsFixed(0) ?? '';
    _maxPriceController.text = _draft.maxPrice?.toStringAsFixed(0) ?? '';
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final minPrice = double.tryParse(_minPriceController.text);
    final maxPrice = double.tryParse(_maxPriceController.text);
    final updated = _draft.copyWith(
      minPrice: minPrice,
      maxPrice: maxPrice,
      clearMinPrice: minPrice == null,
      clearMaxPrice: maxPrice == null,
    );
    widget.ref.read(searchFilterProvider.notifier).updateFilters(updated);
    Navigator.of(context).pop();
  }

  void _resetFilters() {
    setState(() {
      _draft = SearchFilters.empty.copyWith(
        search: _draft.search,
      );
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Filter sections
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildPriceSection(),
                    const SizedBox(height: 24),
                    _buildConditionSection(),
                    const SizedBox(height: 24),
                    _buildRatingSection(),
                    const SizedBox(height: 24),
                    _buildTimeSection(),
                  ],
                ),
              ),

              // Apply button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _applyFilters,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Terapkan Filter',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Harga', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: 'Minimum',
                  hintStyle: const TextStyle(fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: TextField(
                controller: _maxPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: 'Maksimum',
                  hintStyle: const TextStyle(fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kondisi', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _FilterChip(
              label: 'Baru',
              selected: _draft.condition == 'New',
              onTap: () => setState(() {
                _draft = _draft.condition == 'New'
                    ? _draft.copyWith(clearCondition: true)
                    : _draft.copyWith(condition: 'New');
              }),
            ),
            _FilterChip(
              label: 'Bekas',
              selected: _draft.condition == 'Used',
              onTap: () => setState(() {
                _draft = _draft.condition == 'Used'
                    ? _draft.copyWith(clearCondition: true)
                    : _draft.copyWith(condition: 'Used');
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rating Minimum', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [4.0, 3.0].map((rating) {
            final selected = _draft.minRating == rating;
            return _FilterChip(
              label: '⭐ ${rating.toInt()}+',
              selected: selected,
              onTap: () => setState(() {
                _draft = selected
                    ? _draft.copyWith(clearMinRating: true)
                    : _draft.copyWith(minRating: rating);
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeSection() {
    final options = [
      (label: '7 Hari', value: 7),
      (label: '14 Hari', value: 14),
      (label: '1 Bulan', value: 30),
      (label: '3 Bulan', value: 90),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ditambahkan Sejak', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final selected = _draft.createdSince == opt.value;
            return _FilterChip(
              label: opt.label,
              selected: selected,
              onTap: () => setState(() {
                _draft = selected
                    ? _draft.copyWith(clearCreatedSince: true)
                    : _draft.copyWith(createdSince: opt.value);
              }),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
