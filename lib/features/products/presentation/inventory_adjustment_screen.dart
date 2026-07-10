import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/features/products/domain/stock_adjustment_math.dart';
import 'package:zynk/features/products/presentation/widgets/adjustment_basket_view.dart';
import 'package:zynk/features/products/presentation/widgets/adjustment_catalog_list.dart';
import 'package:zynk/features/products/presentation/widgets/adjustment_config_bar.dart';
import 'package:zynk/features/products/providers/batch_stock_provider.dart';

/// POS-style stock-adjustment screen: the catalog (with live stock) is always
/// visible. On mobile a FAB opens a bottom sheet holding the configuration +
/// basket + confirm CTA; on desktop that same block sits in a right-hand pane.
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

  void _snack(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Applies the basket as pending stock adjustments. Returns true on success
  /// so callers can decide navigation (desktop stays put; the mobile sheet
  /// closes itself). Does NOT pop the screen — the catalog stays visible.
  Future<bool> _submitBatch() async {
    final items = ref.read(batchStockProvider);
    if (items.isEmpty) return false;

    if (_reasonId == null) {
      _snack('Please select a reason for this adjustment.');
      return false;
    }

    final profile = ref.read(currentProfileProvider);
    if (profile == null) return false;

    if (ref.read(currentBranchIdProvider) == null) {
      _snack('Please select a branch first.');
      return false;
    }

    final allBranchesMode = _selectedBranchIds.length > 1;
    // In 'set' mode every row has an absolute target (0 is valid); otherwise
    // skip rows the user left at zero.
    final enteredItems = items
        .where((item) => item.quantityChange != 0 || _mode == 'set')
        .toList();
    if (enteredItems.isEmpty) {
      _snack('Please enter a quantity for at least one item.');
      return false;
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
        _snack(
          allBranchesMode
              ? 'Submitted $adjustedCount item(s) across all branches for review.'
              : 'Submitted $adjustedCount item(s) for review!',
          error: false,
        );
      }
      return true;
    } catch (e) {
      if (mounted) _snack('Error: $e');
      return false;
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

  AdjustmentConfigBar _configBar() {
    return AdjustmentConfigBar(
      selectedBranchIds: _selectedBranchIds,
      mode: _mode,
      reasonId: _reasonId,
      referenceController: _referenceController,
      onBranchToggle: _toggleBranch,
      onModeChanged: (m) => setState(() => _mode = m),
      onReasonChanged: (r) => setState(() => _reasonId = r),
    );
  }

  /// The configuration + basket + confirm CTA. Used as the desktop right pane
  /// and as the "Basket" tab on mobile. Config changes call setState, which
  /// rebuilds this pane in place (no overlay), so no extra plumbing is needed.
  Widget _buildBasketPane(ColorScheme cs, int count, bool allBranches) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              if (count > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () =>
                              ref.read(batchStockProvider.notifier).clear(),
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.trash,
                      size: 16,
                    ),
                    label: const Text('Clear all'),
                    style: TextButton.styleFrom(foregroundColor: cs.error),
                  ),
                ),
              _configBar(),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),
              AdjustmentBasketView(
                selectedBranchIds: _selectedBranchIds,
                mode: _mode,
                shrinkWrap: true,
              ),
            ],
          ),
        ),
        _buildConfirmBar(cs, count, allBranches),
      ],
    );
  }

  AppBar _appBar(BuildContext context, {PreferredSizeWidget? bottom}) {
    return AppBar(
      leading: Builder(
        builder: (context) => MediaQuery.of(context).size.width < 840
            ? IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.list),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : const SizedBox.shrink(),
      ),
      title: const Text('Stock Adjustments'),
      bottom: bottom,
    );
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

    final catalog = AdjustmentCatalogList(
      selectedBranchIds: _selectedBranchIds,
    );
    final basketPane = _buildBasketPane(
      colorScheme,
      batchItems.length,
      allBranchesMode,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide screens: catalog + basket side by side (both always visible).
        if (constraints.maxWidth > 800) {
          return Scaffold(
            drawer: const AppDrawer(),
            appBar: _appBar(context),
            body: Row(
              children: [
                Expanded(flex: 5, child: catalog),
                const VerticalDivider(width: 1),
                Expanded(flex: 5, child: basketPane),
              ],
            ),
          );
        }

        // Mobile: two tabs — Catalog and Basket (with a live item-count badge).
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            drawer: const AppDrawer(),
            appBar: _appBar(
              context,
              bottom: TabBar(
                tabs: [
                  const Tab(
                    icon: PhosphorIcon(PhosphorIconsRegular.squaresFour),
                    text: 'Catalog',
                  ),
                  Tab(
                    icon: Badge(
                      label: Text('${batchItems.length}'),
                      isLabelVisible: batchItems.isNotEmpty,
                      child: const PhosphorIcon(PhosphorIconsRegular.stack),
                    ),
                    text: 'Basket',
                  ),
                ],
              ),
            ),
            body: TabBarView(children: [catalog, basketPane]),
          ),
        );
      },
    );
  }

  /// The confirm CTA for the desktop pane (the mobile sheet has its own footer).
  Widget _buildConfirmBar(ColorScheme colorScheme, int count, bool allBranches) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: count == 0 || _isLoading ? null : () => _submitBatch(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            count > 0 ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : const PhosphorIcon(PhosphorIconsBold.checkCircle, size: 18),
                label: Text(
                  _isLoading ? 'Processing...' : _confirmLabel(count, allBranches),
                ),
              ),
            ),
          ],
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
