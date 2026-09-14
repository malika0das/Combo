import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, VoidCallback;

import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/prefs_repository.dart';
import '../../../../domain/use_cases/search_catalog_use_case.dart';
import '../../../../models/catalog.dart' show Category, SearchHit;
import '../../../../services/search_engine.dart' show SearchResult;

/// Search UI state (UI layer, MVVM ViewModel).
///
/// Owns debounce, category/brand filters, completions and the recent-write
/// side-effect. The View stays dumb: it renders this state through a
/// ListenableBuilder and forwards keystrokes here.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    required CatalogRepository catalog,
    required PrefsRepository prefs,
    SearchCatalogUseCase? search,
    this.onFirstHit,
  })  : _catalog = catalog,
        _prefs = prefs,
        _search = search ?? const SearchCatalogUseCase();

  final CatalogRepository _catalog;
  final PrefsRepository _prefs;
  final SearchCatalogUseCase _search;

  /// Fired on nothing -> found transitions (haptics live in the View).
  final VoidCallback? onFirstHit;

  Timer? _debounce;
  String _query = '';
  String? _categoryId;
  String? _brand;
  SearchResult _result = const SearchResult(
    hits: [],
    suggestions: [],
    scopedCategoryId: null,
    fuzzy: false,
  );
  List<String> _completions = const [];
  bool _searching = false;

  String get query => _query;
  String? get categoryId => _categoryId;
  String? get brand => _brand;
  SearchResult get result => _result;
  List<SearchHit> get hits => _result.hits;
  List<String> get completions => _completions;
  bool get searching => _searching;

  List<Category> get categories => _catalog.catalog?.categories ?? const [];

  List<String> get brandsInResults => _search.brandsIn(_result);

  List<SearchHit> get filteredHits => _brand == null
      ? _result.hits
      : _result.hits.where((h) => h.brand.name == _brand).toList();

  void init(String initialQuery) {
    if (initialQuery.isEmpty) return;
    _query = initialQuery;
    run(initialQuery);
  }

  void onChanged(String value) {
    _query = value;
    _completions = _search.completions(_catalog.engine, value, limit: 6);
    _searching = value.trim().isNotEmpty;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => run(value));
  }

  void setCategory(String? id) {
    _categoryId = id;
    run(_query);
  }

  void setBrand(String? name) {
    _brand = name;
    notifyListeners();
  }

  void clear() {
    _debounce?.cancel();
    _query = '';
    _brand = null;
    _result = const SearchResult(
      hits: [],
      suggestions: [],
      scopedCategoryId: null,
      fuzzy: false,
    );
    _completions = const [];
    _searching = false;
    notifyListeners();
  }

  void run(String value) {
    final hadHits = _result.hits.isNotEmpty;
    final result = _search.run(_catalog.engine, value, categoryId: _categoryId);
    _result = result;
    _searching = false;
    if (_brand != null &&
        !_result.hits.any((h) => h.brand.name == _brand)) {
      _brand = null;
    }
    notifyListeners();
    if (!hadHits && result.hits.isNotEmpty) onFirstHit?.call();
    if (value.trim().length >= 3 && result.hits.isNotEmpty) {
      unawaited(_prefs.addRecent(value.trim()));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
