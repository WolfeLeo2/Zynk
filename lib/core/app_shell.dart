import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/features/auth/presentation/lock_screen.dart';
import 'package:zynk/features/auth/providers/lock_provider.dart';
import 'package:zynk/core/services/app_update_service.dart';
import 'package:zynk/features/settings/presentation/update_prompt.dart';

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

    // Offer an in-app update once per launch (Android; best-effort). Not while
    // locked or before the profile has loaded.
    ref.listen(appUpdateProvider, (_, next) {
      final info = next.value;
      if (info == null || updatePromptShown) return;
      if (ref.read(lockProvider) || ref.read(currentProfileProvider) == null) {
        return;
      }
      updatePromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showUpdatePrompt(context, info);
      });
    });

    // PIN lock gate — covers the whole app (incl. drawer). The device session
    // stays active underneath, so sync keeps running while locked.
    if (ref.watch(lockProvider)) {
      return const LockScreen();
    }

    // Gate the whole shell until the profile (and therefore role/permissions)
    // has resolved. Prevents the fail-open window where role defaults are read
    // and permission-gated screens render before authz is known.
    if (ref.watch(currentProfileProvider) == null) {
      return const _ProfileLoadingScreen();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          // Mobile & Tablet: Hidden drawer (requires hamburger menu on AppBar)
          return Scaffold(drawer: const AppDrawer(), body: navigationShell);
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

/// Shown after login while the user's profile syncs from the local DB.
class _ProfileLoadingScreen extends StatelessWidget {
  const _ProfileLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Lottie.asset('assets/animations/welcome_loading.json'),
            ),
            const SizedBox(height: 16),
            Text(
              'Just a minute…',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "We're setting up your workspace.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
