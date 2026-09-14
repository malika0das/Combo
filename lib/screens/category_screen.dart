import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/catalog.dart';
import '../motion.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/brand_icon.dart';
import '../widgets/ui.dart';
import 'group_screen.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      bottomNavigationBar: BannerAdSlot(ads: scope.ads),
      body: PageBody(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final padding = EdgeInsets.fromLTRB(
              context.pagePadding,
              8,
              context.pagePadding,
              24,
            );
            final cards = [
              for (var i = 0; i < category.brands.length; i++)
                _BrandCard(
                  category: category,
                  brand: category.brands[i],
                  index: i,
                ),
            ];

            return ListView(
              padding: padding,
              children: [
                _CategoryHeader(category: category),
                const SizedBox(height: 18),
                if (wide)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 440,
                          mainAxisExtent: 112,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (context, i) => cards[i],
                  )
                else
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    cards[i],
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accentFor(category.icon, scheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(iconFor(category.icon), color: tint, size: 23),
            ),
            Gap.wMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a brand',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Select a brand to browse compatible parts.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SoftBadge(
              label: '${category.groupCount} lists',
              icon: Icons.format_list_bulleted_rounded,
              color: tint,
            ),
            SoftBadge(
              label: '${category.modelCount} models',
              icon: Icons.smartphone_rounded,
              color: scheme.tertiary,
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.category,
    required this.brand,
    required this.index,
  });

  final Category category;
  final Brand brand;
  final int index;

  @override
  Widget build(BuildContext context) {
    final style = brandStyle(brand.name);
    return EntranceFade(
      index: index,
      child: Semantics(
        button: true,
        label:
            '${brand.name}, ${brand.groups.length} lists, '
            '${brand.modelCount} models',
        child: PressableScale(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BrandScreen(category: category, brand: brand),
            ),
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  BrandIcon(name: brand.name),
                  Gap.wMd,
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brand.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${brand.groups.length} lists · ${brand.modelCount} models',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: style.color,
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

class BrandScreen extends StatefulWidget {
  const BrandScreen({super.key, required this.category, required this.brand});

  final Category category;
  final Brand brand;

  @override
  State<BrandScreen> createState() => _BrandScreenState();
}

class _BrandScreenState extends State<BrandScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final groups = q.isEmpty
        ? widget.brand.groups
        : widget.brand.groups
              .where(
                (g) =>
                    g.title.toLowerCase().contains(q) ||
                    g.code.toLowerCase().contains(q) ||
                    g.models.any((m) => m.toLowerCase().contains(q)),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.brand.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(height: 1.1),
            ),
            Text(
              widget.category.name,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Filter inside ${widget.brand.name}',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BannerAdSlot(ads: scope.ads),
      body: groups.isEmpty
          ? const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching list',
              message: 'Try a shorter keyword, or clear the filter.',
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                8,
                context.pagePadding,
                24,
              ),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => GroupCard(
                group: groups[i],
                query: _query,
                subtitle: widget.category.name,
                categoryIcon: iconFor(widget.category.icon),
                categoryTint: accentFor(widget.category.icon, scheme),
              ),
            ),
    );
  }
}
