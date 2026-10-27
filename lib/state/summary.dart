import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/summary_repository.dart';

/// The current time. Tests override it so "this month" stays fixed.
final nowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Keyed by the first of the month.
final monthlySummaryProvider = FutureProvider.autoDispose
    .family<MonthlySummary, DateTime>(
      (ref, month) => ref.watch(summaryRepositoryProvider).month(month),
      retry: (_, _) => null,
    );
