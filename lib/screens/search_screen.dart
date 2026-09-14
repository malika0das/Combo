import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/catalog.dart';
import '../motion.dart';
import '../responsive.dart';
import '../services/insight_service.dart';
import '../services/search_engine.dart';
import '../theme.dart';
import '../widgets/brand_icon.dart';
import '../widgets/dimensional.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/ui.dart';
import 'group_screen.dart';
import 'model_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );
  Timer? _debounce;
  String _query = '';
  String? _categoryId;

  /// Optional brand narrowed from the current hits (client-side filter).
  String? _brand;
  SearchResult _result = const SearchResult(
    hits: [],
    suggestions: [],
    scopedCategoryId: null,
    fuzzy: false,
  );
  List<String> _completions = const [];
  bool _searching = false;

  List<SearchHit> get _hits => _result.hits;

  List<SearchHit> get _filteredHits => _brand == null
      ? _hits
      : _hits.where((h) => h.brand.name == _brand).toList(growable: false);

  /// Distinct brands across the current hits, sorted — the filter row is only
  /// worth showing when there is more than one to choose from.
  List<String> get _brandsInResults {
    final names = <String>{for (final h in _hits) h.brand.name}.toList()
      ..sort();
    return names;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _query = widget.initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(_query));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final engine = AppScope.of(context).catalog.engine;
    setState(() {
      _query = value;
      _completions = engine?.complete(value, limit: 6) ?? const [];
      _searching = value.trim().isNotEmpty;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => _run(value));
  }

  void _run(String value) {
    final scope = AppScope.of(context);
    final engine = scope.catalog.engine;
    final result =
        engine?.search(value, categoryId: _categoryId) ??
        const SearchResult(
          hits: [],
          suggestions: [],
          scopedCategoryId: null,
          fuzzy: false,
        );
    final hadHits = _result.hits.isNotEmpty;
    setState(() {
      _result = result;
      _searching = false;
      // A brand filter only makes sense while it still matches something.
      if (_brand != null && !_result.hits.any((h) => h.brand.name == _brand)) {
        _brand = null;
      }
    });
    // A short haptic when a search goes from "nothing" to "found" — the user
    // feels the answer arrive without looking up from the phone in their hand.
    if (!hadHits && result.hits.isNotEmpty) Haptics.confirm();
    if (value.trim().length >= 3 && result.hits.isNotEmpty) {
      scope.prefs.addRecent(value.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasQuery = _query.trim().isNotEmpty;
    final categories = scope.catalog.catalog?.categories ?? const <Category>[];
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'searchbox',
          child: Material(
            color: Colors.transparent,
            child: TextField(
              controller: _controller,
              autofocus: widget.initialQuery.isEmpty,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Model, part or code',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: !hasQuery
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
        ),
        titleSpacing: 8,
      ),
      bottomNavigationBar: BannerAdSlot(ads: scope.ads),
      body: Column(
        children: [
          if (hasQuery && categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _categoryId == null,
                      onSelected: (_) {
                        Haptics.tap();
                        setState(() => _categoryId = null);
                        _run(_query);
                      },
                    ),
                  ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(c.name),
                        selected: _categoryId == c.id,
                        onSelected: (_) {
                          Haptics.tap();
                          setState(() => _categoryId = c.id);
                          _run(_query);
                        },
                      ),
                    ),
                ],
              ),
            ),
          // Brand filter, derived from the current hits. Each chip carries the
          // brand's icon + accent so a row of them scans at a glance.
          if (hasQuery && _hits.isNotEmpty && _brandsInResults.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('All brands'),
                      selected: _brand == null,
                      onSelected: (_) {
                        Haptics.tap();
                        setState(() => _brand = null);
                      },
                    ),
                  ),
                  for (final b in _brandsInResults)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Builder(
                        builder: (context) {
                          final style = brandStyle(b);
                          return FilterChip(
                            avatar: Icon(
                              style.icon,
                              size: 15,
                              color: style.color,
                            ),
                            label: Text(b),
                            selected: _brand == b,
                            onSelected: (_) {
                              Haptics.tap();
                              setState(() => _brand = _brand == b ? null : b);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _buildResults(context, hasQuery, scheme, categories)),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    bool hasQuery,
    ColorScheme scheme,
    List<Category> categories,
  ) {
    final filteredHits = _filteredHits;
    return !hasQuery
        ? _Tips(
            onPick: (q) {
              _controller.text = q;
              _onChanged(q);
            },
          )
        // While the debounce is pending, show shaped skeletons rather than a
        // spinner: the layout does not jump when the real results land.
        : (_searching && _hits.isEmpty)
        ? const _ResultSkeletons()
        : _hits.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DepthOrb(
                    color: scheme.primary,
                    size: 92,
                    icon: Icons.search_rounded,
                  ),
                  Gap.lg,
                  Text(
                    _result.suggestions.isEmpty
                        ? 'Nothing found yet'
                        : 'Close, but not exact',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Gap.sm,
                  Text(
                    InsightService.emptyMessage(
                      _query.trim(),
                      _result.suggestions.isNotEmpty,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_result.suggestions.isNotEmpty) ...[
                    Gap.xl,
                    Text(
                      'Did you mean',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Gap.sm,
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in _result.suggestions)
                          ActionChip(
                            label: Text(s),
                            onPressed: () {
                              _controller.text = s;
                              _onChanged(s);
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          )
        : filteredHits.isEmpty
        ? _NoBrandResults(
            brand: _brand!,
            onClear: () => setState(() => _brand = null),
          )
        : ListView.separated(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              12,
              context.pagePadding,
              24,
            ),
            itemCount: filteredHits.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                String? scopedName;
                final scopedId = _result.scopedCategoryId;
                if (scopedId != null) {
                  for (final c in categories) {
                    if (c.id == scopedId) scopedName = c.name;
                  }
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_completions.isNotEmpty)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final c in _completions)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  avatar: const Icon(
                                    Icons.phone_iphone_rounded,
                                    size: 16,
                                  ),
                                  label: Text(c),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ModelScreen(model: c),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        AnimatedCounter(
                          value: filteredHits.length,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          ' matching list${filteredHits.length == 1 ? '' : 's'}'
                          '${scopedName == null ? '' : ' in $scopedName'}'
                          '${_result.fuzzy ? ' · showing close matches' : ''}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                );
              }
              final hit = filteredHits[i - 1];
              return EntranceFade(
                index: i - 1,
                child: GroupCard(
                  group: hit.group,
                  query: _query,
                  subtitle: '${hit.category.name} · ${hit.brand.name}',
                  categoryIcon: iconFor(hit.category.icon),
                  categoryTint: accentFor(hit.category.icon, scheme),
                ),
              );
            },
          );
  }
}

class _NoBrandResults extends StatelessWidget {
  const _NoBrandResults({required this.brand, required this.onClear});

  final String brand;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 42, color: scheme.primary),
            Gap.lg,
            Text(
              'No $brand lists here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Gap.sm,
            Text(
              'Try another brand or show all brands again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Gap.lg,
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Show all brands'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholders shaped like GroupCards.
class _ResultSkeletons extends StatelessWidget {
  const _ResultSkeletons();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Shimmer(
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          12,
          context.pagePadding,
          24,
        ),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(double.infinity, 14),
              const SizedBox(height: 8),
              bar(140, 10),
              const SizedBox(height: 14),
              Row(
                children: [
                  bar(64, 22),
                  const SizedBox(width: 6),
                  bar(78, 22),
                  const SizedBox(width: 6),
                  bar(52, 22),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips({required this.onPick});

  final ValueChanged<String> onPick;

  static const _samples = [
    'Redmi 9A',
    'Y21',
    'A10',
    'Realme C11',
    'rn9pro',
    'Redmi 9A battery',
    'Vivo Y17 glass',
  ];

  @override
  Widget build(BuildContext context) {
    final recent = AppScope.of(context).prefs.recent;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (recent.isNotEmpty) ...[
          const SectionHeader(title: 'Recent'),
          Wrap(
            spacing: 8,
            children: [
              for (final q in recent)
                ActionChip(label: Text(q), onPressed: () => onPick(q)),
            ],
          ),
          Gap.xl,
        ],
        const SectionHeader(
          title: 'Try a search',
          subtitle: 'Spelling and spacing do not matter',
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final q in _samples)
              ActionChip(label: Text(q), onPressed: () => onPick(q)),
          ],
        ),
      ],
    );
  }
}
