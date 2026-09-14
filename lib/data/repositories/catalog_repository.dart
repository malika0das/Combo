import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/catalog.dart';
import '../../services/catalog_service.dart';
import '../../services/search_engine.dart';
import '../services/catalog_api_service.dart';
import '../services/prefs_storage_service.dart';

/// Single source of truth for catalog data (Data layer).
///
/// Consumes [CatalogApiService] (bundled asset + remote HTTP) and
/// [PrefsStorageService] (cached copy). Owns the bundled > cached > remote
/// version policy and the lazily-built typo-tolerant [SearchEngine] index.
/// New ViewModels observe this repository, never the services.
///
/// Migration note: the legacy CatalogService stays untouched and keeps
/// serving existing screens; this repository shares the same
/// SharedPreferences cache key so both stay consistent.
class CatalogRepository extends ChangeNotifier {
  CatalogRepository({
    required CatalogApiService api,
    required PrefsStorageService storage,
  })  : _api = api,
        _storage = storage,
        _service = null;

  /// Delegating constructor: mirrors the live legacy service so there is
  /// exactly one source of catalog truth during migration.
  CatalogRepository.fromService(
    CatalogService service, {
    required PrefsStorageService storage,
  })  : _service = service,
        _api = CatalogApiService(),
        _storage = storage {
    service.addListener(_forward);
  }

  final CatalogApiService _api;
  final PrefsStorageService _storage;
  final CatalogService? _service;

  void _forward() => notifyListeners();

  Catalog? _catalog;
  SearchEngine? _engine;
  bool _loading = true;
  bool _refreshing = false;
  bool _disposed = false;
  String? _error;
  String _source = 'bundled';

  Catalog? get catalog {
    final service = _service;
    return service != null ? service.catalog : _catalog;
  }

  /// Typo-tolerant search index, built lazily on first use.
  SearchEngine? get engine {
    final service = _service;
    if (service != null) return service.engine;
    final catalog = _catalog;
    if (catalog == null) return null;
    return _engine ??= SearchEngine(catalog);
  }

  bool get loading {
    final service = _service;
    return service != null ? service.loading : _loading;
  }

  bool get refreshing {
    final service = _service;
    return service != null ? service.refreshing : _refreshing;
  }

  String? get error {
    final service = _service;
    return service != null ? service.error : _error;
  }

  String get source {
    final service = _service;
    return service != null ? service.source : _source;
  }

  Future<void> init() async {
    final service = _service;
    if (service != null) return;
    _loading = true;
    notifyListeners();
    try {
      final bundled = await _api.loadBundled();
      final cached = _loadCached();
      _catalog = (cached != null && cached.version > bundled.version)
          ? cached
          : bundled;
      _source = identical(_catalog, cached) ? 'cached update' : 'bundled';
      _engine = null;
      _error = null;
    } catch (_) {
      _error = 'Could not load list data.';
    }
    _loading = false;
    if (!_disposed) notifyListeners();
    if (CatalogApiService.remoteUrl.isNotEmpty) {
      unawaited(refreshFromRemote());
    }
  }

  Catalog? _loadCached() {
    try {
      final raw = _storage.string(PrefsStorageService.catalogCacheKey);
      if (raw == null) return null;
      return _api.parseRaw(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> refreshFromRemote({bool userInitiated = false}) async {
    final service = _service;
    if (service != null) {
      return service.refreshFromRemote(userInitiated: userInitiated);
    }
    if (CatalogApiService.remoteUrl.isEmpty) return Future.value(false);
    if (_disposed || _refreshing) return Future.value(false);
    _refreshing = true;
    if (userInitiated) notifyListeners();
    var updated = false;
    try {
      final raw = await _api.fetchRemoteRaw();
      if (raw != null) {
        final remote = _api.parseRaw(raw);
        if (_catalog == null || remote.version > _catalog!.version) {
          _catalog = remote;
          _engine = null;
          _source = 'online update';
          await _storage.setString(PrefsStorageService.catalogCacheKey, raw);
          updated = true;
        }
      }
    } catch (_) {
      // Keep current data on any failure.
    }
    _refreshing = false;
    if (!_disposed) notifyListeners();
    return updated;
  }

  @override
  void dispose() {
    _service?.removeListener(_forward);
    _disposed = true;
    super.dispose();
  }
}
