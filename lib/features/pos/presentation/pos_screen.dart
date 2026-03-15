import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/pos/providers/customer_providers.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/pos/providers/cart_provider.dart';
import 'package:zynk/features/pos/presentation/components/pos_product_card.dart';
import 'package:zynk/features/pos/presentation/components/pos_ticket.dart';
import 'package:uuid/uuid.dart';

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
  String _searchQuery = '';
  String? _selectedCategoryId;
  Customer? _selectedCustomer;
  String _salespersonName = '';

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

  void _addToCart(Product product) {
    HapticFeedback.lightImpact();

    // Validate against current stock if the item is not a service
    if (!product.isService) {
      final stockState = ref.read(stockProvider(product.id)).value;
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
          final branchId = ref.read(currentBranchIdProvider);
          if (tenantId == null || branchId == null || branchId == 'all') return;
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
    final productsAsync = ref.watch(allProductsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final cart = ref.watch(cartProvider);
    final cartItems = cart.items;

    final isMobile = MediaQuery.of(context).size.width <= 900;

    final categories = categoriesAsync.value ?? [];

    return productsAsync.when(
      data: (products) {
        var filtered = products.toList();
        if (_selectedCategoryId != null) {
          filtered = filtered
              .where((p) => p.categoryId == _selectedCategoryId)
              .toList();
        }
        if (_searchQuery.isNotEmpty) {
          filtered = filtered
              .where(
                (p) =>
                    p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();
        }

        if (!isMobile) {
          return Scaffold(
            body: Row(
              children: [
                // Product Grid Area
                Expanded(
                  flex: 2,
                  child: _ProductGrid(
                    isMobile: false,
                    products: filtered,
                    categories: categories,
                    selectedCategoryId: _selectedCategoryId,
                    onCategoryChanged: (id) =>
                        setState(() => _selectedCategoryId = id),
                    searchController: _searchController,
                    onSearchChanged: (q) => setState(() => _searchQuery = q),
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
                    salespersonName: _salespersonName.isEmpty
                        ? null
                        : _salespersonName,
                    onSelectCustomer: _showCustomerSelector,
                    onSalespersonNameChanged: (name) =>
                        setState(() => _salespersonName = name),
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Layout (Tabbed)
        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('POS'),
                  pinned: true,
                  floating: true,
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: [
                      const Tab(
                        text: 'Products',
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
                  products: filtered,
                  categories: categories,
                  selectedCategoryId: _selectedCategoryId,
                  onCategoryChanged: (id) =>
                      setState(() => _selectedCategoryId = id),
                  searchController: _searchController,
                  onSearchChanged: (q) => setState(() => _searchQuery = q),
                  onAddToCart: _addToCart,
                ),
                PosTicket(
                  items: cartItems,
                  total: _total,
                  onRemoveItem: _removeFromCart,
                  onClearTicket: _clearCart,
                  selectedCustomer: _selectedCustomer,
                  salespersonName: _salespersonName.isEmpty
                      ? null
                      : _salespersonName,
                  onSelectCustomer: _showCustomerSelector,
                  onSalespersonNameChanged: (name) =>
                      setState(() => _salespersonName = name),
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT GRID
class _ProductGrid extends StatelessWidget {
  final bool isMobile;
  final List<Product> products;
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Function(Product) onAddToCart;

  const _ProductGrid({
    this.isMobile = false,
    required this.products,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        if (!isMobile)
          const SliverAppBar(title: Text('POS'), floating: true, snap: true),
        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products...',
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
        // Category Filter Chips
        if (categories.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: selectedCategoryId == null,
                      onSelected: (_) => onCategoryChanged(null),
                    ),
                  ),
                  ...categories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat.name),
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
        if (products.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    searchController.text.isNotEmpty
                        ? PhosphorIconsDuotone.magnifyingGlass
                        : PhosphorIconsDuotone.package,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    searchController.text.isNotEmpty
                        ? 'No products match "${searchController.text}"'
                        : 'No products found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (searchController.text.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Add products from Settings to get started.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final product = products[index];
                return PosProductCard(
                  product: product,
                  onTap: () => onAddToCart(product),
                  onAddToCart: () => onAddToCart(product),
                );
              }, childCount: products.length),
            ),
          ),
      ],
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
          if (!_creating)
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
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
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
                        onPressed: _nameCtrl.text.trim().isEmpty
                            ? null
                            : () => widget.onCreateNew(
                                _nameCtrl.text.trim(),
                                _phoneCtrl.text.trim(),
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

          // Customer List — from stream
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
