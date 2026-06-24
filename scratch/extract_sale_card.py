import os
import re

filepath = '/Users/app/AndroidStudioProjects/Zynk/lib/features/sales/presentation/sales_list_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# find '// ─────────────────────────────────────────────────────────────────────────────\n// SALE CARD (Shopify-style)\n// ─────────────────────────────────────────────────────────────────────────────'
# and remove everything from there to the end.
split_token = '// ─────────────────────────────────────────────────────────────────────────────\n// SALE CARD (Shopify-style)'
if split_token in content:
    content = content.split(split_token)[0]

# Add import if missing
import_statement = "import 'widgets/sale_card.dart';\n"
if "import 'widgets/sale_card.dart';" not in content:
    imports = list(re.finditer(r"^import\s+.*?;", content, re.MULTILINE))
    if imports:
        last_import = imports[-1]
        content = content[:last_import.end()] + "\n" + import_statement + content[last_import.end():]
    else:
        content = import_statement + content

# Change _SaleCard to SaleCard
content = content.replace('_SaleCard(', 'SaleCard(')

with open(filepath, 'w') as f:
    f.write(content)
print("Updated sales_list_screen.dart")
