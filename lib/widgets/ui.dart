import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Small monospaced pill for part codes, battery numbers and SKUs. Tapping it
/// copies the code, which is the single most repeated action at a repair counter.
class CodeChip extends StatelessWidget {
  const CodeChip({super.key, required this.code, this.copyable = true});

  final String code;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(code, style: AppFonts.code(context)),
          if (copyable) ...[
            Gap.wXs,
            Icon(Icons.copy_rounded, size: 12, color: scheme.outline),
          ],
        ],
      ),
    );
    if (!copyable) return pill;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied $code')),
        );
      },
      child: pill,
    );
  }
}

/// A soft, tinted badge used for category names and counts.
class SoftBadge extends StatelessWidget {
  const SoftBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: tint),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 11.5,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with optional trailing action — keeps vertical rhythm even
/// across every screen.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Friendly empty / error state with consistent spacing and tone.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: scheme.primary),
            ),
            Gap.lg,
            Text(title,
                textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            Gap.sm,
            Text(message,
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            if (action != null) ...[Gap.lg, action!],
          ],
        ),
      ),
    );
  }
}

/// The disclaimer shown under part lists. Quiet, but always present — which is
/// also what keeps the listing honest for Play review.
class VerifyNotice extends StatelessWidget {
  const VerifyNotice({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        // A hairline keeps the notice legible wherever it sits: on the raw
        // canvas (home, group detail) and inside dark mode where surface-on-
        // background tone steps nearly vanish.
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_outlined, size: 17, color: scheme.outline),
          Gap.wSm,
          Expanded(
            child: Text(
              text ??
                  'Always verify connector pin count, pitch, latch, flex length, '
                      'frame revision and panel type physically before fitting '
                      'the part.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
