import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

enum PremiumButtonVariant { primary, accent, ghost, danger }

/// Premium gradient-filled button with haptic feedback and subtle shadow.
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PremiumButtonVariant.primary,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PremiumButtonVariant variant;
  final bool expand;
  final bool compact;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final disabled = widget.onPressed == null;

    final gradient = switch (widget.variant) {
      PremiumButtonVariant.primary => AppColors.primaryGradient,
      PremiumButtonVariant.accent => AppColors.accentGradient,
      PremiumButtonVariant.ghost => null,
      PremiumButtonVariant.danger => const LinearGradient(
          colors: [Color(0xFFEF5350), Color(0xFFB71C1C)],
        ),
    };
    final fg = widget.variant == PremiumButtonVariant.ghost
        ? scheme.onSurface
        : Colors.white;

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.97 : 1,
      curve: Curves.easeOut,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: GestureDetector(
          onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
          onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
          onTapCancel: disabled ? null : () => setState(() => _pressed = false),
          onTap: disabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                },
          child: Container(
            height: widget.compact ? 48 : 52,
            padding:
                EdgeInsets.symmetric(horizontal: widget.compact ? 20 : 24),
            decoration: BoxDecoration(
              gradient: gradient,
              color: widget.variant == PremiumButtonVariant.ghost
                  ? Colors.transparent
                  : null,
              borderRadius: BorderRadius.circular(20),
              border: widget.variant == PremiumButtonVariant.ghost
                  ? Border.all(
                      color: AppColors.glassBorder(brightness),
                      width: 1,
                    )
                  : null,
              boxShadow: widget.variant == PremiumButtonVariant.ghost
                  ? [
                      BoxShadow(
                        color: brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.40)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.30),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
