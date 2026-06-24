import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/widgets/app_drawer.dart';

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

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class StockReportScreen extends ConsumerWidget {
  const StockReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_stockReportDataProvider);
    final branchesAsync = ref.watch(branchesProvider);
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            leading: Builder(
              builder: (context) => IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: const Text('Stock Report'),
            actions: [
              dataAsync.maybeWhen(
                data: (rows) => rows.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const PhosphorIcon(PhosphorIconsRegular.filePdf),
                        tooltip: 'Export PDF',
                        onPressed: () {
                          final messenger = ScaffoldMessenger.of(context);
                          _exportPdf(rows, selectedBranchName, messenger);
                        },
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All-time stock movement per branch',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Branch selector (radio-style — one at a time)
                  branchesAsync.when(
                    loading: () => const _BranchChipShimmer(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (branches) {
                      final realBranches = branches
                          .where((b) => b.id != 'all')
                          .toList();
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: realBranches
                              .map(
                                (b) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(b.name),
                                    selected: selectedBranchId == b.id,
                                    showCheckmark: false,
                                    onSelected: (_) => ref
                                        .read(
                                          _stockReportBranchProvider.notifier,
                                        )
                                        .select(b.id),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Table area
          dataAsync.when(
            loading: () =>
                const SliverToBoxAdapter(child: _StockTableShimmer()),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Failed to load report: $e')),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const SliverFillRemaining(child: _EmptyState());
              }
              return SliverToBoxAdapter(child: _StockDataTable(rows: rows));
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
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

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Stock Report',
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
            border: TableBorder.all(
              color: colorScheme.outlineVariant,
              width: 0.5,
              borderRadius: BorderRadius.circular(8),
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
              final isLow = available <= 0;
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

class _BranchChipShimmer extends StatelessWidget {
  const _BranchChipShimmer();

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
  const _EmptyState();

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
            'No stock data for this branch',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different branch above',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
