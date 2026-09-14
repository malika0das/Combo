import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import '../models/catalog.dart';
import '../motion.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'group_screen.dart';

/// A purchase / stock list the shop builds while browsing, then sends to a
/// supplier over WhatsApp in one tap.
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([scope.prefs, scope.catalog]),
      builder: (context, _) {
        final catalog = scope.catalog.catalog;
        final items = <(Category, Brand, ComboGroup)>[];
        if (catalog != null) {
          for (final c in catalog.categories) {
            for (final b in c.brands) {
              for (final g in b.groups) {
                if (scope.prefs.inStockList(g.code)) items.add((c, b, g));
              }
            }
          }
        }
        final text = _orderText(scope, items);
        final pieces =
            items.fold<int>(0, (a, e) => a + scope.prefs.qtyFor(e.$3.code));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Order list'),
            actions: [
              if (items.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Send / share',
                  icon: const Icon(Icons.send_rounded),
                  onPressed: () => Share.share(text),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order list copied')),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Clear list',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClear(context, scope),
                ),
              ],
            ],
          ),
          body: items.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your order list is empty',
                  message:
                      'Tap the cart icon on any part list to add it here, then '
                      'send the whole order to your supplier in one tap.',
                )
              : PageBody(
                  child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      context.pagePadding, 12, context.pagePadding, 24),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    // Summary + primary action. The send affordance used to
                    // live only in the app bar, which technicians rarely look
                    // at mid-task — a CTA at the top of the list is where the
                    // eye lands first.
                    if (i == 0) {
                      return EntranceFade(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      items.length == 1
                                          ? '1 list ready to send'
                                          : '${items.length} lists ready to send',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pieces > items.length
                                          ? '$pieces pieces · notes travel with the order.'
                                          : 'Notes travel with the order.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Gap.wMd,
                              FilledButton.icon(
                                onPressed: () => Share.share(text),
                                icon: const Icon(Icons.send_rounded, size: 18),
                                label: const Text('Send'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final (category, brand, group) = items[i - 1];
                    final code = group.code;
                    final note = scope.prefs.noteFor(code);
                    final qty = scope.prefs.qtyFor(code);
                    return EntranceFade(
                      index: i,
                      // Swipe left to remove, with an undo — faster than
                      // hunting for a small remove button on a busy card.
                      child: Dismissible(
                        key: ValueKey('stock_$code'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          Haptics.warn();
                          scope.prefs.toggleStock(code);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Removed ${group.title}'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => scope.prefs.toggleStock(code),
                            ),
                          ));
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              color:
                                  Theme.of(context).colorScheme.onErrorContainer),
                        ),
                        child: Card(
                        child: ListTile(
                          title: Text(group.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${category.name} · ${brand.name} · ${group.code}'
                            '${note.isEmpty ? '' : '\nNote: $note'}',
                          ),
                          isThreeLine: note.isNotEmpty,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => GroupScreen(group: group),
                          )),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Note',
                                icon: const Icon(Icons.edit_note_rounded),
                                onPressed: () =>
                                    _editNote(context, scope, code, note),
                              ),
                              // Quantity stepper: how many pieces of this
                              // list go on the order. Lands in the shared text.
                              IconButton(
                                tooltip: 'Fewer pieces',
                                icon: const Icon(
                                    Icons.remove_circle_outline_rounded),
                                onPressed: qty > 1
                                    ? () => scope.prefs.setQty(code, qty - 1)
                                    : null,
                              ),
                              Text('x$qty',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700)),
                              IconButton(
                                tooltip: 'More pieces',
                                icon: const Icon(
                                    Icons.add_circle_outline_rounded),
                                onPressed: () =>
                                    scope.prefs.setQty(code, qty + 1),
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                    );
                  },
                  ),
                ),
        );
      },
    );
  }

  String _orderText(AppScope scope, List<(Category, Brand, ComboGroup)> items) {
    final buffer = StringBuffer('Parts order list\n');
    for (var i = 0; i < items.length; i++) {
      final (category, _, group) = items[i];
      final note = scope.prefs.noteFor(group.code);
      final qty = scope.prefs.qtyFor(group.code);
      buffer.writeln('${i + 1}. [${category.name}] ${group.title} '
          '(${group.code}) x$qty${note.isEmpty ? '' : ' — $note'}');
    }
    buffer.write('\nvia Combo Universal app');
    return buffer.toString();
  }

  Future<void> _editNote(
      BuildContext context, AppScope scope, String code, String current) async {
    final controller = TextEditingController(text: current);
    try {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Qty, price, shelf or supplier',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) await scope.prefs.setNote(code, result);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmClear(BuildContext context, AppScope scope) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear order list?'),
        content: const Text('This removes every item from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) await scope.prefs.clearStock();
  }
}
