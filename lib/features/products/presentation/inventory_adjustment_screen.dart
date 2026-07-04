import 'package:button_group_m3e/button_group_m3e.dart';
import 'package:button_m3e/button_m3e.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/features/products/domain/stock_adjustment_math.dart';
import 'package:zynk/features/products/providers/batch_stock_provider.dart';
import 'package:zynk/features/products/presentation/widgets/adjustment_basket_view.dart';
import 'package:zynk/features/products/presentation/widgets/adjustment_catalog_list.dart';
import 'package:zynk/features/products/presentation/widgets/adjustment_config_bar.dart';

/// Two-zone stock-adjustment screen. Desktop shows catalog + basket side by
/// side; mobile shows a persistent config bar + a Catalog/Basket toggle, with
/// the mode-aware confirm CTA always pinned to the bottom on both.
class InventoryAdjustmentScreen extends ConsumerStatefulWidget {
  const InventoryAdjustmentScreen({super.key});

  @override
  ConsumerState<InventoryAdjustmentScreen> createState() =>
      _InventoryAdjustmentScreenState();
}

class _InventoryAdjustmentScreenState
    extends ConsumerState<InventoryAdjustmentScreen> {
  final TextEditingController _referenceController = TextEditingController();
  bool _isLoading = false;
  Set<String> _selectedBranchIds = {};
  bool _initializedBranches = false;
  String? _reasonId;
  String _mode = 'add'; // 'add' | 'subtract' | 'set'
  String _view = 'catalog'; // mobile only: 'catalog' | 'basket'

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  /// Seed the branch selection once branches load: a locked user gets their
  /// single branch; "all" fans out to every branch; otherwise the active one.
  void _maybeInitBranches(List<Branch> branches, String? selectedBranchId) {
    if (_initializedBranches || branches.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final branchState = ref.read(branchSelectionProvider);
      setState(() {
        if (branchState.isLocked && branchState.selectedBranchId != null) {
          _selectedBranchIds = {branchState.selectedBranchId!};
        } else if (selectedBranchId == 'all') {
          _selectedBranchIds = branches.map((b) => b.id).toSet();
        } else if (selectedBranchId != null) {
          _selectedBranchIds = {selectedBranchId};
        }
        _initializedBranches = true;
      });
    });
  }

  void _toggleBranch(String branchId, bool selected) {
    setState(() {
      if (selected) {
        _selectedBranchIds.add(branchId);
      } else if (_selectedBranchIds.length > 1) {
        _selectedBranchIds.remove(branchId); // never drop the last branch
      }
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitBatch() async {
    final items = ref.read(batchStockProvider);
    if (items.isEmpty) return;

    if (_reasonId == null) {
      _snack('Please select a reason for this adjustment.');
      return;
    }

    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    if (ref.read(currentBranchIdProvider) == null) {
      _snack('Please select a branch first.');
      return;
    }

    final allBranchesMode = _selectedBranchIds.length > 1;
    // In 'set' mode every row has an absolute target (0 is valid); otherwise
    // skip rows the user left at zero.
    final enteredItems = items
        .where((item) => item.quantityChange != 0 || _mode == 'set')
        .toList();
    if (enteredItems.isEmpty) {
      _snack('Please enter a quantity for at least one item.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final referenceNumber = _referenceController.text.isNotEmpty
          ? _referenceController.text
          : null;

      final branchIds = allBranchesMode
          ? (ref.read(branchesProvider).value ??
                    await repo.getBranches(profile.tenantId))
                .where((b) => _selectedBranchIds.contains(b.id))
                .map((b) => b.id)
                .toList()
          : _selectedBranchIds.toList();

      if (branchIds.isEmpty) {
        throw Exception('No branches found to apply stock changes.');
      }

      int adjustedCount = 0;
      for (final branchId in branchIds) {
        // 'set' target → delta depends on each branch's own current stock, so
        // resolve per branch (one batched read); add/subtract deltas don't.
        final currentById = _mode == 'set'
            ? await repo.getProductStockValues(
                enteredItems.map((i) => i.product.id).toList(),
                branchId,
              )
            : const <String, num>{};

        final adjustmentItems = <BatchAdjustmentItem>[];
        for (final item in enteredItems) {
          final quantityChange = resolveStockDelta(
            _mode,
            currentById[item.product.id] ?? 0,
            item.quantityChange,
          );
          if (quantityChange != 0) {
            adjustmentItems.add(
              BatchAdjustmentItem(
                productId: item.product.id,
                quantityChange: quantityChange,
                notes: item.notes,
              ),
            );
          }
        }
        if (adjustmentItems.isEmpty) continue;
        adjustedCount = adjustmentItems.length;

        await repo.batchAdjustStock(
          tenantId: profile.tenantId,
          branchId: branchId,
          items: adjustmentItems,
          createdBy: profile.userId,
          salespersonId: profile.id,
          adjustmentType: 'auto',
          reasonId: _reasonId,
          referenceNumber: referenceNumber,
        );
      }

      if (mounted) {
        ref.read(batchStockProvider.notifier).clear();
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allBranchesMode
                  ? 'Updated stock for $adjustedCount item(s) across all branches.'
                  : 'Adjustment confirmed for $adjustedCount item(s)!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// CTA text that reflects the current mode (Add/Remove/Set) instead of
  /// always saying "Add", and notes when it fans out to every branch.
  String _confirmLabel(int count, bool allBranches) {
    final verb = switch (_mode) {
      'subtract' => 'Remove',
      'set' => 'Set',
      _ => 'Add',
    };
    final items = '$count item${count == 1 ? '' : 's'}';
    return allBranches
        ? '$verb · all branches ($items)'
        : '$verb stock ($items)';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final batchItems = ref.watch(batchStockProvider);
    final selectedBranchId = ref.watch(currentBranchIdProvider);
    final allBranchesMode = _selectedBranchIds.length > 1;

    if (selectedBranchId == null) {
      return Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(title: const Text('Adjustments')),
        body: _buildInvalidBranchState(context, colorScheme),
      );
    }

    ref
        .watch(branchesProvider)
        .whenData(
          (branches) => _maybeInitBranches(
            branches.where((b) => b.id != 'all').toList(),
            selectedBranchId,
          ),
        );

    final configBar = AdjustmentConfigBar(
      selectedBranchIds: _selectedBranchIds,
      mode: _mode,
      reasonId: _reasonId,
      referenceController: _referenceController,
      onBranchToggle: _toggleBranch,
      onModeChanged: (m) => setState(() => _mode = m),
      onReasonChanged: (r) => setState(() => _reasonId = r),
    );
    final basket = AdjustmentBasketView(
      selectedBranchIds: _selectedBranchIds,
      mode: _mode,
    );

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => MediaQuery.of(context).size.width < 840
              ? IconButton(
                  icon: const PhosphorIcon(PhosphorIconsRegular.list),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                )
              : const SizedBox.shrink(),
        ),
        title: const Text('Adjustments'),
        actions: [
          if (batchItems.isNotEmpty)
            TextButton.icon(
              onPressed: () => ref.read(batchStockProvider.notifier).clear(),
              icon: const PhosphorIcon(PhosphorIconsRegular.trash),
              label: const Text('Clear All'),
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                const Expanded(flex: 4, child: AdjustmentCatalogList()),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: configBar,
                      ),
                      Expanded(child: basket),
                      _buildFooter(
                        colorScheme,
                        batchItems.length,
                        allBranchesMode,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: configBar,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildViewToggle(batchItems.length),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _view == 'catalog'
                    ? const AdjustmentCatalogList()
                    : basket,
              ),
              _buildFooter(colorScheme, batchItems.length, allBranchesMode),
            ],
          );
        },
      ),
    );
  }

  Widget _buildViewToggle(int count) {
    return ButtonGroupM3E(
      selection: true,
      overflow: ButtonGroupM3EOverflow.none,
      type: ButtonGroupM3EType.connected,
      style: ButtonM3EStyle.filled,
      size: ButtonGroupM3ESize.sm,
      shape: ButtonGroupM3EShape.round,
      selectedIndex: _view == 'catalog' ? 0 : 1,
      actions: [
        ButtonGroupM3EAction(
          label: const Text('Catalog'),
          icon: const PhosphorIcon(PhosphorIconsRegular.squaresFour, size: 18),
          style: _view == 'catalog' ? ButtonM3EStyle.tonal : null,
          onPressed: () => setState(() => _view = 'catalog'),
        ),
        ButtonGroupM3EAction(
          label: Text('Basket · $count'),
          icon: const PhosphorIcon(PhosphorIconsRegular.stack, size: 18),
          style: _view == 'basket' ? ButtonM3EStyle.tonal : null,
          onPressed: () => setState(() => _view = 'basket'),
        ),
      ],
    );
  }

  Widget _buildFooter(ColorScheme colorScheme, int count, bool allBranches) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: count == 0 || _isLoading ? null : _submitBatch,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const PhosphorIcon(PhosphorIconsRegular.checkCircle),
          label: Text(
            _isLoading ? 'Processing...' : _confirmLabel(count, allBranches),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidBranchState(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIconsRegular.storefront,
              size: 64,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 24),
            Text(
              'Branch Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please select a branch from the app bar drop-down before proceeding.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.pop(),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onErrorContainer,
                foregroundColor: colorScheme.errorContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
