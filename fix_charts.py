with open('lib/features/dashboard/presentation/widgets/charts.dart', 'r') as f:
    lines = f.readlines()

out = []
# Find lines that are `    );` followed by `  }` and `}`
for i, line in enumerate(lines):
    if line == '    );\n' and i + 1 < len(lines) and lines[i+1] == '  }\n' and i + 2 < len(lines) and lines[i+2] == '}\n':
        out.append('      ),\n')
        out.append('    );\n')
    else:
        out.append(line)

with open('lib/features/dashboard/presentation/widgets/charts.dart', 'w') as f:
    f.writelines(out)

