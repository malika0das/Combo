import 'dart:convert';
import 'dart:io';

import 'package:combo_universal/models/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Catalog catalog;

  setUpAll(() {
    final raw = File('assets/data/catalog.json').readAsStringSync();
    catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('bundled catalog parses with categories and models', () {
    expect(catalog.categories, isNotEmpty);
    expect(catalog.categories.first.modelCount, greaterThan(0));
    expect(catalog.modelCount, greaterThan(catalog.categories.first.modelCount));
    expect(catalog.groupCount, greaterThan(900));
  });

  test('recent model directory is normalized and de-duplicated', () {
    expect(catalog.knownModelCount, greaterThan(100));
    final keys = catalog.knownModels.map((m) => m.toLowerCase()).toList();
    expect(keys.toSet().length, keys.length);
    // Galaxy S25 now has a sourced OCA listing, so it is a compatibility
    // model rather than a directory-only pending model. Keep an actually
    // un-mapped recent release in the directory assertion.
    expect(catalog.knownModels, contains('iPhone 18 Pro'));
    expect(catalog.knownModels, isNot(contains('Galaxy S25')));
  });

  test('group codes are unique (saved-list keys depend on this)', () {
    final codes = <String>[];
    for (final c in catalog.categories) {
      for (final b in c.brands) {
        for (final g in b.groups) {
          codes.add(g.code);
        }
      }
    }
    expect(codes.toSet().length, codes.length);
  });

  test('bundled catalog is the full scraped dataset', () {
    expect(catalog.version, greaterThanOrEqualTo(2));
    final groups = catalog.categories
        .expand((c) => c.brands)
        .expand((b) => b.groups)
        .toList();
    expect(groups.length, greaterThan(900));
    final models = groups.expand((g) => g.models).length;
    expect(models, greaterThan(5000));
    // Every group must carry at least one model, else the UI shows a blank card.
    expect(groups.every((g) => g.models.isNotEmpty), isTrue);
    // No leftover placeholder rows from the source website.
    expect(
      groups.any((g) =>
          g.models.any((m) => m.toLowerCase().startsWith('coming soon'))),
      isFalse,
    );
  });

  test('all expected categories are present', () {
    final ids = catalog.categories.map((c) => c.id).toSet();
    expect(
      ids,
      containsAll(<String>[
        'combo',
        'battery',
        'frame',
        'powerflex',
        'displayconnector',
        'oca',
        'tempered',
        'ccboard',
        'case',
      ]),
    );
  });

  test('new repair-part categories and compatibility labels are present', () {
    final byId = {
      for (final category in catalog.categories) category.id: category,
    };
    expect(
      byId.keys,
      containsAll(<String>['frame', 'powerflex', 'displayconnector', 'oca']),
    );
    expect(byId['frame']!.name, 'Frame / Middle Frame');
    expect(byId['powerflex']!.name, 'Power / Volume Flex');
    expect(byId['displayconnector']!.name, 'Display Connector');
    expect(byId['oca']!.name, 'Touch / OCA Glass');
    expect(byId['ccboard']!.name, 'Charging Sub Board');
    expect(byId['case']!.name, 'Back Cover');
    expect(byId['tempered']!.name, 'Tempered / Screen Guard');

    bool hasModel(String categoryId, String model) {
      final normal = model.toLowerCase();
      return byId[categoryId]!.brands
          .expand((brand) => brand.groups)
          .any((group) => group.models.any((m) => m.toLowerCase() == normal));
    }

    expect(hasModel('frame', 'iPhone 13'), isTrue);
    expect(hasModel('powerflex', 'Galaxy A53 5G'), isTrue);
    expect(hasModel('displayconnector', 'Vivo V21 5G'), isTrue);
    expect(hasModel('oca', 'Galaxy S25'), isTrue);
  });

  test('battery groups expose a battery code as title', () {
    final battery = catalog.categories.firstWhere((c) => c.id == 'battery');
    final group = battery.brands.first.groups.first;
    expect(group.title, isNotEmpty);
    expect(group.code, startsWith('BAT-'));
  });

  test('search can be scoped to one category and is capped', () {
    final scoped = catalog.search('vivo', categoryId: 'battery');
    expect(scoped, isNotEmpty);
    expect(scoped.every((h) => h.category.id == 'battery'), isTrue);
    expect(catalog.search('a', limit: 25).length, lessThanOrEqualTo(25));
  });

  test('malformed optional catalog fields fail soft', () {
    final parsed = Catalog.fromJson({
      'version': 'unknown',
      'updatedAt': 2026,
      'categories': [
        {
          'id': 'battery',
          'name': 'Battery',
          'brands': [
            {
              'id': 'demo',
              'name': 'Demo',
              'groups': [
                {
                  'code': 42,
                  'title': null,
                  'models': ['Demo A', null, ''],
                },
                'not an object',
              ],
            },
            null,
          ],
        },
        'not an object',
      ],
    });

    expect(parsed.version, 0);
    expect(parsed.categories, hasLength(1));
    expect(parsed.categories.single.brands, hasLength(1));
    expect(parsed.categories.single.brands.single.groups, hasLength(1));
    expect(parsed.categories.single.brands.single.groups.single.models,
        ['Demo A']);
  });

  test('search is case insensitive and partial', () {
    expect(catalog.search('redmi 9a'), isNotEmpty);
    expect(catalog.search('9A'), isNotEmpty);
    expect(catalog.search(''), isEmpty);
    expect(catalog.search('nonexistent model xyz'), isEmpty);
  });

  test('exact model matches rank first', () {
    final hits = catalog.search('Redmi 9A');
    expect(hits.first.exact, isTrue);
  });

  test('share text includes every model', () {
    final group = catalog.categories.first.brands.first.groups.first;
    for (final m in group.models) {
      expect(group.shareText, contains(m));
    }
  });
}
