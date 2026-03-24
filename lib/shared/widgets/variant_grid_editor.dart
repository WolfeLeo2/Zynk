import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class VariantRowData {
  final Map<String, String> attributes;
  final TextEditingController skuController;
  final TextEditingController costController;
  final TextEditingController priceController;
  final TextEditingController stockController;
  File? imageFile;
  String? existingImageUrl;

  VariantRowData(this.attributes)
      : skuController = TextEditingController(),
        costController = TextEditingController(),
        priceController = TextEditingController(),
        stockController = TextEditingController(text: '0');

  void dispose() {
    skuController.dispose();
    costController.dispose();
    priceController.dispose();
    stockController.dispose();
  }
}

class VariantGridEditor extends StatelessWidget {
  final List<VariantRowData> variants;
  final VoidCallback onCopyToAll;
  final Future<void> Function(VariantRowData variant)? onPickImage;
  final bool showStockColumn;

  const VariantGridEditor({
    super.key,
    required this.variants,
    required this.onCopyToAll,
    this.onPickImage,
    this.showStockColumn = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (variants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              PhosphorIcon(PhosphorIconsDuotone.gridFour, size: 48, color: cs.outlineVariant),
              const SizedBox(height: 12),
              Text(
                'Add attributes with options to\nauto-generate variants here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVariantTableHeader(theme, cs),
        const Divider(height: 1),
        ...List.generate(variants.length, (i) => _buildVariantRow(variants[i], i, theme, cs)),
        const SizedBox(height: 12),
        // Quick fill banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              PhosphorIcon(PhosphorIconsDuotone.lightbulb, color: cs.onPrimaryContainer, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip: Enter values in the first row, then use "Copy to all".',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                ),
              ),
              TextButton.icon(
                onPressed: onCopyToAll,
                icon: const Icon(PhosphorIconsBold.copy, size: 16),
                label: const Text('Copy to all'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVariantTableHeader(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 48), // Space for image
          Expanded(
            flex: 3,
            child: Text('Variant', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text('SKU', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text('Cost', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text('Price', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (showStockColumn)
            Expanded(
              flex: 1,
              child: Text('Stock', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildVariantRow(VariantRowData variant, int index, ThemeData theme, ColorScheme cs) {
    final label = variant.attributes.values.join(' / ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Image Picker
          GestureDetector(
            onTap: onPickImage != null ? () => onPickImage!(variant) : null,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
                image: _getImageProvider(variant),
              ),
              child: _getImageProvider(variant) == null
                  ? Icon(PhosphorIconsRegular.image, size: 20, color: cs.onSurfaceVariant)
                  : null,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: _compactField(variant.skuController, 'SKU'),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: _compactField(variant.costController, '0.00', isNumeric: true),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: _compactField(variant.priceController, '0.00', isNumeric: true),
          ),
          if (showStockColumn) ...[
            const SizedBox(width: 4),
            Expanded(
              flex: 1,
              child: _compactField(variant.stockController, '0', isNumeric: true),
            ),
          ],
        ],
      ),
    );
  }

  DecorationImage? _getImageProvider(VariantRowData variant) {
    if (variant.imageFile != null) {
      return DecorationImage(image: FileImage(variant.imageFile!), fit: BoxFit.cover);
    } else if (variant.existingImageUrl != null) {
      // Very basic network image for now
      //TODO: Add CachedNetworkImage
      return DecorationImage(image: NetworkImage(variant.existingImageUrl!), fit: BoxFit.cover);
    }
    return null;
  }

  Widget _compactField(TextEditingController ctrl, String hint, {bool isNumeric = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
