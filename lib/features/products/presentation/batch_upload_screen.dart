import 'package:button_group_m3e/button_group_m3e.dart';
import 'package:button_m3e/button_m3e.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/utils/quantity.dart';
import 'package:zynk/features/products/data/csv_import_service.dart';
import 'package:zynk/features/products/domain/csv_import_analysis.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

const _templateCsv =
    'name,category,item_group,selling_price,cost_price,quantity,sku\n'
    'Ceramic Tile 30x30,Tiles,Floor Tiles,1200,800,50,TIL-3030\n'
    'Cement 50kg,Building,Cement,750,600,120,\n'
    'Toilet DFT013,Sanitary,Toilets,8500,,1.5,';

class BatchUploadScreen extends ConsumerStatefulWidget {
  const BatchUploadScreen({super.key});

  @override
  ConsumerState<BatchUploadScreen> createState() => _BatchUploadScreenState();
}

class _BatchUploadScreenState extends ConsumerState<BatchUploadScreen> {
  CsvAnalysis? _analysis;
  ImportStockMode _mode = ImportStockMode.add;
  bool _isLoading = false;
  String? _error;
  String? _reasonId;
  Set<String>? _branchIds; // null until branches load; then all selected

  void _initBranches(List<Branch> branches) {
    if (_branchIds != null || branches.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _branchIds = branches.map((b) => b.id).toSet());
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ref.read(csvImportServiceProvider).pickAndParseCsv();
      if (data == null) {
        setState(() => _isLoading = false); // user cancelled
        return;
      }
      setState(() {
        _analysis = analyzeProductCsv(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _import() async {
    final analysis = _analysis;
    if (analysis == null || analysis.importableCount == 0) return;

    final branchIds = _branchIds?.toList() ?? const [];
    if (branchIds.isEmpty) {
      setState(() => _error = 'Select at least one branch to import into.');
      return;
    }
    if (_reasonId == null) {
      setState(() => _error = 'Select a reason for this stock adjustment.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ref
          .read(csvImportServiceProvider)
          .importRows(
            analysis.importable,
            _mode,
            branchIds: branchIds,
            reasonId: _reasonId,
          );

      if (mounted) {
        final parts = [
          if (result.created > 0) '${result.created} created',
          if (result.updated > 0) '${result.updated} updated',
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              parts.isEmpty
                  ? 'Nothing to import.'
                  : 'Import complete — ${parts.join(', ')}.',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _error = 'Import failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _copyTemplate() async {
    await Clipboard.setData(const ClipboardData(text: _templateCsv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV template copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final analysis = _analysis;
    final branches = ref.watch(branchesProvider).value ?? const <Branch>[];
    final selectableBranches = branches.where((b) => b.id != 'all').toList();
    _initBranches(selectableBranches);

    return Scaffold(
      appBar: AppBar(title: const Text('Import from CSV'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FormatCard(onCopyTemplate: _copyTemplate),
              const SizedBox(height: 16),
              _ModeSelector(
                mode: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 16),
              _ReasonPicker(
                reasonId: _reasonId,
                onChanged: (r) => setState(() => _reasonId = r),
              ),
              if (selectableBranches.length > 1) ...[
                const SizedBox(height: 16),
                _BranchSelector(
                  branches: selectableBranches,
                  selected: _branchIds ?? const {},
                  onToggle: (id, on) => setState(() {
                    final next = {...?_branchIds};
                    if (on) {
                      next.add(id);
                    } else if (next.length > 1) {
                      next.remove(id);
                    }
                    _branchIds = next;
                  }),
                ),
              ],
              const SizedBox(height: 16),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (analysis == null)
                Expanded(child: _pickPrompt(cs))
              else if (!analysis.ok)
                Expanded(child: _headerErrors(analysis, cs, theme))
              else
                Expanded(child: _preview(analysis, cs, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickPrompt(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: _pickFile,
            icon: const PhosphorIcon(PhosphorIconsBold.fileCsv),
            label: const Text('Select CSV File'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: cs.error),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerErrors(CsvAnalysis analysis, ColorScheme cs, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PhosphorIcon(
                    PhosphorIconsDuotone.warning,
                    color: cs.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "This file's columns don't match",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onErrorContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final e in analysis.headerErrors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $e',
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Detected: ${analysis.detectedHeaders.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onErrorContainer.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowClockwise),
          label: const Text('Choose a different file'),
        ),
      ],
    );
  }

  Widget _preview(CsvAnalysis analysis, ColorScheme cs, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _summaryChip(
              cs,
              PhosphorIconsRegular.checkCircle,
              '${analysis.importableCount} to import',
              cs.primary,
            ),
            if (analysis.fixCount > 0) ...[
              const SizedBox(width: 8),
              _summaryChip(
                cs,
                PhosphorIconsRegular.wrench,
                '${analysis.fixCount} auto-fixed',
                cs.tertiary,
              ),
            ],
            if (analysis.skippedCount > 0) ...[
              const SizedBox(width: 8),
              _summaryChip(
                cs,
                PhosphorIconsRegular.prohibit,
                '${analysis.skippedCount} skipped',
                cs.error,
              ),
            ],
            const Spacer(),
            TextButton(onPressed: _pickFile, child: const Text('Change')),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: analysis.rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) =>
                _RowTile(row: analysis.rows[i], mode: _mode),
          ),
        ),
        const SizedBox(height: 16),
        if (_reasonId == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Select a reason above to enable import.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        FilledButton.icon(
          onPressed: analysis.importableCount == 0 || _reasonId == null
              ? null
              : _import,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const PhosphorIcon(PhosphorIconsRegular.downloadSimple),
          label: Text(
            analysis.fixCount > 0
                ? 'Apply ${analysis.fixCount} fixes & import ${analysis.importableCount} rows'
                : 'Import ${analysis.importableCount} rows',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(
    ColorScheme cs,
    PhosphorIconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final ImportStockMode mode;
  final ValueChanged<ImportStockMode> onChanged;

  const _ModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Stock:',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        ButtonGroupM3E(
          selection: true,
          overflow: ButtonGroupM3EOverflow.none,
          type: ButtonGroupM3EType.connected,
          style: ButtonM3EStyle.filled,
          size: ButtonGroupM3ESize.sm,
          shape: ButtonGroupM3EShape.round,
          selectedIndex: mode == ImportStockMode.add ? 0 : 1,
          actions: [
            ButtonGroupM3EAction(
              label: const Text('Add to stock'),
              icon: const PhosphorIcon(PhosphorIconsRegular.plus, size: 18),
              style: mode == ImportStockMode.add ? ButtonM3EStyle.tonal : null,
              onPressed: () => onChanged(ImportStockMode.add),
            ),
            ButtonGroupM3EAction(
              label: const Text('Set to'),
              icon: const PhosphorIcon(PhosphorIconsRegular.equals, size: 18),
              style: mode == ImportStockMode.set ? ButtonM3EStyle.tonal : null,
              onPressed: () => onChanged(ImportStockMode.set),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReasonPicker extends ConsumerWidget {
  final String? reasonId;
  final ValueChanged<String?> onChanged;

  const _ReasonPicker({required this.reasonId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reasonsAsync = ref.watch(adjustmentReasonsProvider);
    return reasonsAsync.when(
      data: (reasons) => DropdownButtonFormField<String>(
        initialValue: reasonId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Reason * (for the stock adjustment audit trail)',
          prefixIcon: const PhosphorIcon(PhosphorIconsRegular.question),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        hint: const Text('Select a reason'),
        items: [
          for (final r in reasons)
            DropdownMenuItem(value: r.id, child: Text(r.label)),
        ],
        onChanged: onChanged,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Could not load reasons: $e'),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  final List<Branch> branches;
  final Set<String> selected;
  final void Function(String id, bool on) onToggle;

  const _BranchSelector({
    required this.branches,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Import into branches',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in branches)
              FilterChip(
                label: Text(b.name),
                selected: selected.contains(b.id),
                avatar: const PhosphorIcon(
                  PhosphorIconsRegular.storefront,
                  size: 14,
                ),
                onSelected: (on) => onToggle(b.id, on),
              ),
          ],
        ),
      ],
    );
  }
}

class _FormatCard extends StatelessWidget {
  final VoidCallback onCopyTemplate;

  const _FormatCard({required this.onCopyTemplate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(PhosphorIconsDuotone.info, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'CSV format',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onCopyTemplate,
                icon: const PhosphorIcon(PhosphorIconsRegular.copy, size: 16),
                label: const Text('Copy template'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
              children: [
                const TextSpan(
                  text: 'Required: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: 'name, quantity'),
                TextSpan(
                  text: '  (quantity also accepts "stock" or "qty")\n',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const TextSpan(
                  text: 'Optional: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text:
                      'category, item_group, selling_price, cost_price, sku, '
                      'barcode, description, image_url',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Existing items (matched by name) get their stock adjusted; new '
            'names are created. Numbers may include commas or currency symbols '
            '— they\'re cleaned automatically. Fractional stock (e.g. 1.5) is '
            'supported.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final ImportRow row;
  final ImportStockMode mode;

  const _RowTile({required this.row, required this.mode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (PhosphorIconData icon, Color color) = row.skip
        ? (PhosphorIconsFill.xCircle, cs.error)
        : row.hasFixes
        ? (PhosphorIconsFill.warningCircle, cs.tertiary)
        : (PhosphorIconsFill.checkCircle, cs.primary);

    final verb = mode == ImportStockMode.set ? 'Set to' : 'Add';

    return Opacity(
      opacity: row.skip ? 0.6 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: PhosphorIcon(icon, color: color),
        title: Text(
          row.name.isEmpty ? '(no name)' : row.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: row.skip ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.skip
                  ? 'Line ${row.lineNumber} · will be skipped'
                  : '$verb ${formatQty(row.quantity)}'
                        '${row.sellingPrice != null ? ' · price ${formatQty(row.sellingPrice!)}' : ''}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            for (final issue in row.issues)
              Text(
                issue.fixable
                    ? '⚠ ${issue.field}: ${issue.original} → ${issue.fixed}'
                    : '✕ ${issue.field}: ${issue.message}',
                style: TextStyle(
                  color: issue.fixable ? cs.tertiary : cs.error,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
