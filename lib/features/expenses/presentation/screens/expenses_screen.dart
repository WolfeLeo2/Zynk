import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:zynk/features/expenses/providers/expenses_provider.dart';
import 'package:zynk/features/expenses/presentation/widgets/log_expense_sheet.dart';
import 'package:zynk/shared/widgets/shimmer_skeletons.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final expensesAsync = ref.watch(expensesListProvider());
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Implement Month Picker
            },
            icon: const PhosphorIcon(PhosphorIconsRegular.calendar),
          ),
        ],
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(PhosphorIconsRegular.receipt, size: 64, color: cs.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses logged yet',
                    style: theme.textTheme.titleMedium?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              final category = categoriesAsync.whenOrNull(
                data: (cats) => cats.where((c) => c.id == expense.categoryId).firstOrNull,
              );

              return RepaintBoundary(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: PhosphorIcon(PhosphorIconsRegular.receipt, color: cs.primary, size: 24),
                    ),
                    title: Text(
                      category?.name ?? 'Uncategorized',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (expense.description != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              expense.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            PhosphorIcon(PhosphorIconsRegular.clock, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd, yyyy • HH:mm').format(
                                expense.expenseDate ?? expense.createdAt ?? DateTime.now(),
                              ),
                              style: theme.textTheme.bodySmall
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            PhosphorIcon(PhosphorIconsRegular.houseLine, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              expense.branchName ?? 'Branch',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            PhosphorIcon(PhosphorIconsRegular.user, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              expense.staffName ?? 'Staff',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Text(
                      'Ksh ${expense.amount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const ListSkeleton(),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogExpense(context),
        label: const Text('Log Expense'),
        icon: const PhosphorIcon(PhosphorIconsRegular.plus),
      ),
    );
  }

  void _showLogExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: const LogExpenseSheet(),
      ),
    );
  }
}
