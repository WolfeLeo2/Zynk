import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';

class ProductDetailsScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            onPressed: () => context.push('/products/add', extra: product),
            icon: const PhosphorIcon(PhosphorIconsDuotone.pencilSimple),
            tooltip: 'Edit Item',
          ),
          IconButton(
            onPressed: () => context.push(
              '/products/add',
              extra: {'product': product, 'clone': true},
            ),
            icon: const PhosphorIcon(PhosphorIconsDuotone.copy),
            tooltip: 'Clone Item',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: const [],
      ),
    );
  }
}
