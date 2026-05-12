import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zynk/core/config/powersync.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/expenses/data/expenses_repository.dart';
import 'package:zynk/features/expenses/models/expense.dart';
import 'package:zynk/features/expenses/models/expense_category.dart';

part 'expenses_provider.g.dart';

@riverpod
ExpensesRepository expensesRepository(ExpensesRepositoryRef ref) {
  return ExpensesRepository(db);
}

@riverpod
Stream<List<ExpenseCategory>> expenseCategories(ExpenseCategoriesRef ref) {
  final repo = ref.watch(expensesRepositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId == null) return const Stream.empty();
  return repo.watchExpenseCategories(tenantId);
}

@riverpod
Stream<List<Expense>> expensesList(ExpensesListRef ref, {DateTime? month}) {
  final repo = ref.watch(expensesRepositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  
  if (tenantId == null) {
    return const Stream.empty();
  }
  
  return repo.watchExpenses(
    tenantId: tenantId,
    branchId: branchId,
    month: month,
  );
}
