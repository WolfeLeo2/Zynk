import os
import re

CURRENCY_IMPORT = "import 'package:zynk/core/utils/currency.dart';\n"

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original_content = content

    # Regex 1: 'Ksh ${expr.toStringAsFixed(0)}' => CurrencyHelper.format(expr)
    # We match the variable / expression carefully
    content = re.sub(r"'Ksh \${([^}]+)\.toStringAsFixed\(\d\)}'", r"CurrencyHelper.format(\1)", content)
    content = re.sub(r"'KES \${([^}]+)\.toStringAsFixed\(\d\)}'", r"CurrencyHelper.format(\1)", content)

    # Some might be inside larger strings like 'Price: Ksh ${...}'
    # Let's replace only the 'Ksh ${...}' part if it's inside a string
    # Actually, simpler: replace Ksh ${...toStringAsFixed(..)} and KES ${...toStringAsFixed(..)} directly
    # 'KES ${resolvedPrice.toStringAsFixed(2)}' -> CurrencyHelper.format(resolvedPrice)
    # But what if it's 'Cost: KES ${...}'? Then it becomes 'Cost: ${CurrencyHelper.format(...)}'
    
    # A more generic approach: replace Ksh ${expr.toStringAsFixed(X)} with ${CurrencyHelper.format(expr)}
    content = re.sub(r"(Ksh|KES) \${([^}]+)\.toStringAsFixed\(\d\)}", r"${\1_PLACEHOLDER\2}", content)
    
    # Now replace the placeholder back to CurrencyHelper.format(expr)
    # Wait, the \$ was part of the string interpolation. If we are inside a string, we need to inject ${CurrencyHelper.format(expr)}
    content = content.replace("Ksh_PLACEHOLDER", "CurrencyHelper.format(")
    content = content.replace("KES_PLACEHOLDER", "CurrencyHelper.format(")
    # Fix the trailing brace of the placeholder
    content = re.sub(r"\${CurrencyHelper\.format\(([^}]+)}", r"${CurrencyHelper.format(\1)}", content)
    
    # Clean up standalone strings: '${CurrencyHelper.format(expr)}' -> CurrencyHelper.format(expr)
    content = re.sub(r"'\${CurrencyHelper\.format\(([^}]+)\)}'", r"CurrencyHelper.format(\1)", content)

    if content != original_content:
        # Add import if missing
        if "package:zynk/core/utils/currency.dart" not in content:
            # Find last import
            imports = list(re.finditer(r"^import\s+.*?;", content, re.MULTILINE))
            if imports:
                last_import = imports[-1]
                content = content[:last_import.end()] + "\n" + CURRENCY_IMPORT + content[last_import.end():]
            else:
                content = CURRENCY_IMPORT + content
        
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk('/Users/app/AndroidStudioProjects/Zynk/lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
