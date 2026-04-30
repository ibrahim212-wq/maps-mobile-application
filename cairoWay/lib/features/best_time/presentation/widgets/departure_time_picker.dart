import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';

class DepartureTimePicker extends StatelessWidget {
  const DepartureTimePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.bufferMinutes = 10,
    this.onBufferChanged,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final int bufferMinutes;
  final ValueChanged<int>? onBufferChanged;

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 14)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              surface: theme.colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    onChanged(DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final quickTimes = <_QuickTime>[
      _QuickTime('Now', now),
      _QuickTime('In 30 min', now.add(const Duration(minutes: 30))),
      _QuickTime('In 1 hour', now.add(const Duration(hours: 1))),
      _QuickTime('12:30 PM', DateTime(now.year, now.month, now.day, 12, 30)),
      _QuickTime('1:00 PM', DateTime(now.year, now.month, now.day, 13)),
      _QuickTime('1:30 PM', DateTime(now.year, now.month, now.day, 13, 30)),
    ];

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: 20,
      blur: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Arrive by',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                DateFormat('EEE, MMM d · h:mm a').format(value),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in quickTimes)
                _ChoiceChip(
                  label: t.label,
                  selected: _sameMinute(value, t.value),
                  onTap: () => onChanged(t.value),
                ),
              _ChoiceChip(
                label: 'Custom',
                selected: !quickTimes.any((t) => _sameMinute(value, t.value)),
                icon: Icons.tune_rounded,
                onTap: () => _pickCustom(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Arrival buffer',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BufferChip(
                  label: 'On time',
                  selected: bufferMinutes == 0,
                  onTap: () => onBufferChanged?.call(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BufferChip(
                  label: '10 min early',
                  selected: bufferMinutes == 10,
                  onTap: () => onBufferChanged?.call(10),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BufferChip(
                  label: '20 min early',
                  selected: bufferMinutes == 20,
                  onTap: () => onBufferChanged?.call(20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;
}

class _QuickTime {
  const _QuickTime(this.label, this.value);
  final String label;
  final DateTime value;
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary
                : AppColors.glassFillLight(brightness),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : AppColors.glassBorder(brightness),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15,
                    color: selected ? Colors.white : scheme.primary),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? Colors.white : scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BufferChip extends StatelessWidget {
  const _BufferChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : AppColors.glassFillLight(brightness),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? scheme.primary
                : AppColors.glassBorder(brightness),
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
