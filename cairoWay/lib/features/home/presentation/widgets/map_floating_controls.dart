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
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        // Default: 4 buttons of 48px + 3 gaps of 12px = 228px
        double btnSize = 48.0;
        double gap = 12.0;
        if (h < 228) {
          btnSize = 40.0;
          if (h < (40.0 * 4 + 12.0 * 3)) gap = 8.0;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _IconButton(
              icon: Icons.layers_rounded,
              tooltip: 'Layers',
              onTap: onLayers,
              size: btnSize,
            ),
            SizedBox(height: gap),
            _IconButton(
              icon: Icons.traffic_rounded,
              tooltip: 'Traffic',
              active: trafficOn,
              onTap: onToggleTraffic,
              size: btnSize,
            ),
            SizedBox(height: gap),
            _IconButton(
              icon: Icons.brightness_1,
              tooltip: 'Traffic signals',
              active: signalsOn,
              onTap: onToggleSignals,
              smallIcon: true,
              size: btnSize,
            ),
            SizedBox(height: gap),
            _IconButton(
              icon: Icons.my_location_rounded,
              tooltip: 'My location',
              highlighted: true,
              onTap: onRecenter,
              size: btnSize,
              label: 'recenter',
            ),
          ],
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: 0.2);
      },
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.size,
    this.tooltip,
    this.active = false,
    this.highlighted = false,
    this.smallIcon = false,
    this.label,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;
  final bool active;
  final bool highlighted;
  final bool smallIcon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlighted || active ? scheme.primary : scheme.onSurface;
    final btn = GlassContainer(
      borderRadius: 16,
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Center(
        child: label != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFF00A854), size: 20),
                  const SizedBox(height: 2),
                  Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFF00A854),
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Icon(icon, color: color, size: smallIcon ? 16 : 24),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
