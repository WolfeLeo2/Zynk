import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/providers/app_providers.dart' hide userRoleProvider;
import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';

import 'package:zynk/core/widgets/app_drawer.dart';
import 'widgets/metric_cards.dart';
import 'widgets/charts.dart';
import 'widgets/orders_list.dart';
import 'widgets/products_list.dart';
import 'staff_dashboard_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN DASHBOARD LAYOUT
// ─────────────────────────────────────────────────────────────────────────────

class DashboardLayout extends ConsumerWidget {
  const DashboardLayout({super.key});

  Future<void> _refreshDashboard(WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    ref.invalidate(dashboardRefreshTriggerProvider);
    await Future.delayed(const Duration(milliseconds: 1200));
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final salesAsync = ref.watch(salesDataProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final tenantAsync = ref.watch(currentTenantProvider);
    final greeting = ref.watch(greetingProvider);

    final displayName = profileAsync.value?.displayName ?? 'User';
    final tenantName = tenantAsync.value?.name ?? 'Passionate Homes';

    final hasDashboardPermission = profileAsync.value?.hasPermission(Permission.viewDashboard) ?? false;
    if (!hasDashboardPermission && profileAsync.value != null) {
      return StaffDashboardLayout(
        role: role,
        displayName: displayName,
        tenantName: tenantName,
        photoUrl: profileAsync.value?.profilePictureUrl,
        greeting: greeting,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 840;

        if (isDesktop) {
          return _DesktopDashboard(
            colorScheme: colorScheme,
            theme: theme,
            role: role,
            salesAsync: salesAsync,
            displayName: displayName,
            tenantName: tenantName,
            greeting: greeting,
            onRefresh: () => _refreshDashboard(ref),
          );
        }

        return _MobileDashboard(
          colorScheme: colorScheme,
          theme: theme,
          role: role,
          salesAsync: salesAsync,
          displayName: displayName,
          tenantName: tenantName,
          photoUrl: profileAsync.value?.profilePictureUrl,
          greeting: greeting,
          onRefresh: () => _refreshDashboard(ref),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP LAYOUT
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopDashboard extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  final UserRole role;
  final AsyncValue<double> salesAsync;
  final String displayName;
  final String tenantName;
  final String greeting;
  final VoidCallback onRefresh;

  const _DesktopDashboard({
    required this.colorScheme,
    required this.theme,
    required this.role,
    required this.salesAsync,
    required this.displayName,
    required this.tenantName,
    required this.greeting,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => onRefresh(),
        displacement: 40,
        strokeWidth: 3,
        color: colorScheme.primary,
        backgroundColor: colorScheme.surface,
        child: Column(
          children: [
            DesktopAppBar(
              colorScheme: colorScheme,
              theme: theme,
              tenantName: tenantName,
              displayName: displayName,
              role: role,
              greeting: greeting,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DesktopMetricsGrid(
                      salesAsync: salesAsync,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RevenueBarChart(),
                              SizedBox(height: 24),
                              RecentOrdersTable(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              const PaymentMethodsChart(),
                              const SizedBox(height: 24),
                              const TopSellingProductsList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE LAYOUT
// ─────────────────────────────────────────────────────────────────────────────

class _MobileDashboard extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  final UserRole role;
  final AsyncValue<double> salesAsync;
  final String displayName;
  final String tenantName;
  final String? photoUrl;
  final String greeting;
  final VoidCallback onRefresh;

  const _MobileDashboard({
    required this.colorScheme,
    required this.theme,
    required this.role,
    required this.salesAsync,
    required this.displayName,
    required this.tenantName,
    this.photoUrl,
    required this.greeting,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => onRefresh(),
        displacement: 60,
        strokeWidth: 3,
        color: colorScheme.primary,
        backgroundColor: colorScheme.surface,
        child: SafeArea(
          top: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              DashboardSliverAppBar(
                role: role,
                displayName: displayName,
                tenantName: tenantName,
                photoUrl: photoUrl,
                greeting: greeting,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 12),
                    const MobileMetricsGrid(),
                    const SizedBox(height: 24),
                    const RevenueBarChart(),
                    const SizedBox(height: 24),
                    const PaymentMethodsChart(),
                    const SizedBox(height: 24),
                    const TopSellingProductsList(),
                    const SizedBox(height: 24),
                    const RecentOrdersList(),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class DesktopAppBar extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  final String tenantName;
  final String displayName;
  final UserRole role;
  final String greeting;

  const DesktopAppBar({
    super.key,
    required this.colorScheme,
    required this.theme,
    required this.tenantName,
    required this.displayName,
    required this.role,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tenantName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$greeting, $displayName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class DashboardSliverAppBar extends StatelessWidget {
  final UserRole role;
  final String displayName;
  final String tenantName;
  final String? photoUrl;
  final String greeting;

  const DashboardSliverAppBar({
    super.key,
    required this.role,
    required this.displayName,
    required this.tenantName,
    this.photoUrl,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverAppBar.medium(
      pinned: true,
      expandedHeight: 140,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.primaryContainer,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const PhosphorIcon(PhosphorIconsDuotone.list),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      leadingWidth: 56,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tenantName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            '$greeting, $displayName',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [const SizedBox(width: 8)],
    );
  }
}
