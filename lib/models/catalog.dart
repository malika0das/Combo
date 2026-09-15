/// Safely narrows an untrusted JSON list to object maps. Remote catalog files
/// are optional, but a malformed update must never crash the whole app or leave
/// the search screen with a half-built object graph.
List<Map<String, dynamic>> _objectList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((raw) => Map<String, dynamic>.from(raw))
      .toList(growable: false);
}

String _string(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

class Catalog {
  final int version;
  final String updatedAt;
  final String notice;

  /// Recent phones that are searchable even when no workshop-tested part list
  /// exists yet. Compatibility groups remain the source of truth for fitment;
  /// this directory only prevents new releases from being invisible.
  final List<String> knownModels;
  final List<Category> categories;

  const Catalog({
    required this.version,
    required this.updatedAt,
    required this.notice,
    this.knownModels = const [],
    required this.categories,
  });

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
        version: json['version'] is num ? (json['version'] as num).toInt() : 0,
        updatedAt: _string(json['updatedAt']),
        notice: _string(json['notice']),
        knownModels: (json['knownModels'] is List
                ? (json['knownModels'] as List)
                : const [])
            .map((e) => e is String ? e.trim() : '')
            .where((model) => model.isNotEmpty)
            .toSet()
            .toList(growable: false),
        categories: _objectList(json['categories'])
            .map(Category.fromJson)
            .toList(growable: false),
      );

  /// Total compatibility references in the catalog. This intentionally counts
  /// a model once per compatibility list: the number tells a technician how
  /// much repair coverage is available, not how many distinct phone names
  /// exist. Directory-only names are exposed separately through [knownModels].
  int get modelCount =>
      categories.fold(0, (sum, category) => sum + category.modelCount);

  int get groupCount =>
      categories.fold(0, (sum, category) => sum + category.groupCount);

  int get knownModelCount => knownModels.length;

  /// A newer remote file is only safe to adopt when it contains real lists.
  /// This prevents a truncated or schema-shifted response from replacing a
  /// perfectly usable offline catalog with an empty screen.
  bool get isUsable => categories.isNotEmpty && groupCount > 0;

  /// Flat list of every group with its category/brand context, used for search.
  List<SearchHit> search(String rawQuery, {String? categoryId, int limit = 400}) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final hits = <SearchHit>[];
    for (final category in categories) {
      if (categoryId != null && category.id != categoryId) continue;
      for (final brand in category.brands) {
        for (final group in brand.groups) {
          final matched = group.models
              .where((m) => m.toLowerCase().contains(query))
              .toList();
          final titleMatch = group.title.toLowerCase().contains(query) ||
              group.code.toLowerCase().contains(query);
          if (matched.isEmpty && !titleMatch) continue;
          hits.add(SearchHit(
            category: category,
            brand: brand,
            group: group,
            matchedModels: matched,
            exact: matched.any((m) => m.toLowerCase() == query),
          ));
        }
      }
    }
    hits.sort((a, b) {
      if (a.exact != b.exact) return a.exact ? -1 : 1;
      final byCount = b.matchedModels.length.compareTo(a.matchedModels.length);
      if (byCount != 0) return byCount;
      return a.group.code.compareTo(b.group.code);
    });
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }
}

class Category {
  final String id;
  final String name;
  final String icon;
  final List<Brand> brands;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.brands,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: _string(json['id']),
        name: _string(json['name']),
        icon: _string(json['icon'], 'display'),
        brands: _objectList(json['brands'])
            .map(Brand.fromJson)
            .toList(growable: false),
      );

  int get modelCount =>
      brands.fold(0, (sum, b) => sum + b.groups.fold(0, (s, g) => s + g.models.length));

  int get groupCount => brands.fold(0, (sum, b) => sum + b.groups.length);
}

class Brand {
  final String id;
  final String name;
  final List<ComboGroup> groups;

  const Brand({required this.id, required this.name, required this.groups});

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
        id: _string(json['id']),
        name: _string(json['name']),
        groups: _objectList(json['groups'])
            .map(ComboGroup.fromJson)
            .toList(growable: false),
      );

  int get modelCount => groups.fold(0, (s, g) => s + g.models.length);
}

class ComboGroup {
  final String code;
  final String title;
  final String quality;
  final String note;
  final List<String> models;

  const ComboGroup({
    required this.code,
    required this.title,
    required this.quality,
    required this.note,
    required this.models,
  });

  factory ComboGroup.fromJson(Map<String, dynamic> json) => ComboGroup(
        code: _string(json['code']),
        title: _string(json['title']),
        quality: _string(json['quality']),
        note: _string(json['note']),
        models: (json['models'] is List ? (json['models'] as List) : const [])
            .map((e) => e.toString().trim())
            .where((model) => model.isNotEmpty && model != 'null')
            .toList(growable: false),
      );

  /// Compact one-line form, handy for WhatsApp quotes.
  String get oneLine => '$title: ${models.join(', ')}';

  String get shareText =>
      '$title ($code)\nCompatible models:\n${models.map((m) => '• $m').join('\n')}'
      '${note.isEmpty ? '' : '\n\nNote: $note'}\n\nvia Combo Universal app';
}

class SearchHit {
  final Category category;
  final Brand brand;
  final ComboGroup group;
  final List<String> matchedModels;
  final bool exact;
  final int score;

  const SearchHit({
    required this.category,
    required this.brand,
    required this.group,
    required this.matchedModels,
    required this.exact,
    this.score = 0,
  });
}
