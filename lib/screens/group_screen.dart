import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import '../models/catalog.dart';
import '../motion.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/highlight_text.dart';
import '../widgets/ui.dart';
import 'model_screen.dart';

/// Compact card used in brand and search lists.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    required this.query,
    required this.subtitle,
    this.categoryIcon,
    this.categoryTint,
  });

  final ComboGroup group;
  final String query;
  final String subtitle;

  /// Optional part-category identity. When set, a small tinted tile leads the
  /// card so a mixed list (search results, saved lists) can be scanned by
  /// colour the same way the home grid is.
  final IconData? categoryIcon;
  final Color? categoryTint;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final preview = group.models.take(4).toList();
    return PressableScale(
      onTap: () {
        scope.ads.maybeShowInterstitial();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GroupScreen(group: group, query: query),
        ));
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (categoryIcon != null && categoryTint != null) ...[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: categoryTint!.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryIcon, size: 19, color: categoryTint),
                    ),
                    Gap.wMd,
                  ],
                  Expanded(
                    child: HighlightText(
                      text: group.title,
                      query: query,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: scope.prefs,
                    builder: (context, _) => IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: scope.prefs.inStockList(group.code)
                          ? 'In order list'
                          : 'Add to order list',
                      icon: SoftSwitcher(
                        child: Icon(
                          scope.prefs.inStockList(group.code)
                              ? Icons.shopping_cart_rounded
                              : Icons.add_shopping_cart_outlined,
                          key: ValueKey(scope.prefs.inStockList(group.code)),
                          size: 20,
                          color: scope.prefs.inStockList(group.code)
                              ? scheme.primary
                              : null,
                        ),
                      ),
                      onPressed: () {
                        scope.prefs.inStockList(group.code)
                            ? Haptics.warn()
                            : Haptics.confirm();
                        scope.prefs.toggleStock(group.code);
                      },
                    ),
                  ),
                  AnimatedBuilder(
                    animation: scope.prefs,
                    builder: (context, _) => IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Save',
                      icon: SoftSwitcher(
                        child: Icon(
                          scope.prefs.isSaved(group.code)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          key: ValueKey(scope.prefs.isSaved(group.code)),
                          color: scope.prefs.isSaved(group.code)
                              ? scheme.primary
                              : null,
                        ),
                      ),
                      onPressed: () {
                        scope.prefs.isSaved(group.code)
                            ? Haptics.warn()
                            : Haptics.confirm();
                        scope.prefs.toggleSaved(group.code);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '$subtitle · ${group.quality}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Gap.wSm,
                  SoftBadge(
                    label: '${group.models.length}',
                    icon: Icons.smartphone_rounded,
                    dense: true,
                    color: scheme.primary,
                  ),
                ],
              ),
              Gap.md,
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in preview)
                    _ModelChip(model: m, query: query),
                  if (group.models.length > preview.length)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: scheme.primary.withValues(alpha: 0.08),
                      side: BorderSide.none,
                      label: Text(
                        '+${group.models.length - preview.length}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.model, required this.query});

  final String model;
  final String query;

  @override
  Widget build(BuildContext context) {
    // Tapping a model chip now opens its full profile — every part that fits
    // it — instead of being a dead end.
    return ActionChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: HighlightText(
        text: model,
        query: query,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
      ),
      onPressed: () {
        Haptics.tap();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ModelScreen(model: model),
        ));
      },
    );
  }
}

/// Renders the compatible-model rows. Groups larger than [_previewCount] only
/// render a preview until the user asks for the rest, which keeps opening a
/// 105-model glass list instant.
class _ModelList extends StatefulWidget {
  const _ModelList({required this.group, required this.query});

  final ComboGroup group;
  final String query;

  @override
  State<_ModelList> createState() => _ModelListState();
}

class _ModelListState extends State<_ModelList> {
  static const _previewCount = 25;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final models = widget.group.models;
    final showAll = _expanded || models.length <= _previewCount;
    final count = showAll ? models.length : _previewCount;

    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          ListTile(
            dense: true,
            leading: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${i + 1}', style: AppFonts.code(context, size: 10.5)),
            ),
            title: HighlightText(text: models[i], query: widget.query),
            onTap: () {
              Haptics.tap();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ModelScreen(model: models[i]),
              ));
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Copy model',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Haptics.confirm();
                    Clipboard.setData(ClipboardData(text: models[i]));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied ${models[i]}')),
                    );
                  },
                ),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
          if (i != count - 1)
            const Divider(height: 1, indent: 16, endIndent: 16),
        ],
        if (!showAll) ...[
          const Divider(height: 1),
          TextButton.icon(
            onPressed: () {
              Haptics.tap();
              setState(() => _expanded = true);
            },
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            label: Text('Show all ${models.length} models'),
          ),
        ],
      ],
    );
  }
}

Future<void> _editNote(
    BuildContext context, AppScope scope, String code, String current) async {
  final controller = TextEditingController(text: current);
  try {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Shop note'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. Rs 850 • rack B2'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save')),
      ],
    ),
  );
  if (result != null) await scope.prefs.setNote(code, result);
  } finally {
    // The dialog owns a controller that must be released, otherwise every
    // note edit leaks one for the lifetime of the app.
    controller.dispose();
  }
}

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key, required this.group, this.query = ''});

  final ComboGroup group;
  final String query;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compatibility list'),
        actions: [
          AnimatedBuilder(
            animation: scope.prefs,
            builder: (context, _) => IconButton(
              tooltip: 'Save',
              icon: Icon(scope.prefs.isSaved(group.code)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded),
              onPressed: () => scope.prefs.toggleSaved(group.code),
            ),
          ),
          AnimatedBuilder(
            animation: scope.prefs,
            builder: (context, _) => IconButton(
              tooltip: 'Add to order list',
              icon: Icon(scope.prefs.inStockList(group.code)
                  ? Icons.shopping_cart_rounded
                  : Icons.add_shopping_cart_outlined),
              onPressed: () {
                scope.prefs.inStockList(group.code)
                    ? Haptics.warn()
                    : Haptics.confirm();
                scope.prefs.toggleStock(group.code);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(scope.prefs.inStockList(group.code)
                      ? 'Added to order list'
                      : 'Removed from order list'),
                ));
              },
            ),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => Share.share(group.shareText),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: group.shareText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('List copied')),
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: BannerAdSlot(ads: scope.ads),
      body: PageBody(
        child: ListView(
        padding: EdgeInsets.fromLTRB(
            context.pagePadding, 12, context.pagePadding, 24),
        children: [
          Text(group.title, style: Theme.of(context).textTheme.headlineSmall),
          Gap.md,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CodeChip(code: group.code),
              if (group.quality.isNotEmpty)
                SoftBadge(label: group.quality, color: scheme.primary),
              SoftBadge(
                label: '${group.models.length} models',
                icon: Icons.smartphone_rounded,
                color: scheme.tertiary,
              ),
            ],
          ),
          if (group.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: scheme.onTertiaryContainer),
                  Gap.wSm,
                  Expanded(
                    child: Text(
                      group.note,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: scope.prefs,
            builder: (context, _) {
              final note = scope.prefs.noteFor(group.code);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_note_rounded),
                  title: Text(note.isEmpty ? 'Add a shop note' : note),
                  subtitle: const Text('Price, shelf, supplier — stays on this device'),
                  onTap: () => _editNote(context, scope, group.code, note),
                ),
              );
            },
          ),
          Gap.xl,
          SectionHeader(
            title: 'Compatible models',
            subtitle: 'Tap a model to see every part that fits it',
            trailing: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: group.models.join('\n')));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All models copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy_all_outlined, size: 16),
              label: const Text('Copy all'),
            ),
          ),
          Card(
            // sliver-free but lazy: ListView.separated inside a ListView needs
            // shrinkWrap, which builds every child up-front. With up to 105
            // models per group that cost a visible hitch on open, so the list
            // is built manually and long lists are paged behind a "show all".
            child: _ModelList(group: group, query: query),
          ),
          Gap.lg,
          const VerifyNotice(),
        ],
        ),
      ),
    );
  }
}
