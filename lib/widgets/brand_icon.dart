import 'package:flutter/material.dart';

/// A consistent, non-trademarked visual mark for a phone family.
///
/// The icon and colour come from [brandStyle], while this widget owns the
/// sizing and background treatment so category cards and search filters never
/// drift apart visually.
class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, required this.name, this.size = 52});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = brandStyle(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.30),
      ),
      child: Icon(style.icon, size: size * 0.46, color: style.color),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Brand icon + accent
/// ---------------------------------------------------------------------------
/// Brand logos are trademarked, so instead of imitating marks, every phone
/// family gets an icon that hints at its name plus a stable accent colour.
/// A long brand list then scans by silhouette and hue rather than by reading
/// every line — the same trick the category grid already uses.
///
/// Matching is keyword-based on the group name, because one row can cover a
/// whole family ("Xiaomi, Redmi, Poco, Mi") and all of them should share one
/// identity. Unknown brands get a deterministic hash of their name, so a row
/// keeps the same colour across restarts.

({IconData icon, Color color}) brandStyle(String name) {
  final n = name.toLowerCase();

  // Specific families first, then looser keywords.
  if (n.contains('iphone') || n.contains('apple') || n.contains('ios')) {
    return (icon: Icons.phone_iphone_rounded, color: const Color(0xFF5A5F66));
  }
  if (n.contains('ipad') || n.contains('tablet')) {
    return (icon: Icons.tablet_mac_rounded, color: const Color(0xFF5A5F66));
  }
  if (n.contains('pixel') || n.contains('google')) {
    return (icon: Icons.diamond_outlined, color: const Color(0xFF4285F4));
  }
  if (n.contains('samsung')) {
    return (icon: Icons.phone_android_rounded, color: const Color(0xFF4265C7));
  }
  if (n.contains('poco')) {
    return (icon: Icons.bolt_rounded, color: const Color(0xFFE0A21A));
  }
  if (n.contains('xiaomi') ||
      n.contains('redmi') ||
      n.contains(' mi') ||
      n.endsWith('mi')) {
    return (icon: Icons.flash_on_rounded, color: const Color(0xFFE8705F));
  }
  if (n.contains('iqoo')) {
    return (icon: Icons.speed_rounded, color: const Color(0xFF17A673));
  }
  if (n.contains('vivo')) {
    return (icon: Icons.graphic_eq_rounded, color: const Color(0xFF4A6CF7));
  }
  if (n.contains('oneplus') || n.contains('one plus')) {
    return (icon: Icons.looks_one_rounded, color: const Color(0xFFE03E3E));
  }
  if (n.contains('realme')) {
    return (icon: Icons.verified_rounded, color: const Color(0xFFE0A21A));
  }
  if (n.contains('oppo')) {
    return (
      icon: Icons.radio_button_checked_rounded,
      color: const Color(0xFF17A673),
    );
  }
  if (n.contains('infinix')) {
    return (icon: Icons.all_inclusive_rounded, color: const Color(0xFF9B5DE5));
  }
  if (n.contains('tecno')) {
    return (icon: Icons.memory_rounded, color: const Color(0xFF00A3C4));
  }
  if (n.contains('itel')) {
    return (icon: Icons.apps_rounded, color: const Color(0xFF00A3C4));
  }
  if (n.contains('motorola') || n.contains('moto')) {
    // The bat-wing roundel, abstracted to a circular arrow.
    return (icon: Icons.autorenew_rounded, color: const Color(0xFF5C7CFA));
  }
  if (n.contains('nokia')) {
    return (icon: Icons.link_rounded, color: const Color(0xFF2E64C8));
  }
  if (n.contains('huawei')) {
    return (icon: Icons.local_florist_rounded, color: const Color(0xFFE03E3E));
  }
  if (n.contains('honor')) {
    return (
      icon: Icons.workspace_premium_rounded,
      color: const Color(0xFF4A6CF7),
    );
  }
  if (n.contains('lava')) {
    return (
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFE8705F),
    );
  }
  if (n.contains('micromax')) {
    return (icon: Icons.apps_rounded, color: const Color(0xFF9B5DE5));
  }
  if (n.contains('asus') || n.contains('rog')) {
    return (icon: Icons.sports_esports_rounded, color: const Color(0xFF5A5F66));
  }
  if (n.contains('sony') || n.contains('xperia')) {
    return (icon: Icons.headphones_rounded, color: const Color(0xFF5A5F66));
  }
  if (n.contains('jio')) {
    return (icon: Icons.wifi_rounded, color: const Color(0xFF2E64C8));
  }

  // Unknown brand: stable pseudo-random pick from name hash.
  final h = name.hashCode.abs();
  const icons = [
    Icons.smartphone_rounded,
    Icons.phone_android_rounded,
    Icons.devices_rounded,
    Icons.phonelink_ring_rounded,
  ];
  return (
    icon: icons[h % icons.length],
    color: HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.52, 0.44).toColor(),
  );
}
