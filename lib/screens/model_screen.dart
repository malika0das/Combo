import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import '../motion.dart';
import '../responsive.dart';
import '../services/search_engine.dart';
import '../theme.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/dimensional.dart';
import '../widgets/ui.dart';
import 'group_screen.dart';

/// Everything the catalog knows about one phone: which combo, battery, glass,
/// board and cover fit it, plus the other phones that share those parts.
class ModelScreen extends StatelessWidget {
  const ModelScreen({super.key, required this.model});

  final String model;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final profile = scope.catalog.engine?.profileFor(model);

    if (profile == null || profile.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(model, overflow: TextOverflow.ellipsis)),
        bottomNavigationBar: BannerAdSlot(ads: scope.ads),
        body: const EmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Nothing recorded yet',
          message: 'No universal parts are listed for this model.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.model, overflow: TextOverflow.ellipsis),
        actions: [
          _HeaderAction(
            tooltip: 'Share parts sheet',
            icon: Icons.share_rounded,
            onPressed: () {
              Haptics.tap();
              Share.share(_sheet(profile));
            },
          ),
          _HeaderAction(
            tooltip: 'Copy parts sheet',
            icon: Icons.content_copy_rounded,
            onPressed: () async {
              Haptics.tap();
              await Clipboard.setData(ClipboardData(text: _sheet(profile)));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Parts sheet copied')),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BannerAdSlot(ads: scope.ads),
      body: PageBody(
        maxWidth: 860,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            12,
            context.pagePadding,
            24,
          ),
          children: [
            EntranceFade(child: _ModelHero(profile: profile)),
            Gap.xl,
            SectionHeader(
              title: 'Compatible parts',
              subtitle: 'Open a part list to see codes and matching models',
              trailing: SoftBadge(
                label: '${profile.parts.length}',
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.inventory_2_outlined,
              ),
            ),
            for (final (index, part) in profile.parts.indexed) ...[
              EntranceFade(
                index: index,
                child: _PartListCard(
                  part: part,
                  onTap: () {
                    scope.ads.maybeShowInterstitial();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupScreen(
                          group: part.group,
                          query: profile.model,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (profile.siblings.isNotEmpty) ...[
              Gap.md,
              EntranceFade(
                index: profile.parts.length,
                child: _RelatedModelsPreview(
                  sourceModel: profile.model,
                  models: profile.siblings,
                  onOpenModel: (sibling) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ModelScreen(model: sibling),
                      ),
                    );
                  },
                ),
              ),
            ],
            Gap.xl,
            const VerifyNotice(),
          ],
        ),
      ),
    );
  }

  String _sheet(ModelProfile profile) {
    final buffer = StringBuffer('Universal parts for ${profile.model}\n');
    for (final part in profile.parts) {
      buffer.writeln(
        '\n${part.category.name}: ${part.group.title} '
        '(${part.group.code})',
      );
      buffer.writeln(
        'Also fits: ${part.group.models.take(12).join(', ')}'
        '${part.group.models.length > 12 ? ' …' : ''}',
      );
    }
    buffer.write('\nvia Combo Universal app');
    return buffer.toString();
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(42, 42),
          padding: const EdgeInsets.all(9),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _ModelHero extends StatelessWidget {
  const _ModelHero({required this.profile});

  final ModelProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TiltCard(
      maxTilt: 0.06,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4B3621), Color(0xFF21170F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final iconSize = compact ? 44.0 : 54.0;
            final stackMetrics = constraints.maxWidth < 260;
            final partsLabel = profile.parts.length == 1
                ? 'part list'
                : 'part lists';

            final partMetric = _HeroMetric(
              value: profile.parts.length,
              label: partsLabel,
              icon: Icons.format_list_bulleted_rounded,
            );
            final relatedMetric = _HeroMetric(
              value: profile.siblings.length,
              label: 'related models',
              icon: Icons.phone_android_rounded,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COMPATIBILITY PROFILE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: brandYellow,
                              fontSize: 10,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            profile.model,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              height: 1.14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: brandYellow.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(compact ? 14 : 18),
                        border: Border.all(
                          color: brandYellow.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Icon(
                        Icons.phone_android_rounded,
                        color: brandYellow,
                        size: 25,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (stackMetrics) ...[
                  partMetric,
                  const SizedBox(height: 12),
                  relatedMetric,
                ] else
                  Row(
                    children: [
                      Expanded(child: partMetric),
                      Container(
                        width: 1,
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        color: Colors.white24,
                      ),
                      Expanded(child: relatedMetric),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: brandYellow),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedCounter(
                value: value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PartListCard extends StatelessWidget {
  const _PartListCard({required this.part, required this.onTap});

  final ModelPart part;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accentFor(part.category.icon, scheme);
    final count = part.group.models.length;

    return Semantics(
      button: true,
      label:
          'Open ${part.category.name}: ${part.group.title}, fits $count models',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Haptics.tap();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      iconFor(part.category.icon),
                      color: tint,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.category.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          part.group.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            CodeChip(code: part.group.code, copyable: false),
                            SoftBadge(
                              label:
                                  'Fits $count ${count == 1 ? 'model' : 'models'}',
                              color: tint,
                              icon: Icons.groups_2_rounded,
                              dense: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: tint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RelatedModelsPreview extends StatelessWidget {
  const _RelatedModelsPreview({
    required this.sourceModel,
    required this.models,
    required this.onOpenModel,
  });

  final String sourceModel;
  final List<String> models;
  final ValueChanged<String> onOpenModel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewCount = constraints.maxWidth >= Breakpoints.medium
            ? 12
            : 6;
        final preview = models.take(previewCount).toList(growable: false);
        final remaining = models.length - preview.length;
        final chipMaxWidth = constraints.maxWidth > 160
            ? constraints.maxWidth - 32
            : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Related models',
              subtitle: 'Each shares at least one compatible part',
              trailing: SoftBadge(
                label: '${models.length}',
                color: scheme.primary,
                icon: Icons.phone_android_rounded,
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.account_tree_rounded,
                            size: 19,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            remaining > 0
                                ? 'Showing ${preview.length} of ${models.length} models'
                                : '${models.length} matching models',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final sibling in preview)
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: chipMaxWidth),
                            child: ActionChip(
                              label: Text(
                                sibling,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () {
                                Haptics.tap();
                                onOpenModel(sibling);
                              },
                            ),
                          ),
                      ],
                    ),
                    if (remaining > 0) ...[
                      const Divider(height: 28),
                      TextButton.icon(
                        onPressed: () {
                          Haptics.tap();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _RelatedModelsScreen(
                                sourceModel: sourceModel,
                                models: models,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text('View all ${models.length} models'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RelatedModelsScreen extends StatelessWidget {
  const _RelatedModelsScreen({required this.sourceModel, required this.models});

  final String sourceModel;
  final List<String> models;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Related models')),
      bottomNavigationBar: BannerAdSlot(ads: scope.ads),
      body: PageBody(
        maxWidth: 720,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            12,
            context.pagePadding,
            24,
          ),
          itemCount: models.length + 1,
          separatorBuilder: (context, index) =>
              SizedBox(height: index == 0 ? 16 : 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.hub_rounded,
                          color: scheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${models.length} matching models',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Each shares at least one compatible part with $sourceModel.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final related = models[index - 1];
            return Semantics(
              button: true,
              label: 'Open $related',
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.phone_android_rounded,
                      color: scheme.primary,
                      size: 21,
                    ),
                  ),
                  title: Text(related),
                  subtitle: const Text('View compatible parts'),
                  trailing: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                  onTap: () {
                    Haptics.tap();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ModelScreen(model: related),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
