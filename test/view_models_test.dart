import 'package:combo_universal/data/repositories/catalog_repository.dart';
import 'package:combo_universal/data/repositories/prefs_repository.dart';
import 'package:combo_universal/data/services/prefs_storage_service.dart';
import 'package:combo_universal/services/catalog_service.dart';
import 'package:combo_universal/services/prefs_service.dart';
import 'package:combo_universal/ui/features/home/view_models/home_view_model.dart';
import 'package:combo_universal/ui/features/search/view_models/search_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skill Step 8 validator (part 2): ViewModel unit tests.
///
/// ViewModels are constructed with constructor-injected repositories so they
/// can be exercised without any widget tree or platform channels.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalogRepo;
  late PrefsRepository prefsRepo;
  late CatalogService catalogService;
  late PrefsService prefsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    prefsService = PrefsService();
    await prefsService.init();
    final storage = PrefsStorageService();
    await storage.init();
    catalogService = CatalogService();
    catalogRepo = CatalogRepository.fromService(catalogService, storage: storage);
    prefsRepo = PrefsRepository.delegating(service: prefsService, storage: storage);
  });

  tearDown(() {
    catalogRepo.dispose();
    prefsRepo.dispose();
  });

  group('SearchViewModel', () {
    test('starts empty and exposes initial state', () {
      final vm = SearchViewModel(catalog: catalogRepo, prefs: prefsRepo);
      expect(vm.hits, isEmpty);
      expect(vm.searching, isFalse);
      expect(vm.query, '');
      expect(vm.categories, isEmpty);
      vm.dispose();
    });

    test('brand filter falls back to all hits when empty', () async {
      final vm = SearchViewModel(catalog: catalogRepo, prefs: prefsRepo);
      vm.setBrand('Xiaomi');
      expect(vm.filteredHits, isEmpty);
      vm.dispose();
    });

    test('clear resets state', () {
      final vm = SearchViewModel(catalog: catalogRepo, prefs: prefsRepo);
      vm.onChanged('redmi');
      vm.clear();
      expect(vm.query, '');
      expect(vm.hits, isEmpty);
      expect(vm.searching, isFalse);
      expect(vm.brand, isNull);
      vm.dispose();
    });
  });

  group('HomeViewModel', () {
    test('forwards catalog loading state from legacy service', () {
      final vm = HomeViewModel(catalog: catalogRepo, prefs: prefsRepo);
      expect(vm.catalog, isNull);
      expect(vm.source, 'bundled');
      expect(vm.loading, isTrue);
      vm.dispose();
    });

    test('forwards prefs state and dismisses insights', () async {
      final vm = HomeViewModel(catalog: catalogRepo, prefs: prefsRepo);
      var notified = false;
      vm.addListener(() => notified = true);
      await prefsRepo.addRecent('probe');
      expect(notified, isTrue);
      expect(vm.prefs.recent, contains('probe'));
      await vm.dismissInsight('first_run');
      expect(vm.prefs.isInsightDismissed('first_run'), isTrue);
      vm.dispose();
    });
  });
}