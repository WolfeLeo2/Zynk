import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/theme/app_tokens.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final displayName = profileAsync.value?.displayName ?? 'Business Owner';
    final photoUrl = profileAsync.value?.profilePictureUrl;
    
    final currentPath = GoRouterState.of(context).uri.path;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
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
                Text(
                  'Zynk',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _DrawerItem(
                  icon: PhosphorIconsDuotone.house,
                  label: 'Dashboard',
                  path: '/',
                  currentPath: currentPath,
                ),
                _DrawerItem(
                  icon: PhosphorIconsDuotone.storefront,
                  label: 'Point of Sale',
                  path: '/pos',
                  currentPath: currentPath,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text('SALES', style: _headerStyle(theme)),
                ),
                _DrawerItem(
                  icon: PhosphorIconsDuotone.receipt,
                  label: 'Invoices',
                  path: '/sales',
                  currentPath: currentPath,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
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
                  label: 'Adjustments',
                  path: '/adjustments',
                  currentPath: currentPath,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text('SYSTEM', style: _headerStyle(theme)),
                ),
                _DrawerItem(
                  icon: PhosphorIconsDuotone.buildings,
                  label: 'Branches',
                  path: '/settings/branches',
                  currentPath: currentPath,
                ),
                _DrawerItem(
                  icon: PhosphorIconsDuotone.users,
                  label: 'Staff Members',
                  path: '/settings/staff',
                  currentPath: currentPath,
                ),
                _DrawerItem(
                  icon: PhosphorIconsDuotone.gear,
                  label: 'Settings',
                  path: '/settings',
                  currentPath: currentPath,
                ),
              ],
            ),
          ),

          // User Profile
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light ? Colors.white : AppTokens.bgSurfaceHighlightDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  )
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
                            color: AppTokens.brandSecondary,
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
      color: theme.brightness == Brightness.light ? AppTokens.textMutedLight : AppTokens.textMutedDark,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
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
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // Close drawer if open (mobile)
            if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
              Navigator.of(context).pop();
            }
            
            if (!isSelected) {
              context.go(path); // Let goRouter handle the branch navigation
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                PhosphorIcon(
                  icon,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
