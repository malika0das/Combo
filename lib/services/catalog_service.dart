import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalog.dart';
import 'search_engine.dart';

/// Loads the catalog with a hybrid strategy:
/// 1. bundled asset (instant, always works offline)
/// 2. cached remote copy (if previously downloaded and newer)
/// 3. background remote refresh (silently upgrades the cache)
///
/// Remote updates are strictly opt-in: the app never talks to a hardcoded
/// server. Provide one at build time with e.g.
///   flutter build appbundle --dart-define=CATALOG_URL=https://your-host/catalog.json
/// Without it the bundled + cached data is used and nothing leaves the device.
class CatalogService extends ChangeNotifier {
  CatalogService({http.Client? client}) : _client = client ?? http.Client();

  /// Point this at a JSON file you host (same schema as assets/data/catalog.json).
  /// No default: an unset URL means the app is fully offline and makes zero
  /// network requests for data.
  static const String remoteUrl = String.fromEnvironment('CATALOG_URL');

  static const _cacheKey = 'catalog_cache_v1';

  final http.Client _client;

  Catalog? _catalog;
  SearchEngine? _engine;
  bool _loading = true;
  bool _refreshing = false;
  bool _disposed = false;
  String? _error;
  String _source = 'bundled';

  Catalog? get catalog => _catalog;

  /// Typo-tolerant search index. Built lazily on first use and cached: doing it
  /// eagerly in [init] added ~5,700 index insertions to the very first frame.
  SearchEngine? get engine {
    final catalog = _catalog;
    if (catalog == null) return null;
    return _engine ??= SearchEngine(catalog);
  }
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  String get source => _source;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      final bundled = await _loadBundled();
      final cached = await _loadCached();
      _catalog = (cached != null && cached.version > bundled.version) ? cached : bundled;
      _source = identical(_catalog, cached) ? 'cached update' : 'bundled';
      _engine = null; // built lazily on first access, off the critical path
      _error = null;
    } catch (e) {
      _error = 'Could not load list data.';
    }
    _loading = false;
    notifyListeners();
    // Only hit the network when a remote endpoint was configured at build
    // time; a fresh install of a URL-free build stays 100% offline.
    if (remoteUrl.isNotEmpty) unawaited(refreshFromRemote());
  }

  Future<Catalog> _loadBundled() async {
    final raw = await rootBundle.loadString('assets/data/catalog.json');
    return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<Catalog?> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Downloads a newer catalog if one is published. Failures are non-fatal:
  /// the app keeps working with bundled/cached data.
  Future<bool> refreshFromRemote({bool userInitiated = false}) async {
    if (remoteUrl.isEmpty) return false; // no endpoint configured: stay offline
    if (_disposed || _refreshing) return false;
    _refreshing = true;
    if (userInitiated) notifyListeners();
    var updated = false;
    try {
      final res = await _client
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final remote = Catalog.fromJson(
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
        if (_catalog == null || remote.version > _catalog!.version) {
          _catalog = remote;
          _engine = null; // invalidate; rebuilt lazily against the new catalog
          _source = 'online update';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, utf8.decode(res.bodyBytes));
          updated = true;
        }
      }
    } catch (_) {
      // Offline, or the endpoint is not published yet. Ignore and keep the seed.
    }
    _refreshing = false;
    if (!_disposed) notifyListeners();
    return updated;
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
