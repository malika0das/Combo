import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/prefs_repository.dart';
import '../../../../domain/use_cases/get_insight_use_case.dart';
import '../../../../models/catalog.dart' show Catalog;
import '../../../../services/search_engine.dart' show SearchEngine;

/// Home UI state (UI layer, MVVM ViewModel).
///
/// Aggregates catalog + prefs signals for the home View, which renders via
/// ListenableBuilder. Refresh + insight-dismissal commands live here.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required CatalogRepository catalog,
    required PrefsRepository prefs,
    GetInsightUseCase? insights,
  })  : _catalog = catalog,
        _prefs = prefs,
        _insights = insights ?? const GetInsightUseCase() {
    _catalog.addListener(_forward);
    _prefs.addListener(_forward);
  }

  final CatalogRepository _catalog;
  final PrefsRepository _prefs;
  final GetInsightUseCase _insights;

  Catalog? get catalog => _catalog.catalog;
  bool get loading => _catalog.loading;
  bool get refreshing => _catalog.refreshing;
  String? get error => _catalog.error;
  String get source => _catalog.source;
  SearchEngine? get engine => _catalog.engine;
  PrefsRepository get prefs => _prefs;

  Insight? insight({DateTime? now}) => _insights(
        recent: _prefs.recent,
        saved: _prefs.saved,
        stock: _prefs.stock,
        isDismissed: _prefs.isInsightDismissed,
        catalog: _catalog.catalog,
        engine: _catalog.engine,
        now: now,
      );

  Future<bool> refresh() => _catalog.refreshFromRemote(userInitiated: true);

  Future<void> retry() => _catalog.init();

  Future<void> dismissInsight(String id) => _prefs.dismissInsight(id);

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _catalog.removeListener(_forward);
    _prefs.removeListener(_forward);
    super.dispose();
  }
}
