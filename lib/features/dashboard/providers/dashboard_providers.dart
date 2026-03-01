import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/dashboard/models/dashboard_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REFRESH TRIGGER
// ─────────────────────────────────────────────────────────────────────────────

final dashboardRefreshTriggerProvider = Provider.autoDispose<DateTime>(
  (ref) => DateTime.now(),
);

// ─────────────────────────────────────────────────────────────────────────────
// CHART TYPE
// ─────────────────────────────────────────────────────────────────────────────

class ChartTypeNotifier extends Notifier<ChartType> {
  @override
  ChartType build() => ChartType.line;
  void setType(ChartType type) => state = type;
}

final chartTypeProvider = NotifierProvider<ChartTypeNotifier, ChartType>(
  ChartTypeNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// REAL DATA PROVIDERS — streams from PowerSync
// ─────────────────────────────────────────────────────────────────────────────

/// Today's revenue (sum of completed sales grand_total for today)
final todaysRevenueProvider = StreamProvider.autoDispose<double>((ref) {
  ref.watch(dashboardRefreshTriggerProvider);
  final repo = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchTodaysRevenue(branchId: branchId);
});

/// Total all-time revenue
final salesDataProvider = StreamProvider.autoDispose<double>((ref) {
  ref.watch(dashboardRefreshTriggerProvider);
  final repository = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repository.watchTotalSales(branchId: branchId);
});

/// Today's order count
final todaysOrderCountProvider = StreamProvider.autoDispose<int>((ref) {
  ref.watch(dashboardRefreshTriggerProvider);
  final repo = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchTodaysOrderCount(branchId: branchId);
});

/// Average order value (today)
final averageOrderValueProvider = StreamProvider.autoDispose<double>((ref) {
  ref.watch(dashboardRefreshTriggerProvider);
  final repo = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchAverageOrderValue(branchId: branchId);
});

/// Low stock item count
final lowStockCountProvider = StreamProvider.autoDispose<int>((ref) {
  ref.watch(dashboardRefreshTriggerProvider);
  final repo = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchLowStockCount(branchId: branchId);
});

/// Staff count
final staffCountProvider = StreamProvider.autoDispose<int>((ref) {
  ref.watch(dashboardRefreshTriggerProvider);
  final repo = ref.watch(repositoryProvider);
  return repo.watchStaffCount();
});

/// Customer count
final customerCountProvider = StreamProvider.autoDispose<int>((ref) {
  ref.watch(dashboardRefreshTriggerProvider);
  final repo = ref.watch(repositoryProvider);
  return repo.watchCustomers().map((list) => list.length);
});

// ─────────────────────────────────────────────────────────────────────────────
// RECENT SALES (replaces mock ordersDataProvider)
// ─────────────────────────────────────────────────────────────────────────────

final recentSalesProvider = StreamProvider.autoDispose<List<Sale>>((ref) {
  ref.watch(dashboardRefreshTriggerProvider);
  final repo = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchSales(branchId: branchId, limit: 10);
});

// ─────────────────────────────────────────────────────────────────────────────
// TOP PRODUCTS (replaces mock productsDataProvider)
// ─────────────────────────────────────────────────────────────────────────────

final topProductsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(dashboardRefreshTriggerProvider);
      final repo = ref.watch(repositoryProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      return repo.watchTopProducts(branchId: branchId, limit: 6);
    });

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT METHOD BREAKDOWN (replaces mock paymentMethodsProvider)
// ─────────────────────────────────────────────────────────────────────────────

final paymentBreakdownProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(dashboardRefreshTriggerProvider);
      final repo = ref.watch(repositoryProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      return repo.watchPaymentMethodBreakdown(branchId: branchId);
    });

// Static chart palette — no theme dependency so this works everywhere
const _chartColors = [
  Color(0xFF6366F1), // Indigo
  Color(0xFF22C55E), // Green
  Color(0xFFF59E0B), // Amber
  Color(0xFFEF4444), // Red
  Color(0xFF8B5CF6), // Purple
];

/// Converts raw payment breakdown into PieChartSectionData
final paymentMethodsProvider =
    Provider.autoDispose<AsyncValue<List<PieChartSectionData>>>((ref) {
      final breakdown = ref.watch(paymentBreakdownProvider);

      return breakdown.when(
        data: (rows) {
          if (rows.isEmpty) return const AsyncValue.data([]);

          final total = rows.fold<double>(
            0,
            (sum, r) => sum + ((r['total'] as num?)?.toDouble() ?? 0),
          );
          if (total <= 0) return const AsyncValue.data([]);

          return AsyncValue.data(
            rows.asMap().entries.map((entry) {
              final r = entry.value;
              final amount = (r['total'] as num?)?.toDouble() ?? 0;
              final pct = (amount / total * 100).round();
              final method = (r['payment_method'] as String?) ?? 'Other';
              final label = _formatMethodName(method);
              return PieChartSectionData(
                value: amount,
                title: '$pct%\n$label',
                color: _chartColors[entry.key % _chartColors.length],
                radius: 60,
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

String _formatMethodName(String raw) {
  switch (raw.toLowerCase()) {
    case 'cash':
      return 'Cash';
    case 'mpesa':
    case 'm-pesa':
      return 'M-Pesa';
    case 'card':
      return 'Card';
    case 'bank_transfer':
      return 'Bank Transfer';
    default:
      return raw[0].toUpperCase() + raw.substring(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPARKLINE DATA (kept as simple lists for metric cards — derived from streams)
// ─────────────────────────────────────────────────────────────────────────────

// Sparklines show a mini trend indicator. Since we don't store daily aggregates
// locally, we just show a flat line at the current value for now. The sparkline
// widget handles empty lists gracefully.
final revenueSparklineProvider = Provider.autoDispose<AsyncValue<List<double>>>(
  (ref) {
    final revenue = ref.watch(todaysRevenueProvider);
    return revenue.when(
      data: (val) => AsyncValue.data([
        val * 0.7,
        val * 0.8,
        val * 0.85,
        val * 0.9,
        val * 0.95,
        val,
      ]),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );
  },
);

final ordersSparklineProvider = Provider.autoDispose<AsyncValue<List<double>>>((
  ref,
) {
  final orders = ref.watch(todaysOrderCountProvider);
  return orders.when(
    data: (val) {
      final v = val.toDouble();
      return AsyncValue.data([v * 0.6, v * 0.7, v * 0.8, v * 0.85, v * 0.9, v]);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// METRIC DETAIL DATA
// ─────────────────────────────────────────────────────────────────────────────

final metricDetailDataProvider =
    Provider.family<MetricDetailData, MetricDetailParams>((ref, params) {
      switch (params.type) {
        case MetricType.revenue:
          return createRevenueDetailData(params.value, params.colorScheme);
        case MetricType.orders:
          return createOrdersDetailData(
            params.value.toInt(),
            params.colorScheme,
          );
        case MetricType.aov:
          return createAOVDetailData(params.value, params.colorScheme);
        case MetricType.lowStock:
          return createLowStockDetailData(
            params.value.toInt(),
            params.colorScheme,
          );
        default:
          return createRevenueDetailData(params.value, params.colorScheme);
      }
    });

class MetricDetailParams {
  final MetricType type;
  final double value;
  final ColorScheme colorScheme;

  MetricDetailParams({
    required this.type,
    required this.value,
    required this.colorScheme,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final greetingProvider = Provider<String>((ref) {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
});

// ─────────────────────────────────────────────────────────────────────────────
// CHART TIME RANGE
// ─────────────────────────────────────────────────────────────────────────────

class ChartTimeRangeNotifier extends Notifier<String> {
  @override
  String build() => 'This Week';
  void setRange(String range) => state = range;
}

final chartTimeRangeProvider = NotifierProvider<ChartTimeRangeNotifier, String>(
  ChartTimeRangeNotifier.new,
);

/// Convert time range label to days
int _rangeToDays(String range) {
  switch (range) {
    case 'Today':
      return 1;
    case 'This Week':
      return 7;
    case 'This Month':
      return 30;
    case 'This Year':
      return 365;
    default:
      return 7;
  }
}

/// Daily revenue + order data for the interactive chart
final dailySalesChartProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(dashboardRefreshTriggerProvider);
      final repo = ref.watch(repositoryProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      final range = ref.watch(chartTimeRangeProvider);
      return repo.watchDailySalesData(
        branchId: branchId,
        days: _rangeToDays(range),
      );
    });
