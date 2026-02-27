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
import 'package:zynk/features/products/presentation/product_details_screen.dart';
import 'package:zynk/features/products/presentation/group_details_screen.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/sales/presentation/sales_list_screen.dart';
import 'package:zynk/features/sales/presentation/create_invoice_screen.dart';
import 'package:zynk/features/sales/presentation/sale_detail_screen.dart';
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
        builder: (context, state) {
          final product = state.extra as Product?;
          return AddProductScreen(existingProduct: product);
        },
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
          // 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardLayout(),
                routes: [
                  GoRoute(
                    path: 'products',
                    builder: (context, state) => const ProductsScreen(),
                    routes: [
                      GoRoute(
                        path: 'groups/:id',
                        builder: (context, state) {
                          final group = state.extra as ItemGroup;
                          return GroupDetailsScreen(group: group);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 1: POS
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pos',
                builder: (context, state) => const PosScreen(),
              ),
            ],
          ),
          // 2: Sales / Invoices
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sales',
                builder: (context, state) => const SalesListScreen(),
                routes: [
                  GoRoute(
                    path: 'create-invoice',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>? ?? {};
                      return CreateInvoiceScreen(
                        cartItems: extra['cartItems'] ?? [],
                        customer: extra['customer'],
                        staffName: extra['staffName'],
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final saleId = state.pathParameters['id']!;
                      return SaleDetailScreen(saleId: saleId);
                    },
                  ),
                ],
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
