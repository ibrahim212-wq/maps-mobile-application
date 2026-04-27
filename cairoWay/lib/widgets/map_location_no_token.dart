import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Shown when there is no token, the map failed, or the user is using the Cairo default.
class LocationFallbackPanel extends StatelessWidget {
  const LocationFallbackPanel({
    super.key,
    required this.latController,
    required this.lngController,
    this.mapError,
    this.onRetryMap,
    this.showTokenHint = true,
  });

  final TextEditingController latController;
  final TextEditingController lngController;
  final String? mapError;
  final VoidCallback? onRetryMap;
  final bool showTokenHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mapError != null) ...[
                  Text(
                    mapError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                  if (onRetryMap != null) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onRetryMap,
                        child: const Text('Try loading map again'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                if (showTokenHint)
                  Text(
                    'Add MAPBOX_ACCESS_TOKEN in .env for a live, pannable map. '
                    'Until then, the app uses central Cairo; you can adjust coordinates below if needed.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (showTokenHint) const SizedBox(height: 8),
                Text('Default location', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Cairo center (adjust below if you like)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Adjust coordinates',
                      style: theme.textTheme.labelLarge,
                    ),
                    children: [
                      TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Latitude',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Longitude',
                        ),
                      ),
                    ],
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
