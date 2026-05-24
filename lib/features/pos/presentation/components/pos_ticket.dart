import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:zynk/features/pos/providers/cart_provider.dart';
import 'package:zynk/features/pos/providers/pos_providers.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/services/product_pricing_service.dart';
import 'package:zynk/features/dashboard/presentation/widgets/skeleton_widgets.dart';

class PosTicket extends ConsumerWidget {
  final List<PosCartItem> items;
  final double total;
  final Function(PosCartItem) onRemoveItem;
  final VoidCallback onClearTicket;

  // Customer & Staff info
  final Customer? selectedCustomer;
  final String? salespersonId;
  final VoidCallback? onSelectCustomer;
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
    this.onSalespersonIdChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final branch = ref.watch(selectedPosBranchProvider);
    final staffAsync = ref.watch(humanStaffByBranchProvider(branch?.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── HEADER ───
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Current Ticket',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
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

        // ─── STAFF + CUSTOMER SECTION ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Staff name and Branch row
              Row(
                children: [
                  Expanded(
                    child: staffAsync.when(
                      data: (staffList) {
                        return Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cs.outline),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: salespersonId,
                              hint: Text(
                                'Select Salesperson',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                              ),
                              isExpanded: true,
                              icon: PhosphorIcon(
                                PhosphorIconsRegular.caretDown,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Select Salesperson'),
                                ),
                                ...staffList.map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                              onChanged: onSalespersonIdChanged,
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (err, stack) => const Text('Error loading options'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIconsRegular.storefront,
                          color: branch != null ? cs.primary : cs.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        ref.watch(branchSelectionProvider).isLoading
                            ? const SkeletonText(width: 80, height: 16)
                            : Text(
                                branch?.name ?? 'No branch',
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color:
                                      branch != null ? cs.onSurface : cs.error,
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Customer selector
              InkWell(
                onTap: onSelectCustomer,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.addressBook,
                        color: cs.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: selectedCustomer != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedCustomer!.name,
                                    style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (selectedCustomer!.phone != null ||
                                      selectedCustomer!.email != null)
                                    Text(
                                      [
                                        selectedCustomer!.phone,
                                        selectedCustomer!.email,
                                      ].whereType<String>().join(' • '),
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              )
                            : Text(
                                'Select customer',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                      ),
                      PhosphorIcon(
                        selectedCustomer != null
                            ? PhosphorIconsRegular.x
                            : PhosphorIconsRegular.caretRight,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.15)),

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

        // ─── TOTALS + CHARGE + INVOICE ───
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
              // Subtotal row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$itemCount item${itemCount != 1 ? 's' : ''}',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    'Ksh ${total.toStringAsFixed(0)}',
                    style: GoogleFonts.googleSansFlex(
                      textStyle: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontVariations: [
                          FontVariation.weight(900),
                          FontVariation.opticalSize(12),
                        ],
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                              if (salespersonId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Please select a salesperson before creating an invoice.',
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              GoRouter.of(context).push(
                                '/sales/create-invoice',
                                  extra: {
                                    'cartItems': items,
                                    'customer': selectedCustomer,
                                    'salespersonId': salespersonId,
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
    final stockState = ref.watch(stockByBranchProvider((productId: item.product.id, branchId: posBranchId))).value;

    return Dismissible(
      key: ValueKey(item.product.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: PhosphorIcon(
          PhosphorIconsBold.trash,
          color: cs.onErrorContainer,
          size: 20,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            // Product name + unit price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      if (item.isSqmBased) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ksh ${item.pricePerSqm.toStringAsFixed(0)}/sqm (Ksh ${item.effectivePrice.toStringAsFixed(0)}/box)',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.totalSqm.toStringAsFixed(2)} sqm (${item.quantity} box${item.quantity != 1 ? 'es' : ''})',
                              style: tt.bodySmall?.copyWith(
                                color: cs.primary.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }
                      final group = item.product.itemGroupId != null
                          ? ref.watch(itemGroupProvider(item.product.itemGroupId!)).value
                          : null;
                      final resolvedPrice = ref
                          .watch(productPricingServiceProvider)
                          .resolveSellingPrice(item.product, group);
                      return Text(
                        'Ksh ${resolvedPrice.toStringAsFixed(0)} each',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Quantity controls
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      ref.read(cartProvider.notifier).setQuantity(item.product.id, item.quantity - 1);
                    },
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: PhosphorIcon(PhosphorIconsBold.minus, size: 16, color: cs.primary),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 32),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}',
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (!item.product.isService) {
                        final availableStock = stockState?.quantity ?? 0;
                        if (item.quantity + 1 > availableStock) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cannot add ${item.product.name}. Only $availableStock in stock.'),
                              backgroundColor: cs.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                      }
                      ref.read(cartProvider.notifier).setQuantity(item.product.id, item.quantity + 1);
                    },
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: PhosphorIcon(PhosphorIconsBold.plus, size: 16, color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Line total
            SizedBox(
              width: 70,
              child: Text(
                'Ksh ${item.total.toStringAsFixed(0)}',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
