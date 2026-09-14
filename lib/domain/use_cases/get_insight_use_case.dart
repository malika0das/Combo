import '../../models/catalog.dart' show Catalog;
import '../../services/insight_service.dart';
import '../../services/prefs_service.dart';
import '../../services/search_engine.dart';

export '../../services/insight_service.dart' show Insight, InsightTone;

/// Domain use case: single proactive home insight (Logic layer).
///
/// Thin wrapper over [InsightService] so ViewModels depend on the domain
/// layer instead of services directly. Takes plain snapshots so it stays
/// unit-testable without widgets or SharedPreferences.
class GetInsightUseCase {
  const GetInsightUseCase({InsightService? service})
      : _service = service ?? const InsightService();

  final InsightService _service;

  Insight? call({
    required List<String> recent,
    required List<String> saved,
    required List<String> stock,
    required bool Function(String id) isDismissed,
    required Catalog? catalog,
    required SearchEngine? engine,
    DateTime? now,
  }) {
    final prefs = _SnapshotPrefs(
      snapshotRecent: recent,
      snapshotSaved: saved,
      snapshotStock: stock,
      snapshotIsDismissed: isDismissed,
    );
    final insight = _service.build(
      prefs: prefs,
      catalog: catalog,
      engine: engine,
      now: now,
    );
    if (insight == null) return null;
    if (isDismissed(insight.id)) return null;
    return insight;
  }
}

/// Minimal PrefsService-compatible facade backed by snapshots.
class _SnapshotPrefs extends PrefsService {
  _SnapshotPrefs({
    required this.snapshotRecent,
    required this.snapshotSaved,
    required this.snapshotStock,
    required this.snapshotIsDismissed,
  });

  final List<String> snapshotRecent;
  final List<String> snapshotSaved;
  final List<String> snapshotStock;
  final bool Function(String id) snapshotIsDismissed;

  @override
  List<String> get recent => snapshotRecent;

  @override
  List<String> get saved => snapshotSaved;

  @override
  List<String> get stock => snapshotStock;

  @override
  bool isInsightDismissed(String id) => snapshotIsDismissed(id);
}
