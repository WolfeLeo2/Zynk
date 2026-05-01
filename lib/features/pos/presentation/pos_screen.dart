import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/customers/providers/customer_providers.dart';
import 'package:zynk/shared/widgets/shimmer_skeletons.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/pos/providers/cart_provider.dart';
import 'package:zynk/features/pos/providers/pos_providers.dart';
import 'package:zynk/features/pos/presentation/components/pos_product_card.dart';
import 'package:zynk/features/pos/presentation/components/pos_ticket.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:intl_phone_field/intl_phone_field.dart';


class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with SingleTickerProviderStateMixin {
  // No local cart state — use cartProvider instead (persists across navigation)
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedGroupId;
  Customer? _selectedCustomer;
  String? _salespersonId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(Product product) => _doAddToCart(product);

  void _doAddToCart(Product product) {
    HapticFeedback.lightImpact();

    // Validate against current stock if the item is not a service
    if (!product.isService) {
      final posBranchId = ref.read(posBranchProvider);
      final stockState = ref.read(stockByBranchProvider((
        productId: product.id,
        branchId: posBranchId,
      ))).value;
      final availableStock = stockState?.quantity ?? 0;

      final currentCartQty = ref
          .read(cartProvider)
          .items
          .firstWhere(
            (item) => item.product.id == product.id,
            orElse: () => PosCartItem(product: product, quantity: 0),
          )
          .quantity;

      if (currentCartQty + 1 > availableStock) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot add ${product.name}. Only $availableStock in stock.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    ref.read(cartProvider.notifier).addItem(product);

    final isMobile = MediaQuery.of(context).size.width <= 900;
    if (isMobile) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to ticket'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeFromCart(PosCartItem item) {
    ref.read(cartProvider.notifier).removeItem(item.product.id);
  }

  void _clearCart() {
    ref.read(cartProvider.notifier).clear();
  }

  // All sales now go through the invoice flow.
  // The PosTicket's 'Create Invoice' button handles navigation.

  void _showCustomerSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CustomerSelectorSheet(
        selectedCustomer: _selectedCustomer,
        onSelected: (customer) {
          setState(() => _selectedCustomer = customer);
          Navigator.pop(sheetContext);
        },
        onClear: () {
          setState(() => _selectedCustomer = null);
          Navigator.pop(sheetContext);
        },
        onCreateNew: (name, phone, email) async {
          final tenantId = ref.read(tenantIdProvider);
          final branchId = ref.read(posBranchProvider);
          if (tenantId == null || branchId == null) return; // Removed 'all' check as POS now defaults to a real branch
          final repo = ref.read(repositoryProvider);
          final customer = Customer(
            id: const Uuid().v4(),
            tenantId: tenantId,
            branchId: branchId,
            name: name,
            phone: phone.isNotEmpty ? phone : null,
            email: email.isNotEmpty ? email : null,
          );
          await repo.createCustomer(customer);
          setState(() => _selectedCustomer = customer);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  double get _total => ref.watch(cartProvider).total;

  @override
  Widget build(BuildContext context) {
    final posBranchId = ref.watch(posBranchProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final itemGroupsAsync = ref.watch(allItemGroupsProvider);
    final cart = ref.watch(cartProvider);
    final cartItems = cart.items;

    final isMobile = MediaQuery.of(context).size.width <= 900;

    final categories = categoriesAsync.value ?? [];
    final itemGroups = itemGroupsAsync.value ?? [];

    if (!isMobile) {
      return Scaffold(
        drawer: const AppDrawer(),
        body: Row(
          children: [
            // Product Grid Area
            Expanded(
              flex: 2,
              child: _ProductGrid(
                isMobile: false,
                posBranchId: posBranchId,
                categories: categories,
                itemGroups: itemGroups,
                selectedCategoryId: _selectedCategoryId,
                selectedGroupId: _selectedGroupId,
                onCategoryChanged: (id) =>
                    setState(() => _selectedCategoryId = id),
                onGroupChanged: (id) =>
                    setState(() => _selectedGroupId = id),
                searchController: _searchController,
                onSearchChanged: (q) => setState(() {}),
                onAddToCart: _addToCart,
              ),
            ),
            const VerticalDivider(width: 1),
            // Ticket Area
            Expanded(
              flex: 1,
              child: PosTicket(
                items: cartItems,
                total: _total,
                onRemoveItem: _removeFromCart,
                onClearTicket: _clearCart,
                selectedCustomer: _selectedCustomer,
                salespersonId: _salespersonId,
                onSelectCustomer: _showCustomerSelector,
                onSalespersonIdChanged: (id) =>
                    setState(() => _salespersonId = id),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Layout (Tabbed)
    return Scaffold(
      drawer: const AppDrawer(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              leading: Builder(
                builder: (context) {
                  if (MediaQuery.of(context).size.width < 840) {
                    return IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.list),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              automaticallyImplyLeading: false,
              title: const Text('POS'),
              pinned: true,
              floating: true,
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(
                    text: 'Items',
                    icon: Icon(PhosphorIconsDuotone.gridFour),
                  ),
                  Tab(
                    text: 'Ticket (${cartItems.length})',
                    icon: Badge(
                      isLabelVisible: cartItems.isNotEmpty,
                      label: Text('${cartItems.length}'),
                      child: const Icon(PhosphorIconsDuotone.receipt),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _ProductGrid(
              isMobile: true,
              posBranchId: posBranchId,
              categories: categories,
              itemGroups: itemGroups,
              selectedCategoryId: _selectedCategoryId,
              selectedGroupId: _selectedGroupId,
              onCategoryChanged: (id) =>
                  setState(() => _selectedCategoryId = id),
              onGroupChanged: (id) => setState(() => _selectedGroupId = id),
              searchController: _searchController,
              onSearchChanged: (q) => setState(() {}),
              onAddToCart: _addToCart,
            ),
            PosTicket(
              items: cartItems,
              total: _total,
              onRemoveItem: _removeFromCart,
              onClearTicket: _clearCart,
              selectedCustomer: _selectedCustomer,
              salespersonId: _salespersonId,
              onSelectCustomer: _showCustomerSelector,
              onSalespersonIdChanged: (id) =>
                  setState(() => _salespersonId = id),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT GRID
class _ProductGrid extends ConsumerWidget {
  final bool isMobile;
  final String? posBranchId;
  final List<Category> categories;
  final List<ItemGroup> itemGroups;
  final String? selectedCategoryId;
  final String? selectedGroupId;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onGroupChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Function(Product) onAddToCart;

  const _ProductGrid({
    this.isMobile = false,
    required this.posBranchId,
    required this.categories,
    required this.itemGroups,
    required this.selectedCategoryId,
    required this.selectedGroupId,
    required this.onCategoryChanged,
    required this.onGroupChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final branches = ref.watch(branchesProvider).value ?? const [];
    final branchOptions = branches.where((b) => b.id != 'all').toList();
    final productsAsync = ref.watch(productsByBranchProvider(posBranchId));

    return CustomScrollView(
      slivers: [
        if (!isMobile)
          const SliverAppBar(title: Text('POS'), floating: true, snap: true),
        if (branchOptions.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: DropdownButtonFormField<String>(
                key: ValueKey(posBranchId),
                initialValue: branchOptions.any((b) => b.id == posBranchId)
                    ? posBranchId
                    : (branchOptions.isNotEmpty ? branchOptions.first.id : null),
                decoration: const InputDecoration(
                  labelText: 'Selling Branch',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(PhosphorIconsRegular.storefront),
                ),
                items: branchOptions
                    .map(
                      (b) => DropdownMenuItem<String>(
                        value: b.id,
                        child: Text(b.name),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next == null) return;
                  ref.read(posBranchProvider.notifier).setBranch(next);
                },
              ),
            ),
          ),
        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        // Category and Group Filter Chips
        if (categories.isNotEmpty || itemGroups.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      showCheckmark: false,
                      selected:
                          selectedCategoryId == null && selectedGroupId == null,
                      onSelected: (_) {
                        onCategoryChanged(null);
                        onGroupChanged(null);
                      },
                    ),
                  ),

                  // Item Groups Action/Dropdown styled chip
                  if (itemGroups.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(
                          PhosphorIconsDuotone.folders,
                          size: 18,
                          color: selectedGroupId != null
                              ? colorScheme.onPrimaryContainer
                              : null,
                        ),
                        label: Text(
                          selectedGroupId != null
                              ? itemGroups
                                    .firstWhere(
                                      (g) => g.id == selectedGroupId,
                                      orElse: () => itemGroups.first,
                                    )
                                    .name
                              : 'Groups',
                          style: TextStyle(
                            color: selectedGroupId != null
                                ? colorScheme.onPrimaryContainer
                                : null,
                          ),
                        ),
                        showCheckmark: false,
                        selected: selectedGroupId != null,
                        selectedColor: colorScheme.primaryContainer,
                        onSelected: (_) {
                          _showGroupSelector(context, colorScheme);
                        },
                        onDeleted: selectedGroupId != null
                            ? () => onGroupChanged(null)
                            : null,
                        deleteIconColor: colorScheme.onPrimaryContainer,
                      ),
                    ),

                  if (itemGroups.isNotEmpty && categories.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: VerticalDivider(endIndent: 12, indent: 12),
                    ),

                  ...categories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat.name),
                        showCheckmark: false,
                        selected: selectedCategoryId == cat.id,
                        onSelected: (_) => onCategoryChanged(
                          selectedCategoryId == cat.id ? null : cat.id,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        productsAsync.when(
          data: (products) {
            var filtered = products.toList();
            if (selectedCategoryId != null) {
              filtered = filtered
                  .where((p) => p.categoryId == selectedCategoryId)
                  .toList();
            }
            if (selectedGroupId != null) {
              filtered = filtered
                  .where((p) => p.itemGroupId == selectedGroupId)
                  .toList();
            }
            if (searchController.text.isNotEmpty) {
              filtered = filtered
                  .where(
                    (p) => p.name
                        .toLowerCase()
                        .contains(searchController.text.toLowerCase()),
                  )
                  .toList();
            }

            if (filtered.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        searchController.text.isNotEmpty
                            ? PhosphorIconsDuotone.magnifyingGlass
                            : PhosphorIconsDuotone.package,
                        size: 64,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchController.text.isNotEmpty
                            ? 'No items match "${searchController.text}"'
                            : 'No items found',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      ),
                      if (searchController.text.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Add items to get started.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = filtered[index];
                    return PosProductCard(
                      product: product,
                      onTap: () => onAddToCart(product),
                      onAddToCart: () => onAddToCart(product),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: GridSkeleton(),
          ),
          error: (err, stack) => SliverFillRemaining(
            child: Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  void _showGroupSelector(BuildContext context, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Item Group',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: itemGroups.length,
                  itemBuilder: (context, index) {
                    final group = itemGroups[index];
                    final isSelected = selectedGroupId == group.id;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          PhosphorIconsDuotone.folders,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(group.name),
                      trailing: isSelected
                          ? Icon(
                              PhosphorIconsBold.check,
                              color: colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        onGroupChanged(group.id);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER SELECTOR BOTTOM SHEET — ConsumerStatefulWidget to watch stream
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerSelectorSheet extends ConsumerStatefulWidget {
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onSelected;
  final VoidCallback onClear;
  final Future<void> Function(String name, String phone, String email)
  onCreateNew;

  const _CustomerSelectorSheet({
    this.selectedCustomer,
    required this.onSelected,
    required this.onClear,
    required this.onCreateNew,
  });

  @override
  ConsumerState<_CustomerSelectorSheet> createState() =>
      _CustomerSelectorSheetState();
}

class _CustomerSelectorSheetState
    extends ConsumerState<_CustomerSelectorSheet> {
  String _query = '';
  bool _creating = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isPhoneValid = false;
  String _completePhone = '';


  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    if (_query.isEmpty) return customers;
    final q = _query.toLowerCase();
    return customers
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              (c.phone?.contains(q) ?? false) ||
              (c.email?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final customersAsync = ref.watch(allCustomersProvider);
    final profile = ref.watch(currentUserProfileProvider).value;
    final canManage = profile?.hasPermission(Permission.manageCustomers) ?? false;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Customer',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (widget.selectedCustomer != null)
                      TextButton(
                        onPressed: widget.onClear,
                        child: const Text('Clear'),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or email...',
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Create New Customer Toggle
          if (!_creating && canManage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _creating = true),
                icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 16),
                label: const Text('Add New Customer'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),

          // Create New Customer Form
          if (_creating)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Customer',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  IntlPhoneField(
                    controller: _phoneCtrl,
                    initialCountryCode: 'KE',
                    decoration: const InputDecoration(
                      labelText: 'Phone *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (phone) {
                      _completePhone = phone.completeNumber;
                      setState(() {
                        _isPhoneValid = phone.isValidNumber();
                      });
                    },
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _creating = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: (_nameCtrl.text.trim().isEmpty || !_isPhoneValid)
                            ? null
                            : () => widget.onCreateNew(
                                  _nameCtrl.text.trim(),
                                  _completePhone,
                                  _emailCtrl.text.trim(),
                                ),
                        child: const Text('Save & Select'),
                      ),

                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          Expanded(
            child: customersAsync.when(
              loading: () => const ListSkeleton(itemCount: 3, padding: EdgeInsets.symmetric(horizontal: 12)),
              error: (err, _) => Center(
                child: Text(
                  'Failed to load customers: $err',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
              data: (customers) {
                final filtered = _filterCustomers(customers);
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No customers yet — add one above'
                          : 'No results for "$_query"',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    final isSelected =
                        widget.selectedCustomer?.id == customer.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? colorScheme.primary
                            : colorScheme.primaryContainer,
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        customer.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        [
                          customer.phone,
                          customer.email,
                        ].where((e) => e != null && e.isNotEmpty).join(' • '),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: isSelected
                          ? PhosphorIcon(
                              PhosphorIconsBold.checkCircle,
                              color: colorScheme.primary,
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => widget.onSelected(customer),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
