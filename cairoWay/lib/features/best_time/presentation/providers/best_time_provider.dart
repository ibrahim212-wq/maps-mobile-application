import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/best_time_service.dart';
import '../../domain/models/best_time_request.dart';
import '../../domain/models/time_suggestion.dart';

/// Async family-provider that fetches Best-Time suggestions for a given
/// origin/destination/arrival-time tuple.
///
/// Family equality is satisfied because [BestTimeRequest] overrides `==`
/// and `hashCode`, so calling `bestTimeProvider(req)` with the same params
/// reuses the cached result without re-hitting the service.
final bestTimeProvider = FutureProvider.autoDispose
    .family<BestTimeResult, BestTimeRequest>((ref, request) async {
  final svc = ref.watch(bestTimeServiceProvider);
  return svc.getBestTime(request);
});
