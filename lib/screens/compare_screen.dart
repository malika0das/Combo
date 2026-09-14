import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import '../motion.dart';
import '../responsive.dart';
import '../services/search_engine.dart';
import '../theme.dart';
import '../widgets/dimensional.dart';
import '../widgets/ui.dart';
import 'model_screen.dart';

/// "Can I use one part for both phones?" — pick two (or more) models and see
/// which categories they share a universal part in.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, this.initialModels = const []});

  final List<String> initialModels;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late List<String> _models = [...widget.initialModels];
  // Owned by Autocomplete; keeping a reference lets a selection reset the
  // field without creating a second controller or leaking the framework one.
  TextEditingController? _inputController;

  /// Bumped whenever a comparison newly succeeds, to fire the burst.
  int _matchToken = 0;
  bool _wasMatched = false;

  /// Build must stay pure, so the celebration state is reconciled *after* the
  /// frame. Mutating it inline used to re-fire the burst and the haptic on
  /// every unrelated rebuild (theme change, keyboard opening, rotation).
  void _syncMatchState(bool matched) {
    if (matched == _wasMatched) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || matched == _wasMatched) return;
      setState(() {
        _wasMatched = matched;
        if (matched) _matchToken++;
      });
    });
  }

  void _add(String model) {
    if (model.trim().isEmpty) return;
    if (_models.any((m) => m.toLowerCase() == model.toLowerCase())) {
      Haptics.warn();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$model is already on the list')),
      );
      return;
    }
    Haptics.confirm();
    setState(() => _models = [..._models, model]);
  }

  @override
  Widget build(BuildContext context) {
    // As a shell tab this screen is built before the catalog engine has
    // loaded, so it must rebuild when the catalog arrives.
    return AnimatedBuilder(
      animation: AppScope.of(context).catalog,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final scope = AppScope.of(context);
    final engine = scope.catalog.engine;
    final scheme = Theme.of(context).colorScheme;
    final profiles =
        engine == null ? <ModelProfile>[] : _models.map(engine.profileFor).toList();
    final shared = _sharedParts(profiles);
    _syncMatchState(shared.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare models'),
        actions: [
          if (shared.isNotEmpty)
            IconButton(
              tooltip: 'Share result',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => Share.share(_summary(shared)),
            ),
          if (_models.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => setState(() => _models = []),
            ),
        ],
      ),
      body: PageBody(
        child: ListView(
        padding: EdgeInsets.fromLTRB(
            context.pagePadding, 12, context.pagePadding, 24),
        children: [
          Autocomplete<String>(
            optionsBuilder: (value) {
              if (value.text.trim().length < 2) return const Iterable<String>.empty();
              return engine?.complete(value.text, limit: 8) ?? const <String>[];
            },
            onSelected: (model) {
              _add(model);
              _inputController?.clear();
            },
            fieldViewBuilder: (context, controller, focusNode, _) {
              _inputController = controller;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) {
                  _add(v);
                  controller.clear();
                },
                decoration: const InputDecoration(
                  hintText: 'Add a model, e.g. Redmi 9A',
                  prefixIcon: Icon(Icons.add_rounded),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in _models)
                EntranceFade(
                  child: InputChip(
                    label: Text(m),
                    onDeleted: () {
                      Haptics.warn();
                      setState(
                          () => _models = _models.where((x) => x != m).toList());
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_models.length < 2)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    CompatibilityGlyph(matched: false, color: scheme.primary),
                    Gap.lg,
                    Text('Add two models',
                        style: Theme.of(context).textTheme.titleMedium),
                    Gap.sm,
                    Text(
                      'See which universal parts cover both — useful before '
                      'you buy stock.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else if (shared.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_off_rounded, color: scheme.onErrorContainer),
                  Gap.wMd,
                  Expanded(
                    child: Text(
                      'No shared universal part. These models need separate parts.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF17A673), Color(0xFF0E8A5F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF17A673).withValues(alpha: 0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const CompatibilityGlyph(matched: true, color: Colors.white),
                      Gap.md,
                      Text(
                        'One part fits all ${_models.length}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Shared in ${shared.length} '
                        '${shared.length == 1 ? "category" : "categories"}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                SuccessBurst(trigger: _matchToken, color: Colors.white),
              ],
            ),
            Gap.md,
            for (final part in shared)
              Card(
                child: ListTile(
                  leading: Icon(iconFor(part.category.icon),
                      color: accentFor(part.category.icon, scheme)),
                  title: Text(part.category.name),
                  subtitle: Text('${part.group.title}\n${part.group.code}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: part.group.oneLine)),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          if (_models.isNotEmpty) ...[
            const SectionHeader(title: 'Per model'),
            for (final profile in profiles)
              Card(
                child: ListTile(
                  title: Text(profile.model),
                  subtitle: Text(profile.isEmpty
                      ? 'Not found in the catalog'
                      : '${profile.parts.length} part lists'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ModelScreen(model: profile.model),
                  )),
                ),
              ),
          ],
        ],
        ),
      ),
    );
  }

  /// A part is shared when the same group code appears for every model.
  List<ModelPart> _sharedParts(List<ModelProfile> profiles) {
    if (profiles.length < 2) return const [];
    if (profiles.any((p) => p.isEmpty)) return const [];
    final first = profiles.first.parts;
    return first.where((part) {
      return profiles.skip(1).every((p) =>
          p.parts.any((other) => other.group.code == part.group.code));
    }).toList();
  }

  String _summary(List<ModelPart> shared) {
    final buffer = StringBuffer('Shared universal parts\n');
    buffer.writeln('Models: ${_models.join(', ')}\n');
    for (final part in shared) {
      buffer.writeln('${part.category.name}: ${part.group.title} '
          '(${part.group.code})');
    }
    buffer.write('\nvia Combo Universal app');
    return buffer.toString();
  }
}
