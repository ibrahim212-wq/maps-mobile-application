import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/place.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/services/places_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../../home/presentation/providers/home_prompt_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = const ['home', 'work'];
  int _index = 0;
  final _ctrl = PageController();

  Future<void> _next() async {
    HapticFeedback.lightImpact();
    // Saving any place permanently dismisses the home/work prompt.
    await ref.read(homeWorkPromptDismissedProvider.notifier).dismiss();
    if (!mounted) return;
    if (_index >= _pages.length - 1) {
      context.pop();
      return;
    }
    setState(() => _index++);
    _ctrl.animateToPage(_index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic);
  }

  Future<void> _skip() async {
    await ref.read(homeWorkPromptDismissedProvider.notifier).dismiss();
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up'),
        actions: [
          TextButton(onPressed: _skip, child: const Text('Skip')),
        ],
      ),
      body: PageView.builder(
        controller: _ctrl,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _pages.length,
        itemBuilder: (_, i) => _PickPlacePage(
          label: _pages[i],
          onSaved: _next,
        ),
      ),
    );
  }
}

class _PickPlacePage extends ConsumerStatefulWidget {
  const _PickPlacePage({required this.label, required this.onSaved});
  final String label;
  final VoidCallback onSaved;

  @override
  ConsumerState<_PickPlacePage> createState() => _PickPlacePageState();
}

class _PickPlacePageState extends ConsumerState<_PickPlacePage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  bool _loading = false;
  Place? _selected;

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      final r = await ref.read(placesServiceProvider).autocomplete(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    });
  }

  Future<void> _useGps() async {
    final loc = await ref.read(locationServiceProvider).currentLocation();
    if (loc == null || !mounted) return;
    final reverse =
        await ref.read(placesServiceProvider).reverse(loc.lat, loc.lng);
    final place = reverse ??
        Place(id: 'gps', name: 'My location', lat: loc.lat, lng: loc.lng);
    setState(() => _selected = place);
  }

  Future<void> _save() async {
    final p = _selected;
    if (p == null) return;
    await ref
        .read(storageServiceProvider)
        .upsertSavedPlace(widget.label, p);
    widget.onSaved();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.label == 'home'
        ? 'Where is your home?'
        : 'Where is your work?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              widget.label == 'home'
                  ? Icons.home_rounded
                  : Icons.business_center_rounded,
              color: Colors.white,
              size: 28,
            ),
          ).animate().scale(),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Optional. Saving makes commute predictions smarter.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: 'Search address or place',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.my_location_rounded),
              title: const Text('Use my current location'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _useGps,
            ),
          ),
          const SizedBox(height: 12),
          if (_selected != null)
            Card(
              color: scheme.primary.withValues(alpha: 0.10),
              child: ListTile(
                leading: Icon(Icons.check_circle_rounded,
                    color: scheme.primary),
                title: Text(_selected!.name),
                subtitle: Text(_selected!.address ?? ''),
              ),
            ),
          Expanded(
            child: _loading
                ? ListView(
                    children: const [
                      ShimmerListTile(),
                      ShimmerListTile(),
                      ShimmerListTile(),
                    ],
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: const Icon(Icons.location_on_rounded),
                        title: Text(p.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(p.address ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => setState(() => _selected = p),
                      );
                    },
                  ),
          ),
          PremiumButton(
            label: 'Save & continue',
            icon: Icons.check_rounded,
            onPressed: _selected == null ? null : _save,
          ),
        ],
      ),
    );
  }
}
