import re

filepath = 'lib/features/dashboard/presentation/widgets/charts.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Replace all occurrences of the standard container pattern
pattern = r'(decoration:\s*BoxDecoration\(\s*color:\s*colorScheme\.surface,\s*borderRadius:\s*BorderRadius\.circular\([^)]+\),)'
replacement = r'\1\n        border: Border.all(\n          color: colorScheme.outlineVariant.withValues(alpha: 0.5),\n          width: 0.5,\n        ),'

new_content = re.sub(pattern, replacement, content)

with open(filepath, 'w') as f:
    f.write(new_content)

print(f"Updated {filepath}")
