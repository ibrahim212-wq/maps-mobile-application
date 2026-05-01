import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/glass_container.dart';

/// Bottom-navigation shell that hosts the four primary tabs.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    _Tab(AppRoutes.home, Icons.map_rounded, 'Map'),
    _Tab(AppRoutes.insights, Icons.insights_rounded, 'Insights'),
    _Tab(AppRoutes.alerts, Icons.notifications_rounded, 'Alerts'),
    _Tab(AppRoutes.profile, Icons.person_rounded, 'Profile'),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].path) return i;
      if (i > 0 && location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFor(location);
    final mq = MediaQuery.of(context);
    
    final isHome = location == AppRoutes.home;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: isHome
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, mq.padding.bottom + 16),
              child: GlassContainer(
                borderRadius: 28,
                height: 70,
                padding: EdgeInsets.zero,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      _NavItem(
                        icon: _tabs[i].icon,
                        label: _tabs[i].label,
                        selected: index == i,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.go(_tabs[i].path);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Tab {
  final String path;
  final IconData icon;
  final String label;
  const _Tab(this.path, this.icon, this.label);
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
