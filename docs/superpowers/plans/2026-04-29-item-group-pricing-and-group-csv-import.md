# Item Group Pricing + Group CSV Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tenant-wide item group defaults for selling/buying prices and fixed commission, allow per-item price overrides (null = inherit), and support group-based CSV imports that auto-create item groups.

**Architecture:** Store pricing defaults on item groups, keep per-item overrides nullable, and resolve effective prices at read time with a helper that uses the product’s group. CSV import is format-detected and branches to either the existing product import flow or the group-based flow.

**Tech Stack:** Flutter (Dart), Riverpod, PowerSync local schema, Supabase Postgres

---

### Task 1: Supabase schema + function updates (fixed commission, group defaults)

**Files:**
- Create: `supabase/migrations/20260429120000_item_group_defaults_and_fixed_commission.sql`

- [ ] **Step 1: Write migration SQL**

```sql
BEGIN;

ALTER TABLE public.item_groups
  ADD COLUMN IF NOT EXISTS default_selling_price numeric,
  ADD COLUMN IF NOT EXISTS default_buying_price numeric;

ALTER TABLE public.item_groups
  DROP COLUMN IF EXISTS default_commission_type;

ALTER TABLE public.products
  DROP COLUMN IF EXISTS commission_type;

ALTER TABLE public.products
  ALTER COLUMN base_price DROP DEFAULT;

CREATE OR REPLACE FUNCTION public.calculate_commission_on_sale()
RETURNS trigger AS $$
DECLARE
  v_item_group_id UUID;
  v_salesperson_id TEXT;
  v_commission_value DECIMAL;
  v_calculated_amount DECIMAL := 0;
  v_tenant_id UUID;
BEGIN
  SELECT item_group_id, tenant_id INTO v_item_group_id, v_tenant_id
  FROM public.products
  WHERE id = NEW.product_id;

  SELECT salesperson_id INTO v_salesperson_id
  FROM public.sales
  WHERE id = NEW.sale_id;

  IF v_item_group_id IS NOT NULL THEN
    SELECT default_commission_value
    INTO v_commission_value
    FROM public.item_groups
    WHERE id = v_item_group_id;

    IF v_commission_value IS NOT NULL AND v_salesperson_id IS NOT NULL THEN
      v_calculated_amount := v_commission_value * COALESCE(NEW.quantity, 0);

      IF v_calculated_amount > 0 AND v_salesperson_id ~* '^[0-9a-fA-F-]{36}$' THEN
        INSERT INTO public.commissions (tenant_id, salesperson_id, sale_id, amount, status)
        VALUES (v_tenant_id, v_salesperson_id::UUID, NEW.sale_id, v_calculated_amount, 'pending');
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;
```

- [ ] **Step 2: Apply migration using Supabase MCP**

Use `apply_migration` with the SQL above (no CLI).

- [ ] **Step 3: Verify columns**

Run:

```sql
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('item_groups', 'products', 'commissions')
order by table_name, ordinal_position;
```

Expected: `item_groups` has `default_selling_price`/`default_buying_price`, no `default_commission_type`; `products` has no `commission_type` and `base_price` default is NULL.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260429120000_item_group_defaults_and_fixed_commission.sql
git commit -m "feat(db): add item group price defaults and fixed commission"
```

---

### Task 2: Update local schema + models + repository

**Files:**
- Modify: `lib/core/models/schema_models.dart`
- Modify: `lib/core/models/schema_models.g.dart`
- Modify: `lib/core/config/powersync.dart`
- Modify: `lib/data/local/repository.dart`
- Modify: `lib/features/products/presentation/providers/product_providers.dart`

- [ ] **Step 1: Update `ItemGroup` + `Product` models**

```dart
@JsonSerializable(fieldRename: FieldRename.snake)
class ItemGroup {
  final String id;
  final String tenantId;
  final String? branchId;
  final String name;
  final String? description;
  final double? defaultSellingPrice;
  final double? defaultBuyingPrice;
  final double? defaultCommissionValue;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? updatedAt;

  ItemGroup({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.name,
    this.description,
    this.defaultSellingPrice,
    this.defaultBuyingPrice,
    this.defaultCommissionValue,
    this.createdAt,
    this.updatedAt,
  });
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Product {
  final String id;
  final String tenantId;
  final String? branchId;
  final String? itemGroupId;
  final String? categoryId;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final String? imageUrl;
  final double? basePrice; // nullable for group inheritance
  final double? costPrice;
  ...
}
```

- [ ] **Step 2: Update PowerSync schema for item_groups**

```dart
const Table('item_groups', [
  Column.text('tenant_id'),
  Column.text('branch_id'),
  Column.text('name'),
  Column.text('description'),
  Column.real('default_selling_price'),
  Column.real('default_buying_price'),
  Column.real('default_commission_value'),
  Column.text('created_at'),
  Column.text('updated_at'),
]);
```

- [ ] **Step 3: Update repository item group SQL**

```dart
await _db.execute(
  'INSERT INTO item_groups (id, tenant_id, branch_id, name, description, default_selling_price, default_buying_price, default_commission_value, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
  [
    group.id,
    group.tenantId,
    group.branchId,
    group.name,
    group.description,
    group.defaultSellingPrice,
    group.defaultBuyingPrice,
    group.defaultCommissionValue,
    DateTime.now().toIso8601String(),
    DateTime.now().toIso8601String(),
  ],
);

await _db.execute(
  'UPDATE item_groups SET name = ?, description = ?, default_selling_price = ?, default_buying_price = ?, default_commission_value = ?, updated_at = ? WHERE id = ?',
  [
    group.name,
    group.description,
    group.defaultSellingPrice,
    group.defaultBuyingPrice,
    group.defaultCommissionValue,
    DateTime.now().toIso8601String(),
    group.id,
  ],
);
```

- [ ] **Step 4: Replace `batchSetPriceForGroup` with group default update**

```dart
Future<void> batchSetPriceForGroup(String groupId, double newPrice) async {
  await _db.execute(
    'UPDATE item_groups SET default_selling_price = ?, updated_at = ? WHERE id = ?',
    [newPrice, DateTime.now().toIso8601String(), groupId],
  );
}
```

- [ ] **Step 5: Add an item group map provider**

```dart
final itemGroupMapProvider = Provider.autoDispose<Map<String, ItemGroup>>((ref) {
  final groups = ref.watch(allItemGroupsProvider).value ?? [];
  return {for (final g in groups) g.id: g};
});
```

- [ ] **Step 6: Regenerate JSON models**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `schema_models.g.dart` updates with new fields and nullable `base_price`.

---

### Task 3: Add price resolution helpers + unit tests

**Files:**
- Create: `lib/core/models/product_pricing.dart`
- Create: `test/core/models/product_pricing_test.dart`

- [ ] **Step 1: Add helper functions**

```dart
import 'package:zynk/core/models/schema_models.dart';

const _currencyPrefix = 'Ksh ';

String formatKes(double? value) {
  if (value == null) return '${_currencyPrefix}--';
  return '$_currencyPrefix${value.toStringAsFixed(0)}';
}

double? resolveSellingPrice(Product product, Map<String, ItemGroup> groups) {
  if (product.basePrice != null) return product.basePrice;
  final groupId = product.itemGroupId;
  if (groupId == null) return null;
  return groups[groupId]?.defaultSellingPrice;
}

double? resolveBuyingPrice(Product product, Map<String, ItemGroup> groups) {
  if (product.costPrice != null) return product.costPrice;
  final groupId = product.itemGroupId;
  if (groupId == null) return null;
  return groups[groupId]?.defaultBuyingPrice;
}
```

- [ ] **Step 2: Add tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/product_pricing.dart';

void main() {
  test('uses product price override when set', () {
    final product = Product(
      id: 'p1',
      tenantId: 't1',
      name: 'Widget',
      basePrice: 1200,
    );
    final price = resolveSellingPrice(product, {});
    expect(price, 1200);
  });

  test('falls back to group default when product price is null', () {
    final group = ItemGroup(
      id: 'g1',
      tenantId: 't1',
      name: 'Group',
      defaultSellingPrice: 500,
    );
    final product = Product(
      id: 'p1',
      tenantId: 't1',
      name: 'Widget',
      itemGroupId: 'g1',
      basePrice: null,
    );
    final price = resolveSellingPrice(product, {'g1': group});
    expect(price, 500);
  });

  test('returns null when no override or group default', () {
    final product = Product(
      id: 'p1',
      tenantId: 't1',
      name: 'Widget',
      basePrice: null,
    );
    final price = resolveSellingPrice(product, {});
    expect(price, isNull);
  });
}
```

- [ ] **Step 3: Run tests**

Run:

```bash
dart test test/core/models/product_pricing_test.dart
```

Expected: PASS

---

### Task 4: CSV import format detection + group import flow

**Files:**
- Modify: `lib/features/products/data/csv_import_service.dart`
- Modify: `lib/features/products/presentation/batch_upload_screen.dart`
- Create: `test/features/products/csv_import_parser_test.dart`

- [ ] **Step 1: Add format detection + parser helpers**

```dart
enum CsvImportFormat { standard, group }

CsvImportFormat detectFormat(List<String> headers) {
  final lower = headers.map((h) => h.toLowerCase().trim()).toSet();
  if (lower.containsAll({'name', 'category', 'selling_price', 'initial_stock'})) {
    return CsvImportFormat.standard;
  }
  if (lower.containsAll({
    'name',
    'item group',
    'stock',
    'group selling price',
    'group buying price',
    'group commission',
  })) {
    return CsvImportFormat.group;
  }
  throw Exception('CSV headers do not match a supported format.');
}
```

- [ ] **Step 2: Implement group CSV import in `importProducts`**

```dart
final groupsSnapshot = await repo.watchItemGroups().first;
final groupMapByName = {
  for (final g in groupsSnapshot) g.name.trim().toLowerCase(): g,
};

ItemGroup _ensureGroup(String name, double? selling, double? buying, double? commission) async {
  final key = name.trim().toLowerCase();
  final existing = groupMapByName[key];
  if (existing != null) return existing;

  final newGroup = ItemGroup(
    id: const Uuid().v4(),
    tenantId: tenantId,
    branchId: null,
    name: name.trim(),
    defaultSellingPrice: selling,
    defaultBuyingPrice: buying,
    defaultCommissionValue: commission,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  await repo.createItemGroup(newGroup);
  groupMapByName[key] = newGroup;
  return newGroup;
}
```

- [ ] **Step 3: Coerce stock values to int using `floor`**

```dart
int parseStock(dynamic raw) {
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty) return 0;
  final parsed = double.tryParse(text);
  if (parsed == null) return 0;
  return parsed.floor();
}
```

- [ ] **Step 4: Add tests for format detection**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/features/products/data/csv_import_service.dart';

void main() {
  test('detects standard format', () {
    final headers = ['name', 'category', 'selling_price', 'initial_stock'];
    expect(detectFormat(headers), CsvImportFormat.standard);
  });

  test('detects group format', () {
    final headers = [
      'name',
      'item group',
      'stock',
      'group selling price',
      'group buying price',
      'group commission',
    ];
    expect(detectFormat(headers), CsvImportFormat.group);
  });
}
```

- [ ] **Step 5: Update Batch Upload help text**

Add a second format description in `batch_upload_screen.dart`:

```dart
'Group CSV format headers (auto-creates item groups):\n'
'• name\n'
'• item group\n'
'• stock\n'
'• group selling price\n'
'• group buying price\n'
'• group commission\n\n'
'Optional override headers:\n'
'• selling_price\n'
'• cost_price'
```

---

### Task 5: Item group UI updates (create/edit/list)

**Files:**
- Modify: `lib/features/products/presentation/add_item_group_screen.dart`
- Modify: `lib/features/products/presentation/group_details_screen.dart`
- Modify: `lib/features/products/presentation/item_groups_screen.dart`
- Modify: `lib/features/products/presentation/add_product_screen.dart`

- [ ] **Step 1: Add default prices and fixed commission to group creation**

```dart
final _sellingPriceController = TextEditingController();
final _buyingPriceController = TextEditingController();
final _commissionController = TextEditingController();

final group = ItemGroup(
  id: const Uuid().v4(),
  tenantId: tenantId,
  branchId: branchId,
  name: _nameController.text.trim(),
  description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
  defaultSellingPrice: double.tryParse(_sellingPriceController.text),
  defaultBuyingPrice: double.tryParse(_buyingPriceController.text),
  defaultCommissionValue: double.tryParse(_commissionController.text),
);
```

- [ ] **Step 2: Update Group Details screen to remove type selector**

Replace commission type selector with a single fixed amount input and add default price inputs. Use the same `ItemGroup` fields shown above in `ItemGroup` update.

- [ ] **Step 3: Update batch price action in Item Groups list**

Change copy and action to update group default selling price instead of all products:

```dart
await repo.batchSetPriceForGroup(group.id, price);
```

Update UI text to: "Set default selling price for group".

---

### Task 6: Product create/edit (inheritance + overrides)

**Files:**
- Modify: `lib/features/products/presentation/add_product_screen.dart`
- Modify: `lib/features/products/presentation/providers/add_product_controller.dart`

- [ ] **Step 1: Add override toggle state**

```dart
bool _overrideGroupPrices = false;
```

- [ ] **Step 2: When group is selected, show inherited prices**

```dart
final groupMap = ref.watch(itemGroupMapProvider);
final selectedGroup = _selectedItemGroupId == null ? null : groupMap[_selectedItemGroupId];
final inheritedSelling = selectedGroup?.defaultSellingPrice;
final inheritedBuying = selectedGroup?.defaultBuyingPrice;
```

Render a small panel under the group selector:
- "Inherited Selling Price: Ksh X"
- "Inherited Buying Price: Ksh Y"
- Toggle: "Override group prices"

- [ ] **Step 3: Update price validation**

If no group is selected, keep selling price required. If a group is selected and override is OFF, skip validation and pass `null` for `price`/`costPrice`.

```dart
final hasGroup = _selectedItemGroupId != null;
final price = _overrideGroupPrices ? double.tryParse(_priceController.text) : null;
final costPrice = _overrideGroupPrices ? double.tryParse(_costPriceController.text) : null;
```

- [ ] **Step 4: Make `price` nullable in controller**

```dart
Future<void> saveProduct({
  ...
  required double? price,
  required double? costPrice,
  ...
})
```

Use `basePrice: price` directly; allow null for inheritance.

---

### Task 7: Update price display across POS and product views

**Files:**
- Modify: `lib/features/pos/presentation/components/pos_product_card.dart`
- Modify: `lib/features/pos/presentation/components/pos_ticket.dart`
- Modify: `lib/features/pos/domain/pos_cart_item.dart`
- Modify: `lib/features/pos/providers/cart_provider.dart`
- Modify: `lib/features/pos/presentation/pos_screen.dart`
- Modify: `lib/features/products/presentation/composite_items_screen.dart`
- Modify: `lib/features/products/presentation/composite_item_details_screen.dart`
- Modify: `lib/features/sales/presentation/create_invoice_screen.dart`

- [ ] **Step 1: Use price resolver in POS cards**

```dart
final groupMap = ref.watch(itemGroupMapProvider);
final price = resolveSellingPrice(product, groupMap);
Text(formatKes(price));
```

- [ ] **Step 2: Cart items use effective price**

```dart
class PosCartItem {
  ...
  double get effectivePrice => overridePrice ?? product.basePrice ?? 0;
}
```

- [ ] **Step 3: Pass effective price into cart**

```dart
void addItem(Product product, {int availableStock = 999, double? overridePrice}) {
  ...
  items.add(PosCartItem(product: product, overridePrice: overridePrice));
}
```

In `PosScreen._doAddToCart`:

```dart
final groupMap = ref.read(itemGroupMapProvider);
final effectivePrice = resolveSellingPrice(product, groupMap);
ref.read(cartProvider.notifier).addItem(product, overridePrice: effectivePrice);
```

- [ ] **Step 4: Replace `basePrice` display in composite item list**

In `composite_items_screen.dart`:

```dart
final groupMap = ref.watch(itemGroupMapProvider);
final price = resolveSellingPrice(product, groupMap);
Text(formatKes(price));
```

- [ ] **Step 5: Replace `basePrice` display in composite item detail**

In `composite_item_details_screen.dart`:

```dart
final groupMap = ref.watch(itemGroupMapProvider);
final price = resolveSellingPrice(_product!, groupMap);
final cost = resolveBuyingPrice(_product!, groupMap);
Text('Price: ${formatKes(price)}');
Text('Cost: ${formatKes(cost)}');
```

- [ ] **Step 6: POS ticket uses `item.effectivePrice`**

In `pos_ticket.dart`:

```dart
Text('Ksh ${item.effectivePrice.toStringAsFixed(0)} each');
```

- [ ] **Step 7: Invoice editor compares against effective price**

In `create_invoice_screen.dart`:

```dart
final effective = item.effectivePrice;
overridePrice: price != effective ? price : null,
```

---

### Task 8: Analysis + verification

**Files:**
- N/A

- [ ] **Step 1: Run tests**

```bash
dart test
```

- [ ] **Step 2: Run analyzer**

```bash
dart analyze
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib test

git commit -m "feat: add item group pricing defaults and group CSV import"
```

---

## Self-Review Checklist
- Spec coverage: all data model changes, CSV flow, UI updates, and pricing resolution are represented.
- Placeholder scan: no TODOs or vague steps.
- Type consistency: nullable `base_price` handled in model, UI, and DB.

## Execution Handoff
Plan complete and saved to `docs/superpowers/plans/2026-04-29-item-group-pricing-and-group-csv-import.md`.

Two execution options:
1. Subagent-Driven (recommended)
2. Inline Execution

Which approach?
