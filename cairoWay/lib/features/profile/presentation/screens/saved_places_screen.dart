import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/premium_button.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final saved = storage.savedPlaces();
    return Scaffold(
      appBar: AppBar(title: const Text('Saved places')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final s in saved)
                  ListTile(
                    leading: Icon(_iconFor(s.label)),
                    title:
                        Text(s.label[0].toUpperCase() + s.label.substring(1)),
                    subtitle: Text(s.place.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        await storage.removeSavedPlace(s.id);
                        ref.invalidate(storageServiceProvider);
                      },
                    ),
                  ),
                if (saved.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No saved places yet.'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumButton(
            label: 'Add a place',
            icon: Icons.add_location_alt_rounded,
            onPressed: () => context.push(AppRoutes.onboarding),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String label) => switch (label) {
        'home' => Icons.home_rounded,
        'work' => Icons.business_center_rounded,
        _ => Icons.bookmark_rounded,
      };
}
