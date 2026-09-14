import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../format.dart';
import '../models/catalog.dart';
import '../motion.dart';
import '../responsive.dart';
import '../services/insight_service.dart';
import '../theme.dart';
import '../widgets/animated_icons.dart';
import '../widgets/insight_card.dart';
import '../widgets/stat_tile.dart';
import '../widgets/ui.dart';
import 'category_screen.dart';
import 'compare_screen.dart';
import 'home_shell.dart';
import 'model_screen.dart';
import 'models_az_screen.dart';
import 'saved_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenTab});

  /// When running inside [HomeShell], quick actions and the proactive
  /// suggestion switch tabs instead of pushing duplicate screens. When null
  /// (e.g. an old push path), each action falls back to a plain push.
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([scope.catalog, scope.prefs]),
      builder: (context, _) {
        final catalog = scope.catalog.catalog;
        return Scaffold(
          appBar: AppBar(
            title: const _BrandTitle(),
            actions: [
              _HomeHeaderAction(
                tooltip: 'Saved lists',
                icon: Icons.bookmarks_rounded,
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SavedScreen())),
              ),
              _HomeHeaderAction(
                tooltip: 'Settings',
                icon: Icons.settings_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          body: scope.catalog.loading
              ? const Center(child: CircularProgressIndicator())
              : catalog == null
              ? _ErrorState(onRetry: () => scope.catalog.init())
              : RefreshIndicator(
                  onRefresh: () async {
                    final updated = await scope.catalog.refreshFromRemote(
                      userInitiated: true,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            updated
                                ? 'List updated to the latest version.'
                                : 'You already have the latest list.',
                          ),
                        ),
                      );
                    }
                  },
                  child: _Body(catalog: catalog, onOpenTab: onOpenTab),
                ),
        );
      },
    );
  }
}

class _HomeHeaderAction extends StatelessWidget {
  const _HomeHeaderAction({
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

class _Body extends StatelessWidget {
  const _Body({required this.catalog, this.onOpenTab});

  final Catalog catalog;
  final ValueChanged<int>? onOpenTab;

  /// Switches to a shell tab when one is available, otherwise pushes the
  /// screen directly (kept for any path that builds HomeScreen standalone).
  void _openTab(BuildContext context, int index) {
    final cb = onOpenTab;
    if (cb != null) {
      cb(index);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => switch (index) {
          tabAz => const ModelsAzScreen(),
          tabCompare => const CompareScreen(),
          _ => const StockScreen(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final recent = scope.prefs.recent;
    final theme = Theme.of(context);
    final pad = context.pagePadding;
    final modelCount = catalog.modelCount;

    final insight = const InsightService().build(
      prefs: scope.prefs,
      catalog: catalog,
      engine: scope.catalog.engine,
    );
    final showInsight =
        insight != null && !scope.prefs.isInsightDismissed(insight.id);

    return PageBody(
      maxWidth: 960,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 4, pad, 28),
        children: [
          const EntranceFade(index: 0, child: _Greeting()),
          Gap.md,
          EntranceFade(
            index: 1,
            child: _SearchBox(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
          ),
          Gap.md,
          EntranceFade(
            index: 2,
            child: _GlanceTiles(catalog: catalog, modelCount: modelCount),
          ),
          if (showInsight) ...[
            Gap.md,
            InsightCard(
              insight: insight,
              onDismiss: () => scope.prefs.dismissInsight(insight.id),
              onAction: () => _runInsight(context, insight),
            ),
          ],
          if (recent.isNotEmpty) ...[
            Gap.lg,
            EntranceFade(
              index: 2,
              child: SectionHeader(
                title: 'Recent searches',
                trailing: TextButton(
                  onPressed: scope.prefs.clearRecent,
                  child: const Text('Clear'),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                primary: false,
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final query = recent[index];
                  return ActionChip(
                    avatar: const Icon(Icons.history_rounded, size: 15),
                    label: Text(query),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(initialQuery: query),
                      ),
                    ),
                  );
                },
              ),
            ),
            Gap.lg,
          ],
          EntranceFade(
            index: 2,
            child: Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.compare_arrows_rounded,
                    label: 'Compare',
                    caption: 'one part, two phones',
                    tint: const Color(0xFF9B5DE5),
                    phase: 0.00,
                    onTap: () => _openTab(context, tabCompare),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.sort_by_alpha_rounded,
                    label: 'A\u2013Z',
                    caption: 'all models',
                    tint: const Color(0xFF00A3C4),
                    phase: 0.33,
                    onTap: () => _openTab(context, tabAz),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Order',
                    caption: 'send to supplier',
                    tint: const Color(0xFF17A673),
                    phase: 0.66,
                    onTap: () => _openTab(context, tabOrder),
                  ),
                ),
              ],
            ),
          ),
          Gap.xl,
          const SectionHeader(title: 'Browse by part'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: catalog.categories.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: context.isWide ? 240 : 210,
              // A fixed extent rather than an aspect ratio: the tile content is a
              // fixed three-line stack, so a ratio clips it as soon as the tile
              // gets wide (tablets) or the text scale goes up. The extent grows
              // with the text scale for the same reason.
              mainAxisExtent: statTileExtent(context),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, i) {
              final c = catalog.categories[i];
              return EntranceFade(
                index: 3 + i,
                child: _CategoryCard(category: c, phase: (i * 0.37) % 1),
              );
            },
          ),
          Gap.xl,
          VerifyNotice(text: catalog.notice),
          Gap.md,
          Center(
            child: Text(
              'List v${catalog.version} · updated ${catalog.updatedAt}',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  void _runInsight(BuildContext context, Insight insight) {
    if (insight.actionModel != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ModelScreen(model: insight.actionModel!),
        ),
      );
      return;
    }
    if (insight.actionQuery != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SearchScreen(initialQuery: insight.actionQuery!),
        ),
      );
      return;
    }
    switch (insight.id) {
      case 'order_ready':
        _openTab(context, tabOrder);
      case 'compare_hint':
        final recent = AppScope.of(context).prefs.recent;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                CompareScreen(initialModels: recent.take(2).toList()),
          ),
        );
    }
  }
}

/// Editorial hero: eyebrow, big time-aware greeting with a trailing period,
/// and the sparkle motif — the reference design's signature move.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final engine = AppScope.of(context).catalog.engine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WELCOME BACK',
          // Semibold keeps this small all-caps eyebrow crisp across Android
          // text engines while the bundled font asset is loading.
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                '${InsightService.greeting(DateTime.now())}.',
                style: theme.textTheme.displaySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            const SparkStar(color: brandSeed, size: 46, phase: 0.3),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            AnimatedCounter(
              value: engine?.modelCount ?? 0,
              style: theme.textTheme.bodySmall,
            ),
            Text(' models ready offline', style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

/// Two high-signal totals keep the home screen useful at a glance: how many
/// model entries are covered and how many lists can be ordered. The cards stay
/// equal-height at larger text scales and never rely on a fragile aspect ratio.
class _GlanceTiles extends StatelessWidget {
  const _GlanceTiles({required this.catalog, required this.modelCount});

  final Catalog catalog;
  final int modelCount;

  @override
  Widget build(BuildContext context) {
    final lists = catalog.groupCount;
    final height = statTileExtent(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        final tiles = [
          SizedBox(
            height: height,
            child: StatTile(
              eyebrow: 'Models',
              value: modelCount,
              caption: 'ready offline',
              tint: brandSeed,
              icon: Icons.inventory_2_outlined,
              semanticsLabel: '${groupDigits(modelCount)} models ready offline',
            ),
          ),
          SizedBox(
            height: height,
            child: StatTile(
              eyebrow: 'Lists',
              value: lists,
              caption: 'in ${catalog.categories.length} part types',
              tint: const Color(0xFF9B5DE5),
              icon: Icons.format_list_bulleted_rounded,
              phase: 0.4,
              semanticsLabel: '${groupDigits(lists)} compatibility lists',
            ),
          ),
        ];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tiles[0],
              const SizedBox(height: 10),
              tiles[1],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 12),
            Expanded(child: tiles[1]),
          ],
        );
      },
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AnimatedBrandMark(),
        Gap.wSm,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Combo Universal',
              style: theme.textTheme.titleMedium?.copyWith(height: 1.05),
            ),
            Text(
              'Spare parts compatibility',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.caption,
    required this.tint,
    required this.onTap,
    this.phase = 0,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color tint;
  final VoidCallback onTap;

  /// Stagger for the breathing icon loop, so the three actions never pulse
  /// in lockstep.
  final double phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Flat pastel card: the accent IS the surface — no border, no elevation,
    // and no alpha wash, so text on top of it stays crisp.
    return Semantics(
      button: true,
      label: '$label, $caption',
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            color: pastelSurface(tint, scheme),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BreathingIcon(
                icon: icon,
                tint: tint,
                iconSize: 18,
                containerSize: 34,
                borderRadius: 11,
                phase: phase,
                tileColor: scheme.surface,
              ),
              Gap.sm,
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 13.5,
                  color: pastelInk(scheme),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w600,
                  color: pastelInkMuted(scheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Hero(
      tag: 'searchbox',
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(30),
        child: PressableScale(
          scale: 0.985,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: brandSeed.withValues(alpha: 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                PingIcon(
                  icon: Icons.search_rounded,
                  tint: scheme.primary,
                  size: 21,
                ),
                Gap.wSm,
                Expanded(
                  child: _RotatingHint(
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tap',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cycles through example searches so the empty search field teaches the app's
/// range without a tutorial. Pauses entirely under reduced-motion.
class _RotatingHint extends StatefulWidget {
  const _RotatingHint({this.style});

  final TextStyle? style;

  @override
  State<_RotatingHint> createState() => _RotatingHintState();
}

class _RotatingHintState extends State<_RotatingHint> {
  static const _hints = [
    'Search a model, part or code',
    'Try "Redmi 9A battery"',
    'Try "vivo y17 glass"',
    'Try "BN4A"',
  ];

  int _i = 0;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Stop cycling while the app is backgrounded: the rebuilds are invisible
    // but still cost wakeups and battery.
    _lifecycle = AppLifecycleListener(
      onHide: _stop,
      onPause: _stop,
      onShow: _start,
      onRestart: _start,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Under reduced motion only the first hint is ever shown, so the timer
    // would rebuild the widget to no visible effect.
    if (Motion.reduced(context)) {
      _stop();
    } else {
      _start();
    }
  }

  void _start() {
    if (_timer != null || !mounted) return;
    if (Motion.reduced(context)) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _hints.length);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return Text(
        _hints.first,
        style: widget.style,
        overflow: TextOverflow.ellipsis,
      );
    }
    return AnimatedSwitcher(
      duration: Motion.base,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        _hints[_i],
        key: ValueKey(_i),
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, this.phase = 0});

  final Category category;

  /// Stagger for the breathing icon so grid neighbours pulse out of sync.
  final double phase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accentFor(category.icon, scheme);
    return StatTile(
      // The tile leads with how much is inside the list; the part type is the
      // label above it, because that is the order a technician scans in:
      // "which of these covers the most?".
      eyebrow: category.name,
      value: category.modelCount,
      caption: '${category.groupCount} lists',
      semanticsLabel:
          '${category.name}: '
          '${groupDigits(category.modelCount)} models across '
          '${category.groupCount} lists',
      tint: tint,
      icon: iconFor(category.icon),
      phase: phase,
      onTap: () {
        AppScope.of(context).ads.maybeShowInterstitial();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CategoryScreen(category: category)),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load the list',
      message: 'The bundled data could not be read. Try again.',
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Retry'),
      ),
    );
  }
}
