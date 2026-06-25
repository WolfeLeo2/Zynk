import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';
import 'package:zynk/features/dashboard/presentation/widgets/metric_cards.dart';
import 'package:zynk/features/dashboard/presentation/widgets/orders_list.dart';
import 'package:zynk/features/dashboard/presentation/widgets/skeleton_widgets.dart';
import 'package:zynk/features/dashboard/presentation/widgets/empty_error_states.dart';

import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/features/dashboard/presentation/dashboard_layout.dart';

class StaffDashboardLayout extends ConsumerWidget {
  final UserRole role;
  final String displayName;
  final String tenantName;
  final String? photoUrl;
  final String greeting;

  const StaffDashboardLayout({
    super.key,
    required this.role,
    required this.displayName,
    required this.tenantName,
    this.photoUrl,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      drawer: const AppDrawer(),
      body: CustomScrollView(
        slivers: [
          if (!isDesktop)
            DashboardSliverAppBar(
              role: role,
              displayName: displayName,
              tenantName: tenantName,
              photoUrl: photoUrl,
              greeting: greeting,
            ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  DesktopAppBar(
                    colorScheme: colorScheme,
                    theme: theme,
                    tenantName: tenantName,
                    displayName: displayName,
                    role: role,
                    greeting: greeting,
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32.0 : 16.0,
                    vertical: isDesktop ? 0.0 : 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Staff Metrics Grid
                      isDesktop
                          ? const _StaffDesktopMetricsGrid()
                          : const _StaffMobileMetricsGrid(),

                      const SizedBox(height: 24),

                      // 2. Main Content Area
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  _StaffQuickActions(),
                                  SizedBox(height: 24),
                                  RecentOrdersTable(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(flex: 1, child: const _LowStockList()),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _StaffQuickActions(),
                            SizedBox(height: 24),
                            RecentOrdersList(),
                            SizedBox(height: 24),
                            _LowStockList(),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAFF METRICS GRID
// ─────────────────────────────────────────────────────────────────────────────

class _StaffDesktopMetricsGrid extends ConsumerWidget {
  const _StaffDesktopMetricsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ordersAsync = ref.watch(todaysOrderCountProvider);
    final pendingAsync = ref.watch(pendingApprovalsCountProvider);
    final lowStockAsync = ref.watch(lowStockCountProvider);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ordersAsync.isLoading
                ? SkeletonCard(colorScheme: colorScheme)
                : MetricCardWithSparkline(
                    title: 'Today\'s Transactions',
                    value: '${ordersAsync.value ?? 0}',
                    rawValue: (ordersAsync.value ?? 0).toDouble(),
                    icon: PhosphorIconsDuotone.receipt,
                    color: colorScheme.primary,
                    sparklineData: const [],
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: pendingAsync.isLoading
                ? SkeletonCard(colorScheme: colorScheme)
                : MetricCardWithSparkline(
                    title: 'Pending Invoices',
                    value: '${pendingAsync.value ?? 0}',
                    rawValue: (pendingAsync.value ?? 0).toDouble(),
                    icon: PhosphorIconsDuotone.clock,
                    color: (pendingAsync.value ?? 0) > 0
                        ? colorScheme.error
                        : colorScheme.tertiary,
                    sparklineData: const [],
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: lowStockAsync.isLoading
                ? SkeletonCard(colorScheme: colorScheme)
                : MetricCardWithSparkline(
                    title: 'Low Stock Alerts',
                    value: '${lowStockAsync.value ?? 0}',
                    rawValue: (lowStockAsync.value ?? 0).toDouble(),
                    icon: PhosphorIconsDuotone.warning,
                    color: (lowStockAsync.value ?? 0) > 0
                        ? colorScheme.error
                        : Colors.green,
                    sparklineData: const [],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StaffMobileMetricsGrid extends ConsumerWidget {
  const _StaffMobileMetricsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ordersAsync = ref.watch(todaysOrderCountProvider);
    final pendingAsync = ref.watch(pendingApprovalsCountProvider);
    final lowStockAsync = ref.watch(lowStockCountProvider);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: ordersAsync.isLoading
              ? SkeletonCard(colorScheme: colorScheme)
              : MetricCardWithSparkline(
                  title: 'Today\'s Transactions',
                  value: '${ordersAsync.value ?? 0}',
                  rawValue: (ordersAsync.value ?? 0).toDouble(),
                  icon: PhosphorIconsDuotone.receipt,
                  color: colorScheme.primary,
                  sparklineData: const [],
                  isLargeCard: true,
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 140,
                child: pendingAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Pending Invoices',
                        value: '${pendingAsync.value ?? 0}',
                        rawValue: (pendingAsync.value ?? 0).toDouble(),
                        icon: PhosphorIconsDuotone.clock,
                        color: (pendingAsync.value ?? 0) > 0
                            ? colorScheme.error
                            : colorScheme.tertiary,
                        sparklineData: const [],
                        isSmallCard: true,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 140,
                child: lowStockAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Low Stock Alerts',
                        value: '${lowStockAsync.value ?? 0}',
                        rawValue: (lowStockAsync.value ?? 0).toDouble(),
                        icon: PhosphorIconsDuotone.warning,
                        color: (lowStockAsync.value ?? 0) > 0
                            ? colorScheme.error
                            : Colors.green,
                        sparklineData: const [],
                        isSmallCard: true,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAFF QUICK ACTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _StaffQuickActions extends StatelessWidget {
  const _StaffQuickActions();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Row(
            children: [
              Expanded(
                child: _StaffActionButton(
                  label: 'New Sale',
                  icon: PhosphorIconsBold.cashRegister,
                  color: colorScheme.primary,
                  onTap: () => context.push('/pos'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StaffActionButton(
                  label: 'Add Stock',
                  icon: PhosphorIconsBold.plus,
                  color: colorScheme.secondary,
                  onTap: () => context.push('/adjustments'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffActionButton extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StaffActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOW STOCK LIST
// ─────────────────────────────────────────────────────────────────────────────

class _LowStockList extends ConsumerWidget {
  const _LowStockList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final lowStockAsync = ref.watch(lowStockProductsProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Low Stock Items',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/products'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          lowStockAsync.when(
            data: (products) {
              if (products.isEmpty) {
                return EmptyState(
                  colorScheme: colorScheme,
                  title: 'Stock looks good',
                  message: 'No items are currently below their reorder level',
                  icon: PhosphorIconsDuotone.package,
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  final qty = (p['quantity'] as num?)?.toInt() ?? 0;
                  final reorder = (p['reorder_level'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIconsDuotone.warningCircle,
                              color: colorScheme.error,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name']?.toString() ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Reorder level: $reorder',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$qty left',
                            style: TextStyle(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => ErrorState(
              colorScheme: colorScheme,
              message: 'Failed to load low stock items',
              onRetry: () => ref.invalidate(lowStockProductsProvider),
            ),
          ),
        ],
      ),
    );
  }
}
