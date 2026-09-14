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
      expect(engine.hasModel('Galaxy S25'), isTrue);
      expect(engine.profileFor('Galaxy S25').isEmpty, isTrue);
      expect(engine.search('Galaxy S25').hits, isEmpty);
      expect(engine.search('Galaxy S25').suggestions, isEmpty);
      expect(engine.complete('Galaxy S25'), contains('Galaxy S25'));
    });
  });
}
