import 'package:powersync/powersync.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../services/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

final _log = AppLogger('PowerSync');

// 1. Definition of the Local Schema (Mirrors Supabase)
final schema = Schema([
  // Tenants
  const Table('tenants', [
    Column.text('name'),
    Column.text('plan_type'),
    Column.text('address'),
    Column.text('phone'),
    Column.text('email'),
    Column.text('logo_url'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Locations
  const Table('locations', [
    Column.text('tenant_id'),
    Column.text('name'),
    Column.text('type'),
    Column.text('address'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Branches
  const Table('branches', [
    Column.text('tenant_id'),
    Column.text('location_id'),
    Column.text('name'),
    Column.text('address'),
    Column.text('phone'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Profiles
  const Table('profiles', [
    Column.text('user_id'),
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('role'),
    Column.text('permissions'),
    Column.text('display_name'),
    Column.text('profile_picture_url'),
    Column.text('phone'),
    Column.text('address'),
    Column.text('status'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Categories
  const Table('categories', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('name'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Expense Categories
  const Table('expense_categories', [
    Column.text('tenant_id'),
    Column.text('name'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Expenses
  const Table('expenses', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('category_id'),
    Column.text('staff_member_id'),
    Column.real('amount'),
    Column.text('description'),
    Column.text('payment_method'),
    Column.text('expense_date'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Staff Members
  const Table('staff_members', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('name'),
    Column.text('phone'),
    Column.text('email'),
    Column.text('profile_picture_url'),
    Column.text('status'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Item Groups (pure organizational containers)
  const Table('item_groups', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('name'),
    Column.text('description'),
    Column.text('default_commission_type'),
    Column.real('default_commission_value'),
    Column.real('default_selling_price'),
    Column.real('default_buying_price'),
    Column.text('default_pricing_unit'),
    Column.real('default_coverage_per_box'),
    Column.text('attributes'), // JSON string
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Composite Item Components
  const Table('composite_item_components', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('composite_product_id'),
    Column.text('component_product_id'),
    Column.integer('quantity'),
  ]),

  // Units of Measurement
  const Table('units_of_measurement', [
    Column.text('tenant_id'),
    Column.text('label'),
    Column.text('abbreviation'),
    Column.text('base_unit_id'),
    Column.real('conversion_factor'),
    Column.text('created_at'),
  ]),

  // Products
  const Table('products', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('item_group_id'),
    Column.text('category_id'),
    Column.text('name'),
    Column.text('sku'),
    Column.text('barcode'),
    Column.text('description'),
    Column.text('image_url'),
    Column.real('base_price'),
    Column.real('cost_price'),
    Column.text('tax_category'),
    Column.integer('is_service'), // Boolean as Integer (0/1)
    Column.text('commission_type'),
    Column.real('commission_value'),
    Column.text('pricing_unit'),
    Column.real('coverage_per_box'),
    Column.text('uom_id'),
    Column.text('parent_id'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Product-Branch availability mapping (shared catalog visibility)
  const Table('product_branches', [
    Column.text('tenant_id'),
    Column.text('product_id'),
    Column.text('branch_id'),
    Column.text('created_at'),
  ]),

  // Stock
  const Table('stock', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('product_id'),
    Column.integer('quantity'),
    Column.integer('reorder_level'),
    Column.text('last_updated'),
  ]),

  // Stock Adjustments
  const Table('stock_adjustments', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('product_id'),
    Column.text('adjustment_type'),
    Column.integer('quantity'),
    Column.text('reference_number'),
    Column.text('notes'),
    Column.text('created_by'),
    Column.text('salesperson_id'),
    Column.text('reason_id'),
    Column.text('status'),
    Column.text('bundle_id'),
    Column.text('created_at'),
  ]),

  // Stock Adjustment Reasons
  const Table('stock_adjustment_reasons', [
    Column.text('tenant_id'),
    Column.text('label'),
    Column.text('created_at'),
  ]),

  // Customers
  const Table('customers', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('name'),
    Column.text('phone'),
    Column.text('email'),
    Column.integer('loyalty_points'),
    Column.real('credit_limit'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Sales (evolved into full invoice)
  const Table('sales', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('customer_id'),
    Column.text('invoice_number'),
    Column.text('sale_type'),
    Column.text('created_by'),
    Column.text('salesperson_id'),
    Column.text('approved_by'),
    Column.real('total_amount'),
    Column.real('subtotal'),
    Column.real('tax_amount'),
    Column.real('discount_amount'),
    Column.real('grand_total'),
    Column.real('amount_paid'),
    Column.text('payment_method'),
    Column.text('status'),
    Column.integer('required_approvals'),
    Column.integer('approval_count'),
    Column.text('payment_status'),
    Column.text('notes'),
    Column.text('due_date'),
    Column.text('completed_at'),
    Column.text('voided_at'),
    Column.text('void_reason'),
    Column.text('external_ref'),
    Column.text('fulfillment_status'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Sale Approvals
  const Table('sale_approvals', [
    Column.text('sale_id'),
    Column.text('tenant_id'),
    Column.text('approver_user_id'),
    Column.text('decision'),
    Column.text('notes'),
    Column.text('created_at'),
  ]),

  // Sale Items
  const Table('sale_items', [
    Column.text('sale_id'),
    Column.text('product_id'),
    Column.text('tenant_id'),
    Column.integer('quantity'),
    Column.real('unit_price'),
    Column.real('cost_price'),
    Column.real('tax_amount'),
    Column.real('discount'),
    Column.real('total'),
    Column.text('product_name'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Sale Payments
  const Table('sale_payments', [
    Column.text('sale_id'),
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.real('amount'),
    Column.text('payment_method'),
    Column.text('reference_number'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Credit Notes
  const Table('credit_notes', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('original_sale_id'),
    Column.text('credit_number'),
    Column.text('status'),
    Column.text('reason'),
    Column.real('subtotal'),
    Column.real('tax_amount'),
    Column.real('total'),
    Column.text('applied_to_sale_id'),
    Column.text('created_by'),
    Column.text('approved_by'),
    Column.integer('restock_items'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Credit Note Items (junction table — was previously a JSON blob)
  const Table('credit_note_items', [
    Column.text('credit_note_id'),
    Column.text('product_id'),
    Column.text('product_name'),
    Column.integer('quantity'),
    Column.real('unit_price'),
    Column.real('tax_amount'),
    Column.real('total'),
    Column.text('tenant_id'),
    Column.text('created_at'),
  ]),

  // Commissions
  const Table('commissions', [
    Column.text('tenant_id'),
    Column.text('sale_id'),
    Column.text('salesperson_id'),
    Column.real('amount'),
    Column.text('status'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Profile Branches
  const Table('profile_branches', [
    Column.text('tenant_id'),
    Column.text('profile_id'),
    Column.text('branch_id'),
    Column.text('created_at'),
  ]),

  // Daily KPI Snapshots (server-generated aggregates)
  const Table('daily_kpi_snapshots', [
    Column.text('snapshot_date'),
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.integer('orders_count'),
    Column.real('gross_sales'),
    Column.real('payments_collected'),
    Column.real('total_expenses'),
    Column.real('net_profit'),
    Column.integer('pending_approval_count'),
    Column.integer('low_stock_count'),
    Column.real('inventory_value'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Daily Payment Method Snapshots (server-generated aggregates)
  const Table('daily_payment_method_snapshots', [
    Column.text('snapshot_date'),
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('payment_method'),
    Column.integer('txn_count'),
    Column.real('total_amount'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Daily Product Sales Snapshots (server-generated aggregates)
  const Table('daily_product_sales_snapshots', [
    Column.text('snapshot_date'),
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('product_id'),
    Column.integer('quantity_sold'),
    Column.real('revenue_total'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
]);

// 2. Global Database Instance
late final PowerSyncDatabase db;

// 3. Supabase Connector
class SupabaseConnector extends PowerSyncBackendConnector {
  final SupabaseClient supabase;
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  // Financial writes are server-authoritative and must flow via Edge Functions.
  static const Set<String> _serverAuthoritativeTables = {
    'sales',
    'sale_items',
    'sale_payments',
    'credit_notes',
    'credit_note_items',
    'commissions',
    'daily_kpi_snapshots',
    'daily_payment_method_snapshots',
    'daily_product_sales_snapshots',
  };

  SupabaseConnector(this.supabase);

  String _normalizeAdjustmentType(dynamic raw, dynamic quantityRaw) {
    final value = (raw as String?)?.toLowerCase();
    if (value == 'addition' ||
        value == 'reduction' ||
        value == 'initial' ||
        value == 'damage') {
      return value!;
    }

    final quantity = (quantityRaw as num?)?.toInt() ?? 0;
    if (quantity < 0) return 'reduction';
    if (quantity > 0) return 'addition';
    return 'initial';
  }

  String? _normalizeCreatedBy(dynamic raw) {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      return currentUserId;
    }

    final asString = raw?.toString();
    if (asString == null || asString.isEmpty) return null;
    return asString;
  }

  bool _hasInvalidBranchId(Map<String, dynamic> payload) {
    if (!payload.containsKey('branch_id')) return false;
    final branchId = payload['branch_id']?.toString();
    if (branchId == null || branchId.isEmpty) return true;
    return !_uuidRegex.hasMatch(branchId);
  }

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // 1. Get the current session
    final session = supabase.auth.currentSession;
    if (session == null) {
      // Not logged in
      return null;
    }

    // 2. Use the access token to authenticate with PowerSync
    final token = session.accessToken;

    // 3. Retrieve the PowerSync URL from environment
    const powerSyncUrl = String.fromEnvironment('POWERSYNC_URL');
    if (powerSyncUrl.isEmpty) {
      throw Exception('POWERSYNC_URL not found in environment');
    }

    // 4. Return credentials
    return PowerSyncCredentials(endpoint: powerSyncUrl, token: token);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (var op in transaction.crud) {
        final table = op.table;
        final id = op.id;
        final data = op.opData;

        if (_serverAuthoritativeTables.contains(table)) {
          _log.w(
            'Skipping direct upload for server-authoritative table "$table" (id=$id). Use Edge Functions for this write path.',
          );
          continue;
        }

        // Map PowerSync operations to Supabase (PostgREST)
        if (op.op == UpdateType.put) {
          // UPSERT (Insert or Update)
          final payload = <String, dynamic>{...data ?? {}, 'id': id};

          if (payload.containsKey('branch_id') &&
              payload['branch_id'] == 'all') {
            payload['branch_id'] = null;
          }

          if ((table == 'stock' || table == 'stock_adjustments') &&
              _hasInvalidBranchId(payload)) {
            _log.w(
              'Skipping invalid $table upload with non-UUID branch_id: ${payload['branch_id']}',
            );
            continue;
          }

          if (table == 'stock_adjustments') {
            payload['adjustment_type'] = _normalizeAdjustmentType(
              payload['adjustment_type'],
              payload['quantity'],
            );
            payload['created_by'] = _normalizeCreatedBy(payload['created_by']);
          }
          if (table == 'product_branches') {
            await supabase
                .from(table)
                .upsert(payload, onConflict: 'product_id,branch_id');
          } else if (table == 'profile_branches') {
            await supabase
                .from(table)
                .upsert(payload, onConflict: 'profile_id,branch_id');
          } else {
            await supabase.from(table).upsert(payload);
          }
        } else if (op.op == UpdateType.patch) {
          // UPDATE
          final payload = <String, dynamic>{...data!};

          if (payload.containsKey('branch_id') &&
              payload['branch_id'] == 'all') {
            payload['branch_id'] = null;
          }

          if ((table == 'stock' || table == 'stock_adjustments') &&
              _hasInvalidBranchId(payload)) {
            _log.w(
              'Skipping invalid $table patch with non-UUID branch_id: ${payload['branch_id']}',
            );
            continue;
          }

          if (table == 'stock_adjustments') {
            if (payload.containsKey('adjustment_type')) {
              payload['adjustment_type'] = _normalizeAdjustmentType(
                payload['adjustment_type'],
                payload['quantity'],
              );
            }
            if (payload.containsKey('created_by')) {
              payload['created_by'] = _normalizeCreatedBy(
                payload['created_by'],
              );
            }
          }
          await supabase.from(table).update(payload).eq('id', id);
        } else if (op.op == UpdateType.delete) {
          // DELETE
          await supabase.from(table).delete().eq('id', id);
        }
      }
      // Mark transaction as complete
      await transaction.complete();
    } catch (e) {
      // Revert/Retry later
      _log.e('Upload Error: $e');
      // For now, we don't complete the transaction so it retries
    }
  }
}

// 4. Initialization Function
Future<void> openPowerSyncDatabase() async {
  late String path;
  if (kIsWeb) {
    path = 'zynk_powersync.db';
  } else {
    final dir = await getApplicationDocumentsDirectory();
    path = join(dir.path, 'zynk_powersync.db');
  }

  // Open the database
  db = PowerSyncDatabase(schema: schema, path: path);
  await db.initialize();

  // Connect to backend
  final connector = SupabaseConnector(Supabase.instance.client);
  db.connect(connector: connector);
}
