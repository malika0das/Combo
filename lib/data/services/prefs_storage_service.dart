import 'package:shared_preferences/shared_preferences.dart';

/// Stateless local-storage wrapper (Data layer).
///
/// Pure persistence: no ChangeNotifier, no UI state, no business rules.
/// The repository owns in-memory state and calls here to persist.
class PrefsStorageService {
  PrefsStorageService({SharedPreferences? prefs}) : _prefs = prefs;

  static const String recentKey = 'recent_searches';
  static const String savedKey = 'saved_groups';
  static const String darkKey = 'dark_mode';
  static const String consentKey = 'ads_personalized';
  static const String listKey = 'stock_list';
  static const String qtyKey = 'stock_qty';
  static const String notesKey = 'group_notes';
  static const String fontKey = 'font_scale';
  static const String dismissedKey = 'dismissed_insights';
  static const String catalogCacheKey = 'catalog_cache_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  SharedPreferences get prefs {
    final p = _prefs;
    assert(p != null, 'PrefsStorageService.init() must be called first');
    return p!;
  }

  List<String> strings(String key) => prefs.getStringList(key) ?? const [];

  Future<bool> setStrings(String key, List<String> value) =>
      prefs.setStringList(key, value);

  String? string(String key) => prefs.getString(key);

  Future<bool> setString(String key, String value) =>
      prefs.setString(key, value);

  bool flag(String key) => prefs.getBool(key) ?? false;

  Future<bool> setFlag(String key, bool value) => prefs.setBool(key, value);

  double number(String key, double fallback) =>
      prefs.getDouble(key) ?? fallback;

  Future<bool> setNumber(String key, double value) =>
      prefs.setDouble(key, value);
}
