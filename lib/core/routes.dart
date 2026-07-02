import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zynk/core/app_shell.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/features/auth/sign_in_screen.dart';
import 'package:zynk/features/auth/sign_up_screen.dart';
import 'package:zynk/features/auth/verify_email_screen.dart';
import 'package:zynk/features/auth/forgot_password_screen.dart';
import 'package:zynk/features/auth/verify_otp_screen.dart';
import 'package:zynk/features/auth/reset_password_screen.dart';
import 'package:zynk/features/settings/presentation/change_password_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/features/dashboard/presentation/dashboard_layout.dart';
import 'package:zynk/features/pos/presentation/pos_screen.dart';
import 'package:zynk/features/products/presentation/add_product_screen.dart';
import 'package:zynk/features/products/presentation/products_screen.dart';
import 'package:zynk/features/products/presentation/group_details_screen.dart';
import 'package:zynk/features/products/presentation/inventory_adjustment_screen.dart';
import 'package:zynk/features/products/presentation/product_details_screen.dart';
import 'package:zynk/features/products/presentation/product_transaction_history_screen.dart';
import 'package:zynk/features/products/presentation/item_groups_screen.dart';
import 'package:zynk/features/products/presentation/add_item_group_screen.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/features/sales/presentation/sales_list_screen.dart';
import 'package:zynk/features/sales/presentation/create_invoice_screen.dart';
import 'package:zynk/features/sales/presentation/edit_invoice_screen.dart';
import 'package:zynk/features/sales/presentation/sale_detail_screen.dart';
import 'package:zynk/features/settings/presentation/settings_screen.dart';
import 'package:zynk/features/settings/presentation/branches_screen.dart';
import 'package:zynk/features/settings/presentation/staff_screen.dart';
import 'package:zynk/features/settings/presentation/add_staff_screen.dart';
import 'package:zynk/features/products/presentation/adjustments_screen.dart';
import 'package:zynk/features/reports/presentation/reports_screen.dart';
import 'package:zynk/features/reports/presentation/commissions_report_screen.dart';
import 'package:zynk/features/reports/presentation/stock_report_screen.dart';
import 'package:zynk/features/customers/presentation/customers_screen.dart';
import 'package:zynk/features/products/presentation/adjustment_detail_screen.dart';
import 'package:zynk/features/expenses/presentation/screens/expenses_screen.dart';

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
          loc == '/login' ||
          loc == '/signup' ||
          loc == '/verify-email' ||
          loc == '/forgot-password' ||
          loc == '/forgot-password/verify' ||
          loc == '/forgot-password/reset';

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
        // (Dashboard access is now handled internally by DashboardLayout conditionally rendering StaffDashboard)

        // Enforce POS access
        if (loc.startsWith('/pos') &&
            !profile.hasPermission(Permission.posAccess)) {
          return '/';
        }

        // Enforce Product access
        if (loc.startsWith('/products') || loc.startsWith('/adjustments')) {
          if (!profile.hasPermission(Permission.manageProducts) &&
              !profile.hasPermission(Permission.manageStock)) {
            return profile.hasPermission(Permission.viewDashboard)
                ? '/'
                : '/pos';
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
        if ((loc.startsWith('/settings/reports') ||
                loc.startsWith('/settings/stock-report')) &&
            !profile.hasPermission(Permission.viewReports)) {
          return profile.hasPermission(Permission.viewDashboard) ? '/' : '/pos';
        }

        // Enforce Customers access
        if (loc.startsWith('/settings/customers') &&
            !profile.hasPermission(Permission.manageCustomers)) {
          return '/settings';
        }

        // Enforce Expenses access
        if (loc.startsWith('/expenses') &&
            !profile.hasPermission(Permission.manageExpenses)) {
          return '/';
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
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/forgot-password/verify',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return VerifyOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password/reset',
        builder: (context, state) => const ResetPasswordScreen(),
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
                        path: 'details',
                        builder: (context, state) {
                          final product = state.extra as Product;
                          return ProductDetailsScreen(product: product);
                        },
                        routes: [
                          GoRoute(
                            path: 'history',
                            builder: (context, state) {
                              final extra =
                                  state.extra as Map<String, dynamic>?;
                              final productId =
                                  extra?['productId'] as String? ?? '';
                              final productName =
                                  extra?['productName'] as String? ?? 'Product';
                              return ProductTransactionHistoryScreen(
                                productId: productId,
                                productName: productName,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'adjustments',
                    builder: (context, state) =>
                        const InventoryAdjustmentScreen(),
                  ),
                  GoRoute(
                    path: 'expenses',
                    builder: (context, state) => const ExpensesScreen(),
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
                        branchId: extra['branchId'],
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
                          final extra =
                              state.extra as Map<String, dynamic>? ?? {};
                          return EditInvoiceScreen(
                            saleId: saleId,
                            wasApproved: extra['wasApproved'] == true,
                          );
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
                    path: 'adjustments-review',
                    builder: (context, state) => const AdjustmentsScreen(),
                    routes: [
                      GoRoute(
                        path: ':bundleId',
                        builder: (context, state) {
                          final bundleId = state.pathParameters['bundleId']!;
                          return AdjustmentDetailScreen(bundleId: bundleId);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'stock-report',
                    builder: (context, state) => const StockReportScreen(),
                  ),
                  GoRoute(
                    path: 'commissions',
                    builder: (context, state) =>
                        const CommissionsReportScreen(),
                  ),
                  GoRoute(
                    path: 'customers',
                    builder: (context, state) => const CustomersScreen(),
                  ),
                  GoRoute(
                    path: 'change-password',
                    builder: (context, state) => const ChangePasswordScreen(),
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

/// Triggers router re-evaluation on auth state changes AND when the user's
/// profile (role/permissions) resolves or changes — so permission-gated
/// redirects are re-run once the profile loads, not only at login/logout.
class AuthListenable extends ChangeNotifier {
  final Ref ref;
  late bool _wasLoggedIn;
  String? _lastProfileKey;

  AuthListenable(this.ref) {
    _wasLoggedIn = ref.read(authStateProvider).value != null;
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (_, next) {
      final isLoggedIn = next.value != null;
      if (isLoggedIn != _wasLoggedIn) {
        _wasLoggedIn = isLoggedIn;
        notifyListeners();
      }
    });
    ref.listen<Profile?>(currentProfileProvider, (_, next) {
      // Re-run redirects only when the authz-relevant identity actually changes.
      final key = '${next?.userId}:${next?.role}:${next?.permissions}';
      if (key != _lastProfileKey) {
        _lastProfileKey = key;
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
