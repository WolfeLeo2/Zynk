import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// GRANULAR PERMISSIONS
// ─────────────────────────────────────────────────────────────────────────────

/// Individual permission flags that can be toggled per staff member.
/// Owner/Admin always has ALL permissions regardless of this list.
enum Permission {
  // ── Sales ──
  posAccess(
    'pos_access',
    'POS Access',
    'Can use POS to process walk-in sales',
    PermissionCategory.sales,
  ),
  createInvoices(
    'create_invoices',
    'Create Invoices',
    'Can create B2B invoices and quotes',
    PermissionCategory.sales,
  ),
  approveInvoices(
    'approve_invoices',
    'Approve Invoices',
    'Can approve or reject pending invoices.',
    PermissionCategory.sales,
  ),
  editSales(
    'edit_sales',
    'Edit Invoices',
    'Can edit pending invoices',
    PermissionCategory.sales,
  ),
  deleteSales(
    'delete_sales',
    'Delete Invoices',
    'Can delete invoices and payments',
    PermissionCategory.sales,
  ),
  voidSales(
    'void_sales',
    'Void Sales',
    'Can void completed sales and reverse stock.',
    PermissionCategory.sales,
  ),
  recordPayments(
    'record_payments',
    'Record Payments',
    'Can record payments on invoices',
    PermissionCategory.sales,
  ),
  issueCreditNotes(
    'issue_credit_notes',
    'Issue Credit Notes',
    'Can issue refunds and credit notes',
    PermissionCategory.sales,
  ),
  applyDiscounts(
    'apply_discounts',
    'Apply Discounts',
    'Can apply discounts at POS or on invoices',
    PermissionCategory.sales,
  ),
  manageExpenses(
    'manage_expenses',
    'Manage Expenses',
    'Can log and view business expenses',
    PermissionCategory.sales,
  ),

  // ── Inventory ──
  manageProducts(
    'manage_products',
    'Manage Products',
    'Can add, edit, and delete products',
    PermissionCategory.inventory,
  ),
  manageStock(
    'manage_stock',
    'Manage Stock',
    'Can adjust stock levels manually',
    PermissionCategory.inventory,
  ),
  approveStock(
    'approve_stock',
    'Approve Stock',
    'Can approve or reject pending stock adjustments',
    PermissionCategory.inventory,
  ),
  viewCostPrices(
    'view_cost_prices',
    'View Cost Prices',
    'Can see cost price and profit margins',
    PermissionCategory.inventory,
  ),

  // ── Reports ──
  viewReports(
    'view_reports',
    'View Reports',
    'Can access sales reports and analytics',
    PermissionCategory.reports,
  ),
  viewDashboard(
    'view_dashboard',
    'View Dashboard',
    'Can see dashboard metrics and charts',
    PermissionCategory.reports,
  ),
  exportData(
    'export_data',
    'Export Data',
    'Can export reports to CSV or PDF',
    PermissionCategory.reports,
  ),

  // ── People ──
  manageCustomers(
    'manage_customers',
    'Manage Customers',
    'Can add and edit customer profiles',
    PermissionCategory.people,
  ),
  manageStaff(
    'manage_staff',
    'Manage Staff',
    'Can invite, edit, and deactivate staff',
    PermissionCategory.people,
  ),

  // ── Settings ──
  manageBranches(
    'manage_branches',
    'Manage Branches',
    'Can add and edit branch locations',
    PermissionCategory.settings,
  ),
  manageBusiness(
    'manage_business',
    'Manage Business',
    'Can edit business settings and billing',
    PermissionCategory.settings,
  );

  final String value; // stored in DB
  final String displayName;
  final String description;
  final PermissionCategory category;

  const Permission(
    this.value,
    this.displayName,
    this.description,
    this.category,
  );

  static Permission? fromString(String value) {
    for (final p in Permission.values) {
      if (p.value == value) return p;
    }
    return null;
  }

  /// Parse a JSON-encoded list of permission strings.
  static Set<Permission> fromJsonList(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final List<dynamic> list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => Permission.fromString(e as String))
          .whereType<Permission>()
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Encode a set of permissions to a JSON string for storage.
  static String toJsonList(Set<Permission> permissions) {
    return jsonEncode(permissions.map((p) => p.value).toList());
  }
}

/// Categories for grouping permissions in the UI.
enum PermissionCategory {
  sales('Sales', 'Point of sale, invoicing, and payment operations'),
  inventory('Inventory', 'Product and stock management'),
  reports('Reports', 'Analytics, dashboards, and data exports'),
  people('People', 'Customer and staff management'),
  settings('Settings', 'Business and branch configuration');

  final String displayName;
  final String description;

  const PermissionCategory(this.displayName, this.description);

  /// Get all permissions that belong to this category.
  List<Permission> get permissions =>
      Permission.values.where((p) => p.category == this).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// USER ROLE (title/label + default permissions)
// ─────────────────────────────────────────────────────────────────────────────

enum UserRole {
  owner('Owner'),
  manager('Manager'),
  cashier('Cashier');

  final String label;
  const UserRole(this.label);

  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (e) => e.label.toLowerCase() == role.toLowerCase(),
      orElse: () => UserRole.cashier,
    );
  }

  String toShortString() => label;

  // --- Core checks ---
  bool get isOwner => this == owner;
  bool get isManager => this == manager;
  bool get isCashier => this == cashier;

  /// Owner always has all permissions.
  bool get hasAllPermissions => isOwner;

  /// Default permissions for this role (used when creating new staff).
  Set<Permission> get defaultPermissions {
    switch (this) {
      case UserRole.owner:
        return Permission.values.toSet(); // all
      case UserRole.manager:
        return {
          Permission.posAccess,
          Permission.createInvoices,
          Permission.approveInvoices,
          Permission.editSales,
          Permission.deleteSales,
          Permission.voidSales,
          Permission.recordPayments,
          Permission.issueCreditNotes,
          Permission.applyDiscounts,
          Permission.manageProducts,
          Permission.manageStock,
          Permission.approveStock,
          Permission.viewCostPrices,
          Permission.viewReports,
          Permission.viewDashboard,
          Permission.exportData,
          Permission.manageCustomers,
          Permission.manageExpenses,
        };
      case UserRole.cashier:
        return {
          Permission.posAccess,
          Permission.recordPayments,
          Permission.manageCustomers,
          Permission.manageStock,
        };
    }
  }
}
