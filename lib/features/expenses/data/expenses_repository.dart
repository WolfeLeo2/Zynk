import 'package:powersync/powersync.dart';
import 'package:zynk/features/expenses/models/expense.dart';
import 'package:zynk/features/expenses/models/expense_category.dart';

class ExpensesRepository {
  final PowerSyncDatabase _db;

  ExpensesRepository(this._db);

  Stream<List<ExpenseCategory>> watchExpenseCategories(String tenantId) {
    return _db
        .watch(
          'SELECT * FROM expense_categories WHERE tenant_id = ? ORDER BY name ASC',
          parameters: [tenantId],
        )
        .map(
          (rows) => rows.map((row) => ExpenseCategory.fromMap(row)).toList(),
        );
  }

  Stream<List<Expense>> watchExpenses({
    required String tenantId,
    String? branchId,
    DateTime? month,
  }) {
    String sql = '''
      SELECT
        e.*,
        b.name as branch_name,
        COALESCE(s.name, sp.display_name) as staff_name,
        ec.name as category_name
      FROM expenses e
      LEFT JOIN branches b ON e.branch_id = b.id
      LEFT JOIN staff_members s ON e.staff_member_id = s.id
      LEFT JOIN profiles sp ON sp.id = e.staff_member_id
      LEFT JOIN expense_categories ec ON e.category_id = ec.id
      WHERE e.tenant_id = ?
    ''';
    final params = [tenantId];

    if (branchId != null && branchId != 'all') {
      sql += ' AND e.branch_id = ?';
      params.add(branchId);
    }

    if (month != null) {
      final startOfMonth = DateTime(
        month.year,
        month.month,
        1,
      ).toIso8601String();
      final endOfMonth = DateTime(
        month.year,
        month.month + 1,
        0,
        23,
        59,
        59,
      ).toIso8601String();
      sql += ' AND e.expense_date >= ? AND e.expense_date <= ?';
      params.add(startOfMonth);
      params.add(endOfMonth);
    }

    sql += ' ORDER BY e.expense_date DESC';

    return _db
        .watch(sql, parameters: params)
        .map((rows) => rows.map((row) => Expense.fromMap(row)).toList());
  }

  Future<void> insertExpense(Expense expense) async {
    await _db.execute(
      '''INSERT INTO expenses (
        id, tenant_id, branch_id, category_id, staff_member_id, amount, description, payment_method, expense_date, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        expense.id,
        expense.tenantId,
        expense.branchId,
        expense.categoryId,
        expense.staffMemberId,
        expense.amount,
        expense.description,
        expense.paymentMethod,
        expense.expenseDate?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> insertCategory(ExpenseCategory category) async {
    await _db.execute(
      'INSERT INTO expense_categories (id, tenant_id, name, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      [
        category.id,
        category.tenantId,
        category.name,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }
}
