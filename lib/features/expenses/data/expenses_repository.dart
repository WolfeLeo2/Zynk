import 'package:powersync/powersync.dart';
import 'package:zynk/features/expenses/models/expense.dart';
import 'package:zynk/features/expenses/models/expense_category.dart';

class ExpensesRepository {
  final PowerSyncDatabase _db;

  ExpensesRepository(this._db);

  Stream<List<ExpenseCategory>> watchExpenseCategories(String tenantId) {
    return _db.watch(
      'SELECT * FROM expense_categories WHERE tenant_id = ? ORDER BY name ASC',
      parameters: [tenantId],
    ).map((rows) => rows.map((row) => ExpenseCategory.fromMap(row)).toList());
  }

  Stream<List<Expense>> watchExpenses({
    required String tenantId,
    String? branchId,
    DateTime? month,
  }) {
    String sql = 'SELECT * FROM expenses WHERE tenant_id = ?';
    final params = [tenantId];

    if (branchId != null && branchId != 'all') {
      sql += ' AND branch_id = ?';
      params.add(branchId);
    }

    if (month != null) {
      final startOfMonth = DateTime(month.year, month.month, 1).toIso8601String();
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59).toIso8601String();
      sql += ' AND expense_date >= ? AND expense_date <= ?';
      params.add(startOfMonth);
      params.add(endOfMonth);
    }

    sql += ' ORDER BY expense_date DESC';

    return _db.watch(sql, parameters: params).map((rows) => rows.map((row) => Expense.fromMap(row)).toList());
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
        expense.expenseDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
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
