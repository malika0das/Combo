import 'package:flutter/material.dart';

import '../data/repositories/catalog_repository.dart';
import '../data/repositories/prefs_repository.dart';
import '../data/services/prefs_storage_service.dart';
import '../services/catalog_service.dart';
import '../services/prefs_service.dart';
import '../ui/features/home/view_models/home_view_model.dart';
import '../ui/features/search/view_models/search_view_model.dart';

/// Dependency injection container (manual, no new packages).
///
/// Per Skill Step 7: Service -> Repository -> UseCase -> ViewModel.
/// Until AppScope gains repository fields (next migration commit), the
/// repositories are built once here and cached per process. ViewModels are
/// created per screen. Call [init] from main() before runApp.
///
/// NOTE: additive-only file — does not touch AppScope or any screen, so it
/// cannot conflict with in-flight work on other branches.
class Injection {
  Injection._();

  static CatalogRepository? _catalog;
  static PrefsRepository? _prefs;

  /// Build (or reuse) the app-scoped repositories. Pass the live legacy
  /// services so the repositories delegate to the single source of truth
  /// (zero divergence during migration).
  static Future<void> init({
    required CatalogService catalogService,
    required PrefsService prefsService,
  }) async {
    if (_catalog != null && _prefs != null) return;
    final storage = PrefsStorageService();
    await storage.init();
    _catalog = CatalogRepository.fromService(catalogService, storage: storage);
    _prefs = PrefsRepository.delegating(service: prefsService, storage: storage);
  }

  static CatalogRepository catalogOf(BuildContext context) {
    final catalog = _catalog;
    assert(catalog != null, 'Call Injection.init() in main() first');
    return catalog!;
  }

  static PrefsRepository prefsOf(BuildContext context) {
    final prefs = _prefs;
    assert(prefs != null, 'Call Injection.init() in main() first');
    return prefs!;
  }

  static SearchViewModel searchViewModelOf(
    BuildContext context, {
    String initialQuery = '',
    VoidCallback? onFirstHit,
  }) {
    final vm = SearchViewModel(
      catalog: catalogOf(context),
      prefs: prefsOf(context),
      onFirstHit: onFirstHit,
    );
    vm.init(initialQuery);
    return vm;
  }

  static HomeViewModel homeViewModelOf(BuildContext context) {
    return HomeViewModel(
      catalog: catalogOf(context),
      prefs: prefsOf(context),
    );
  }

  /// Test seam: build repositories without touching global state.
  static Future<({CatalogRepository catalog, PrefsRepository prefs})>
      createRepositories({
    required CatalogService catalogService,
    required PrefsService prefsService,
    required PrefsStorageService storage,
  }) async {
    final catalog = CatalogRepository.fromService(
      catalogService,
      storage: storage,
    );
    final prefs = PrefsRepository.delegating(
      service: prefsService,
      storage: storage,
    );
    return (catalog: catalog, prefs: prefs);
  }
}
