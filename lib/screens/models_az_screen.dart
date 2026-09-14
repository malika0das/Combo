import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../motion.dart';
import '../responsive.dart';
import '../services/search_engine.dart';
import '../widgets/ui.dart';
import 'model_screen.dart';

/// A–Z browser over every distinct phone model in the catalog, for when the
/// technician does not know the exact spelling.
class ModelsAzScreen extends StatefulWidget {
  const ModelsAzScreen({super.key});

  @override
  State<ModelsAzScreen> createState() => _ModelsAzScreenState();
}

class _ModelsAzScreenState extends State<ModelsAzScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _filter = '';

  /// Normalising ~3,000 model names on every keystroke was the single biggest
  /// source of jank on this screen. The packed forms are computed once and
  /// reused, and typing is debounced.
  List<String>? _all;
  List<String> _packed = const [];
  List<String> _models = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _ensureIndex(List<String> all) {
    if (identical(_all, all)) return;
    _all = all;
    _packed = all
        .map((m) => SearchEngine.compact(SearchEngine.normalize(m)))
        .toList(growable: false);
    _models = all;
  }

  void _onFilterChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      final needle = SearchEngine.compact(SearchEngine.normalize(value));
      final all = _all ?? const <String>[];
      setState(() {
        _filter = value;
        if (needle.isEmpty) {
          _models = all;
        } else {
          final out = <String>[];
          for (var i = 0; i < all.length; i++) {
            if (_packed[i].contains(needle)) out.add(all[i]);
          }
          _models = out;
        }
      });
    });
  }

  /// Safe first letter — a blank or symbol-led name used to crash on `[0]`.
  static String _initial(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '#' : trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // As a shell tab this screen is built before the catalog engine has
    // loaded, so it must rebuild when the catalog arrives.
    return AnimatedBuilder(
      animation: AppScope.of(context).catalog,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final scope = AppScope.of(context);
    final SearchEngine? engine = scope.catalog.engine;
    final all = engine?.allModels ?? const <String>[];
    _ensureIndex(all);
    final models = _models;
    final filterActive = _filter.trim().isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All models'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _controller,
              onChanged: _onFilterChanged,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search models',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _filter.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onFilterChanged('');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: scope.catalog.loading
          ? const Center(child: CircularProgressIndicator())
          : models.isEmpty
          ? const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No models found',
              message: 'Try a shorter spelling or clear the search.',
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.pagePadding,
                        10,
                        context.pagePadding,
                        6,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${models.length} ${models.length == 1 ? 'model' : 'models'}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              filterActive
                                  ? 'Matching your search'
                                  : 'Tap a model to see compatible parts',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        interactive: true,
                        child: ListView.separated(
                          itemCount: models.length,
                          separatorBuilder: (context, i) {
                            final sameLetter =
                                _initial(models[i]) == _initial(models[i + 1]);
                            return sameLetter
                                ? Divider(
                                    indent: 72,
                                    endIndent: 16,
                                    color: scheme.outlineVariant.withValues(
                                      alpha: 0.55,
                                    ),
                                  )
                                : const SizedBox(height: 8);
                          },
                          itemBuilder: (context, i) {
                            final model = models[i];
                            final showHeader =
                                i == 0 ||
                                _initial(model) != _initial(models[i - 1]);
                            return ListTile(
                              dense: true,
                              leading: showHeader
                                  ? Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Text(
                                        _initial(model),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    )
                                  : const SizedBox(width: 34),
                              title: Text(
                                model,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                              ),
                              onTap: () {
                                Haptics.tap();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ModelScreen(model: model),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
