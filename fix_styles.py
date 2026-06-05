import os
import re

files = [
    'phosphor_icons_bold.dart',
    'phosphor_icons_duotone.dart',
    'phosphor_icons_fill.dart',
    'phosphor_icons_light.dart',
    'phosphor_icons_regular.dart',
    'phosphor_icons_thin.dart',
]

dir_path = 'packages/phosphor_flutter/lib/src'

for file in files:
    path = os.path.join(dir_path, file)
    with open(path, 'r') as f:
        content = f.read()
    
    # 1. PhosphorFlatIconData(0xe072, 'Style')
    def repl_flat(m):
        code = m.group(1)
        style = m.group(2)
        return f"PhosphorFlatIconData(IconData({code}, fontFamily: 'Phosphor{style}', fontPackage: 'phosphor_flutter', matchTextDirection: true))"
    
    content = re.sub(r"PhosphorFlatIconData\((0x[0-9a-fA-F]+),\s*'([^']+)'\)", repl_flat, content)
    
    # 2. PhosphorDuotoneIconData(0x..., -> PhosphorDuotoneIconData(IconData(0x..., ...)
    def repl_duotone(m):
        code = m.group(1)
        return f"PhosphorDuotoneIconData(\n    IconData({code}, fontFamily: 'PhosphorDuotone', fontPackage: 'phosphor_flutter', matchTextDirection: true),"
        
    content = re.sub(r"PhosphorDuotoneIconData\(\s*(0x[0-9a-fA-F]+),", repl_duotone, content)
    
    # 3. PhosphorIconData(0x..., 'Style')
    def repl_icon_data(m):
        code = m.group(1)
        style = m.group(2)
        return f"PhosphorIconData(IconData({code}, fontFamily: 'Phosphor{style}', fontPackage: 'phosphor_flutter', matchTextDirection: true))"
        
    content = re.sub(r"PhosphorIconData\((0x[0-9a-fA-F]+),\s*'([^']+)'\)", repl_icon_data, content)

    with open(path, 'w') as f:
        f.write(content)

print("Styles updated")
