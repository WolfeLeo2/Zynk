import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/providers/app_providers.dart' hide userRoleProvider;
import 'package:zynk/core/theme/app_tokens.dart';

class DashboardLayout extends ConsumerWidget {
  const DashboardLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repository = ref.watch(repositoryProvider);

    // Watch Metrics
    final salesAsync = ref.watch(
      StreamProvider((ref) => repository.watchTotalSales()),
    );
    //Commenting out staff count for now.
    //TODO: Uncomment when we add payments and want to see staff performance.
    /*final staffAsync = ref.watch(
      StreamProvider((ref) => repository.watchStaffCount()),
    );*/
    final profileAsync = ref.watch(currentUserProfileProvider);
    final tenantAsync = ref.watch(currentTenantProvider);

    final displayName = profileAsync.value?.displayName ?? 'User';
    final tenantName = tenantAsync.value?.name ?? 'Workspace';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 840;

        if (isDesktop) {
          return _buildDesktopLayout(
            context,
            theme,
            colorScheme,
            role,
            salesAsync,
            //staffAsync,
            displayName,
            tenantName,
          );
        }

        return _buildMobileLayout(
          context,
          theme,
          colorScheme,
          role,
          salesAsync,
          //staffAsync,
          displayName,
          profileAsync.value?.profilePictureUrl,
          tenantName,
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    UserRole role,
    AsyncValue<double> salesAsync,
    //AsyncValue<int> staffAsync,
    String displayName,
    String tenantName,
  ) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Custom Desktop Top Bar
          Padding(
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
                Row(children: [_BranchSelector(role: role)]),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Metric Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Total Revenue',
                          value: salesAsync.when(
                            data: (val) => 'Ksh ${val.toStringAsFixed(0)}',
                            loading: () => '...',
                            error: (_, __) => 'Error',
                          ),
                          icon: PhosphorIconsDuotone.currencyDollar,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MetricCard(
                          title: 'Daily Orders',
                          value: '24', // Placeholder
                          icon: PhosphorIconsDuotone.receipt,
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MetricCard(
                          title: 'Low Stock Items',
                          value: '3', // Placeholder
                          icon: PhosphorIconsDuotone.warning,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Main Content Split
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column (70%)
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SalesReportChart(colorScheme: colorScheme),
                            const SizedBox(height: 24),
                            _RecentOrders(colorScheme: colorScheme),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column (30%)
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _QuickActionsDesktop(colorScheme: colorScheme),
                            const SizedBox(height: 24),
                            _TopSellingProducts(colorScheme: colorScheme),
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
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    UserRole role,
    AsyncValue<double> salesAsync,
    //AsyncValue<int> staffAsync,
    String displayName,
    String? photoUrl,
    String tenantName,
  ) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            _DashboardSliverAppBar(
              role: role,
              displayName: displayName,
              photoUrl: photoUrl,
              tenantName: tenantName,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Quick Actions (Horizontal Scroll)
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _MobileQuickAction(
                          icon: PhosphorIconsDuotone.package,
                          label: 'Products',
                          color: colorScheme.primary,
                          onTap: () => context.push('/products'),
                        ),
                        const SizedBox(width: 12),
                        _MobileQuickAction(
                          icon: PhosphorIconsBold.plus,
                          label: 'Add',
                          color: colorScheme.secondary,
                          onTap: () => context.push('/add-product'),
                        ),
                        const SizedBox(width: 12),
                        _MobileQuickAction(
                          icon: PhosphorIconsBold.cashRegister,
                          label: 'POS',
                          color: colorScheme.tertiary,
                          onTap: () => context.push('/pos'),
                        ),
                        const SizedBox(width: 12),
                        _MobileQuickAction(
                          icon: PhosphorIconsBold.users,
                          label: 'Staff',
                          color: colorScheme.primary,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Metrics Grid
                  Text(
                    'Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Total Revenue',
                          value: salesAsync.when(
                            data: (val) => 'Ksh ${val.toStringAsFixed(0)}',
                            loading: () => '...',
                            error: (_, __) => 'Error',
                          ),
                          icon: PhosphorIconsDuotone.currencyDollar,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'Daily Orders',
                          value: '24',
                          icon: PhosphorIconsDuotone.receipt,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sales Report Chart
                  _SalesReportChart(colorScheme: colorScheme),
                  const SizedBox(height: 24),

                  // Top Selling Products
                  _TopSellingProducts(colorScheme: colorScheme),
                  const SizedBox(height: 24),

                  // Recent Orders
                  _RecentOrders(colorScheme: colorScheme),
                  const SizedBox(height: 80), // Padding for bottom nav
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PhosphorIcon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsBold.trendUp,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '12%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesReportChart extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SalesReportChart({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Report',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  'This Week',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: const FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 6,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3),
                      FlSpot(1, 4),
                      FlSpot(2, 3.5),
                      FlSpot(3, 5),
                      FlSpot(4, 4),
                      FlSpot(5, 5.5),
                      FlSpot(6, 5),
                    ],
                    isCurved: true,
                    color: colorScheme.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.3),
                          colorScheme.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSellingProducts extends StatelessWidget {
  final ColorScheme colorScheme;

  const _TopSellingProducts({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Selling Products',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildItem('Espresso Latte', '124 sales', 'Ksh 350', colorScheme),
          const SizedBox(height: 12),
          _buildItem('Chocolate Muffin', '98 sales', 'Ksh 250', colorScheme),
          const SizedBox(height: 12),
          _buildItem(
            'Iced Caramel Macchiato',
            '76 sales',
            'Ksh 450',
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    String name,
    String subtitle,
    String price,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: PhosphorIcon(
            PhosphorIconsDuotone.coffee,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                subtitle,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          price,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _RecentOrders extends StatelessWidget {
  final ColorScheme colorScheme;

  const _RecentOrders({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 16),
          _buildOrderItem(
            '#1042',
            'Walk-in Customer',
            'Ksh 1,200',
            'Completed',
            colorScheme,
          ),
          const Divider(height: 24),
          _buildOrderItem(
            '#1043',
            'John Doe',
            'Ksh 450',
            'Preparing',
            colorScheme,
          ),
          const Divider(height: 24),
          _buildOrderItem(
            '#1044',
            'Jane Smith',
            'Ksh 850',
            'Completed',
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(
    String id,
    String name,
    String total,
    String status,
    ColorScheme colorScheme,
  ) {
    final isCompleted = status == 'Completed';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: PhosphorIcon(PhosphorIconsDuotone.receipt, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                id,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(total, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MobileQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            PhosphorIcon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsDesktop extends StatelessWidget {
  final ColorScheme colorScheme;

  const _QuickActionsDesktop({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionBtn(
                context,
                'Open POS',
                PhosphorIconsBold.cashRegister,
                () => context.push('/pos'),
              ),
              _buildActionBtn(
                context,
                'Products',
                PhosphorIconsDuotone.package,
                () => context.push('/products'),
              ),
              _buildActionBtn(
                context,
                'Add Item',
                PhosphorIconsBold.plus,
                () => context.push('/add-product'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _DashboardSliverAppBar extends StatelessWidget {
  final UserRole role;
  final String displayName;
  final String tenantName;
  final String? photoUrl;

  const _DashboardSliverAppBar({
    required this.role,
    required this.displayName,
    required this.tenantName,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return SliverAppBar.medium(
      pinned: true,
      expandedHeight: 140,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: theme.scaffoldBackgroundColor,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: InkWell(
          onTap: () => context.push('/settings'),
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: photoUrl != null
                ? CachedNetworkImageProvider(photoUrl!)
                : null,
            child: photoUrl == null
                ? PhosphorIcon(
                    PhosphorIconsDuotone.user,
                    color: colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
        ),
      ),
      leadingWidth: 56, // Adjust for padding
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
        _BranchSelector(role: role),
        const SizedBox(width: 16),
      ],
    );
  }
}

class _BranchSelector extends ConsumerWidget {
  final UserRole role;

  const _BranchSelector({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final branchesState = ref.watch(branchesProvider);
    final selectionState = ref.watch(branchSelectionProvider);

    return branchesState.when(
      data: (branches) {
        if (branches.isEmpty) return const SizedBox.shrink();

        // Use selected branch, fallback to first available
        final selectedBranchId =
            selectionState.selectedBranchId ?? branches.first.id;
        final selectedBranchName = branches
            .firstWhere(
              (b) => b.id == selectedBranchId,
              orElse: () => branches.first,
            )
            .name;

        // Cashier View (Read-only Badge)
        if (!role.canManageBusiness) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  selectedBranchName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        // Owner/Manager View (Dropdown)
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedBranchId,
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
              items: branches.map((branch) {
                return DropdownMenuItem(
                  value: branch.id,
                  child: Text(
                    branch.name,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(branchSelectionProvider.notifier).selectBranch(val);
                }
              },
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(right: 16),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
