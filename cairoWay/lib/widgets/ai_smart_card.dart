import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../providers/home_map_providers.dart';

/// PRD: proactive commute insight card (Home tab), collapsible.
class AiSmartCard extends ConsumerWidget {
  const AiSmartCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(aiSmartCardExpandedProvider);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              ref.read(aiSmartCardExpandedProvider.notifier).state = !expanded;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.expand_less,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI suggested route',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  const Text(
                    'RouteMind',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) const _CardBody(),
        ],
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Text('🤖', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'Good morning!',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Text('🏠', style: TextStyle(fontSize: 18)),
              Text('  →  ', style: TextStyle(color: AppColors.textSecondary)),
              Text('🏢', style: TextStyle(fontSize: 18)),
              SizedBox(width: 6),
              Text(
                'Work',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Right now: 35 min',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const Text(
            'Best time to leave: 7:15 AM (28 min — save 7 min)',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Navigate now'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Set reminder'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
