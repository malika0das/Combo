import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import '../motion.dart';
import '../responsive.dart';
import '../services/catalog_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'policy_screen.dart';

/// Settings: appearance, data and legal, in the same editorial card language
/// as the rest of the app.
///
/// What makes this screen feel finished rather than merely functional:
///  * the page is centred and width-limited on tablets ([PageBody]), so rows
///    never stretch across a foldable;
///  * sections cascade in with the same [EntranceFade] stagger as Home;
///  * every tappable row haptics the same way the rest of the app does;
///  * the text-size control owns a full-width row with `A`/`A` gutters,
///    because it is the accessibility feature users come here for;
///  * the update row reports the real state of the catalog - including "this
///    build ships updates off" - instead of pretending a check always means
///    something.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final pad = context.pagePadding;
    return AnimatedBuilder(
      animation: Listenable.merge([scope.prefs, scope.catalog, scope.ads]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: PageBody(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 28),
            children: [
              const EntranceFade(
                index: 0,
                child: SectionHeader(
                  title: 'Appearance',
                  subtitle: 'How the app looks and behaves on your device.',
                ),
              ),
              EntranceFade(index: 1, child: _appearanceCard(scope, context)),
              Gap.lg,
              const EntranceFade(
                index: 2,
                child: SectionHeader(
                  title: 'Data',
                  subtitle: 'What lives on this device, and what updates.',
                ),
              ),
              EntranceFade(index: 3, child: _dataCard(scope, context)),
              Gap.lg,
              const EntranceFade(
                index: 4,
                child: SectionHeader(
                  title: 'Legal',
                  subtitle: 'Policies, licences and the disclaimer.',
                ),
              ),
              EntranceFade(index: 5, child: _legalCard(context)),
              Gap.xl,
              const EntranceFade(index: 6, child: _VersionFooter()),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single settings row: leading icon, title, optional subtitle and optional
/// trailing widget. One consistent rhythm for every row, and the same haptic
/// vocabulary as the rest of the app.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing = const Icon(Icons.chevron_right_rounded),
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: trailing,
    onTap: () {
      Haptics.tap();
      onTap();
    },
  );
}

/// The appearance group: dark theme, text size and the ad-safety controls.
Widget _appearanceCard(AppScope scope, BuildContext context) {
  final prefs = scope.prefs;
  final theme = Theme.of(context);
  return Card(
    child: Column(
      children: [
        // The leading icon swaps between sun and moon so the toggle's meaning
        // stays legible at a glance as well as by label.
        SwitchListTile(
          title: const Text('Dark theme'),
          subtitle: const Text('Warm dark surfaces for a low-light bench.'),
          secondary: SoftSwitcher(
            child: Icon(
              prefs.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              key: ValueKey(prefs.dark),
            ),
          ),
          value: prefs.dark,
          onChanged: (v) {
            Haptics.confirm();
            prefs.setDark(v);
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.format_size_rounded),
          title: const Text('Text size'),
          subtitle: const Text('Scales every screen, from 85% to 150%.'),
          trailing: SoftSwitcher(
            child: Text(
              '${(prefs.fontScale * 100).round()}%',
              key: ValueKey((prefs.fontScale * 100).round()),
              style: theme.textTheme.labelMedium,
            ),
          ),
        ),
        const Divider(height: 1),
        // The slider owns a full-width row: it is the accessibility control
        // this section exists for, and it needs room to be grabbed by a
        // finger on a repair bench. The A/A gutters say "smaller" and
        // "larger" in the most direct possible way.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Text(
                'A',
                style: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: prefs.fontScale,
                  min: 0.85,
                  max: 1.5,
                  divisions: 13,
                  label: '${(prefs.fontScale * 100).round()}%',
                  onChanged: (v) {
                    Haptics.confirm();
                    prefs.setFontScale(v);
                  },
                ),
              ),
              Text(
                'A',
                style: theme.textTheme.labelLarge?.copyWith(fontSize: 20),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Personalised ads'),
          subtitle: const Text(
            'Turn off to see only non-personalised ads. The app stays free '
            'either way.',
          ),
          secondary: const Icon(Icons.ads_click_rounded),
          value: prefs.personalizedAds,
          onChanged: (v) {
            Haptics.confirm();
            prefs.setPersonalizedAds(v);
            scope.ads.setPersonalized(v);
          },
        ),
        // Google requires EEA/UK users to be able to revisit their consent
        // choice at any time from a persistent control.
        if (scope.ads.privacyOptionsRequired) ...[
          const Divider(height: 1),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy options',
            subtitle: 'Review or change your ad consent choices.',
            onTap: () => scope.ads.showPrivacyOptions(),
          ),
        ],
      ],
    ),
  );
}

/// The data group: catalog update and sharing.
Widget _dataCard(AppScope scope, BuildContext context) {
  final catalog = scope.catalog;
  return Card(
    child: Column(
      children: [
        _Tile(
          icon: Icons.download_rounded,
          title: 'Check for list update',
          subtitle: _updateStatus(catalog),
          trailing: catalog.refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final updated = await _checkForUpdate(scope, context);
            if (updated == null || !context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  updated
                      ? 'List updated.'
                      : 'You already have the latest list.',
                ),
              ),
            );
          },
        ),
        const Divider(height: 1),
        // Shared through the system share sheet - the app never opens an
        // external URL or hardcodes a store link.
        _Tile(
          icon: Icons.share_rounded,
          title: 'Share this app',
          subtitle: 'Recommend it to another technician.',
          onTap: () => Share.share(
            'Combo Universal \u2014 universal combo, battery, glass '
            'and board compatibility list for mobile repair technicians.',
          ),
        ),
      ],
    ),
  );
}

/// The legal group: policy screens and the licence notices.
Widget _legalCard(BuildContext context) {
  void open(PolicyKind kind) {
    Haptics.tap();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PolicyScreen(kind: kind)));
  }

  return Card(
    child: Column(
      children: [
        _Tile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          onTap: () => open(PolicyKind.privacy),
        ),
        const Divider(height: 1),
        _Tile(
          icon: Icons.gavel_rounded,
          title: 'Terms & disclaimer',
          onTap: () => open(PolicyKind.terms),
        ),
        const Divider(height: 1),
        // The SIL OFL and Apache-2.0 both require their notices to be viewable
        // by the end user, not just present in the bundle.
        _Tile(
          icon: Icons.description_outlined,
          title: 'Open source licences',
          onTap: () => open(PolicyKind.licences),
        ),
      ],
    ),
  );
}

/// One honest line about the catalog: what version, from where, and whether an
/// update can even be attempted on this build.
String _updateStatus(CatalogService catalog) {
  final version = catalog.catalog?.version;
  if (version == null) return 'Loading the bundled list\u2026';
  if (CatalogService.remoteUrl.isEmpty) {
    return 'List v$version \u00b7 this build ships updates off';
  }
  return switch (catalog.source) {
    'online update' => 'List v$version \u00b7 up to date online',
    'cached update' => 'List v$version \u00b7 from a previous update',
    _ => 'List v$version \u00b7 bundled, tap to check',
  };
}

/// Checks for a newer list, or explains on builds without a remote catalog.
/// Returns null when nothing was attempted (updates off / already running).
Future<bool?> _checkForUpdate(AppScope scope, BuildContext context) async {
  if (CatalogService.remoteUrl.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updates are turned off for this build.')),
      );
    }
    return null;
  }
  if (scope.catalog.refreshing) return null;
  return scope.catalog.refreshFromRemote(userInitiated: true);
}

/// Brand and version line at the bottom of Settings.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) => Center(
        child: Text(
          snap.hasData
              ? 'Combo Universal \u00b7 v${snap.data!.version} '
                    '(${snap.data!.buildNumber})'
              : '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
