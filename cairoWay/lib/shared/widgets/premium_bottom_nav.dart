import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PremiumBottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final fill = isDark ? const Color(0xE0050B0D) : const Color(0xE5FFFFFF);
    final stroke = isDark ? const Color(0x3800DC8C) : const Color(0xD1FFFFFF);
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              top: BorderSide(color: stroke, width: 1.0),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;
                  return _PremiumBottomNavItemWidget(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => onTap(index),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumBottomNavItem {
  const PremiumBottomNavItem({
    required this.icon,
    required this.label,
  });
  final IconData icon;
  final String label;
}

class _PremiumBottomNavItemWidget extends StatelessWidget {
  const _PremiumBottomNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final PremiumBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color activeColor = AppColors.primaryGreen;
    Color inactiveColor = isDark ? const Color(0x6BFFFFFF) : const Color(0x6B17212B);
    
    final color = isSelected ? activeColor : inactiveColor;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
