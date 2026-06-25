import os

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    if "app_theme.dart" in filepath or "printing" in filepath:
        return
        
    keywords = ['side: BorderSide(', 'side: BorderSide.none']
    
    out = []
    i = 0
    changed = False
    while i < len(content):
        matched = False
        for kw in keywords:
            if content.startswith(kw, i):
                matched = True
                if kw == 'side: BorderSide.none':
                    j = i + len(kw)
                    while j < len(content) and content[j] in [' ', '\t', '\n', '\r']:
                        j += 1
                    if j < len(content) and content[j] == ',':
                        j += 1
                    i = j
                    changed = True
                    break
                else:
                    depth = 1
                    j = i + len(kw)
                    while j < len(content) and depth > 0:
                        if content[j] == '(':
                            depth += 1
                        elif content[j] == ')':
                            depth -= 1
                        j += 1
                    
                    while j < len(content) and content[j] in [' ', '\t', '\n', '\r']:
                        j += 1
                    if j < len(content) and content[j] == ',':
                        j += 1
                    
                    i = j
                    changed = True
                    break
        
        if not matched:
            out.append(content[i])
            i += 1

    if changed:
        with open(filepath, 'w') as f:
            f.write("".join(out))
        print(f"Updated {filepath}")

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

