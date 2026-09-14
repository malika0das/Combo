import '../../services/search_engine.dart'
    show SearchEngine, SearchResult;

/// Domain use case: search the catalog (Logic layer).
///
/// Wraps the typo-tolerant [SearchEngine] index so ViewModels never touch
/// search internals. The [SearchEngine] instance comes from the repository
/// (single source of truth); this class only adds the brand-filter rule
/// reused by search + compare flows.
class SearchCatalogUseCase {
  const SearchCatalogUseCase();

  SearchResult run(
    SearchEngine? engine,
    String query, {
    String? categoryId,
    String? brand,
  }) {
    const empty = SearchResult(
      hits: [],
      suggestions: [],
      scopedCategoryId: null,
      fuzzy: false,
    );
    if (engine == null) return empty;
    final result = engine.search(query, categoryId: categoryId);
    if (brand == null) return result;
    final filtered = result.hits.where((h) => h.brand.name == brand).toList();
    return SearchResult(
      hits: filtered,
      suggestions: result.suggestions,
      scopedCategoryId: result.scopedCategoryId,
      fuzzy: result.fuzzy,
    );
  }

  List<String> completions(SearchEngine? engine, String query,
          {int limit = 6}) =>
      engine?.complete(query, limit: limit) ?? const [];

  List<String> brandsIn(SearchResult result) {
    final names = <String>{for (final h in result.hits) h.brand.name}.toList()
      ..sort();
    return names;
  }
}
