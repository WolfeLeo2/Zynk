import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/utils/responsive_modal.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:zynk/features/pos/presentation/components/pos_ticket.dart';
import 'package:zynk/features/pos/providers/cart_provider.dart';
import 'package:zynk/features/pos/providers/pos_providers.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/shared/widgets/product_card.dart';
import 'package:zynk/shared/widgets/shimmer_skeletons.dart';

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
      final stockState = ref
          .read(
            stockByBranchProvider((
              productId: product.id,
              branchId: posBranchId,
            )),
          )
          .value;
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

    final itemGroups = ref.read(allItemGroupsProvider).value ?? [];
    final itemGroup = product.itemGroupId != null
        ? itemGroups.where((g) => g.id == product.itemGroupId).firstOrNull
        : null;

    ref.read(cartProvider.notifier).addItem(product, itemGroup: itemGroup);

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

  Future<void> _createNewCustomer(
    String name,
    String phone,
    String email,
  ) async {
    final tenantId = ref.read(tenantIdProvider);
    final branchId = ref.read(posBranchProvider);
    if (tenantId == null || branchId == null) return;
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
    if (!mounted) return;
    setState(() => _selectedCustomer = customer);
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
    final branches = ref.watch(branchesProvider).value ?? const [];
    final branchOptions = branches.where((b) => b.id != 'all').toList();

    PreferredSizeWidget buildAppBar() {
      return AppBar(
        title: const Text('POS'),
        leading: isMobile
            ? Builder(
                builder: (context) => IconButton(
                  icon: const PhosphorIcon(PhosphorIconsRegular.list),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        actions: [
          if (branchOptions.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: ValueKey(posBranchId),
                  value: branchOptions.any((b) => b.id == posBranchId)
                      ? posBranchId
                      : (branchOptions.isNotEmpty
                            ? branchOptions.first.id
                            : null),
                  icon: const PhosphorIcon(PhosphorIconsRegular.storefront),
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
        ],
      );
    }

    if (!isMobile) {
      return Scaffold(
        appBar: buildAppBar(),
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
                onGroupChanged: (id) => setState(() => _selectedGroupId = id),
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
                onSelectCustomer: (c) => setState(() => _selectedCustomer = c),
                onClearCustomer: () => setState(() => _selectedCustomer = null),
                onCreateCustomer: _createNewCustomer,
                onSalespersonIdChanged: (id) =>
                    setState(() => _salespersonId = id),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Layout
    return Scaffold(
      appBar: buildAppBar(),
      drawer: const AppDrawer(),
      body: _ProductGrid(
        isMobile: true,
        posBranchId: posBranchId,
        categories: categories,
        itemGroups: itemGroups,
        selectedCategoryId: _selectedCategoryId,
        selectedGroupId: _selectedGroupId,
        onCategoryChanged: (id) => setState(() => _selectedCategoryId = id),
        onGroupChanged: (id) => setState(() => _selectedGroupId = id),
        searchController: _searchController,
        onSearchChanged: (q) => setState(() {}),
        onAddToCart: _addToCart,
      ),
      floatingActionButton: cartItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                showResponsiveModal(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  builder: (sheetContext) => StatefulBuilder(
                    builder: (context, setSheetState) {
                      return Consumer(
                        builder: (context, ref, child) {
                          final currentCart = ref.watch(cartProvider);
                          return FractionallySizedBox(
                            heightFactor: 0.9,
                            child: PosTicket(
                              items: currentCart.items,
                              total: currentCart.total,
                              onRemoveItem: _removeFromCart,
                              onClearTicket: () {
                                _clearCart();
                                Navigator.pop(sheetContext);
                              },
                              selectedCustomer: _selectedCustomer,
                              salespersonId: _salespersonId,
                              onSelectCustomer: (c) {
                                setState(() => _selectedCustomer = c);
                                setSheetState(() {});
                              },
                              onClearCustomer: () {
                                setState(() => _selectedCustomer = null);
                                setSheetState(() {});
                              },
                              onCreateCustomer: (n, p, e) async {
                                await _createNewCustomer(n, p, e);
                                setSheetState(() {});
                              },
                              onSalespersonIdChanged: (id) {
                                setState(() => _salespersonId = id);
                                setSheetState(() {});
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
              icon: Badge(
                label: Text('${cartItems.length}'),
                backgroundColor: Theme.of(context).colorScheme.error,
                isLabelVisible: cartItems.isNotEmpty,
                child: const PhosphorIcon(PhosphorIconsRegular.shoppingCart),
              ),
              label: const Text('View Cart'),
            )
          : null,
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
    final productsAsync = ref.watch(productsByBranchProvider(posBranchId));

    return CustomScrollView(
      slivers: [
        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const PhosphorIcon(
                  PhosphorIconsRegular.magnifyingGlass,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
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
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: selectedGroupId != null
                              ? colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedGroupId != null
                                ? Colors.transparent
                                : colorScheme.outline,
                            width: 0.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: selectedGroupId,
                            hint: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsDuotone.folders,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Groups',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            icon: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: PhosphorIcon(
                                PhosphorIconsRegular.caretDown,
                                size: 14,
                                color: selectedGroupId != null
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                            isDense: true,
                            dropdownColor: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            selectedItemBuilder: (BuildContext context) {
                              return [
                                const Text('All Groups'),
                                ...itemGroups.map((g) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PhosphorIcon(
                                        PhosphorIconsDuotone.folders,
                                        size: 16,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        g.name,
                                        style: TextStyle(
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ];
                            },
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Groups'),
                              ),
                              ...itemGroups.map((g) {
                                return DropdownMenuItem<String?>(
                                  value: g.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PhosphorIcon(
                                        PhosphorIconsDuotone.folders,
                                        size: 16,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(g.name),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) => onGroupChanged(val),
                          ),
                        ),
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
                    (p) => p.name.toLowerCase().contains(
                      searchController.text.toLowerCase(),
                    ),
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
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchController.text.isNotEmpty
                            ? 'No items match "${searchController.text}"'
                            : 'No items found',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      if (searchController.text.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Add items to get started.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
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
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = filtered[index];
                  return SharedProductCard(
                    product: product,
                    onTap: () => onAddToCart(product),
                    showCartBadges: true,
                    overrideBranchId: posBranchId,
                  );
                }, childCount: filtered.length),
              ),
            );
          },
          loading: () => const SliverFillRemaining(child: GridSkeleton()),
          error: (err, stack) =>
              SliverFillRemaining(child: Center(child: Text('Error: $err'))),
        ),
      ],
    );
  }
}
