import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/commute_preferences.dart';

class CommuteOnboardingPage extends StatefulWidget {
  const CommuteOnboardingPage({
    super.key,
    required this.onComplete,
  });

  final void Function(CommutePreferences) onComplete;

  @override
  State<CommuteOnboardingPage> createState() => _CommuteOnboardingPageState();
}

class _CommuteOnboardingPageState extends State<CommuteOnboardingPage> {
  CommuteTimeSlot _slot = CommuteTimeSlot.sevenToEight;
  DateTime? _customTime; // time-of-day
  CommuteDayMode _dayMode = CommuteDayMode.sundayToThursday;
  final Set<int> _customDays = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _customTime = DateTime(n.year, n.month, n.day, 7, 0);
  }

  Future<void> _pickTime() async {
    final t = _customTime ?? DateTime(2024, 1, 1, 7, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: t.hour, minute: t.minute),
    );
    if (picked != null) {
      setState(() {
        _customTime = DateTime(2024, 1, 1, picked.hour, picked.minute);
      });
    }
  }

  void _submit() {
    if (_slot == CommuteTimeSlot.custom && _customTime == null) {
      setState(() {
        _error = 'Pick a time for custom, or choose a preset window.';
      });
      return;
    }
    if (_dayMode == CommuteDayMode.custom && _customDays.isEmpty) {
      setState(() {
        _error = 'Select at least one day, or choose Sun–Thu.';
      });
      return;
    }
    setState(() => _error = null);
    widget.onComplete(
      CommutePreferences(
        timeSlot: _slot,
        customTime: _slot == CommuteTimeSlot.custom ? _customTime : null,
        dayMode: _dayMode,
        customWeekdays: _dayMode == CommuteDayMode.custom
            ? Set<int>.from(_customDays)
            : const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'When do you usually commute?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Typical work-week departures: morning toward work.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text('Time', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TimeChip(
                label: '6 – 7 AM',
                selected: _slot == CommuteTimeSlot.sixToSeven,
                onSelect: () => setState(() => _slot = CommuteTimeSlot.sixToSeven),
              ),
              _TimeChip(
                label: '7 – 8 AM',
                selected: _slot == CommuteTimeSlot.sevenToEight,
                onSelect: () => setState(() => _slot = CommuteTimeSlot.sevenToEight),
              ),
              _TimeChip(
                label: '8 – 9 AM',
                selected: _slot == CommuteTimeSlot.eightToNine,
                onSelect: () => setState(() => _slot = CommuteTimeSlot.eightToNine),
              ),
              _TimeChip(
                label: '9 – 10 AM',
                selected: _slot == CommuteTimeSlot.nineToTen,
                onSelect: () => setState(() => _slot = CommuteTimeSlot.nineToTen),
              ),
              _TimeChip(
                label: 'Custom',
                selected: _slot == CommuteTimeSlot.custom,
                onSelect: () => setState(() => _slot = CommuteTimeSlot.custom),
              ),
            ],
          ),
          if (_slot == CommuteTimeSlot.custom) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(
                _customTime == null
                    ? 'Choose time'
                    : TimeOfDay(
                        hour: _customTime!.hour,
                        minute: _customTime!.minute,
                      ).format(context),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Days', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<CommuteDayMode>(
            segments: const [
              ButtonSegment(
                value: CommuteDayMode.sundayToThursday,
                label: Text('Sun – Thu'),
                icon: Icon(Icons.date_range, size: 18),
              ),
              ButtonSegment(
                value: CommuteDayMode.custom,
                label: Text('Custom'),
                icon: Icon(Icons.edit_calendar, size: 18),
              ),
            ],
            selected: {_dayMode},
            onSelectionChanged: (s) {
              setState(() => _dayMode = s.first);
            },
          ),
          if (_dayMode == CommuteDayMode.custom) ...[
            const SizedBox(height: 12),
            Text(
              'Select weekdays',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _WeekdayChips(
              selected: _customDays,
              onChanged: (d) {
                setState(() {
                  if (_customDays.contains(d)) {
                    _customDays.remove(d);
                  } else {
                    _customDays.add(d);
                  }
                });
              },
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: _submit,
            child: const Text('Get started'),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelect(),
    );
  }
}

class _WeekdayChips extends StatelessWidget {
  const _WeekdayChips({
    required this.selected,
    required this.onChanged,
  });

  static const _names = {
    DateTime.sunday: 'Sun',
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
  };

  final Set<int> selected;
  final void Function(int weekday) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _names.entries.map((e) {
        return FilterChip(
          label: Text(e.value),
          selected: selected.contains(e.key),
          onSelected: (_) => onChanged(e.key),
        );
      }).toList(),
    );
  }
}
