import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/glass_container.dart';
import '../../domain/models/time_suggestion.dart';
import 'ai_confidence_bar.dart';

class TimeSuggestionCard extends StatelessWidget {
  const TimeSuggestionCard({
    super.key,
    required this.suggestion,
    this.targetArrival,
    this.onNotify,
    this.onStartNavigation,
  }) : _isHero = false;

  const TimeSuggestionCard.recommended({
    super.key,
    required this.suggestion,
    this.targetArrival,
    this.onNotify,
    this.onStartNavigation,
  }) : _isHero = true;

  final TimeSuggestion suggestion;
  final DateTime? targetArrival;
  final VoidCallback? onNotify;
  final VoidCallback? onStartNavigation;
  final bool _isHero;

  @override
  Widget build(BuildContext context) {
    return _isHero ? _buildHero(context) : _buildCompact(context);
  }

  Widget _buildHero(BuildContext context) {
    final timeLabel = DateFormat.jm().format(suggestion.departureTime);
    final arrivalLabel = DateFormat.jm().format(suggestion.arrivalTime);
    final status = _ArrivalStatus.from(suggestion.arrivalTime, targetArrival);

    return GlassContainer(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.recommend_rounded,
                            size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Recommended',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AiConfidenceBar(
                    value: suggestion.confidenceScore,
                    foreground: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Leave at $timeLabel',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Arrive around $arrivalLabel',
                style: TextStyle(
                  color: Colors.white.withAlpha(235),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _StatusPill(
                label: status.label,
                color: Colors.white,
                onPremium: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _LevelBadge(
                    level: suggestion.trafficLevel,
                    color: suggestion.trafficLevel.color,
                    onPremium: true,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${suggestion.estimatedDurationMinutes} min trip',
                    style: TextStyle(
                      color: Colors.white.withAlpha(219),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Reason: ${_friendlyReason(suggestion.reasoning)}',
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (onNotify != null || onStartNavigation != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (onNotify != null)
                      Expanded(
                        child: _ActionButton(
                          label: 'Notify me',
                          icon: Icons.notifications_active_rounded,
                          onTap: onNotify!,
                        ),
                      ),
                    if (onNotify != null && onStartNavigation != null)
                      const SizedBox(width: 10),
                    if (onStartNavigation != null)
                      Expanded(
                        child: _ActionButton(
                          label: 'Start navigation',
                          icon: Icons.navigation_rounded,
                          onTap: onStartNavigation!,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeLabel = DateFormat.jm().format(suggestion.departureTime);
    final arrivalLabel = DateFormat.jm().format(suggestion.arrivalTime);
    final status = _ArrivalStatus.from(suggestion.arrivalTime, targetArrival);

    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave $timeLabel',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arrive $arrivalLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              _LevelBadge(
                level: suggestion.trafficLevel,
                color: suggestion.trafficLevel.color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatusPill(
                label: status.label,
                color: status.colorFor(context),
              ),
              const Spacer(),
              Text(
                '${suggestion.estimatedDurationMinutes} min',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _friendlyReason(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 'Traffic looks manageable for this time.';
    if (text.toLowerCase().contains('historical pattern')) {
      return 'Traffic usually follows this pattern around that time.';
    }
    return text;
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.level,
    required this.color,
    this.onPremium = false,
  });
  final TrafficLevel level;
  final Color color;
  final bool onPremium;

  String _levelLabel() {
    switch (level) {
      case TrafficLevel.free: return 'Free flow';
      case TrafficLevel.light: return 'Light';
      case TrafficLevel.moderate: return 'Moderate';
      case TrafficLevel.heavy: return 'Heavy';
      case TrafficLevel.gridlock: return 'Gridlock';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = onPremium ? Colors.white : color;
    final bg = onPremium
        ? Colors.white.withAlpha(46)
        : color.withAlpha(41);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: onPremium
            ? null
            : Border.all(color: color.withAlpha(51), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _levelLabel(),
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.onPremium = false,
  });
  final String label;
  final Color color;
  final bool onPremium;

  @override
  Widget build(BuildContext context) {
    final fg = onPremium ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onPremium ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrivalStatus {
  const _ArrivalStatus(this.label, this.kind);
  final String label;
  final int kind;

  factory _ArrivalStatus.from(DateTime actual, DateTime? target) {
    if (target == null) return const _ArrivalStatus('Expected on time', 0);
    final delta = target.difference(actual).inMinutes;
    if (delta >= 2) return _ArrivalStatus('Expected $delta min early', 1);
    if (delta <= -2) {
      return _ArrivalStatus('Expected ${delta.abs()} min late', -1);
    }
    return const _ArrivalStatus('Expected on time', 0);
  }

  Color colorFor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (kind > 0) return scheme.primary;
    if (kind < 0) return scheme.error;
    return scheme.onSurfaceVariant;
  }
}
