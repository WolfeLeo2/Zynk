import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/shared/widgets/shimmer_skeletons.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/features/customers/providers/customer_providers.dart';
import 'package:zynk/features/customers/presentation/widgets/customer_form.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(allCustomersProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profile = ref.watch(currentUserProfileProvider).value;
    final canManage = profile?.hasPermission(Permission.manageCustomers) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          if (canManage)
            IconButton(
              onPressed: () => _showAddEditCustomerSheet(context, ref, null),
              icon: const Icon(PhosphorIconsBold.plus),
            ),
        ],
      ),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsDuotone.users,
                    size: 64,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No customers yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first customer to get started',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (canManage)
                    FilledButton.icon(
                      onPressed: () => _showAddEditCustomerSheet(context, ref, null),
                      icon: const Icon(PhosphorIconsRegular.plus),
                      label: const Text('Add Customer'),
                    ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final customer = customers[i];
              return _CustomerCard(
                customer: customer,
                canManage: canManage,
                onEdit: () => _showAddEditCustomerSheet(context, ref, customer),
                onDelete: () => _confirmDelete(context, ref, customer),
              );
            },
          );
        },
        loading: () => const _CustomerListSkeleton(),
        error: (err, stack) => Center(child: Text('Error loading customers: $err')),
      ),
      floatingActionButton: canManage && customersAsync.hasValue && customersAsync.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditCustomerSheet(context, ref, null),
              icon: const Icon(PhosphorIconsBold.plus),
              label: const Text('Add Customer'),
            )
          : null,
    );
  }

  void _showAddEditCustomerSheet(
    BuildContext context,
    WidgetRef ref,
    Customer? existing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CustomerForm(existing: existing),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete "${customer.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(repositoryProvider).deleteCustomer(customer.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${customer.name} deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: cs.primaryContainer,
          child: Text(
            customer.name[0].toUpperCase(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone != null && customer.phone!.isNotEmpty)
              Text(
                customer.phone!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            if (customer.email != null && customer.email!.isNotEmpty)
              Text(
                customer.email!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(PhosphorIconsRegular.pencilSimple),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        PhosphorIconsRegular.trash,
                        color: Colors.red,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}



class _CustomerListSkeleton extends StatelessWidget {
  const _CustomerListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ListSkeleton();
  }
}
