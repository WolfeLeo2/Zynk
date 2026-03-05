import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zynk/core/app_shell.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/features/auth/biometric_lock_screen.dart';
import 'package:zynk/features/auth/sign_in_screen.dart';
import 'package:zynk/features/auth/sign_up_screen.dart';
import 'package:zynk/features/auth/verify_email_screen.dart';
import 'package:zynk/features/auth/biometric_setup_screen.dart';
import 'package:zynk/features/auth/providers/biometric_provider.dart';
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
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: AuthListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.value != null;
      final biometricEnabled = ref.read(biometricEnabledProvider);
      final biometricChecked = ref.read(biometricCheckedProvider);
      final pin = ref.read(pinProvider);
      final hasPin = pin != null;

      final loc = state.matchedLocation;
      final isOnAuthRoute =
          loc == '/login' || loc == '/signup' || loc == '/verify-email';
      final isOnSetupRoute = loc == '/biometric-setup';
      final isOnLockRoute = loc == '/biometric-lock';

      // 1. If not logged in, must be on auth screen
      if (!isLoggedIn) {
        return isOnAuthRoute ? null : '/login';
      }

      // --- Logged-in cases ---

      // 2. Just verified email — push them forward to biometric/PIN setup
      if (loc == '/verify-email') {
        return '/biometric-setup';
      }

      // 3. If they don't have a PIN yet, keep them on /biometric-setup
      //    (BiometricSetupScreen handles completion itself via context.go('/'))
      if (!hasPin && !isOnSetupRoute) {
        return '/biometric-setup';
      }

      // 4. If they have a PIN and are on an auth-flow route, send them home
      if (hasPin && (isOnAuthRoute || isOnSetupRoute)) {
        return '/';
      }

      // 5. At app start: if biometrics are ON and not yet checked this session,
      //    force the lock screen. Only applies when not already on the lock screen.
      if (hasPin && biometricEnabled && !biometricChecked && !isOnLockRoute) {
        return '/biometric-lock';
      }

      // 6. No redirect needed
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
        path: '/verify-email',
        builder: (context, state) {
          final email = state.extra as String?;
          return VerifyEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/biometric-lock',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => BiometricLockScreen(
            onUnlocked: () {
              ref.read(biometricCheckedProvider.notifier).markChecked();
              context.go('/');
            },
          ),
        ),
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
                        salespersonName: extra['salespersonName'],
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

class BiometricToggleListenable extends ChangeNotifier {
  final Ref ref;

  BiometricToggleListenable(this.ref) {
    ref.listen<bool>(biometricEnabledProvider, (_, __) {
      notifyListeners();
    });
    ref.listen<String?>(pinProvider, (_, __) {
      notifyListeners();
    });
  }
}

class CombinedListenable extends ChangeNotifier {
  final List<Listenable> _listenables;

  CombinedListenable(this._listenables) {
    for (var listenable in _listenables) {
      listenable.addListener(notifyListeners);
    }
  }

  @override
  void dispose() {
    for (var listenable in _listenables) {
      listenable.removeListener(notifyListeners);
    }
    super.dispose();
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
