import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/expenses/models/expense.dart';
import 'package:zynk/features/expenses/models/expense_category.dart';
import 'package:zynk/features/expenses/providers/expenses_provider.dart';
import 'package:zynk/core/models/staff_model.dart';
import 'package:zynk/core/models/schema_models.dart';

class LogExpenseSheet extends ConsumerStatefulWidget {
  const LogExpenseSheet({super.key});

  @override
  ConsumerState<LogExpenseSheet> createState() => _LogExpenseSheetState();
}

class _LogExpenseSheetState extends ConsumerState<LogExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  ExpenseCategory? _selectedCategory;
  StaffMember? _selectedStaff;
  Branch? _selectedBranch;
  String _paymentMethod = 'cash';
  final DateTime _expenseDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final staffAsync = ref.watch(humanStaffProvider);
    final branchesAsync = ref.watch(branchesProvider);
    final currentBranchId = ref.watch(currentBranchIdProvider);

    // Auto-select branch
    if (_selectedBranch == null) {
      branchesAsync.whenData((branches) {
        final selectable = branches.where((b) => b.id != 'all').toList();
        Branch? toSelect;
        if (selectable.length == 1) {
          toSelect = selectable.first;
        } else if (currentBranchId != 'all') {
          toSelect = selectable.where((b) => b.id == currentBranchId).firstOrNull;
        }
        if (toSelect != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedBranch == null) {
              setState(() => _selectedBranch = toSelect);
            }
          });
        }
      });
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsRegular.receipt, color: cs.primary),
                const SizedBox(width: 12),
                Text(
                  'Log Expense',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(PhosphorIconsRegular.x),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Amount Field
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: 'Ksh ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Required';
                if (double.tryParse(val) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Branch & Category Row
            Row(
              children: [
                Expanded(
                  child: branchesAsync.when(
                    data: (branches) {
                      final selectable = branches.where((b) => b.id != 'all').toList();
                      return DropdownButtonFormField<Branch>(
                        initialValue: _selectedBranch,
                        decoration: const InputDecoration(
                          labelText: 'Branch',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: selectable.map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedBranch = val),
                        validator: (val) => val == null ? 'Required' : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Error'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: categoriesAsync.when(
                    data: (categories) => DropdownButtonFormField<ExpenseCategory>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        ...categories.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        )),
                        const DropdownMenuItem(
                          value: null,
                          child: Text('+ Add New'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == null) {
                          _showAddCategoryDialog();
                        } else {
                          setState(() => _selectedCategory = val);
                        }
                      },
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Error'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Staff & Payment Method
            Row(
              children: [
                Expanded(
                  child: staffAsync.when(
                    data: (staff) => DropdownButtonFormField<StaffMember>(
                      initialValue: _selectedStaff,
                      decoration: const InputDecoration(
                        labelText: 'Logged By',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: staff.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      validator: (val) => val == null ? 'Please select who is logging this' : null,
                      onChanged: (val) => setState(() => _selectedStaff = val),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Error'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                    ],
                    onChanged: (val) => setState(() => _paymentMethod = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(PhosphorIconsRegular.check),
                label: const Text('Save Expense'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Rent, Utilities'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final repo = ref.read(expensesRepositoryProvider);
      final tenantId = ref.read(tenantIdProvider) ?? '';
      final newCat = ExpenseCategory(
        id: const Uuid().v4(),
        tenantId: tenantId,
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.insertCategory(newCat);
      setState(() => _selectedCategory = newCat);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(expensesRepositoryProvider);
    final tenantId = ref.read(tenantIdProvider) ?? '';
    
    final expense = Expense(
      id: const Uuid().v4(),
      tenantId: tenantId,
      branchId: _selectedBranch!.id,
      categoryId: _selectedCategory!.id,
      staffMemberId: _selectedStaff?.id,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      paymentMethod: _paymentMethod,
      expenseDate: _expenseDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await repo.insertExpense(expense);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense logged successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
