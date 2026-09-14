import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../models/catalog.dart';

/// Stateless raw-data service (Data layer).
///
/// Owns ONLY external I/O: bundled asset read + remote HTTP fetch.
/// No ChangeNotifier, no caching policy, no UI state. Returns raw strings
/// and parsed Domain Models; caching policy lives in the repository.
class CatalogApiService {
  CatalogApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String remoteUrl = String.fromEnvironment('CATALOG_URL');

  final http.Client _client;

  Future<Catalog> loadBundled() async {
    final raw = await rootBundle.loadString('assets/data/catalog.json');
    return parseRaw(raw);
  }

  Catalog parseRaw(String raw) {
    return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Returns the raw body on HTTP 200, else null. Never throws.
  Future<String?> fetchRemoteRaw() async {
    if (remoteUrl.isEmpty) return null;
    try {
      final res = await _client
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) return utf8.decode(res.bodyBytes);
      return null;
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close();
}
