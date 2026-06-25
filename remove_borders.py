import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # We need a function to match balanced parentheses to remove the whole Border.all(...) expression
    # including the trailing comma.
    
    # Simple state machine to find 'border: Border.all(' and consume until the matching ')'
    
    keywords = ['border: Border.all(', 'border: pw.TableBorder.all(', 'border: TableBorder.all(']
    
    out = []
    i = 0
    changed = False
    while i < len(content):
        matched = False
        for kw in keywords:
            if content.startswith(kw, i):
                matched = True
                # consume until balanced parenthesis is closed
                depth = 1
                j = i + len(kw)
                while j < len(content) and depth > 0:
                    if content[j] == '(':
                        depth += 1
                    elif content[j] == ')':
                        depth -= 1
                    j += 1
                
                # consume optional whitespace and trailing comma
                while j < len(content) and content[j] in [' ', '\t', '\n', '\r']:
                    j += 1
                if j < len(content) and content[j] == ',':
                    j += 1
                
                # Remove preceding whitespaces for the line if it was only the border property
                # Actually it's safer to just let dart format fix formatting later, so just skip
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

