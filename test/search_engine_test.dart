import 'dart:convert';
import 'dart:io';

import 'package:combo_universal/models/catalog.dart';
import 'package:combo_universal/services/search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SearchEngine engine;

  setUpAll(() {
    final raw = File('assets/data/catalog.json').readAsStringSync();
    engine = SearchEngine(
        Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  });

  group('normalization', () {
    test('strips punctuation and case', () {
      expect(SearchEngine.normalize('Redmi Note 9-Pro!'), 'redmi note 9 pro');
      expect(SearchEngine.compact(SearchEngine.normalize('Vivo Y21 s')),
          'vivoy21s');
    });

    test('splits word+number tokens and expands aliases', () {
      expect(SearchEngine.tokenize('note8'), contains('8'));
      expect(SearchEngine.tokenize('rn'), contains('redmi'));
      expect(SearchEngine.tokenize('rn9pro'), contains('redmi'));
      expect(SearchEngine.tokenize('1+'), contains('oneplus'));
      // Samsung model names are canonicalized to their retail Galaxy family.
      expect(SearchEngine.tokenize('samsang'), contains('galaxy'));
    });

    test('edit distance bails out early', () {
      expect(SearchEngine.editDistance('redmi', 'redmi'), 0);
      expect(SearchEngine.editDistance('redmi', 'redni'), 1);
      expect(SearchEngine.editDistance('redmi', 'zzzzzz', max: 1),
          greaterThan(1));
    });
  });

  group('search', () {
    test('exact model wins', () {
      final result = engine.search('Redmi 9A');
      expect(result.hits, isNotEmpty);
      expect(result.hits.first.exact, isTrue);
    });

    test('spacing and punctuation do not matter', () {
      expect(engine.search('redmi9a').hits, isNotEmpty);
      expect(engine.search('  REDMI  9a ').hits, isNotEmpty);
      expect(engine.search('rn9pro').hits, isNotEmpty);
    });

    test('typos still find the phone', () {
      expect(engine.search('redni 9a').hits, isNotEmpty);
      expect(engine.search('samsang a10').hits, isNotEmpty);
    });

    test('a part keyword auto-scopes the search', () {
      final result = engine.search('Redmi 9A battery');
      expect(result.scopedCategoryId, 'battery');
      expect(result.hits.every((h) => h.category.id == 'battery'), isTrue);
    });

    test('explicit category scope overrides auto-scope', () {
      final result = engine.search('Redmi 9A battery', categoryId: 'combo');
      expect(result.hits.every((h) => h.category.id == 'combo'), isTrue);
    });

    test('new part keywords resolve to their own categories', () {
      expect(engine.detectCategory('iPhone 13 middle frame'), 'frame');
      expect(engine.detectCategory('Galaxy A53 power volume flex'), 'powerflex');
      expect(
          engine.detectCategory('V21 display connector'), 'displayconnector');
      expect(engine.detectCategory('Galaxy S25 OCA glass'), 'oca');
      expect(engine.detectCategory('Vivo V17 charging sub board'), 'ccboard');
      expect(engine.detectCategory('Oppo F15 back cover'), 'case');
      expect(engine.detectCategory('Redmi 9A tempered glass'), 'tempered');
      expect(engine.detectCategory('V21 lcdflex'), 'displayconnector');
      expect(engine.detectCategory('Galaxy S25 ocaglass'), 'oca');
      expect(engine.detectCategory('Oppo F15 backcover'), 'case');
      // A bare display still means combo; connector requires the explicit
      // phrase so existing display search behaviour does not change.
      expect(engine.detectCategory('Redmi 9A display'), 'combo');
    });

    test('new part searches stay exact-model scoped', () {
      final cases = <String, String>{
        'iPhone 13 middle frame': 'frame',
        'Galaxy A53 power volume flex': 'powerflex',
        'V21 display connector': 'displayconnector',
        'Galaxy S25 OCA glass': 'oca',
        'Vivo V17 charging sub board': 'ccboard',
        'Oppo F15 back cover': 'case',
      };
      for (final entry in cases.entries) {
        final result = engine.search(entry.key);
        expect(result.hits, isNotEmpty, reason: entry.key);
        expect(result.scopedCategoryId, entry.value, reason: entry.key);
        expect(result.hits.every((h) => h.category.id == entry.value), isTrue,
            reason: entry.key);
      }
    });

    test('results are capped', () {
      expect(engine.search('vivo', limit: 10).hits.length, lessThanOrEqualTo(10));
    });

    test('nonsense returns nothing but offers suggestions when close', () {
      expect(engine.search('zzzzzzzzqqqq').hits, isEmpty);
      final near = engine.search('redmi 9aa');
      expect(near.hits.isNotEmpty || near.suggestions.isNotEmpty, isTrue);
    });
  });

  group('model tools', () {
    test('every model resolves to a profile with at least one part', () {
      final profile = engine.profileFor('Redmi 9A');
      expect(profile.isEmpty, isFalse);
      expect(profile.parts, isNotEmpty);
      expect(profile.siblings, isNotEmpty);
      // A model never lists itself as its own sibling.
      expect(
        profile.siblings.any((s) => s.toLowerCase() == 'redmi 9a'),
        isFalse,
      );
    });

    test('profile parts come from distinct groups', () {
      final profile = engine.profileFor('Redmi 9A');
      final codes = profile.parts.map((p) => p.group.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('autocomplete prefers prefix matches', () {
      final options = engine.complete('redmi 9');
      expect(options, isNotEmpty);
      expect(
        options.first.toLowerCase().replaceAll(' ', '').startsWith('redmi9'),
        isTrue,
      );
    });

    test('the A-Z index covers the whole catalog and is sorted', () {
      expect(engine.allModels.length, engine.modelCount);
      expect(engine.modelCount, greaterThan(2500));
      final lower = engine.allModels.map((m) => m.toLowerCase()).toList();
      final sorted = [...lower]..sort();
      expect(lower, sorted);
    });

    test('hasModel is normalization aware', () {
      expect(engine.hasModel('  redmi   9a '), isTrue);
      expect(engine.hasModel('Samsung A10'), isTrue);
      expect(engine.hasModel('not a real phone'), isFalse);
    });

    test('directory-only models are searchable without fake part hits', () {
      // Galaxy S25 has a sourced OCA mapping now; iPhone 18 Pro remains a
      // directory-only recent release and must keep the pending state.
      expect(engine.hasModel('iPhone 18 Pro'), isTrue);
      expect(engine.profileFor('iPhone 18 Pro').isEmpty, isTrue);
      expect(engine.search('iPhone 18 Pro').hits, isEmpty);
      expect(engine.search('iPhone 18 Pro').suggestions, isEmpty);
      expect(engine.complete('iPhone 18 Pro'), contains('iPhone 18 Pro'));
    });
  });
}
