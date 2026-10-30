import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../data/models.dart';
import '../data/summary_repository.dart';
import 'analytics.dart';

/// The current time. Tests override it so "this month" stays fixed.
final nowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Keyed by the first of the month.
final monthlySummaryProvider = FutureProvider.autoDispose
    .family<MonthlySummary, DateTime>(
      (ref, month) => ref.watch(summaryRepositoryProvider).month(month),
      retry: (_, _) => null,
    );

/// The dashboard and analytics stay mounted in their tabs, so every change to
/// money must call this.
void invalidateMonthlySummaries(void Function(ProviderOrFamily) invalidate) {
  invalidate(monthlySummaryProvider);
  invalidate(analyticsMonthsProvider);
  invalidate(analyticsExpensesProvider);
}
