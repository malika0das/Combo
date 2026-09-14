import 'package:flutter/material.dart';

import '../motion.dart';
import '../services/insight_service.dart';
import '../theme.dart';
import 'animated_icons.dart';

/// Renders a proactive [Insight] with a tone-appropriate colour, icon and
/// voice. Dismissible, because a suggestion the user does not want must be
/// easy to make go away — that is what keeps it feeling helpful, not pushy.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.insight,
    required this.onAction,
    required this.onDismiss,
  });

  final Insight insight;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  ({Color color, IconData icon}) get _style => switch (insight.tone) {
        InsightTone.welcome => (
            color: const Color(0xFFE8705F),
            icon: Icons.auto_awesome_rounded
          ),
        InsightTone.tip => (
            color: const Color(0xFF9B5DE5),
            icon: Icons.lightbulb_outline_rounded
          ),
        InsightTone.streak => (
            color: const Color(0xFF17A673),
            icon: Icons.local_shipping_outlined
          ),
        InsightTone.resume => (
            color: const Color(0xFF00A3C4),
            icon: Icons.history_rounded
          ),
        InsightTone.caution => (
            color: const Color(0xFFF0A500),
            icon: Icons.nights_stay_outlined
          ),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _style;

    return Dismissible(
      key: ValueKey('insight_${insight.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.close_rounded,
            size: 18, color: theme.colorScheme.outline),
      ),
      child: EntranceFade(
        child: Container(
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: insight.actionLabel == null
                  ? null
                  : () {
                      Haptics.tap();
                      onAction();
                    },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BreathingIcon(
                      icon: style.icon,
                      tint: style.color,
                      iconSize: 18,
                      containerSize: 34,
                      borderRadius: 11,
                      phase: 0.5,
                    ),
                    Gap.wMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(insight.title,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontSize: 13.5)),
                          const SizedBox(height: 3),
                          Text(insight.message,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(height: 1.45)),
                          if (insight.actionLabel != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  insight.actionLabel!,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: style.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 13, color: style.color),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: theme.colorScheme.outline),
                      onPressed: () {
                        Haptics.tap();
                        onDismiss();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
