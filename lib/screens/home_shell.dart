import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../motion.dart';
import '../responsive.dart';
import '../widgets/banner_ad_slot.dart';
import 'compare_screen.dart';
import 'home_screen.dart';
import 'models_az_screen.dart';
import 'stock_screen.dart';

/// Tab indices, shared with HomeScreen quick actions so they can switch tabs
/// instead of pushing duplicate screens on top of the shell.
const tabHome = 0, tabAz = 1, tabCompare = 2, tabOrder = 3;

const _destinations = [
  NavigationRailDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
    label: Text('Home'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.abc_rounded),
    selectedIcon: Icon(Icons.abc_rounded),
    label: Text('A–Z'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.compare_arrows_outlined),
    selectedIcon: Icon(Icons.compare_arrows_rounded),
    label: Text('Compare'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.shopping_cart_outlined),
    selectedIcon: Icon(Icons.shopping_cart_rounded),
    label: Text('Order'),
  ),
];

/// The app's root navigation shell. Home, A–Z, Compare and Order live in an
/// [IndexedStack] so each tab keeps its scroll position.
///
/// On **compact** screens (phones) the destinations sit in a bottom
/// [NavigationBar] with a banner ad above it.  On **wide** screens (tablets,
/// foldables, landscape) a [NavigationRail] is shown on the leading edge
/// instead, freeing vertical space for content.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = tabHome;

  void _go(int index) {
    if (index == _tab) return;
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final wide = context.isWide;

    final body = IndexedStack(
      index: _tab,
      children: [
        HomeScreen(onOpenTab: _go),
        const ModelsAzScreen(),
        const CompareScreen(),
        const StockScreen(),
      ],
    );

    if (wide) {
      // ── Wide layout: rail on the left, content fills the rest ──────────
      return Scaffold(
        body: Row(
          children: [
            _buildRail(),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // ── Compact layout: bottom bar with ad above ─────────────────────────
    return Scaffold(
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BannerAdSlot(ads: scope.ads),
          _buildBottomBar(scope),
        ],
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────

  Widget _buildRail() {
    return NavigationRail(
      selectedIndex: _tab,
      onDestinationSelected: (i) {
        Haptics.tap();
        _go(i);
      },
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 16),
        child: Tooltip(
          message: 'Combo Universal',
          child: Icon(Icons.hexagon_rounded, size: 28),
        ),
      ),
      destinations: _destinations,
    );
  }

  Widget _buildBottomBar(AppScope scope) {
    return AnimatedBuilder(
      animation: scope.prefs,
      builder: (context, _) {
        final count = scope.prefs.stock.length;
        return NavigationBar(
          height: 72,
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            Haptics.tap();
            _go(i);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.abc_rounded),
              selectedIcon: Icon(Icons.abc_rounded),
              label: 'A–Z',
            ),
            const NavigationDestination(
              icon: Icon(Icons.compare_arrows_outlined),
              selectedIcon: Icon(Icons.compare_arrows_rounded),
              label: 'Compare',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: const Icon(Icons.shopping_cart_rounded),
              label: 'Order',
            ),
          ],
        );
      },
    );
  }
}
