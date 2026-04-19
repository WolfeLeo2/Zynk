import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/services/sales_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

final salesServiceProvider = Provider<SalesService>((ref) {
  return SalesService(Supabase.instance.client);
});

// ─────────────────────────────────────────────────────────────────────────────
// SALES LIST (reactive via PowerSync)
// ─────────────────────────────────────────────────────────────────────────────

final salesListProvider = StreamProvider.autoDispose<List<Sale>>((ref) {
  final repo = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchSales(tenantId: tenantId, branchId: branchId);
});

final completedSalesProvider = StreamProvider.autoDispose<List<Sale>>((ref) {
  final repo = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo
      .watchSales(tenantId: tenantId, branchId: branchId)
      .map((sales) => sales.where((s) => s.isOperationallyCompleted).toList());
});

final pendingSalesProvider = StreamProvider.autoDispose<List<Sale>>((ref) {
  final repo = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchSales(
    tenantId: tenantId,
    branchId: branchId,
    status: InvoiceStatus.pendingApproval,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE SALE DETAIL
// ─────────────────────────────────────────────────────────────────────────────

final saleDetailProvider = StreamProvider.autoDispose.family<Sale?, String>((
  ref,
  saleId,
) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchSaleById(saleId);
});

final saleItemsProvider = StreamProvider.autoDispose
    .family<List<SaleItem>, String>((ref, saleId) {
      final repo = ref.watch(repositoryProvider);
      return repo.watchSaleItems(saleId);
    });

final salePaymentsProvider = StreamProvider.autoDispose
    .family<List<Payment>, String>((ref, saleId) {
      final repo = ref.watch(repositoryProvider);
      return repo.watchPaymentsForSale(saleId);
    });

// ─────────────────────────────────────────────────────────────────────────────
// CREDIT NOTES
// ─────────────────────────────────────────────────────────────────────────────

final creditNotesProvider = StreamProvider.autoDispose<List<CreditNote>>((ref) {
  final repo = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  return repo.watchCreditNotes(tenantId: tenantId);
});

final creditNotesForSaleProvider = StreamProvider.autoDispose
    .family<List<CreditNote>, String>((ref, saleId) {
      final repo = ref.watch(repositoryProvider);
      return repo.watchCreditNotesForSale(saleId);
    });

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD METRICS (real data)
// ─────────────────────────────────────────────────────────────────────────────

final todaysRevenueProvider = StreamProvider.autoDispose<double>((ref) {
  final repo = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchTodaysRevenue(branchId: branchId);
});

final todaysOrderCountProvider = StreamProvider.autoDispose<int>((ref) {
  final repo = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchTodaysOrderCount(branchId: branchId);
});

// Removed average order value provider

final lowStockCountProvider = StreamProvider.autoDispose<int>((ref) {
  final repo = ref.watch(repositoryProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return repo.watchLowStockCount(branchId: branchId);
});

final topProductsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final repo = ref.watch(repositoryProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      return repo.watchTopProducts(branchId: branchId);
    });

final paymentMethodBreakdownProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final repo = ref.watch(repositoryProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      return repo.watchPaymentMethodBreakdown(branchId: branchId);
    });
