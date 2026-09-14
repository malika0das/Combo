import 'dart:convert';
import 'dart:io';

import 'package:combo_universal/data/repositories/prefs_repository.dart';
import 'package:combo_universal/data/services/prefs_storage_service.dart';
import 'package:combo_universal/domain/use_cases/get_insight_use_case.dart';
import 'package:combo_universal/domain/use_cases/search_catalog_use_case.dart';
import 'package:combo_universal/models/catalog.dart';
import 'package:combo_universal/services/prefs_service.dart';
import 'package:combo_universal/services/search_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skill Step 8 validator (part 1): use cases + delegating repository behave
/// identically to the legacy services. Bundled-asset + in-memory prefs only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  late SearchEngine engine;

  setUpAll(() {
    final raw = File('assets/data/catalog.json').readAsStringSync();
    catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    engine = SearchEngine(catalog);
  });

  test('PrefsRepository delegating mirrors PrefsService writes', () async {
    SharedPreferences.setMockInitialValues(const {});
    final service = PrefsService();
    await service.init();
    final storage = PrefsStorageService();
    await storage.init();
    final repo = PrefsRepository.delegating(
      service: service,
      storage: storage,
    );
    await repo.toggleSaved('CODE-1');
    expect(service.isSaved('CODE-1'), isTrue);
    expect(repo.isSaved('CODE-1'), isTrue);
    await repo.toggleSaved('CODE-1');
    expect(repo.isSaved('CODE-1'), isFalse);
    await repo.addRecent('Redmi 9A');
    expect(repo.recent.first, 'Redmi 9A');
    expect(service.recent.first, 'Redmi 9A');
    repo.dispose();
  });

  test('SearchCatalogUseCase matches engine + brand filter', () {
    const useCase = SearchCatalogUseCase();
    final full = useCase.run(engine, 'Redmi 9A');
    expect(full.hits, isNotEmpty);
    final direct = engine.search('Redmi 9A');
    expect(full.hits.length, direct.hits.length);
    final brand = full.hits.first.brand.name;
    final filtered = useCase.run(engine, 'Redmi 9A', brand: brand);
    expect(filtered.hits.every((h) => h.brand.name == brand), isTrue);
    expect(useCase.brandsIn(full), contains(brand));
    expect(useCase.completions(engine, 'Redmi'), isNotEmpty);
    expect(useCase.run(null, 'x').hits, isEmpty);
  });

  test('GetInsightUseCase mirrors InsightService rules', () {
    const useCase = GetInsightUseCase();
    final welcome = useCase(
      recent: const [],
      saved: const [],
      stock: const [],
      isDismissed: (_) => false,
      catalog: catalog,
      engine: engine,
      now: DateTime(2026, 1, 1, 10),
    );
    expect(welcome, isNotNull);
    expect(welcome!.tone, InsightTone.welcome);
    final dismissed = useCase(
      recent: const [],
      saved: const [],
      stock: const [],
      isDismissed: (id) => id == welcome.id,
      catalog: catalog,
      engine: engine,
      now: DateTime(2026, 1, 1, 10),
    );
    expect(dismissed, isNull);
  });
}
