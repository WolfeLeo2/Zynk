import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zynk/core/app_shell.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/features/auth/sign_in_screen.dart';
import 'package:zynk/features/auth/sign_up_screen.dart';
import 'package:zynk/features/auth/verify_email_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/features/dashboard/presentation/dashboard_layout.dart';
import 'package:zynk/features/pos/presentation/pos_screen.dart';
import 'package:zynk/features/products/presentation/add_product_screen.dart';
import 'package:zynk/features/products/presentation/products_screen.dart';
import 'package:zynk/features/products/presentation/group_details_screen.dart';
import 'package:zynk/features/products/presentation/inventory_adjustment_screen.dart';
import 'package:zynk/features/products/presentation/product_details_screen.dart';
import 'package:zynk/features/products/presentation/item_groups_screen.dart';
import 'package:zynk/features/products/presentation/composite_items_screen.dart';
import 'package:zynk/features/products/presentation/add_item_group_screen.dart';
import 'package:zynk/features/products/presentation/add_composite_item_screen.dart';
import 'package:zynk/features/products/presentation/composite_item_details_screen.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/features/sales/presentation/sales_list_screen.dart';
import 'package:zynk/features/sales/presentation/create_invoice_screen.dart';
import 'package:zynk/features/sales/presentation/edit_invoice_screen.dart';
import 'package:zynk/features/sales/presentation/sale_detail_screen.dart';
import 'package:zynk/features/settings/presentation/settings_screen.dart';
import 'package:zynk/features/settings/presentation/branches_screen.dart';
import 'package:zynk/features/settings/presentation/add_branch_screen.dart';
import 'package:zynk/features/settings/presentation/staff_screen.dart';
import 'package:zynk/features/settings/presentation/add_staff_screen.dart';
import 'package:zynk/features/settings/presentation/staff_members_screen.dart';
import 'package:zynk/features/products/presentation/adjustments_screen.dart';
import 'package:zynk/features/reports/presentation/reports_screen.dart';

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

      final loc = state.matchedLocation;
      final isOnAuthRoute =
          loc == '/login' || loc == '/signup' || loc == '/verify-email';

      // Not logged in → must be on an auth screen
      if (!isLoggedIn) {
        return isOnAuthRoute ? null : '/login';
      }

      // Logged in → after email verification, go straight to app
      if (loc == '/verify-email') return '/';

      // Logged in → don't stay on auth screens
      if (isOnAuthRoute) return '/';

      final profile = ref.read(currentUserProfileProvider).value;
      if (profile != null) {
        // Enforce Dashboard access
        if (loc == '/' && !profile.hasPermission(Permission.viewDashboard)) {
          // If no dashboard, redirect to pos or settings
          return profile.hasPermission(Permission.posAccess) ? '/pos' : '/settings';
        }

        // Enforce POS access
        if (loc.startsWith('/pos') && !profile.hasPermission(Permission.posAccess)) {
          return '/';
        }

        // Enforce Product access
        if (loc.startsWith('/products') || loc.startsWith('/adjustments')) {
          if (!profile.hasPermission(Permission.manageProducts) &&
              !profile.hasPermission(Permission.manageStock)) {
            return profile.hasPermission(Permission.viewDashboard) ? '/' : '/pos';
          }
        }

        // Enforce Branches access
        if (loc.startsWith('/settings/branches') &&
            !profile.hasPermission(Permission.manageBranches)) {
          return '/settings';
        }

        // Enforce Staff access
        if (loc.startsWith('/settings/staff') &&
            !profile.hasPermission(Permission.manageStaff)) {
          return '/settings';
        }

        // Enforce Reports access
        if (loc.startsWith('/settings/reports') &&
            !profile.hasPermission(Permission.viewReports)) {
          return profile.hasPermission(Permission.viewDashboard) ? '/' : '/pos';
        }
      }

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
                    builder: (context, state) {
                      final groupId = state.uri.queryParameters['groupId'];
                      return ProductsScreen(initialGroupId: groupId);
                    },
                    routes: [
                      GoRoute(
                        path: 'add',
                        builder: (context, state) {
                          final extra = state.extra;

                          if (extra is Product) {
                            return AddProductScreen(existingProduct: extra);
                          }

                          if (extra is Map<String, dynamic>) {
                            final product = extra['product'];
                            final isClone = extra['clone'] == true;
                            if (product is Product) {
                              return AddProductScreen(
                                existingProduct: product,
                                isCloneMode: isClone,
                              );
                            }
                          }

                          return const AddProductScreen();
                        },
                      ),
                      GoRoute(
                        path: 'groups',
                        builder: (context, state) => const ItemGroupsScreen(),
                        routes: [
                          GoRoute(
                            path: 'add',
                            builder: (context, state) =>
                                const AddItemGroupScreen(),
                          ),
                          GoRoute(
                            path: ':id',
                            builder: (context, state) {
                              final group = state.extra as ItemGroup;
                              return GroupDetailsScreen(group: group);
                            },
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'composite',
                        builder: (context, state) =>
                            const CompositeItemsScreen(),
                        routes: [
                          GoRoute(
                            path: 'add',
                            builder: (context, state) =>
                                const AddCompositeItemScreen(),
                          ),
                          GoRoute(
                            path: ':id',
                            builder: (context, state) {
                              final id = state.pathParameters['id']!;
                              return CompositeItemDetailsScreen(productId: id);
                            },
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'details',
                        builder: (context, state) {
                          final product = state.extra as Product;
                          return ProductDetailsScreen(product: product);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'adjustments',
                    builder: (context, state) =>
                        const InventoryAdjustmentScreen(),
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
                        salespersonId: extra['salespersonId'],
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final saleId = state.pathParameters['id']!;
                      return SaleDetailScreen(saleId: saleId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final saleId = state.pathParameters['id']!;
                          return EditInvoiceScreen(saleId: saleId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 3: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
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
                    builder: (context, state) {
                      final existing = state.extra as Profile?;
                      return AddStaffScreen(existingProfile: existing);
                    },
                  ),
                  GoRoute(
                    path: 'staff-members',
                    builder: (context, state) => const StaffMembersScreen(),
                  ),
                  GoRoute(
                    path: 'adjustments-review',
                    builder: (context, state) => const AdjustmentsScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'commissions',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Triggers router re-evaluation on auth state changes only.
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
    ref.watch(currentUserProfileProvider);
    return const SettingsScreen();
  }
}
