import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/products/data/csv_import_service.dart';

class BatchUploadScreen extends ConsumerStatefulWidget {
  const BatchUploadScreen({super.key});

  @override
  ConsumerState<BatchUploadScreen> createState() => _BatchUploadScreenState();
}

class _BatchUploadScreenState extends ConsumerState<BatchUploadScreen> {
  List<List<dynamic>>? _csvData;
  List<Map<String, dynamic>> _parsedProducts = [];
  bool _isLoading = false;
  String? _error;

  // Expected headers
  final List<String> _requiredHeaders = [
    'name',
    'category',
    'selling_price',
    'initial_stock',
  ];

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(csvImportServiceProvider);
      final data = await service.pickAndParseCsv();

      if (data != null && data.isNotEmpty) {
        _validateAndParseCsv(data);
      } else {
        setState(() {
          _error = 'Selected file is empty.';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _validateAndParseCsv(List<List<dynamic>> data) {
    if (data.isEmpty) return;

    final headers = data.first
        .map((e) => e.toString().toLowerCase().trim())
        .toList();

    // Check required headers
    for (final req in _requiredHeaders) {
      if (!headers.contains(req)) {
        setState(() {
          _error =
              'Missing required column: $req\nFound: ${headers.join(', ')}';
          _csvData = null;
          _parsedProducts = [];
        });
        return;
      }
    }

    final parsed = <Map<String, dynamic>>[];
    String? validationError;

    for (int i = 1; i < data.length; i++) {
      final row = data[i];
      if (row.isEmpty || (row.length == 1 && row.first.toString().isEmpty)) {
        continue; // Skip empty rows
      }

      Map<String, dynamic> productMap = {};
      for (int j = 0; j < headers.length; j++) {
        if (j < row.length) {
          productMap[headers[j]] = row[j];
        }
      }

      // Validate required fields per row
      if (productMap['name'] == null || productMap['name'].toString().isEmpty) {
        validationError = 'Row ${i + 1}: Name is required.';
        break;
      }
      if (productMap['category'] == null ||
          productMap['category'].toString().isEmpty) {
        validationError = 'Row ${i + 1}: Category Name is required.';
        break;
      }
      if (productMap['selling_price'] == null ||
          productMap['selling_price'].toString().isEmpty) {
        validationError = 'Row ${i + 1}: Selling Price is required.';
        break;
      }
      if (productMap['initial_stock'] == null ||
          productMap['initial_stock'].toString().isEmpty) {
        validationError = 'Row ${i + 1}: Initial Stock is required.';
        break;
      }

      parsed.add(productMap);
    }

    if (validationError != null) {
      setState(() {
        _error = validationError;
        _csvData = null;
        _parsedProducts = [];
      });
    } else {
      setState(() {
        _csvData = data;
        _parsedProducts = parsed;
        _error = null;
      });
    }
  }

  Future<void> _importData() async {
    if (_parsedProducts.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(csvImportServiceProvider);
      await service.importProducts(_parsedProducts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${_parsedProducts.length} products!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = 'Import failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Batch Import CSV'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions Card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIconsDuotone.info,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CSV Format Requirements',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your CSV must include the following headers (case-insensitive):\n'
                        '• name\n'
                        '• category (Name of the category, e.g. "Electronics")\n'
                        '• selling_price\n'
                        '• initial_stock\n\n'
                        'Optional headers:\n'
                        '• sku, barcode, description, image_url, cost_price',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // File Picker Area
              if (_csvData == null && !_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _pickFile,
                          icon: const PhosphorIcon(PhosphorIconsBold.fileCsv),
                          label: const Text('Select CSV File'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 20,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              _error!,
                              style: TextStyle(color: colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Loading State
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),

              // Preview Area
              if (_csvData != null && !_isLoading) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview (${_parsedProducts.length} items)',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickFile,
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.pencilSimple,
                      ),
                      label: const Text('Change File'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _parsedProducts.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = _parsedProducts[index];
                        return ListTile(
                          title: Text(p['name']?.toString() ?? 'Unnamed'),
                          subtitle: Text(
                            'Price: \$${p['selling_price']} | Stock: ${p['initial_stock']}',
                          ),
                          trailing: const PhosphorIcon(
                            PhosphorIconsRegular.checkCircle,
                            color: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _importData,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Import Items'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
