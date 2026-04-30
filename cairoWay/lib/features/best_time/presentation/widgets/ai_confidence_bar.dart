import 'package:flutter/material.dart';

class AiConfidenceBar extends StatelessWidget {
  const AiConfidenceBar({
    super.key,
    required this.value,
    this.foreground,
  });

  final double value;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(0.0, 1.0);
    final percent = (clamped * 100).round();
    final label = percent >= 80
        ? 'High'
        : percent >= 60
            ? 'Medium'
            : 'Low';
    final color = foreground ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            'Confidence: $label',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground ?? scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (percent > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($percent%)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: (foreground ?? scheme.onSurfaceVariant)
                        .withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
