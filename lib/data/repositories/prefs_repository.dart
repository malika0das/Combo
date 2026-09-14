import 'package:flutter/foundation.dart';

import '../../services/prefs_service.dart';
import '../services/prefs_storage_service.dart';

/// Single source of truth for local user state (Data layer).
///
/// Wraps the legacy [PrefsService] by delegation during migration, so there
/// is exactly one writer and zero divergence. New ViewModels observe this
/// repository; once all screens migrate, the delegate is removed and the
/// standalone branch below becomes the implementation.
class PrefsRepository extends ChangeNotifier {
  PrefsRepository({required PrefsStorageService storage})
      : _storage = storage,
        _service = null;

  PrefsRepository.delegating({
    required PrefsService service,
    required PrefsStorageService storage,
  })  : _service = service,
        _storage = storage {
    service.addListener(_forward);
  }

  @override
  void dispose() {
    _service?.removeListener(_forward);
    super.dispose();
  }

  final PrefsStorageService _storage;
  final PrefsService? _service;

  void _forward() => notifyListeners();

  static const int maxRecent = 12;

  List<String> _recent = const [];
  List<String> _saved = const [];
  bool _dark = false;
  bool _personalizedAds = false;
  List<String> _stock = const [];
  Map<String, String> _notes = const {};
  Map<String, int> _qty = const {};
  double _fontScale = 1.0;
  List<String> _dismissed = const [];

  List<String> get recent {
    final service = _service;
    return service != null ? service.recent : _recent;
  }
  List<String> get saved {
    final service = _service;
    return service != null ? service.saved : _saved;
  }
  bool get dark {
    final service = _service;
    return service != null ? service.dark : _dark;
  }
  bool get personalizedAds {
    final service = _service;
    return service != null ? service.personalizedAds : _personalizedAds;
  }
  List<String> get stock {
    final service = _service;
    return service != null ? service.stock : _stock;
  }
  double get fontScale {
    final service = _service;
    return service != null ? service.fontScale : _fontScale;
  }
  List<String> get dismissedInsights {
    final service = _service;
    return service != null ? service.dismissedInsights : _dismissed;
  }
  Map<String, String> get notes {
    final service = _service;
    return service != null ? service.notes : _notes;
  }
  Map<String, int> get qty {
    final service = _service;
    return service != null ? service.qty : _qty;
  }

  Future<void> init() async {
    await _storage.init();
    _recent = _storage.strings(PrefsStorageService.recentKey);
    _saved = _storage.strings(PrefsStorageService.savedKey);
    _dark = _storage.flag(PrefsStorageService.darkKey);
    _personalizedAds = _storage.flag(PrefsStorageService.consentKey);
    _stock = _storage.strings(PrefsStorageService.listKey);
    _notes = decodeNotes(_storage.strings(PrefsStorageService.notesKey));
    _qty = decodeQty(_storage.strings(PrefsStorageService.qtyKey));
    _fontScale = _storage.number(PrefsStorageService.fontKey, 1.0);
    _dismissed = _storage.strings(PrefsStorageService.dismissedKey);
    notifyListeners();
  }

  Future<void> addRecent(String query) async {
    final service = _service;
    if (service != null) return service.addRecent(query);
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ..._recent.where((e) => e.toLowerCase() != q.toLowerCase())];
    _recent = next.take(maxRecent).toList();
    await _storage.setStrings(PrefsStorageService.recentKey, _recent);
    notifyListeners();
  }

  Future<void> clearRecent() async {
    final service = _service;
    if (service != null) return service.clearRecent();
    _recent = const [];
    await _storage.setStrings(PrefsStorageService.recentKey, const []);
    notifyListeners();
  }

  bool isSaved(String code) {
    final service = _service;
    return service != null ? service.isSaved(code) : _saved.contains(code);
  }

  Future<void> toggleSaved(String code) async {
    final service = _service;
    if (service != null) return service.toggleSaved(code);
    _saved = _saved.contains(code)
        ? (_saved.where((e) => e != code).toList())
        : [..._saved, code];
    await _storage.setStrings(PrefsStorageService.savedKey, _saved);
    notifyListeners();
  }
  Future<void> setDark(bool value) async {
    final service = _service;
    if (service != null) return service.setDark(value);
    _dark = value;
    await _storage.setFlag(PrefsStorageService.darkKey, value);
    notifyListeners();
  }

  bool inStockList(String code) {
    final service = _service;
    return service != null ? service.inStockList(code) : _stock.contains(code);
  }

  Future<void> toggleStock(String code) async {
    final service = _service;
    if (service != null) return service.toggleStock(code);
    _stock = _stock.contains(code)
        ? _stock.where((e) => e != code).toList()
        : [..._stock, code];
    await _storage.setStrings(PrefsStorageService.listKey, _stock);
    notifyListeners();
  }

  Future<void> clearStock() async {
    final service = _service;
    if (service != null) return service.clearStock();
    _stock = const [];
    await _storage.setStrings(PrefsStorageService.listKey, const []);
    notifyListeners();
  }

  int qtyFor(String code) {
    final service = _service;
    return service != null ? service.qtyFor(code) : (_qty[code] ?? 1);
  }

  Future<void> setQty(String code, int qty) async {
    final service = _service;
    if (service != null) return service.setQty(code, qty);
    final v = qty.clamp(1, 99);
    if (_qty[code] == v) return;
    final next = Map<String, int>.from(_qty);
    next[code] = v;
    _qty = next;
    await _storage.setStrings(PrefsStorageService.qtyKey, encodeQty(next));
    notifyListeners();
  }

  String noteFor(String code) {
    final service = _service;
    return service != null ? service.noteFor(code) : (_notes[code] ?? '');
  }

  Future<void> setNote(String code, String note) async {
    final service = _service;
    if (service != null) return service.setNote(code, note);
    final next = Map<String, String>.from(_notes);
    if (note.trim().isEmpty) {
      next.remove(code);
    } else {
      next[code] = note.trim();
    }
    _notes = next;
    await _storage.setStrings(PrefsStorageService.notesKey, encodeNotes(next));
    notifyListeners();
  }

  bool isInsightDismissed(String id) {
    final service = _service;
    return service != null
        ? service.isInsightDismissed(id)
        : _dismissed.contains(id);
  }

  Future<void> dismissInsight(String id) async {
    final service = _service;
    if (service != null) return service.dismissInsight(id);
    if (_dismissed.contains(id)) return;
    _dismissed =
        [..._dismissed, id].reversed.take(40).toList().reversed.toList();
    await _storage.setStrings(PrefsStorageService.dismissedKey, _dismissed);
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    final service = _service;
    if (service != null) return service.setFontScale(value);
    _fontScale = value.clamp(0.85, 1.5);
    await _storage.setNumber(PrefsStorageService.fontKey, _fontScale);
    notifyListeners();
  }

  Future<void> setPersonalizedAds(bool value) async {
    final service = _service;
    if (service != null) return service.setPersonalizedAds(value);
    _personalizedAds = value;
    await _storage.setFlag(PrefsStorageService.consentKey, value);
    notifyListeners();
  }

  // Encoding identical to PrefsService (single NUL separator) so caches
  // decode the same whichever class wrote them.
  static List<String> encodeNotes(Map<String, String> notes) => notes.entries
      .map((e) => e.key + String.fromCharCode(0) + e.value)
      .toList();

  static Map<String, String> decodeNotes(List<String> raw) {
    final s = String.fromCharCode(0);
    final out = <String, String>{};
    for (final line in raw) {
      final i = line.indexOf(s);
      if (i > 0) out[line.substring(0, i)] = line.substring(i + 1);
    }
    return out;
  }

  static List<String> encodeQty(Map<String, int> qty) => qty.entries
      .map((e) => e.key + String.fromCharCode(0) + e.value.toString())
      .toList();

  static Map<String, int> decodeQty(List<String> raw) {
    final s = String.fromCharCode(0);
    final out = <String, int>{};
    for (final line in raw) {
      final i = line.indexOf(s);
      if (i > 0) {
        final v = int.tryParse(line.substring(i + 1));
        if (v != null && v >= 1) out[line.substring(0, i)] = v.clamp(1, 99);
      }
    }
    return out;
  }
}
