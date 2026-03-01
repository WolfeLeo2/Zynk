import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/core/providers/app_providers.dart' hide userRoleProvider;

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize branch selection — triggers load from SharedPreferences
    ref.watch(branchSelectionProvider);

    final role = ref.watch(userRoleProvider);
    final destinations = _buildDestinations(role);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile: Bottom Navigation Bar
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
          );
        } else if (constraints.maxWidth < 840) {
          // Tablet: Navigation Rail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) => navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  ),
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        } else {
          // Desktop: Custom Sidebar
          return Scaffold(
            body: Row(
              children: [
                _buildSidebar(context, destinations, ref),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    List<_SidebarDestination> destinations,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final displayName = profileAsync.value?.displayName ?? 'Business Owner';
    final photoUrl = profileAsync.value?.profilePictureUrl;

    return Container(
      width: 280,
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final dest = destinations[index];
                final isSelected = navigationShell.currentIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected
                        ? colorScheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: isSelected ? dest.selectedIcon : dest.icon,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              dest.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? colorScheme.onSecondary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // User Profile Area at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
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
                  PhosphorIcon(
                    PhosphorIconsRegular.caretUp,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_SidebarDestination> _buildDestinations(UserRole role) {
    final dests = <_SidebarDestination>[];

    // 0. Dashboard
    dests.add(
      _SidebarDestination(
        icon: PhosphorIcon(PhosphorIconsDuotone.house),
        selectedIcon: PhosphorIcon(
          PhosphorIconsFill.house,
          color: Colors.black87,
        ),
        label: 'Dashboard',
      ),
    );

    // 1. POS
    dests.add(
      _SidebarDestination(
        icon: PhosphorIcon(PhosphorIconsDuotone.storefront),
        selectedIcon: PhosphorIcon(
          PhosphorIconsFill.storefront,
          color: Colors.black87,
        ),
        label: 'POS',
      ),
    );

    // 2. Invoices
    dests.add(
      _SidebarDestination(
        icon: PhosphorIcon(PhosphorIconsDuotone.receipt),
        selectedIcon: PhosphorIcon(
          PhosphorIconsFill.receipt,
          color: Colors.black87,
        ),
        label: 'Invoices',
      ),
    );

    // 3. Settings
    dests.add(
      _SidebarDestination(
        icon: PhosphorIcon(PhosphorIconsDuotone.gear),
        selectedIcon: PhosphorIcon(
          PhosphorIconsFill.gear,
          color: Colors.black87,
        ),
        label: 'Settings',
      ),
    );

    // 4. Design Gallery (Dev only)
    dests.add(
      _SidebarDestination(
        icon: PhosphorIcon(PhosphorIconsDuotone.palette),
        selectedIcon: PhosphorIcon(
          PhosphorIconsFill.palette,
          color: Colors.black87,
        ),
        label: 'Design',
      ),
    );

    return dests;
  }
}

class _SidebarDestination {
  final Widget icon;
  final Widget selectedIcon;
  final String label;

  _SidebarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
