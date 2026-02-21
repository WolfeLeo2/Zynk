import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/pos/presentation/components/pos_product_card.dart';
import 'package:zynk/features/pos/presentation/components/pos_ticket.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with SingleTickerProviderStateMixin {
  // Temporary local state for UI demo
  final List<PosCartItem> _cart = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere(
        (item) => item.product.id == product.id,
      );
      if (existingIndex != -1) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(PosCartItem(product: product));
      }
    });

    // On mobile, show feedback since we can't see the ticket updating immediately if on products tab
    final isMobile = MediaQuery.of(context).size.width <= 900;
    if (isMobile) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to ticket'),
          duration: const Duration(seconds: 1),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => _tabController.animateTo(1),
          ),
        ),
      );
    }
  }

  void _removeFromCart(PosCartItem item) {
    setState(() {
      _cart.removeWhere((i) => i.product.id == item.product.id);
    });
  }

  double get _total => _cart.fold(0, (sum, item) => sum + item.total);

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);

    final isMobile = MediaQuery.of(context).size.width <= 900;

    return productsAsync.when(
      data: (products) {
        if (!isMobile) {
          return Scaffold(
            body: Row(
              children: [
                // Product Grid Area
                Expanded(
                  flex: 2,
                  child: _ProductGrid(
                    products: products,
                    onAddToCart: _addToCart,
                  ),
                ),

                // Vertical Divider
                const VerticalDivider(width: 1),

                // Ticket Area
                Expanded(
                  flex: 1,
                  child: PosTicket(
                    items: _cart,
                    total: _total,
                    onCharge: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Processing Charge...')),
                      );
                    },
                    onRemoveItem: _removeFromCart,
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Layout (Tabbed)
        return Scaffold(
          appBar: AppBar(
            title: const Text('POS'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(
                  text: 'Products',
                  icon: Icon(PhosphorIconsDuotone.gridFour),
                ),
                Tab(
                  text: 'Ticket',
                  icon: const Icon(PhosphorIconsDuotone.receipt),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _ProductGrid(products: products, onAddToCart: _addToCart),
              PosTicket(
                items: _cart,
                total: _total,
                onCharge: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Processing Charge...')),
                  );
                },
                onRemoveItem: _removeFromCart,
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onAddToCart;

  const _ProductGrid({required this.products, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsDuotone.package,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Add products from the dashboard to get started.'),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (MediaQuery.of(context).size.width > 900)
          const SliverAppBar(
            title: Text('Products'),
            floating: true,
            centerTitle: false,
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
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
