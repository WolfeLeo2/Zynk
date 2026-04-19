import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/providers/app_providers.dart' hide userRoleProvider;
import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';

import 'package:shimmer/shimmer.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'widgets/metric_cards.dart';
import 'widgets/charts.dart';
import 'widgets/orders_list.dart';
import 'widgets/products_list.dart';

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
            _DesktopAppBar(
              colorScheme: colorScheme,
              theme: theme,
              tenantName: tenantName,
              displayName: displayName,
              role: role,
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

class _DesktopAppBar extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  final String tenantName;
  final String displayName;
  final UserRole role;

  const _DesktopAppBar({
    required this.colorScheme,
    required this.theme,
    required this.tenantName,
    required this.displayName,
    required this.role,
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
                'Welcome back, $displayName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(children: [BranchSelector(role: role)]),
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
      actions: [
        BranchSelector(role: role),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRANCH SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class BranchSelector extends ConsumerWidget {
  final UserRole role;

  const BranchSelector({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final branchesState = ref.watch(branchesProvider);
    final selectionState = ref.watch(branchSelectionProvider);

    return branchesState.when(
      data: (_) {
        final branches = selectionState.availableBranches;
        if (branches.isEmpty) return const SizedBox.shrink();

        final selectedBranchId =
            selectionState.selectedBranchId ?? branches.first.id;
        final selectedBranchName = branches
            .firstWhere(
              (b) => b.id == selectedBranchId,
              orElse: () => branches.first,
            )
            .name;

        if (!role.isOwner) {
          return _ReadOnlyBranchBadge(
            name: selectedBranchName,
            colorScheme: colorScheme,
          );
        }

        return _BranchDropdown(
          branches: branches,
          selectedId: selectedBranchId,
          colorScheme: colorScheme,
          theme: theme,
        );
      },
      loading: () => _BranchSkeleton(colorScheme: colorScheme),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ReadOnlyBranchBadge extends StatelessWidget {
  final String name;
  final ColorScheme colorScheme;

  const _ReadOnlyBranchBadge({required this.name, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            PhosphorIconsDuotone.storefront,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchDropdown extends ConsumerWidget {
  final List<dynamic> branches;
  final String selectedId;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _BranchDropdown({
    required this.branches,
    required this.selectedId,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          icon: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: PhosphorIcon(
              PhosphorIconsRegular.caretDown,
              size: 14,
              color: colorScheme.primary,
            ),
          ),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          dropdownColor: colorScheme.surfaceContainer,
          items: branches.map<DropdownMenuItem<String>>((branch) {
            return DropdownMenuItem<String>(
              value: branch.id as String,
              child: Text(
                branch.name as String,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              HapticFeedback.lightImpact();
              ref.read(branchSelectionProvider.notifier).selectBranch(val);
            }
          },
        ),
      ),
    );
  }
}

class _BranchSkeleton extends StatelessWidget {
  final ColorScheme colorScheme;

  const _BranchSkeleton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      highlightColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.6,
      ),
      child: Container(
        width: 120,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
