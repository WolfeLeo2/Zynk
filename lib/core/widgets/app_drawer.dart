import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/shared/widgets/branch_dropdown.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final user = ref.watch(authStateProvider).value;
    final tenant = ref.watch(currentTenantProvider).value;

    final displayName =
        profileAsync.value?.displayName ??
        user?.userMetadata?['display_name'] as String? ??
        'Business Owner';
    final photoUrl = profileAsync.value?.profilePictureUrl;

    // Attempt to dynamically break the tenant name into two lines if it contains a space
    String shopName =
        tenant?.name ??
        user?.userMetadata?['shop_name'] as String? ??
        'Passionate Homes';
    if (shopName.contains(' ') && !shopName.contains('\n')) {
      shopName = shopName.replaceFirst(' ', '\n');
    }

    final currentPath = GoRouterState.of(context).uri.path;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 1,
      semanticLabel: 'Main navigation menu',
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const PhosphorIcon(
                    PhosphorIconsDuotone.storefront,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    shopName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Branch picker / current-branch indicator.
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 16, 4),
            child: BranchDropdown(isExpanded: true),
          ),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 6),

          Expanded(
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.hardEdge,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Always show Dashboard, conditionally rendered internally
                  _DrawerItem(
                    icon: PhosphorIconsDuotone.house,
                    label: 'Dashboard',
                    path: '/',
                    currentPath: currentPath,
                  ),

                  if (profileAsync.value?.hasPermission(Permission.posAccess) ==
                      true)
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.storefront,
                      label: 'Point of Sale',
                      path: '/pos',
                      currentPath: currentPath,
                    ),

                  // --- SALES ---
                  if (profileAsync.value?.hasPermission(
                            Permission.createInvoices,
                          ) ==
                          true ||
                      profileAsync.value?.hasPermission(
                            Permission.approveInvoices,
                          ) ==
                          true) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('SALES', style: _headerStyle(theme)),
                    ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.receipt,
                      label: 'Invoices',
                      path: '/sales',
                      currentPath: currentPath,
                    ),
                    if (profileAsync.value?.hasPermission(
                          Permission.manageExpenses,
                        ) ==
                        true)
                      _DrawerItem(
                        icon: PhosphorIconsDuotone.money,
                        label: 'Expenses',
                        path: '/expenses',
                        currentPath: currentPath,
                      ),
                  ],

                  // --- INVENTORY ---
                  if (profileAsync.value?.hasPermission(
                            Permission.manageProducts,
                          ) ==
                          true ||
                      profileAsync.value?.hasPermission(
                            Permission.manageStock,
                          ) ==
                          true) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('INVENTORY', style: _headerStyle(theme)),
                    ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.package,
                      label: 'Items',
                      path: '/products',
                      currentPath: currentPath,
                    ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.package,
                      label: 'Item Groups',
                      path: '/products/groups',
                      currentPath: currentPath,
                    ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.stack,
                      label: 'Composite Items',
                      path: '/products/composite',
                      currentPath: currentPath,
                    ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.slidersHorizontal,
                      label: 'Batch Adjust Stock',
                      path: '/adjustments',
                      currentPath: currentPath,
                    ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.slidersHorizontal,
                      label: 'Adjustments Review',
                      path: '/settings/adjustments-review',
                      currentPath: currentPath,
                    ),
                  ],

                  // --- REPORTS ---
                  if (profileAsync.value?.hasPermission(
                        Permission.viewReports,
                      ) ==
                      true) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('REPORTS', style: _headerStyle(theme)),
                    ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.currencyDollar,
                      label: 'Reports',
                      path: '/settings/reports',
                      currentPath: currentPath,
                    ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.trendUp,
                      label: 'Commissions',
                      path: '/settings/commissions',
                      currentPath: currentPath,
                    ),
                  ],

                  // --- SYSTEM ---
                  if (profileAsync.value?.hasPermission(
                            Permission.manageBranches,
                          ) ==
                          true ||
                      profileAsync.value?.hasPermission(
                            Permission.manageStaff,
                          ) ==
                          true ||
                      profileAsync.value?.role.isOwner == true ||
                      profileAsync.value?.role.isManager == true) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('SYSTEM', style: _headerStyle(theme)),
                    ),
                    if (profileAsync.value?.hasPermission(
                          Permission.manageBranches,
                        ) ==
                        true)
                      _DrawerItem(
                        icon: PhosphorIconsDuotone.buildings,
                        label: 'Branches',
                        path: '/settings/branches',
                        currentPath: currentPath,
                      ),
                    if (profileAsync.value?.hasPermission(
                          Permission.manageStaff,
                        ) ==
                        true)
                      _DrawerItem(
                        icon: PhosphorIconsDuotone.users,
                        label: 'User Accounts',
                        path: '/settings/staff',
                        currentPath: currentPath,
                      ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.gear,
                      label: 'Settings',
                      path: '/settings',
                      currentPath: currentPath,
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('SYSTEM', style: _headerStyle(theme)),
                    ),
                    _DrawerItem(
                      icon: PhosphorIconsDuotone.gear,
                      label: 'Settings',
                      path: '/settings',
                      currentPath: currentPath,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // User Profile
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: photoUrl != null
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? PhosphorIcon(
                            PhosphorIconsDuotone.user,
                            size: 20,
                            color: colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Active',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.secondary,
                          ),
                        ),
                      ],
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

  TextStyle _headerStyle(ThemeData theme) {
    return theme.textTheme.labelSmall!.copyWith(
      color: theme.brightness == Brightness.light
          ? AppTokens.textMutedLight
          : AppTokens.textMutedDark,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final PhosphorIconData icon;
  final String label;
  final String path;
  final String currentPath;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Evaluate if selected
    bool isSelected = false;
    if (path == '/') {
      isSelected = currentPath == '/';
    } else {
      isSelected = currentPath.startsWith(path);
      // Ensure we don't accidentally match /products for /products/batch-adjust
      // wait, actually we want the Products tab active when in batch-adjust
      // if it's nested under it. This is fine.
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        selectedTileColor: colorScheme.primary.withValues(alpha: 0.1),
        leading: PhosphorIcon(
          icon,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          size: 20,
        ),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () {
          if (Scaffold.of(context).hasDrawer &&
              Scaffold.of(context).isDrawerOpen) {
            Navigator.of(context).pop();
          }

          if (!isSelected) {
            context.go(path);
          }
        },
      ),
    );
  }
}
