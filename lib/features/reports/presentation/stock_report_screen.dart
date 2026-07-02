import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

class _StockReportBranchNotifier extends Notifier<String?> {
  @override
  String? build() => null; // null = fall back to global branch

  void select(String id) => state = id;
}

final _stockReportBranchProvider =
    NotifierProvider.autoDispose<_StockReportBranchNotifier, String?>(
      _StockReportBranchNotifier.new,
    );

enum _StockSort {
  nameAsc('Name (A-Z)'),
  nameDesc('Name (Z-A)'),
  availableAsc('Available (Low-High)'),
  availableDesc('Available (High-Low)');

  final String label;
  const _StockSort(this.label);
}

class _StockReportFilters {
  final bool inStockOnly;
  final bool lowStockOnly;
  final String? itemGroupId;
  final String search;
  final _StockSort sort;

  const _StockReportFilters({
    this.inStockOnly = false,
    this.lowStockOnly = false,
    this.itemGroupId,
    this.search = '',
    this.sort = _StockSort.nameAsc,
  });

  _StockReportFilters copyWith({
    bool? inStockOnly,
    bool? lowStockOnly,
    String? itemGroupId,
    bool clearItemGroupId = false,
    String? search,
    _StockSort? sort,
  }) {
    return _StockReportFilters(
      inStockOnly: inStockOnly ?? this.inStockOnly,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      itemGroupId: clearItemGroupId ? null : (itemGroupId ?? this.itemGroupId),
      search: search ?? this.search,
      sort: sort ?? this.sort,
    );
  }
}

class _StockReportFiltersNotifier extends Notifier<_StockReportFilters> {
  @override
  _StockReportFilters build() => const _StockReportFilters();

  void toggleInStock() =>
      state = state.copyWith(inStockOnly: !state.inStockOnly);

  void toggleLowStock() =>
      state = state.copyWith(lowStockOnly: !state.lowStockOnly);

  void selectItemGroup(String? id) => state = id == null
      ? state.copyWith(clearItemGroupId: true)
      : state.copyWith(itemGroupId: id);

  void setSearch(String value) => state = state.copyWith(search: value);

  void setSort(_StockSort sort) => state = state.copyWith(sort: sort);
}

final _stockReportFiltersProvider =
    NotifierProvider.autoDispose<
      _StockReportFiltersNotifier,
      _StockReportFilters
    >(_StockReportFiltersNotifier.new);

final _stockReportDataProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      final globalBranch = ref.watch(currentBranchIdProvider);
      final localBranch = ref.watch(_stockReportBranchProvider);

      // Always resolve to a concrete branch — never send null into the repo
      final branchId = localBranch ?? globalBranch;

      if (tenantId == null || branchId == null || branchId == 'all') {
        return Stream.value([]);
      }

      return ref
          .watch(repositoryProvider)
          .watchStockReport(tenantId: tenantId, branchId: branchId);
    });

/// Applies the current [_StockReportFilters] to the raw report rows, in a
/// single pass so the table, PDF export, and "showing N of M" count always
/// agree on what "filtered" means.
List<Map<String, dynamic>> _applyFilters(
  List<Map<String, dynamic>> rows,
  _StockReportFilters filters,
) {
  var result = rows.where((r) {
    final available = (r['available'] as num?)?.toInt() ?? 0;
    final reorderLevel = (r['reorder_level'] as num?)?.toInt();

    if (filters.inStockOnly && available <= 0) return false;
    if (filters.lowStockOnly &&
        !(reorderLevel != null &&
            reorderLevel > 0 &&
            available <= reorderLevel)) {
      return false;
    }
    if (filters.itemGroupId != null &&
        r['item_group_id'] != filters.itemGroupId) {
      return false;
    }
    if (filters.search.isNotEmpty) {
      final query = filters.search.toLowerCase();
      final name = (r['product_name'] as String? ?? '').toLowerCase();
      final sku = (r['sku'] as String? ?? '').toLowerCase();
      if (!name.contains(query) && !sku.contains(query)) return false;
    }
    return true;
  }).toList();

  int available(Map<String, dynamic> r) =>
      (r['available'] as num?)?.toInt() ?? 0;
  String name(Map<String, dynamic> r) => (r['product_name'] as String? ?? '');

  switch (filters.sort) {
    case _StockSort.nameAsc:
      result.sort((a, b) => name(a).compareTo(name(b)));
    case _StockSort.nameDesc:
      result.sort((a, b) => name(b).compareTo(name(a)));
    case _StockSort.availableAsc:
      result.sort((a, b) => available(a).compareTo(available(b)));
    case _StockSort.availableDesc:
      result.sort((a, b) => available(b).compareTo(available(a)));
  }

  return result;
}

/// True when a row is at/under its reorder level (and a reorder level is set).
bool _isLowStock(Map<String, dynamic> row) {
  final available = (row['available'] as num?)?.toInt() ?? 0;
  final reorderLevel = (row['reorder_level'] as num?)?.toInt();
  return reorderLevel != null && reorderLevel > 0 && available <= reorderLevel;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class StockReportScreen extends ConsumerWidget {
  const StockReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_stockReportDataProvider);
    final branchesAsync = ref.watch(branchesProvider);
    final itemGroupsAsync = ref.watch(allItemGroupsProvider);
    final filters = ref.watch(_stockReportFiltersProvider);
    final selectedBranchId =
        ref.watch(_stockReportBranchProvider) ??
        ref.watch(currentBranchIdProvider);

    // Resolve selected branch name for the PDF header
    final selectedBranchName =
        branchesAsync.value
            ?.firstWhere(
              (b) => b.id == selectedBranchId,
              orElse: () =>
                  Branch(id: '', tenantId: '', name: 'Unknown Branch'),
            )
            .name ??
        'Branch';

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            if (MediaQuery.of(context).size.width < 840) {
              return IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.list),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        title: const Text('Stock Report'),
        actions: [
          PopupMenuButton<_StockSort>(
            icon: const PhosphorIcon(PhosphorIconsRegular.sortAscending),
            tooltip: 'Sort',
            initialValue: filters.sort,
            onSelected: (v) =>
                ref.read(_stockReportFiltersProvider.notifier).setSort(v),
            itemBuilder: (context) => _StockSort.values
                .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                .toList(),
          ),
          dataAsync.maybeWhen(
            data: (rows) {
              final filtered = _applyFilters(rows, filters);
              return filtered.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.filePdf),
                      tooltip: 'Export PDF',
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        _exportPdf(filtered, selectedBranchName, messenger);
                      },
                    );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(
              height: 148,
              child: _FilterPanel(
                filters: filters,
                branchesAsync: branchesAsync,
                itemGroupsAsync: itemGroupsAsync,
                selectedBranchId: selectedBranchId,
                totalCount: dataAsync.value?.length ?? 0,
                filteredCount: dataAsync.maybeWhen(
                  data: (rows) => _applyFilters(rows, filters).length,
                  orElse: () => 0,
                ),
              ),
            ),
          ),
          dataAsync.when(
            loading: () =>
                const SliverToBoxAdapter(child: _StockTableShimmer()),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Failed to load report: $e')),
            ),
            data: (rows) {
              final filtered = _applyFilters(rows, filters);
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(filtered: rows.isNotEmpty),
                );
              }
              return SliverToBoxAdapter(child: _StockDataTable(rows: filtered));
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter panel (pinned header)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _FilterHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}

class _FilterPanel extends ConsumerWidget {
  final _StockReportFilters filters;
  final AsyncValue<List<Branch>> branchesAsync;
  final AsyncValue<List<ItemGroup>> itemGroupsAsync;
  final String? selectedBranchId;
  final int totalCount;
  final int filteredCount;

  const _FilterPanel({
    required this.filters,
    required this.branchesAsync,
    required this.itemGroupsAsync,
    required this.selectedBranchId,
    required this.totalCount,
    required this.filteredCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            onChanged: (v) =>
                ref.read(_stockReportFiltersProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by name or SKU',
              prefixIcon: const PhosphorIcon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Branch + item group + toggle chips, all in one scrollable row.
          SizedBox(
            height: 36,
            child: branchesAsync.when(
              loading: () => const _ChipRowShimmer(),
              error: (_, _) => const SizedBox.shrink(),
              data: (branches) {
                final realBranches = branches
                    .where((b) => b.id != 'all')
                    .toList();
                final itemGroups = itemGroupsAsync.value ?? const [];

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...realBranches.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(b.name),
                            selected: selectedBranchId == b.id,
                            showCheckmark: false,
                            onSelected: (_) => ref
                                .read(_stockReportBranchProvider.notifier)
                                .select(b.id),
                          ),
                        ),
                      ),
                      if (itemGroups.isNotEmpty) ...[
                        const VerticalDivider(width: 16),
                        ...itemGroups.map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(g.name),
                              selected: filters.itemGroupId == g.id,
                              showCheckmark: false,
                              onSelected: (selected) => ref
                                  .read(_stockReportFiltersProvider.notifier)
                                  .selectItemGroup(selected ? g.id : null),
                            ),
                          ),
                        ),
                      ],
                      const VerticalDivider(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('In Stock'),
                          selected: filters.inStockOnly,
                          onSelected: (_) => ref
                              .read(_stockReportFiltersProvider.notifier)
                              .toggleInStock(),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Low Stock'),
                        selected: filters.lowStockOnly,
                        onSelected: (_) => ref
                            .read(_stockReportFiltersProvider.notifier)
                            .toggleLowStock(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalCount == filteredCount
                ? '$totalCount item${totalCount == 1 ? '' : 's'}'
                : 'Showing $filteredCount of $totalCount items',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF Export
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _exportPdf(
  List<Map<String, dynamic>> rows,
  String branchName,
  ScaffoldMessengerState messenger,
) async {
  try {
    final pdf = pw.Document();
    final generated = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Stock Report for $branchName',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated: $generated',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Received', 'Sold', 'Available'],
            data: rows
                .map(
                  (r) => [
                    r['product_name'] ?? '',
                    '${r['received'] ?? 0}',
                    '${r['sold'] ?? 0}',
                    '${r['available'] ?? 0}',
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
          ),
        ],
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );

    final safeName = branchName.replaceAll(RegExp(r'[^\w]'), '_');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final bytes = await pdf.save();

    final path = await FilePicker.saveFile(
      dialogTitle: 'Save Report',
      fileName: 'stock_report_${safeName}_$ts.pdf',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (path != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report saved successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Table
// ─────────────────────────────────────────────────────────────────────────────

class _StockDataTable extends StatelessWidget {
  const _StockDataTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: RepaintBoundary(
          child: DataTable(
            columnSpacing: 24,
            headingRowColor: WidgetStatePropertyAll(
              colorScheme.surfaceContainerHighest,
            ),

            columns: [
              DataColumn(
                label: Text(
                  'Item',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                numeric: true,
                label: Text(
                  'Received',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                numeric: true,
                label: Text(
                  'Sold',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                numeric: true,
                label: Text(
                  'Available',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            rows: rows.map((r) {
              final available = (r['available'] as num?)?.toInt() ?? 0;
              final isLow = _isLowStock(r) || available <= 0;
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      (r['product_name'] as String?) ?? '—',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  DataCell(
                    Text(
                      '${(r['received'] as num?)?.toInt() ?? 0}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${(r['sold'] as num?)?.toInt() ?? 0}',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  DataCell(
                    Text(
                      '$available',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isLow
                            ? colorScheme.error
                            : colorScheme.onSurface,
                        fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer Skeletons
// ─────────────────────────────────────────────────────────────────────────────

class _ChipRowShimmer extends StatelessWidget {
  const _ChipRowShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surface,
      child: Row(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              width: 80,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StockTableShimmer extends StatelessWidget {
  const _StockTableShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
        child: Column(
          children: [
            // Header row
            Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Data rows
            ...List.generate(
              8,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Container(
                  height: 52,
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  /// True when the branch has stock data but the active filters hid all of it
  /// (so the message should point at the filters, not the branch picker).
  final bool filtered;

  const _EmptyState({this.filtered = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.package,
            size: 72,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            filtered
                ? 'No items match the current filters'
                : 'No stock data for this branch',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Try adjusting the filters above'
                : 'Try selecting a different branch above',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
