import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/glass_container.dart';

class MapFloatingControls extends StatelessWidget {
  const MapFloatingControls({
    super.key,
    required this.onRecenter,
    required this.onToggleTraffic,
    required this.onToggleSignals,
    required this.onLayers,
    required this.trafficOn,
    required this.signalsOn,
  });

  final VoidCallback onRecenter;
  final VoidCallback onToggleTraffic;
  final VoidCallback onToggleSignals;
  final VoidCallback onLayers;
  final bool trafficOn;
  final bool signalsOn;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _IconButton(
          icon: Icons.layers_rounded,
          tooltip: 'Layers',
          onTap: onLayers,
        ),
        const SizedBox(height: 10),
        _IconButton(
          icon: Icons.traffic_rounded,
          tooltip: 'Traffic',
          active: trafficOn,
          onTap: onToggleTraffic,
        ),
        const SizedBox(height: 10),
        _IconButton(
          icon: Icons.brightness_1,
          tooltip: 'Traffic signals',
          active: signalsOn,
          onTap: onToggleSignals,
          smallIcon: true,
        ),
        const SizedBox(height: 10),
        _IconButton(
          icon: Icons.my_location_rounded,
          tooltip: 'My location',
          highlighted: true,
          onTap: onRecenter,
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: 0.2);
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.highlighted = false,
    this.smallIcon = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;
  final bool highlighted;
  final bool smallIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlighted || active ? scheme.primary : scheme.onSurface;
    final btn = GlassContainer(
      borderRadius: 16,
      width: 48,
      height: 48,
      padding: EdgeInsets.zero,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Center(
        child: Icon(icon, color: color, size: smallIcon ? 16 : 24),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
