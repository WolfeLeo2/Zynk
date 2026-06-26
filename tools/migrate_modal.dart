import 'dart:io';

void main() {
  final files = [
    'lib/features/customers/presentation/customers_screen.dart',
    'lib/features/expenses/presentation/screens/expenses_screen.dart',
    'lib/features/pos/presentation/pos_screen.dart',
    'lib/features/products/presentation/add_product_screen.dart',
    'lib/features/products/presentation/group_details_screen.dart',
    'lib/features/products/presentation/inventory_adjustment_screen.dart',
    'lib/features/products/presentation/item_groups_screen.dart',
    'lib/features/products/presentation/widgets/edit_item_group_sheet.dart',
    'lib/features/products/presentation/widgets/mismatch_resolution_sheet.dart',
    'lib/features/products/presentation/widgets/product_selection_sheet.dart',
    'lib/features/reports/presentation/commissions_report_screen.dart',
    'lib/features/sales/presentation/sale_detail_screen.dart',
    'lib/features/settings/presentation/branches_screen.dart',
    'lib/features/settings/presentation/staff_members_screen.dart',
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;

    String content = file.readAsStringSync();
    
    // Replace showModalBottomSheet<T> with showResponsiveModal<T>
    content = content.replaceAll('showModalBottomSheet', 'showResponsiveModal');

    // Add import if not present
    if (!content.contains('responsive_modal.dart') && content.contains('showResponsiveModal')) {
      final importString = "import 'package:zynk/core/utils/responsive_modal.dart';\n";
      
      // Find the last import
      final lines = content.split('\n');
      int lastImportIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('import ')) {
          lastImportIndex = i;
        }
      }
      
      if (lastImportIndex != -1) {
        lines.insert(lastImportIndex + 1, importString);
        content = lines.join('\n');
      } else {
        content = importString + content;
      }
    }

    file.writeAsStringSync(content);
    print('Updated $path');
  }
}
