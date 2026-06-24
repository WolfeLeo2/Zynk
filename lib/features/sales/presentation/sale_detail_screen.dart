import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/models/staff_model.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/features/customers/providers/customer_providers.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:zynk/features/sales/presentation/printing/invoice_image_export.dart';
import 'package:zynk/features/sales/presentation/printing/invoice_template.dart';
import 'package:zynk/features/sales/presentation/printing/receipt_template.dart';
import 'package:zynk/features/sales/presentation/printing/delivery_note_template.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zynk/core/utils/currency.dart';
import 'package:zynk/core/utils/responsive_modal.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _saleActionLoadingNotifier =
    NotifierProvider<_SaleActionLoadingNotifier, String?>(
      _SaleActionLoadingNotifier.new,
    );

class _SaleActionLoadingNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? action) => state = action;
}

class _PrintablePayload {
  final pw.Document document;
  final String fileName;

  const _PrintablePayload({required this.document, required this.fileName});
}

/// Zoho-inspired sale detail screen with sections for items, payments,
/// timeline, and action buttons (approve / void / record payment / credit note).
class SaleDetailScreen extends ConsumerWidget {
  final String saleId;
  const SaleDetailScreen({super.key, required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleDetailProvider(saleId));
    // These are watched to keep the providers alive and warmed up for async actions like cloning
    // ignore: unused_local_variable
    final productsAsync = ref.watch(allProductsProvider);
    // ignore: unused_local_variable
    final itemsAsync = ref.watch(saleItemsProvider(saleId));

    final canApprove = ref.watch(
      hasPermissionProvider(Permission.approveInvoices),
    );
    final canEdit = ref.watch(hasPermissionProvider(Permission.editSales));
    final canDelete = ref.watch(hasPermissionProvider(Permission.deleteSales));
    final canPay = ref.watch(hasPermissionProvider(Permission.recordPayments));
    final canVoid = ref.watch(hasPermissionProvider(Permission.voidSales));
    final canCreateInvoices = ref.watch(
      hasPermissionProvider(Permission.createInvoices),
    );

    // Dual-approval eligibility is derived in a provider (authz, not UI).
    final eligibility = ref.watch(saleApprovalEligibilityProvider(saleId));
    final canSubmitApproval = eligibility.canSubmitApproval;
    final hasCurrentUserApproved = eligibility.hasCurrentUserApproved;

    return saleAsync.when(
      data: (sale) {
        if (sale == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Invoice')),
            body: const Center(child: Text('Sale not found')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              sale.saleType == 'pos_sale'
                  ? sale.invoiceNumber ?? ""
                  : sale.invoiceNumber ?? "",
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.printer,
                  size: 22,
                ),
                tooltip: 'Print',
                onSelected: (value) {
                  _handlePrint(context, ref, sale, documentType: value);
                },
                itemBuilder: (_) => [
                  if (sale.saleType != 'pos_sale') ...[
                    const PopupMenuItem(
                      value: 'print_invoice',
                      child: Text('Print Invoice'),
                    ),
                    const PopupMenuItem(
                      value: 'print_delivery_note',
                      child: Text('Print Delivery Note'),
                    ),
                  ],
                  const PopupMenuItem(
                    value: 'print_receipt',
                    child: Text('Print Receipt'),
                  ),
                ],
              ),
              IconButton(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.imageSquare,
                  size: 22,
                ),
                tooltip: 'Save as Image',
                onPressed: () => _handleSaveAsImage(context, ref, sale),
              ),
              Builder(
                builder: (ctx) {
                  final items = <PopupMenuEntry<String>>[
                    if (sale.status == InvoiceStatus.pendingApproval &&
                        sale.amountPaid <= 0 &&
                        canEdit)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Invoice'),
                      ),
                    if (sale.status == InvoiceStatus.approved &&
                        canApprove &&
                        canEdit)
                      const PopupMenuItem(
                        value: 'edit_approved',
                        child: Text('Edit Approved Invoice'),
                      ),
                    if (canCreateInvoices && sale.saleType != 'pos_sale')
                      const PopupMenuItem(
                        value: 'clone_invoice',
                        child: Text('Clone Invoice'),
                      ),
                    if (sale.status == InvoiceStatus.pendingApproval &&
                        canSubmitApproval)
                      const PopupMenuItem(
                        value: 'approve',
                        child: Text('Approve'),
                      ),
                    if (sale.status == InvoiceStatus.pendingApproval &&
                        canApprove)
                      const PopupMenuItem(
                        value: 'final_approve',
                        child: Text('Final Approve (Fast-Track)'),
                      ),
                    if (sale.status == InvoiceStatus.pendingApproval &&
                        canSubmitApproval)
                      const PopupMenuItem(
                        value: 'reject',
                        child: Text('Reject'),
                      ),
                    if (sale.status == InvoiceStatus.approved && canApprove)
                      const PopupMenuItem(
                        value: 'unapprove',
                        child: Text('Unapprove Invoice'),
                      ),
                    if (sale.canBeVoided && canVoid)
                      const PopupMenuItem(
                        value: 'void',
                        child: Text('Void Sale'),
                      ),
                    if (sale.canBeReleased && (canApprove || canPay))
                      const PopupMenuItem(
                        value: 'fulfill',
                        child: Text('Release Goods'),
                      ),
                    if (canDelete && sale.amountPaid <= 0)
                      const PopupMenuItem(
                        value: 'delete_sale',
                        child: Text(
                          'Delete Invoice',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ];

                  if (items.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return PopupMenuButton<String>(
                    onSelected: (action) =>
                        _handleAction(context, ref, sale, action),
                    itemBuilder: (_) => items,
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Status Hero ──
              _StatusHero(sale: sale),
              const SizedBox(height: 20),

              // ── Details Section ──
              _DetailsSection(sale: sale),
              const SizedBox(height: 20),

              // ── Approval Timeline ──
              _SectionTitle(title: 'Approval Timeline'),
              const SizedBox(height: 8),
              _ApprovalTimeline(sale: sale),
              const SizedBox(height: 20),

              // ── Items Section ──
              _SectionTitle(title: 'Items'),
              const SizedBox(height: 8),
              _ItemsList(saleId: sale.id),
              const SizedBox(height: 20),

              // ── Totals ──
              _TotalsCard(sale: sale),
              const SizedBox(height: 20),

              // ── Transaction History ──
              _SectionTitle(title: 'Transaction History'),
              const SizedBox(height: 8),
              _PaymentsList(saleId: sale.id),
              const SizedBox(height: 20),

              // ── Credit Notes ──
              _SectionTitle(title: 'Credit Notes'),
              const SizedBox(height: 8),
              _CreditNotesList(saleId: sale.id),
              const SizedBox(height: 100),
            ],
          ),

          // ── Bottom Action Buttons ──
          bottomNavigationBar: _buildBottomActions(
            context,
            ref,
            sale,
            canApprove,
            canPay,
            canSubmitApproval,
            hasCurrentUserApproved,
          ),
        );
      },
      loading: () => _SaleDetailSkeleton(),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget? _buildBottomActions(
    BuildContext context,
    WidgetRef ref,
    Sale sale,
    bool canApprove,
    bool canPay,
    bool canSubmitApproval,
    bool hasCurrentUserApproved,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final actions = <Widget>[];
    final canCreditNote = ref.watch(
      hasPermissionProvider(Permission.issueCreditNotes),
    );
    final loadingAction = ref.watch(_saleActionLoadingNotifier);

    // Approve button (for pending approval invoices)
    if (sale.status == InvoiceStatus.pendingApproval && canSubmitApproval) {
      final isLoading = loadingAction == 'approve';
      actions.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: canSubmitApproval && !isLoading
                ? () => _handleAction(context, ref, sale, 'approve')
                : null,
            icon: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        canSubmitApproval ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
                  )
                : const PhosphorIcon(PhosphorIconsBold.checkCircle, size: 18),
            label: isLoading
                ? const Text('Approving...')
                : Text(
                    hasCurrentUserApproved
                        ? 'Already Approved'
                        : (!canSubmitApproval && canApprove
                              ? 'Slot Filled'
                              : 'Approve (${sale.approvalCount}/${sale.requiredApprovals})'),
                  ),
            style: FilledButton.styleFrom(
              backgroundColor: canSubmitApproval && !isLoading
                  ? cs.primary
                  : cs.surfaceContainerHighest,
              foregroundColor: canSubmitApproval && !isLoading
                  ? cs.onPrimary
                  : cs.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    if (sale.canAcceptPayment && canPay) {
      actions.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showRecordPayment(context, ref, sale),
            icon: const PhosphorIcon(PhosphorIconsBold.money, size: 18),
            label: const Text('Record Payment'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    if (sale.isOperationallyCompleted && canCreditNote) {
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showCreateCreditNote(context, ref, sale),
            icon: const PhosphorIcon(
              PhosphorIconsRegular.arrowUUpLeft,
              size: 18,
            ),
            label: const Text('Credit Note'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    if (actions.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: actions.expand((w) => [w, const SizedBox(width: 12)]).toList()
          ..removeLast(),
      ),
    );
  }

  Future<void> _handlePrint(
    BuildContext context,
    WidgetRef ref,
    Sale sale, {
    required String documentType,
  }) async {
    final payload = await _preparePrintablePayload(
      context,
      ref,
      sale,
      documentType: documentType,
    );
    if (payload == null) {
      return;
    }

    await Printing.layoutPdf(
      onLayout: (_) => payload.document.save(),
      name: payload.fileName,
    );
  }

  Future<void> _handleSaveAsImage(
    BuildContext context,
    WidgetRef ref,
    Sale sale,
  ) async {
    final payload = await _preparePrintablePayload(
      context,
      ref,
      sale,
      documentType: sale.saleType == 'pos_sale'
          ? 'print_receipt'
          : 'print_invoice',
    );
    if (payload == null) {
      return;
    }

    try {
      final imagePath = await InvoiceImageExport.saveFirstPageAsPng(
        document: payload.document,
        fileName: payload.fileName,
        share: true,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved image: $imagePath')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save image: $e')));
      }
    }
  }

  Future<_PrintablePayload?> _preparePrintablePayload(
    BuildContext context,
    WidgetRef ref,
    Sale sale, {
    required String documentType,
  }) async {
    final itemsAsync = ref.read(saleItemsProvider(sale.id));
    final paymentsAsync = ref.read(salePaymentsProvider(sale.id));
    final tenantAsync = ref.read(currentTenantProvider);
    final customersAsync = ref.read(allCustomersProvider);
    final staffAsync = ref.read(humanStaffProvider);

    final items = itemsAsync.value ?? [];
    final payments = paymentsAsync.value ?? [];
    final tenant = tenantAsync.value;

    if (tenant == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business info not loaded yet')),
        );
      }
      return null;
    }

    String? customerName;
    String? customerAddress;
    String? customerPhone;
    if (sale.customerId != null && customersAsync.hasValue) {
      try {
        final customer = customersAsync.value!.firstWhere(
          (c) => c.id == sale.customerId,
        );
        customerName = customer.name;
        customerAddress = null;
        customerPhone = customer.phone;
      } catch (_) {}
    }

    String? salespersonName;
    if (sale.salespersonId != null && staffAsync.hasValue) {
      try {
        salespersonName = staffAsync.value
            ?.firstWhere((s) => s.id == sale.salespersonId)
            .name;
      } catch (_) {
        salespersonName = null;
      }
    }

    Branch? branch;
    final branchesAsync = ref.read(branchesProvider);
    if (branchesAsync.hasValue) {
      try {
        branch = branchesAsync.value!.firstWhere((b) => b.id == sale.branchId);
      } catch (_) {}
    }

    pw.MemoryImage? logoImage;
    if (tenant.logoUrl != null && tenant.logoUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(tenant.logoUrl!));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Failed to load logo for PDF: $e');
      }
    }

    final pw.Document document;
    if (documentType == 'print_delivery_note') {
      document = DeliveryNoteTemplate.generate(
        sale: sale,
        items: items,
        tenant: tenant,
        branch: branch,
        customerName: customerName,
        customerAddress: customerAddress,
        customerPhone: customerPhone,
        salespersonName: salespersonName,
        logoImage: logoImage,
      );
    } else if (documentType == 'print_receipt' || sale.saleType == 'pos_sale') {
      document = ReceiptTemplate.generate(
        sale: sale,
        items: items,
        tenant: tenant,
        branch: branch,
        customerName: customerName,
        salespersonName: salespersonName,
        logoImage: logoImage,
      );
    } else {
      document = InvoiceTemplate.generate(
        sale: sale,
        items: items,
        payments: payments,
        tenant: tenant,
        branch: branch,
        customerName: customerName,
        customerAddress: customerAddress,
        customerPhone: customerPhone,
        salespersonName: salespersonName,
        logoImage: logoImage,
      );
    }

    final fileName = documentType == 'print_delivery_note'
        ? 'delivery_note_${sale.invoiceNumber ?? 'draft'}'
        : documentType == 'print_receipt' || sale.saleType == 'pos_sale'
        ? 'receipt_${sale.invoiceNumber ?? 'draft'}'
        : 'invoice_${sale.invoiceNumber ?? 'draft'}';

    return _PrintablePayload(document: document, fileName: fileName);
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    Sale sale,
    String action,
  ) async {
    final service = ref.read(salesServiceProvider);
    ref.read(_saleActionLoadingNotifier.notifier).set(action);
    try {
      switch (action) {
        case 'edit':
          if (context.mounted) {
            context.push('/sales/${sale.id}/edit');
          }
          return;
        case 'edit_approved':
          // Unapprove first (reverses stock + payments), then navigate to edit
          final confirmedEdit = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Edit Approved Invoice?'),
              content: const Text(
                'This will revert the invoice to Pending Approval, reverse any stock releases and recorded payments. You will need to re-approve after editing.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Unapprove & Edit'),
                ),
              ],
            ),
          );
          if (confirmedEdit == true) {
            await service.unapproveSale(sale.id, tenantId: sale.tenantId);
            ref.invalidate(saleDetailProvider(sale.id));
            ref.invalidate(saleApprovalsProvider(sale.id));
            ref.invalidate(salePaymentsProvider(sale.id));
            if (context.mounted) {
              context.push(
                '/sales/${sale.id}/edit',
                extra: {'wasApproved': true},
              );
            }
          }
          return;
        case 'clone_invoice':
          try {
            // Ensure all data is loaded before proceeding
            final items = await ref.read(saleItemsProvider(sale.id).future);
            final allProducts = await ref.read(allProductsProvider.future);
            final allCustomers = await ref.read(allCustomersProvider.future);

            final customer = allCustomers.firstWhere(
              (c) => c.id == sale.customerId,
              orElse: () => throw Exception('Customer not found for cloning'),
            );

            final cartItems = items.map((item) {
              final product = allProducts
                  .where((p) => p.id == item.productId)
                  .firstOrNull;

              if (product == null) {
                throw Exception(
                  'Product "${item.productName ?? 'Unknown'}" no longer exists in inventory',
                );
              }

              return PosCartItem(
                product: product,
                quantity: item.quantity,
                overrideName: item.productName,
                overridePrice: item.unitPrice,
              );
            }).toList();

            if (context.mounted) {
              context.push(
                '/sales/create-invoice',
                extra: {
                  'cartItems': cartItems,
                  'customer': customer,
                  'salespersonId': sale.salespersonId,
                  'branchId': sale.branchId,
                },
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to clone: ${e.toString().replaceAll('Exception: ', '')}',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
          return;
        case 'submit_for_approval':
          await service.submitForApproval(sale.id, tenantId: sale.tenantId);
          ref.invalidate(saleDetailProvider(sale.id));
          break;
        case 'approve':
          await service.approveSale(sale.id, tenantId: sale.tenantId);
          ref.invalidate(saleDetailProvider(sale.id));
          ref.invalidate(saleApprovalsProvider(sale.id));
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Invoice approved')));
          }
          break;

        case 'final_approve':
          final confirmedFinal = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Final Approve?'),
              content: const Text(
                'This will immediately approve the invoice, bypassing the normal dual-approval requirement. This action is recorded in the audit trail.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Final Approve'),
                ),
              ],
            ),
          );
          if (confirmedFinal == true) {
            await service.finalApproveSale(sale.id, tenantId: sale.tenantId);
            ref.invalidate(saleDetailProvider(sale.id));
            ref.invalidate(saleApprovalsProvider(sale.id));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invoice fast-track approved ✓')),
              );
            }
          }
          break;

        case 'unapprove':
          final confirmedUnapprove = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Unapprove Invoice?'),
              content: const Text(
                'This will revert the invoice to Pending Approval. Any fulfilled stock will be reversed and recorded payments will be deleted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Unapprove'),
                ),
              ],
            ),
          );
          if (confirmedUnapprove == true) {
            await service.unapproveSale(sale.id, tenantId: sale.tenantId);
            ref.invalidate(saleDetailProvider(sale.id));
            ref.invalidate(saleApprovalsProvider(sale.id));
            ref.invalidate(salePaymentsProvider(sale.id));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invoice reverted to Pending Approval'),
                ),
              );
            }
          }
          break;

        case 'reject':
          await service.rejectSale(
            sale.id,
            tenantId: sale.tenantId,
            reason: 'Rejected by manager',
          );
          ref.invalidate(saleDetailProvider(sale.id));
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Invoice rejected')));
          }
          break;
        case 'fulfill':
          await service.fulfillSale(sale.id, tenantId: sale.tenantId);
          ref.invalidate(saleDetailProvider(sale.id));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Goods released and stock adjusted'),
              ),
            );
          }
          break;
        case 'void':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Void Sale?'),
              content: const Text(
                'This will reverse stock and void the invoice. This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Void'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await service.voidSale(
              sale.id,
              tenantId: sale.tenantId,
              reason: 'Voided by user',
            );
            ref.invalidate(saleDetailProvider(sale.id));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Invoice voided')));
            }
          }
          break;
        case 'delete_sale':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete Invoice?'),
              content: const Text(
                'This will permanently delete the invoice, all payments, and reverse stock. This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await service.deleteSale(saleId: sale.id, tenantId: sale.tenantId);
            ref.invalidate(saleDetailProvider(sale.id));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Invoice deleted')));
              Navigator.pop(context);
            }
          }
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      ref.read(_saleActionLoadingNotifier.notifier).set(null);
    }
  }

  void _showRecordPayment(BuildContext context, WidgetRef ref, Sale sale) {
    showResponsiveModal(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordPaymentSheet(sale: sale),
    );
  }

  void _showCreateCreditNote(BuildContext context, WidgetRef ref, Sale sale) {
    showResponsiveModal(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCreditNoteSheet(saleId: sale.id),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS HERO
// ─────────────────────────────────────────────────────────────────────────────

class _StatusHero extends StatelessWidget {
  final Sale sale;
  const _StatusHero({required this.sale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _colorForStatus(sale.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.08), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: PhosphorIcon(
                _iconForStatus(sale.status),
                color: color,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.status.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatFull(sale.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Release badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            sale.fulfillmentStatus == FulfillmentStatus.released
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sale.fulfillmentStatus.displayName.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              sale.fulfillmentStatus ==
                                  FulfillmentStatus.released
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Payment badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _paymentBadgeColor(sale).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sale.paymentStatus.displayName.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _paymentBadgeColor(sale),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyHelper.format(sale.grandTotal),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (sale.remainingBalance > 0)
                Text(
                  'Due: ${CurrencyHelper.format(sale.remainingBalance)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFFA726),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _paymentBadgeColor(Sale sale) {
    switch (sale.paymentStatus) {
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.partiallyPaid:
        return const Color(0xFFFFA726); // Orange
      case PaymentStatus.unpaid:
        return Colors.red;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEMS LIST
// ─────────────────────────────────────────────────────────────────────────────

class _ItemsList extends ConsumerWidget {
  final String saleId;
  const _ItemsList({required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final itemsAsync = ref.watch(saleItemsProvider(saleId));
    final products = ref.watch(allProductsProvider).value ?? [];

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _emptyHint(theme, 'No items');
        }
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;

              // Resolve product & item group to check sqm details
              final product = products
                  .where((p) => p.id == item.productId)
                  .firstOrNull;
              final itemGroup = (product != null && product.itemGroupId != null)
                  ? ref.watch(itemGroupProvider(product.itemGroupId!)).value
                  : null;

              final isSqmBased =
                  product != null &&
                  (product.pricingUnit == 'sqm' ||
                      itemGroup?.defaultPricingUnit == 'sqm');
              final coverage =
                  (product?.coveragePerBox ??
                      itemGroup?.defaultCoveragePerBox) ??
                  1.0;
              final sqmPrice = isSqmBased
                  ? (item.unitPrice / coverage)
                  : item.unitPrice;
              final totalSqm = isSqmBased ? (item.quantity * coverage) : 0.0;

              return Column(
                children: [
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: cs.outline.withValues(alpha: 0.1),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 30,
                          constraints: const BoxConstraints(minWidth: 30),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isSqmBased
                                ? totalSqm.toStringAsFixed(2)
                                : '${item.quantity}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName ??
                                    item.productId.substring(0, 8),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isSqmBased) ...[
                                Text(
                                  '@ ${CurrencyHelper.format(sqmPrice)}/sqm (${CurrencyHelper.format(item.unitPrice)}/box)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.quantity} box${item.quantity != 1 ? 'es' : ''} (${totalSqm.toStringAsFixed(2)} sqm total)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.primary.withValues(alpha: 0.8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  '@ ${CurrencyHelper.format(item.unitPrice)} each',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          CurrencyHelper.format(item.total),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
      loading: () => _ShimmerSection(height: 60),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOTALS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  final Sale sale;
  const _TotalsCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _row(theme, 'Subtotal', sale.subtotal),
          if (sale.discountAmount > 0)
            _row(theme, 'Discount', -sale.discountAmount),
          if (sale.taxAmount > 0) _row(theme, 'Tax', sale.taxAmount),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grand Total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                CurrencyHelper.format(sale.grandTotal),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          if (sale.amountPaid > 0) ...[
            const SizedBox(height: 8),
            _row(
              theme,
              'Paid',
              sale.amountPaid,
              color: const Color(0xFF66BB6A),
            ),
            if (sale.remainingBalance > 0)
              _row(
                theme,
                'Balance Due',
                sale.remainingBalance,
                color: const Color(0xFFFFA726),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            '${amount < 0 ? "-" : ""}${CurrencyHelper.format(amount.abs())}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENTS LIST
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentsList extends ConsumerWidget {
  final String saleId;
  const _PaymentsList({required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final paymentsAsync = ref.watch(salePaymentsProvider(saleId));
    final isAdmin = ref.watch(hasPermissionProvider(Permission.deleteSales));

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return _emptyHint(theme, 'No payments recorded');
        }
        return Column(
          children: payments.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF66BB6A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        _paymentIcon(p.paymentMethod),
                        color: const Color(0xFF66BB6A),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.paymentMethod.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (p.referenceNumber != null)
                          Text(
                            p.referenceNumber!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyHelper.format(p.amount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF66BB6A),
                    ),
                  ),
                  // Admin-only delete button
                  if (isAdmin)
                    IconButton(
                      icon: PhosphorIcon(
                        PhosphorIconsRegular.trash,
                        size: 18,
                        color: cs.error,
                      ),
                      tooltip: 'Delete payment',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Delete Payment?'),
                            content: const Text(
                              'This will reverse the payment amount and update payment/release state as needed. Continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          try {
                            final service = ref.read(salesServiceProvider);
                            await service.deletePayment(
                              saleId: saleId,
                              paymentId: p.id,
                              tenantId: p.tenantId,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment deleted'),
                                ),
                              );
                            }
                            // Force refresh of the sale and payments list
                            ref.invalidate(salePaymentsProvider(saleId));
                            ref.invalidate(saleDetailProvider(saleId));
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => _ShimmerSection(height: 50),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREDIT NOTES LIST
// ─────────────────────────────────────────────────────────────────────────────

class _CreditNotesList extends ConsumerWidget {
  final String saleId;
  const _CreditNotesList({required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cnAsync = ref.watch(creditNotesForSaleProvider(saleId));

    return cnAsync.when(
      data: (notes) {
        if (notes.isEmpty) {
          return _emptyHint(theme, 'No credit notes');
        }
        return Column(
          children: notes.map((cn) {
            final color = cn.status == CreditNoteStatus.approved
                ? const Color(0xFF66BB6A)
                : cn.status == CreditNoteStatus.applied
                ? Theme.of(context).colorScheme.secondary
                : const Color(0xFFFFA726);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.arrowUUpLeft,
                        color: color,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cn.creditNumber ?? 'CN',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          cn.reason,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyHelper.format(cn.total),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        cn.status.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => _ShimmerSection(height: 50),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECORD PAYMENT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  final Sale sale;
  const _RecordPaymentSheet({required this.sale});

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _amountController = TextEditingController();
  String _method = 'cash';
  final _refController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.sale.remainingBalance.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<bool?> _confirmOverpayment(double excess) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overpayment'),
        content: Text(
          'This payment is ${CurrencyHelper.format(excess)} more than the '
          'outstanding balance. Record the overpayment anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    if (['cash', 'mpesa', 'card', 'bank_transfer'].contains(_method)) {
      if (_refController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Reference number is required for all payment methods',
              ),
            ),
          );
        }
        return;
      }
    }

    // Overpayment guard: confirm before recording more than the balance.
    // The server enforces this too (allow_overpayment flag) — the dialog is
    // the UX, the flag is what makes the server accept the deliberate excess.
    final overpaying = amount > widget.sale.remainingBalance + 0.01;
    if (overpaying) {
      final excess = amount - widget.sale.remainingBalance;
      final proceed = await _confirmOverpayment(excess);
      if (proceed != true) return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(salesServiceProvider)
          .recordPayment(
            saleId: widget.sale.id,
            tenantId: widget.sale.tenantId,
            amount: amount,
            paymentMethod: _method,
            referenceNumber: _refController.text.trim().isEmpty
                ? null
                : _refController.text.trim(),
            allowOverpayment: overpaying,
          );

      // Force refresh
      ref.invalidate(saleDetailProvider(widget.sale.id));
      ref.invalidate(salePaymentsProvider(widget.sale.id));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Record Payment',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Balance: ${CurrencyHelper.format(widget.sale.remainingBalance)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (Ksh)',
                prefixText: 'Ksh ',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(
                  value: 'bank_transfer',
                  child: Text('Bank Transfer'),
                ),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'cash'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _refController,
              decoration: const InputDecoration(
                labelText: 'Reference (Required)',
                hintText: 'M-Pesa code, Cash receipt #, etc.',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Record Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE CREDIT NOTE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _CreateCreditNoteSheet extends ConsumerStatefulWidget {
  final String saleId;
  const _CreateCreditNoteSheet({required this.saleId});

  @override
  ConsumerState<_CreateCreditNoteSheet> createState() =>
      _CreateCreditNoteSheetState();
}

class _CreateCreditNoteSheetState
    extends ConsumerState<_CreateCreditNoteSheet> {
  final _reasonController = TextEditingController();
  bool _loading = false;
  bool _restockItems = false;
  final Map<String, int> _returnQuantities = {};

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a reason')));
      return;
    }

    final selectedItems = _returnQuantities.entries
        .where((e) => e.value > 0)
        .toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select items to return')));
      return;
    }

    setState(() => _loading = true);
    try {
      // Get the items for credit note
      final saleItemsAsync = ref.read(saleItemsProvider(widget.saleId));
      final saleItems = saleItemsAsync.value ?? [];

      final cnItems = <CreditNoteItem>[];
      for (final entry in selectedItems) {
        final saleItem = saleItems.firstWhere(
          (si) => si.productId == entry.key,
        );
        final qty = entry.value;
        cnItems.add(
          CreditNoteItem(
            productId: saleItem.productId,
            productName: saleItem.productName,
            quantity: qty,
            unitPrice: saleItem.unitPrice,
            total: saleItem.unitPrice * qty,
          ),
        );
      }

      final saleDetail = ref.read(saleDetailProvider(widget.saleId)).value;

      await ref
          .read(salesServiceProvider)
          .createCreditNote(
            tenantId: saleDetail!.tenantId,
            branchId: saleDetail.branchId,
            originalSaleId: widget.saleId,
            reason: _reasonController.text,
            items: cnItems,
            restockItems: _restockItems,
          );

      // Force refresh of sale details and credit notes
      ref.invalidate(saleDetailProvider(widget.saleId));
      ref.invalidate(creditNotesForSaleProvider(widget.saleId));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final itemsAsync = ref.watch(saleItemsProvider(widget.saleId));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Create Credit Note',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select items being returned',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Items to return
            Flexible(
              child: itemsAsync.when(
                data: (items) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final returnQty = _returnQuantities[item.productId] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName ??
                                      item.productId.substring(0, 8),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${item.quantity} sold @ ${CurrencyHelper.format(item.unitPrice)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Stepper
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  iconSize: 16,
                                  onPressed: returnQty > 0
                                      ? () => setState(
                                          () =>
                                              _returnQuantities[item
                                                      .productId] =
                                                  returnQty - 1,
                                        )
                                      : null,
                                  icon: const PhosphorIcon(
                                    PhosphorIconsRegular.minus,
                                  ),
                                ),
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '$returnQty',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  iconSize: 16,
                                  onPressed: returnQty < item.quantity
                                      ? () => setState(
                                          () =>
                                              _returnQuantities[item
                                                      .productId] =
                                                  returnQty + 1,
                                        )
                                      : null,
                                  icon: const PhosphorIcon(
                                    PhosphorIconsRegular.plus,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                loading: () => const _ShimmerSection(height: 120),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for return',
                hintText: 'e.g., Defective product, wrong item',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Restock returned items'),
              subtitle: const Text(
                'Increase inventory levels for returned products',
              ),
              value: _restockItems,
              onChanged: (val) => setState(() => _restockItems = val),
              contentPadding: EdgeInsets.zero,
              activeTrackColor: cs.primary,
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Create Credit Note',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION TITLE
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Widget _emptyHint(ThemeData theme, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAILS SECTION (Customer & Staff)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsSection extends ConsumerWidget {
  final Sale sale;
  const _DetailsSection({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final customersAsync = ref.watch(allCustomersProvider);

    final staffAsync = ref.watch(humanStaffProvider);
    // Look up the staff name by salespersonId
    final String staffName = sale.salespersonId == null
        ? 'Not Assigned'
        : staffAsync.whenOrNull(
                data: (staff) => staff
                    .firstWhere(
                      (s) => s.id == sale.salespersonId,
                      orElse: () =>
                          StaffMember(id: '', tenantId: '', name: 'Unknown'),
                    )
                    .name,
              ) ??
              'Loading...';

    String customerName = 'Walk-in Customer';
    String? customerPhone;
    if (customersAsync.hasValue &&
        customersAsync.value != null &&
        sale.customerId != null) {
      try {
        final customer = customersAsync.value!.firstWhere(
          (c) => c.id == sale.customerId,
        );
        customerName = customer.name;
        customerPhone = customer.phone;
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow(theme, PhosphorIconsRegular.user, 'Customer', customerName),
          if (customerPhone != null && customerPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                customerPhone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildRow(
            theme,
            PhosphorIconsRegular.identificationBadge,
            'SalesPerson',
            staffName,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    ThemeData theme,
    PhosphorIconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        PhosphorIcon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalTimeline extends ConsumerWidget {
  final Sale sale;
  const _ApprovalTimeline({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final approvalsAsync = ref.watch(saleApprovalsProvider(sale.id));
    final profilesAsync = ref.watch(staffProvider);
    final requiredApprovals = sale.requiredApprovals < 1
        ? 1
        : sale.requiredApprovals;

    return approvalsAsync.when(
      data: (approvals) {
        final approved = approvals
            .where((a) => a.decision == SaleApprovalDecision.approved)
            .toList();

        final profiles = profilesAsync.value ?? [];
        final ownerProfile = profiles.firstWhere(
          (p) => p.role.isOwner,
          orElse: () => Profile(
            id: '',
            userId: '',
            tenantId: '',
            role: UserRole.owner,
            displayName: 'Owner',
          ),
        );

        final eligibleStaff = profiles
            .where(
              (p) =>
                  p.hasPermission(Permission.approveInvoices) &&
                  !p.role.isOwner,
            )
            .toList();
        eligibleStaff.sort(
          (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
            b.createdAt ?? DateTime.now(),
          ),
        );
        final designatedStaff = eligibleStaff.isNotEmpty
            ? eligibleStaff.first
            : null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${approved.length}/$requiredApprovals approvals collected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (requiredApprovals >= 2) ...[
                    _buildApprovalChip(
                      cs,
                      approved.cast<SaleApproval?>().firstWhere(
                        (a) =>
                            a?.approverRole?.toLowerCase() == 'owner' ||
                            a?.approverUserId == ownerProfile.userId,
                        orElse: () => null,
                      ),
                      pendingName:
                          ownerProfile.displayName?.trim().isNotEmpty == true
                          ? ownerProfile.displayName!.trim()
                          : 'Owner',
                    ),
                    _buildApprovalChip(
                      cs,
                      approved.cast<SaleApproval?>().firstWhere(
                        (a) =>
                            a?.approverRole?.toLowerCase() != 'owner' &&
                            a?.approverUserId != ownerProfile.userId,
                        orElse: () => null,
                      ),
                      pendingName:
                          designatedStaff?.displayName?.trim().isNotEmpty ==
                              true
                          ? designatedStaff!.displayName!.trim()
                          : 'Staff',
                    ),
                  ] else ...[
                    /* Fallback for single approval or generic setup
                    ...List.generate(requiredApprovals, (index) {
                      final approval =
                          index < approved.length ? approved[index] : null;
                      return _buildApprovalChip(
                          cs, 'Approval #${index + 1}', approval);
                    }),
                  ],*/
                  ],
                ],
              ),
            ],
          ),
        );
      },
      loading: () => _ShimmerSection(height: 60),
      error: (e, _) => Text('Error loading approvals: $e'),
    );
  }

  Widget _buildApprovalChip(
    ColorScheme cs,
    SaleApproval? approval, {
    String? pendingName,
  }) {
    if (approval != null) {
      final approverName =
          approval.approverDisplayName?.trim().isNotEmpty == true
          ? approval.approverDisplayName!.trim()
          : approval.approverUserId;
      final ts = approval.createdAt != null
          ? _formatFull(approval.createdAt)
          : 'time unavailable';

      return Chip(
        avatar: PhosphorIcon(
          PhosphorIconsRegular.checkCircle,
          size: 16,
          color: cs.onPrimaryContainer,
        ),
        label: Text('$approverName · $ts'),
        backgroundColor: cs.primaryContainer,
        side: BorderSide.none,
      );
    }

    final pendingDisplay = pendingName != null ? '$pendingName' : 'Pending';
    return Chip(
      avatar: const PhosphorIcon(PhosphorIconsRegular.clock, size: 16),
      label: Text('$pendingDisplay · Pending'),
      side: BorderSide(color: cs.outline.withValues(alpha: 0.8)),
    );
  }
}

Color _colorForStatus(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.pendingApproval:
      return const Color(0xFFFFA726);
    case InvoiceStatus.approved:
      return AppTokens.brandPrimary;
    case InvoiceStatus.rejected:
      return AppTokens.brandAccent;
    case InvoiceStatus.partiallyPaid:
      return const Color(0xFFFFA726);
    case InvoiceStatus.paid:
      return AppTokens.brandSecondary;
    case InvoiceStatus.completed:
      return const Color(0xFF66BB6A);
    case InvoiceStatus.voided:
      return const Color(0xFFEF5350);
  }
}

PhosphorIconData _iconForStatus(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.pendingApproval:
      return PhosphorIconsDuotone.clock;
    case InvoiceStatus.approved:
      return PhosphorIconsDuotone.checkCircle;
    case InvoiceStatus.rejected:
      return PhosphorIconsDuotone.xCircle;
    case InvoiceStatus.partiallyPaid:
      return PhosphorIconsDuotone.percent;
    case InvoiceStatus.paid:
      return PhosphorIconsDuotone.currencyCircleDollar;
    case InvoiceStatus.completed:
      return PhosphorIconsDuotone.sealCheck;
    case InvoiceStatus.voided:
      return PhosphorIconsDuotone.prohibit;
  }
}

PhosphorIconData _paymentIcon(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return PhosphorIconsRegular.money;
    case PaymentMethod.mpesa:
      return PhosphorIconsRegular.cellSignalFull;
    case PaymentMethod.card:
      return PhosphorIconsRegular.creditCard;
    case PaymentMethod.bankTransfer:
      return PhosphorIconsRegular.bank;
    case PaymentMethod.creditNote:
      return PhosphorIconsRegular.arrowUUpLeft;
  }
}

String _formatFull(DateTime? date) {
  if (date == null) return '';
  final d = date.toLocal();
  final months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final min = d.minute.toString().padLeft(2, '0');
  final amPm = d.hour >= 12 ? 'PM' : 'AM';
  return '${months[d.month]} ${d.day}, ${d.year} · $hour:$min $amPm';
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerSection extends StatelessWidget {
  final double height;
  const _ShimmerSection({this.height = 50});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      highlightColor: cs.surfaceContainerHighest.withValues(alpha: 0.7),
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _SaleDetailSkeleton extends StatelessWidget {
  const _SaleDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: Shimmer.fromColors(
        baseColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        highlightColor: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
