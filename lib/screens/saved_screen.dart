import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/catalog.dart';
import '../motion.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/ui.dart';
import 'group_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([scope.prefs, scope.catalog]),
      builder: (context, _) {
        final catalog = scope.catalog.catalog;
        final saved = <(Category, Brand, ComboGroup)>[];
        if (catalog != null) {
          for (final c in catalog.categories) {
            for (final b in c.brands) {
              for (final g in b.groups) {
                if (scope.prefs.isSaved(g.code)) {
                  saved.add((c, b, g));
                }
              }
            }
          }
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Saved lists')),
          bottomNavigationBar: BannerAdSlot(ads: scope.ads),
          body: saved.isEmpty
              ? const EmptyState(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Nothing saved yet',
                  message:
                      'Tap the bookmark icon on any list to keep it here for '
                      'quick offline access.',
                )
              : PageBody(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        context.pagePadding, 12, context.pagePadding, 24),
                    itemCount: saved.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final (category, brand, group) = saved[i];
                      final scheme = Theme.of(context).colorScheme;
                      return EntranceFade(
                        index: i,
                        child: GroupCard(
                          group: group,
                          query: '',
                          subtitle: '${category.name} • ${brand.name}',
                          categoryIcon: iconFor(category.icon),
                          categoryTint: accentFor(category.icon, scheme),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
