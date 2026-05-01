import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/widgets/app_drawer.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize branch selection — triggers load from SharedPreferences
    ref.watch(branchSelectionProvider);
    // Activate branch stream sync — reacts to branchesProvider changes safely
    ref.watch(branchSyncProvider);
    // Fallback: set branch from profile stream for accounts without metadata branch_id
    ref.watch(profileBranchSyncProvider);
    // Enforce account status (logout if blocked)
    ref.watch(statusEnforcerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          // Mobile & Tablet: Hidden drawer (requires hamburger menu on AppBar)
          return Scaffold(
            drawer: const AppDrawer(),
            body: navigationShell,
          );
        } else {
          // Desktop: Persistent Sidebar
          return Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 280, child: AppDrawer()), 
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
      },
    );
  }
}
