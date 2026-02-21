enum UserRole {
  owner('Owner'),
  manager('Manager'),
  cashier('Cashier');

  final String label;
  const UserRole(this.label);

  // Factory to parse string to UserRole
  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (e) => e.label.toLowerCase() == role.toLowerCase(),
      orElse: () => UserRole.cashier, // Default safe fallback
    );
  }

  String toShortString() => label;

  // --- Permissions ---

  bool get isOwner => this == owner;
  bool get isManager => this == manager;
  bool get isCashier => this == cashier;

  /// Full access to settings, reports, and staff management
  bool get canManageBusiness => isOwner;

  /// Access to inventory management and local reports
  bool get canManageBranch => isOwner || isManager;

  /// Access to POS and customer data
  bool get canProcessSales => true; // Everyone can sell

  /// Can view costs and profit margins
  bool get canViewFinancials => isOwner || isManager;

  /// Can edit product details (price, cost)
  bool get canEditProducts => isOwner || isManager;

  /// Can delete critical data (customers, products, etc.)
  bool get canDeleteData => isOwner;
}
