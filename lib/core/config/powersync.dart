import 'package:powersync/powersync.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../services/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  // Item Groups
  const Table('item_groups', [
    Column.text('tenant_id'),
    Column.text('branch_id'),
    Column.text('name'),
    Column.text('description'),
    Column.text('default_commission_type'),
    Column.real('default_commission_value'),
    Column.text('created_at'),
    Column.text('updated_at'),
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
    Column.real('cost_price'), // Added
    Column.text('tax_category'),
    Column.integer('is_service'), // Boolean as Integer (0/1)
    Column.text('created_at'),
    Column.text('updated_at'),
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
    Column.text('salesperson'),
    Column.text('approved_by'),
    Column.real('total_amount'),
    Column.real('subtotal'),
    Column.real('tax_amount'),
    Column.real('discount_amount'),
    Column.real('grand_total'),
    Column.real('amount_paid'),
    Column.text('payment_method'),
    Column.text('status'),
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
]);

// 2. Global Database Instance
late final PowerSyncDatabase db;

// 3. Supabase Connector
class SupabaseConnector extends PowerSyncBackendConnector {
  final SupabaseClient supabase;

  SupabaseConnector(this.supabase);

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
    final powerSyncUrl = dotenv.env['POWERSYNC_URL'];
    if (powerSyncUrl == null) {
      throw Exception('POWERSYNC_URL not found in .env');
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

        // Map PowerSync operations to Supabase (PostgREST)
        if (op.op == UpdateType.put) {
          // UPSERT (Insert or Update)
          await supabase.from(table).upsert({...data ?? {}, 'id': id});
        } else if (op.op == UpdateType.patch) {
          // UPDATE
          await supabase.from(table).update(data!).eq('id', id);
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
