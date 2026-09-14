import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';

/// Compact anchored banner slot. Renders nothing (zero height) until an ad
/// loads, so the layout never shows an empty grey block — required for a clean
/// UX and avoids accidental clicks near interactive controls.
///
/// The slot picks from Google's fixed banner ladder (320x50 / 468x60 / 728x90)
/// so the ad stays compact — the anchored-adaptive size Google returns can
/// reach ~15% of the viewport height, which reads as an oversized ad — and the
/// creative is never wider than the screen, so it is never clipped. A small
/// "Ad" disclosure badge sits above the creative so users can always
/// distinguish ads from content — required by Google policy.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key, required this.ads});

  final AdsService ads;

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  int _loadedForWidth = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Ads initialise asynchronously after first frame, so a slot built before
    // that used to request nothing and stay blank forever. Listening means the
    // banner appears as soon as the SDK is ready.
    widget.ads.addListener(_onAdsChanged);
  }

  void _onAdsChanged() {
    if (!mounted) return;
    // A consent or personalisation change invalidates the loaded creative,
    // even if the device width has not changed.
    final stale = _ad;
    final hadAd = stale != null || _loaded || _loadedForWidth != 0;
    _ad = null;
    _loaded = false;
    _loadedForWidth = 0;
    stale?.dispose();
    if (hadAd) setState(() {});
    _maybeLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  /// Nearest fixed banner size that fits `width`, so the ad never exceeds
  /// 90px of height and never renders narrower than the screen. Using the
  /// full-width anchored-adaptive size instead lets Google choose a height up
  /// to ~15% of the viewport, which looks oversized on phones and tablets.
  AdSize _pickSize(int width) {
    if (width >= 728) return AdSize.leaderboard; // 728x90
    if (width >= 468) return AdSize.fullBanner; // 468x60
    return AdSize.banner; // 320x50
  }

  /// Loads (or reloads) the banner for the current width. Rotating the device
  /// changes the correct banner size, and the old ad would otherwise be left
  /// stretched or clipped.
  Future<void> _maybeLoad() async {
    // SDK down or consent revoked: release whatever was rendered so no stale
    // ad lingers (or leaks) on screen. `_loadedForWidth` is reset so the slot
    // can reload cleanly when ads come back online.
    if (!widget.ads.supported || !widget.ads.initialized) {
      final stale = _ad;
      final hadAd = stale != null || _loaded || _loadedForWidth != 0;
      _ad = null;
      _loaded = false;
      _loadedForWidth = 0;
      stale?.dispose();
      if (hadAd && mounted) setState(() {});
      return;
    }
    if (_loading) return;
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0 || width == _loadedForWidth) return;

    _loading = true;
    _loadedForWidth = width;
    try {
      final previous = _ad;
      final ad = widget.ads.createBanner(
        size: _pickSize(width),
        onLoaded: () {
          if (mounted) setState(() => _loaded = true);
        },
      );
      _ad = ad;
      await ad.load();
      // Only dispose the old ad once its replacement exists, so the slot never
      // collapses to zero height mid-rotation.
      previous?.dispose();
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    widget.ads.removeListener(_onAdsChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final adWidth = ad.size.width.toDouble();
    final adHeight = ad.size.height.toDouble();

    // The creative is drawn at its native size. Never stretch it to the screen
    // (distorts the artwork) and never let it overflow the viewport (clips the
    // artwork) — the size ladder already keeps the box within bounds.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final boxWidth = adWidth < screenWidth ? adWidth : screenWidth;

    return ColoredBox(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin divider so the ad doesn't bleed into the content above.
            Divider(
              height: 1,
              thickness: 0.5,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            // Ad disclosure badge + centred ad creative.
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          'Ad',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      height: adHeight,
                      child: AdWidget(ad: ad),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
