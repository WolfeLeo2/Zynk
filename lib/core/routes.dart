import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zynk/core/app_shell.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/features/auth/biometric_lock_screen.dart';
import 'package:zynk/features/auth/sign_in_screen.dart';
import 'package:zynk/features/auth/sign_up_screen.dart';
import 'package:zynk/features/auth/biometric_setup_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/features/design_system/gallery_page.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/features/dashboard/presentation/dashboard_layout.dart';
import 'package:zynk/features/pos/presentation/pos_screen.dart';
import 'package:zynk/features/products/presentation/add_product_screen.dart';
import 'package:zynk/features/products/presentation/products_screen.dart';
import 'package:zynk/features/products/presentation/product_details_screen.dart'; // Added
import 'package:zynk/core/models/schema_models.dart'; // Added
import 'package:zynk/features/settings/presentation/settings_screen.dart';
import 'package:zynk/features/settings/presentation/branches_screen.dart';
import 'package:zynk/features/settings/presentation/add_branch_screen.dart';
import 'package:zynk/features/settings/presentation/staff_screen.dart';
import 'package:zynk/features/settings/presentation/add_staff_screen.dart';

// Keys
final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: AuthListenable(ref),
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/';
      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/biometric-lock',
        builder: (context, state) =>
            BiometricLockScreen(onUnlocked: () => context.go('/')),
      ),
      GoRoute(
        path: '/biometric-setup',
        builder: (context, state) => const BiometricSetupScreen(),
      ),

      GoRoute(
        path: '/add-product',
        builder: (context, state) => const AddProductScreen(),
      ),

      GoRoute(
        path: '/product-details',
        builder: (context, state) {
          final product = state.extra as Product;
          return ProductDetailsScreen(product: product);
        },
      ),

      // App Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Home Branch (Placeholder)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardLayout(),
              ),

              GoRoute(
                path: '/pos',
                builder: (context, state) => const PosScreen(),
              ),
              GoRoute(
                path: '/products',
                builder: (context, state) => const ProductsScreen(),
              ),
            ],
          ),
          // Settings Branch (Placeholder)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                // Use the wrapper to ensure profile data is loaded
                builder: (context, state) => const _SettingsScreenWrapper(),
                routes: [
                  GoRoute(
                    path: 'branches',
                    builder: (context, state) => const BranchesScreen(),
                  ),
                  GoRoute(
                    path: 'add-branch',
                    builder: (context, state) => const AddBranchScreen(),
                  ),
                  GoRoute(
                    path: 'staff',
                    builder: (context, state) => const StaffScreen(),
                  ),
                  GoRoute(
                    path: 'add-staff',
                    builder: (context, state) => const AddStaffScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Design System Gallery Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/design-gallery',
                builder: (context, state) => const DesignSystemGalleryPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class AuthListenable extends ChangeNotifier {
  final Ref ref;
  late bool _wasLoggedIn;

  AuthListenable(this.ref) {
    _wasLoggedIn = ref.read(authStateProvider).value != null;
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (_, next) {
      final isLoggedIn = next.value != null;
      if (isLoggedIn != _wasLoggedIn) {
        _wasLoggedIn = isLoggedIn;
        notifyListeners();
      }
    });
  }
}

class _SettingsScreenWrapper extends ConsumerWidget {
  const _SettingsScreenWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch profile to ensure it's loaded
    ref.watch(currentUserProfileProvider);
    return const SettingsScreen();
  }
}
