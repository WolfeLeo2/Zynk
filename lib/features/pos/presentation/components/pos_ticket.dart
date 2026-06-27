import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/utils/currency.dart';
import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:zynk/features/pos/presentation/components/customer_lookup_field.dart';
import 'package:zynk/features/pos/providers/cart_provider.dart';
import 'package:zynk/features/pos/providers/pos_providers.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/shared/widgets/qty_stepper.dart';

class PosTicket extends ConsumerWidget {
  final List<PosCartItem> items;
  final double total;
  final Function(PosCartItem) onRemoveItem;
  final VoidCallback onClearTicket;

  // Customer & Staff info
  final Customer? selectedCustomer;
  final String? salespersonId;
  final ValueChanged<Customer>? onSelectCustomer;
  final VoidCallback? onClearCustomer;
  final Future<void> Function(String name, String phone, String email)?
  onCreateCustomer;
  final ValueChanged<String?>? onSalespersonIdChanged;

  const PosTicket({
    super.key,
    required this.items,
    required this.total,
    required this.onRemoveItem,
    required this.onClearTicket,
    this.selectedCustomer,
    this.salespersonId,
    this.onSelectCustomer,
    this.onClearCustomer,
    this.onCreateCustomer,
    this.onSalespersonIdChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final branch = ref.watch(selectedPosBranchProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── HEADER ───
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            children: [
              Text(
                'Cart',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (itemCount > 0)
                Badge(
                  label: Text(
                    '$itemCount items',
                    style: tt.labelSmall?.copyWith(color: cs.onPrimary),
                  ),
                  backgroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  largeSize: 22,
                ),
              const Spacer(),
              if (items.isNotEmpty)
                TextButton.icon(
                  onPressed: onClearTicket,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.trash,
                    size: 18,
                  ),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ),

        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),

        // ─── ITEMS LIST ───
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.3,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIconsDuotone.shoppingCartSimple,
                              size: 32,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items yet',
                          style: tt.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap items to add them to this ticket',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _TicketItemRow(
                      item: item,
                      cs: cs,
                      tt: tt,
                      onRemove: () => onRemoveItem(item),
                    );
                  },
                ),
        ),

        // ─── FOOTER (STAFF, CUSTOMER, TOTALS, INVOICE) ───
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              // Salesperson is now the logged-in staffer (set on submit); no picker.

              // Customer Selection
              if (onSelectCustomer != null &&
                  onClearCustomer != null &&
                  onCreateCustomer != null)
                CustomerLookupField(
                  selectedCustomer: selectedCustomer,
                  onSelected: onSelectCustomer!,
                  onClear: onClearCustomer!,
                  onCreateNew: onCreateCustomer!,
                ),

              const SizedBox(height: 20),

              // Subtotal row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    CurrencyHelper.format(total),
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Grand Total row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grand Total',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    CurrencyHelper.format(total),
                    style: GoogleFonts.googleSansFlex(
                      textStyle: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Consumer(
                builder: (context, ref, child) {
                  final canCreateInvoice = ref.watch(
                    hasPermissionProvider(Permission.createInvoices),
                  );

                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          items.isEmpty ||
                              selectedCustomer == null ||
                              !canCreateInvoice
                          ? null
                          : () {
                              GoRouter.of(context).push(
                                '/sales/create-invoice',
                                extra: {
                                  'cartItems': items,
                                  'customer': selectedCustomer,
                                  'branchId': branch?.id,
                                },
                              );
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        textStyle: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const PhosphorIcon(
                        PhosphorIconsBold.fileText,
                        size: 20,
                      ),
                      label: const Text('Create Invoice'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TICKET ITEM ROW
// ─────────────────────────────────────────────────────────────────────────────

class _TicketItemRow extends ConsumerWidget {
  final PosCartItem item;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onRemove;

  const _TicketItemRow({
    required this.item,
    required this.cs,
    required this.tt,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posBranchId = ref.watch(posBranchProvider);
    // Watch the stock provider so that the value is actively cached for the synchronously tapped + button
    final stockState = ref
        .watch(
          stockByBranchProvider((
            productId: item.product.id,
            branchId: posBranchId,
          )),
        )
        .value;

    return Dismissible(
      key: ValueKey(item.product.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: AppTokens.roundedCard,
        ),
        child: PhosphorIcon(
          PhosphorIconsBold.trash,
          color: cs.onErrorContainer,
          size: 20,
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product name + details (Left side)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Consumer(
                      builder: (context, ref, child) {
                        if (item.isSqmBased) {
                          return Text(
                            '${item.totalSqm.toStringAsFixed(2)} sqm (${item.quantity} box${item.quantity != 1 ? 'es' : ''})',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          );
                        }
                        final group = item.product.itemGroupId != null
                            ? ref
                                  .watch(
                                    itemGroupProvider(
                                      item.product.itemGroupId!,
                                    ),
                                  )
                                  .value
                            : null;
                        return Text(
                          group?.name ?? 'Unit',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Quantity controls (Middle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: QtyStepper(
                  value: item.quantity,
                  onChanged: (newVal) {
                    if (newVal == 0) {
                      onRemove();
                    } else {
                      if (!item.product.isService && newVal > item.quantity) {
                        final availableStock = stockState?.quantity ?? 0;
                        if (newVal > availableStock) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot add ${item.product.name}. Only $availableStock in stock.',
                              ),
                              backgroundColor: cs.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                      }
                      ref
                          .read(cartProvider.notifier)
                          .setQuantity(item.product.id, newVal);
                    }
                  },
                ),
              ),

              // Line total (Right)
              Expanded(
                flex: 1,
                child: Text(
                  CurrencyHelper.format(item.total),
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
