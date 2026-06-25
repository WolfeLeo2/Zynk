import re
import os

files = [
    'lib/features/dashboard/presentation/widgets/quick_actions.dart',
    'lib/features/dashboard/presentation/widgets/skeleton_widgets.dart',
    'lib/features/dashboard/presentation/widgets/empty_error_states.dart'
]

pattern = r'(decoration:\s*BoxDecoration\(\s*color:\s*colorScheme\.surface,\s*borderRadius:\s*BorderRadius\.circular\([^)]+\),)'
replacement = r'\1\n        border: Border.all(\n          color: colorScheme.outlineVariant.withValues(alpha: 0.5),\n          width: 0.5,\n        ),'

for filepath in files:
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            content = f.read()
        new_content = re.sub(pattern, replacement, content)
        if new_content != content:
            with open(filepath, 'w') as f:
                f.write(new_content)
            print(f"Updated {filepath}")

