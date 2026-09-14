import '../models/catalog.dart';

/// Fast, typo-tolerant search over the whole catalog.
///
/// Built once per catalog load and reused, so typing stays smooth even with
/// thousands of models. It understands the shorthand technicians actually
/// type at the counter: "rn9pro", "note 8", "mi a2", "y21s", "a10s combo".
class SearchEngine {
  SearchEngine(this.catalog) {
    _build();
  }

  final Catalog catalog;

  final List<_Entry> _entries = <_Entry>[];

  /// Exact normalised model name -> indices into [_entries]. Backs [profileFor],
  /// which previously linear-scanned all ~5,700 rows on every model tap.
  final Map<String, List<int>> _byModel = <String, List<int>>{};
  final Map<String, _ModelRef> _models = <String, _ModelRef>{};

  /// Inverted index: 3-char shingle -> indices into [_entries]. Lets a query
  /// touch a few hundred candidates instead of all ~5,700 entries, which is
  /// what keeps typing smooth on a low-end phone.
  final Map<String, List<int>> _shingles = <String, List<int>>{};

  /// Small LRU of recent query results. Backspacing re-runs the previous query
  /// constantly, so this turns most keystrokes into a map lookup.
  final Map<String, SearchResult> _cache = <String, SearchResult>{};
  static const _cacheLimit = 32;

  static const _shingleSize = 3;

  /// Brand shorthand and common misspellings mapped to what the data uses.
  static const Map<String, String> aliases = <String, String>{
    'rn': 'redmi note',
    'mi': 'xiaomi',
    'note': 'note',
    // The catalog normalizes both "Samsung A55" and "Samsung Galaxy A55"
    // to the retail family name "Galaxy A55". Keep the common workshop
    // shorthands working against that canonical form.
    'sam': 'galaxy',
    'sammy': 'galaxy',
    'samsung': 'galaxy',
    'samsang': 'galaxy',
    'samsun': 'galaxy',
    'vivi': 'vivo',
    'vivp': 'vivo',
    'opo': 'oppo',
    'oppa': 'oppo',
    'realmi': 'realme',
    'realmy': 'realme',
    'rilme': 'realme',
    'op': 'oneplus',
    '1+': 'oneplus',
    'one plus': 'oneplus',
    'redmy': 'redmi',
    'radmi': 'redmi',
    'ridmi': 'redmi',
    'infinx': 'infinix',
    'tecno': 'tecno',
    'techno': 'tecno',
    'moto': 'motorola',
    'honour': 'honor',
    'iphon': 'iphone',
    'i phone': 'iphone',
    'apple': 'iphone',
    'poko': 'poco',
    'pocco': 'poco',
  };

  /// Words that describe a part rather than a phone, used to auto-scope a
  /// query like "redmi 9a battery" to the Battery category.
  static const Map<String, String> categoryHints = <String, String>{
    'combo': 'combo',
    'folder': 'combo',
    'display': 'combo',
    'lcd': 'combo',
    'screen': 'combo',
    'battery': 'battery',
    'batery': 'battery',
    'cell': 'battery',
    'mah': 'battery',
    'glass': 'tempered',
    'tempered': 'tempered',
    'guard': 'tempered',
    'protector': 'tempered',
    'uv': 'tempered',
    'curved': 'tempered',
    'board': 'ccboard',
    'cc': 'ccboard',
    'sub': 'ccboard',
    'charging': 'ccboard',
    'cover': 'case',
    'case': 'case',
    'back': 'case',
    'pouch': 'case',
  };

  void _build() {
    for (final category in catalog.categories) {
      for (final brand in category.brands) {
        for (final group in brand.groups) {
          for (final model in group.models) {
            final normal = normalize(model);
            final index = _entries.length;
            final packed = compact(normal);
            _entries.add(_Entry(
              category: category,
              brand: brand,
              group: group,
              model: model,
              normal: normal,
              compact: packed,
            ));
            _models.putIfAbsent(normal, () => _ModelRef(model, normal));
            (_byModel[normal] ??= <int>[]).add(index);
            for (final shingle in _shinglesOf(packed)) {
              (_shingles[shingle] ??= <int>[]).add(index);
            }
          }
        }
      }
    }

    // The recent model directory deliberately has no fake compatibility entry.
    // Registering it here makes it available to autocomplete and the A–Z
    // browser while profileFor still returns an empty, honest parts list.
    for (final model in catalog.knownModels) {
      final normal = normalize(model);
      if (normal.isEmpty) continue;
      _models.putIfAbsent(normal, () => _ModelRef(model, normal));
    }
  }

  /// Every distinct model name in the catalog, sorted for the A–Z browser.
  late final List<String> allModels = (_models.values.map((e) => e.display).toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));

  int get modelCount => _models.length;
  int get entryCount => _entries.length;

  static String normalize(String input) {
    final buffer = StringBuffer();
    var lastWasSpace = true;
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      // Keep the plus sign because `1+` is a real technician shorthand for
      // OnePlus. Other punctuation still collapses to a separator, so spacing
      // and dashes remain forgiving.
      final isWord = (rune >= 97 && rune <= 122) ||
          (rune >= 48 && rune <= 57) ||
          rune == 43;
      if (isWord) {
        buffer.write(ch);
        lastWasSpace = false;
      } else if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
    }
    return buffer.toString().trim();
  }

  static String compact(String normalized) => normalized.replaceAll(' ', '');

  /// Accept legacy workshop spellings after the catalog canonicalized Samsung
  /// names to their retail Galaxy family ("Samsung A10" -> "Galaxy A10").
  static String _modelKey(String input) {
    final normal = normalize(input);
    if (!normal.startsWith('samsung ')) return normal;
    final tail = normal.substring('samsung '.length).trim();
    return tail.startsWith('galaxy ') ? tail : 'galaxy $tail';
  }

  /// Distinct 3-character windows of [packed], used to build and probe the
  /// inverted index.
  static Set<String> _shinglesOf(String packed) {
    if (packed.length < _shingleSize) return {packed};
    final out = <String>{};
    for (var i = 0; i + _shingleSize <= packed.length; i++) {
      out.add(packed.substring(i, i + _shingleSize));
    }
    return out;
  }

  /// Rarest shingle bucket for one contiguous string, or null when the string
  /// is too short to shingle. An empty list means "cannot match anything".
  List<int>? _bucketFor(String packed) {
    if (packed.length < _shingleSize) return null;
    List<int>? best;
    for (final shingle in _shinglesOf(packed)) {
      final bucket = _shingles[shingle];
      if (bucket == null) return const [];
      if (best == null || bucket.length < best.length) best = bucket;
    }
    return best;
  }

  /// Entry indices worth scoring, or null to mean "scan everything".
  ///
  /// The scorer accepts a hit either as a contiguous substring of the whole
  /// query OR as all tokens present in any order, so the candidate set must
  /// cover both. Getting this wrong silently drops results for reordered
  /// queries like "9a redmi", so we union the two sources.
  List<int>? _candidates(String queryCompact, List<String> tokens) {
    final direct = _bucketFor(queryCompact);

    // Rarest single token decides the token-order-independent candidates.
    List<int>? tokenBucket;
    for (final token in tokens) {
      final bucket = _bucketFor(token);
      if (bucket == null) {
        // A token too short to index (e.g. "9a") could match anywhere.
        tokenBucket = null;
        break;
      }
      if (tokenBucket == null || bucket.length < tokenBucket.length) {
        tokenBucket = bucket;
      }
    }

    // Either source demanding a full scan forces a full scan.
    if (direct == null && tokens.isEmpty) return null;
    if (tokens.isNotEmpty && tokenBucket == null) return null;
    if (direct == null) return tokenBucket;
    if (tokenBucket == null) return direct;

    final union = <int>{...direct, ...tokenBucket};
    return union.toList(growable: false);
  }

  /// Expands a shorthand even when it is glued to a model number. Technicians
  /// commonly type `rn9pro`, not `rn 9 pro`; exact alias lookup alone would
  /// miss the `rn` prefix and silently turn a useful shortcut into no result.
  static String? _expandAliasPrefix(String token) {
    final matches = aliases.keys
        .where((key) =>
            key.length >= 2 &&
            token.length > key.length &&
            token.startsWith(key) &&
            RegExp(r'\d').hasMatch(token.substring(key.length)))
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (matches.isEmpty) return null;
    final key = matches.first;
    return '${aliases[key]} ${token.substring(key.length)}';
  }

  /// Splits digits from letters so "note8" also matches "note 8", and expands
  /// brand shorthand.
  static List<String> tokenize(String normalized) {
    final tokens = <String>[];
    for (final raw in normalized.split(' ')) {
      if (raw.isEmpty) continue;
      final expanded = aliases[raw] ?? _expandAliasPrefix(raw) ?? raw;
      for (final part in expanded.split(' ')) {
        if (part.isEmpty) continue;
        // Split a mixed token like "9a5000" into "9a" only when it is clearly
        // "word+number", e.g. "note8" -> "note", "8".
        final match = RegExp(r'^([a-z]+)(\d.*)$').firstMatch(part);
        if (match != null && match.group(1)!.length > 2) {
          tokens.add(match.group(1)!);
          tokens.add(match.group(2)!);
        } else {
          tokens.add(part);
        }
      }
    }
    return tokens;
  }

  /// Levenshtein distance with an early exit, used only for short tokens.
  static int editDistance(String a, String b, {int max = 1}) {
    if ((a.length - b.length).abs() > max) return max + 1;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      var rowMin = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final value = [
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        current[j] = value;
        if (value < rowMin) rowMin = value;
      }
      if (rowMin > max) return max + 1;
      previous = current;
    }
    return previous[b.length];
  }

  /// Reads a part keyword out of the query ("redmi 9a battery" -> 'battery').
  String? detectCategory(String rawQuery) {
    for (final token in tokenize(normalize(rawQuery))) {
      final hit = categoryHints[token];
      if (hit != null && catalog.categories.any((c) => c.id == hit)) return hit;
    }
    return null;
  }

  /// Main entry point. [categoryId] null means "all categories"; when
  /// [autoScope] is true a part keyword inside the query narrows it down.
  SearchResult search(
    String rawQuery, {
    String? categoryId,
    bool autoScope = true,
    int limit = 300,
  }) {
    final normal = normalize(rawQuery);
    if (normal.isEmpty) {
      return const SearchResult(
          hits: [], suggestions: [], scopedCategoryId: null, fuzzy: false);
    }

    final cacheKey = '$normal|${categoryId ?? ''}|$autoScope|$limit';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    var scope = categoryId;
    if (scope == null && autoScope) scope = detectCategory(rawQuery);

    final queryTokens = tokenize(normal)
        .where((t) => categoryHints[t] == null || t.length <= 2)
        .toList();
    final effectiveTokens = queryTokens.isEmpty ? tokenize(normal) : queryTokens;
    final queryCompact = compact(effectiveTokens.join(' '));

    final byGroup = <String, _Accumulator>{};
    var usedFuzzy = false;

    for (var pass = 0; pass < 2; pass++) {
      final allowFuzzy = pass == 1;
      // Pass 0 only ever matches substrings, so the shingle index can safely
      // narrow the candidates. Pass 1 is fuzzy and must consider everything.
      final candidates =
          allowFuzzy ? null : _candidates(queryCompact, effectiveTokens);

      void consider(_Entry entry) {
        if (scope != null && entry.category.id != scope) return;
        final score = _score(entry, normal, queryCompact, effectiveTokens,
            allowFuzzy: allowFuzzy);
        if (score <= 0) return;
        if (allowFuzzy) usedFuzzy = true;
        final acc = byGroup.putIfAbsent(
          '${entry.category.id}/${entry.group.code}',
          () => _Accumulator(entry.category, entry.brand, entry.group),
        );
        acc.add(entry.model, score);
      }

      if (candidates != null) {
        for (final i in candidates) {
          consider(_entries[i]);
        }
      } else {
        for (final entry in _entries) {
          consider(entry);
        }
      }
      if (byGroup.isNotEmpty) break;
    }

    // Also allow matching by group code or battery title ("BN4A", "EB-BA546").
    if (byGroup.isEmpty) {
      for (final category in catalog.categories) {
        if (scope != null && category.id != scope) continue;
        for (final brand in category.brands) {
          for (final group in brand.groups) {
            final hay = normalize('${group.code} ${group.title}');
            if (!hay.contains(normal) && !compact(hay).contains(queryCompact)) {
              continue;
            }
            byGroup
                .putIfAbsent('${category.id}/${group.code}',
                    () => _Accumulator(category, brand, group))
                .score += 400;
          }
        }
      }
    }

    final hits = byGroup.values
        .map((a) => SearchHit(
              category: a.category,
              brand: a.brand,
              group: a.group,
              matchedModels: a.matched,
              exact: a.exact,
              score: a.score,
            ))
        .toList()
      ..sort((a, b) {
        if (a.exact != b.exact) return a.exact ? -1 : 1;
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final byCount = b.matchedModels.length.compareTo(a.matchedModels.length);
        if (byCount != 0) return byCount;
        return a.group.code.compareTo(b.group.code);
      });

    final result = SearchResult(
      hits: hits.length > limit ? hits.sublist(0, limit) : hits,
      suggestions: hits.isEmpty && !hasModel(normal)
          ? suggest(rawQuery)
          : const [],
      scopedCategoryId: scope,
      fuzzy: usedFuzzy,
    );

    if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
    _cache[cacheKey] = result;
    return result;
  }

  int _score(
    _Entry entry,
    String normalQuery,
    String queryCompact,
    List<String> tokens, {
    required bool allowFuzzy,
  }) {
    if (entry.normal == normalQuery) return 1000;
    if (entry.compact == queryCompact) return 900;
    if (entry.compact.startsWith(queryCompact)) return 750;
    if (entry.compact.contains(queryCompact)) return 600;
    if (entry.normal.contains(normalQuery)) return 550;

    var matched = 0;
    for (final token in tokens) {
      if (entry.compact.contains(token)) {
        matched++;
      } else if (allowFuzzy && token.length >= 4) {
        final near = entry.normal
            .split(' ')
            .any((word) => editDistance(word, token) <= 1);
        if (near) matched++;
      }
    }
    if (matched == tokens.length && tokens.isNotEmpty) {
      return allowFuzzy ? 200 : 350;
    }
    return 0;
  }

  /// "Did you mean" list for a query that found nothing.
  List<String> suggest(String rawQuery, {int limit = 6}) {
    final normal = normalize(rawQuery);
    if (normal.length < 3) return const [];
    final scored = <MapEntry<String, int>>[];
    for (final ref in _models.values) {
      // editDistance already early-exits on a length gap, but checking here
      // avoids the allocation of its DP rows for the vast majority of models.
      if ((ref.normal.length - normal.length).abs() > 3) continue;
      final distance = editDistance(ref.normal, normal, max: 3);
      if (distance <= 3) scored.add(MapEntry(ref.display, distance));
    }
    scored.sort((a, b) => a.value.compareTo(b.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Autocomplete for the search box, prioritising prefix matches.
  List<String> complete(String rawQuery, {int limit = 8}) {
    final normal = normalize(rawQuery);
    if (normal.isEmpty) return const [];
    final target = compact(normal);
    final starts = <String>[];
    final contains = <String>[];
    for (final ref in _models.values) {
      final c = compact(ref.normal);
      if (c.startsWith(target)) {
        starts.add(ref.display);
      } else if (contains.length < limit * 4 && c.contains(target)) {
        contains.add(ref.display);
      }
      // Only stop once we have plenty of prefix hits; stopping earlier used to
      // discard shorter (better) matches that appear later in the map.
      if (starts.length >= limit * 6) break;
    }
    starts.sort((a, b) => a.length.compareTo(b.length));
    contains.sort((a, b) => a.length.compareTo(b.length));
    return <String>[...starts, ...contains].take(limit).toList();
  }

  /// Every part, in every category, that fits one specific model.
  ModelProfile profileFor(String model) {
    final normal = _modelKey(model);
    final parts = <ModelPart>[];
    final siblings = <String, String>{};
    for (final i in _byModel[normal] ?? const <int>[]) {
      final entry = _entries[i];
      parts.add(ModelPart(entry.category, entry.brand, entry.group));
      for (final other in entry.group.models) {
        final key = normalize(other);
        if (key != normal) siblings.putIfAbsent(key, () => other);
      }
    }
    parts.sort((a, b) => a.category.name.compareTo(b.category.name));
    final display = _models[normal]?.display ?? model;
    final siblingList = siblings.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ModelProfile(model: display, parts: parts, siblings: siblingList);
  }

  bool hasModel(String model) => _models.containsKey(_modelKey(model));
}

class _Entry {
  _Entry({
    required this.category,
    required this.brand,
    required this.group,
    required this.model,
    required this.normal,
    required this.compact,
  });

  final Category category;
  final Brand brand;
  final ComboGroup group;
  final String model;
  final String normal;
  final String compact;
}

class _ModelRef {
  _ModelRef(this.display, this.normal);

  final String display;
  final String normal;
}

class _Accumulator {
  _Accumulator(this.category, this.brand, this.group);

  final Category category;
  final Brand brand;
  final ComboGroup group;
  final List<String> matched = <String>[];
  int score = 0;
  bool exact = false;

  void add(String model, int modelScore) {
    matched.add(model);
    if (modelScore >= 900) exact = true;
    if (modelScore > score) score = modelScore;
    score += 5; // a group covering more matches ranks slightly higher
  }
}

class SearchResult {
  const SearchResult({
    required this.hits,
    required this.suggestions,
    required this.scopedCategoryId,
    required this.fuzzy,
  });

  final List<SearchHit> hits;
  final List<String> suggestions;
  final String? scopedCategoryId;
  final bool fuzzy;

  bool get isEmpty => hits.isEmpty;
}

class ModelPart {
  const ModelPart(this.category, this.brand, this.group);

  final Category category;
  final Brand brand;
  final ComboGroup group;
}

class ModelProfile {
  const ModelProfile({
    required this.model,
    required this.parts,
    required this.siblings,
  });

  final String model;
  final List<ModelPart> parts;

  /// Other models that share at least one part with this one.
  final List<String> siblings;

  bool get isEmpty => parts.isEmpty;
}
