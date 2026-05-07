import os
import re

def main():
    # Looking for #available or @available without proper fallback or suspicious versions
    pattern = re.compile(r'#available\s*\(\s*iOS\s*([0-9.]+)\s*,\s*\*\s*\)')

    for root, dirs, files in os.walk('Ferrite'):
        for file in files:
            if file.endswith('.swift'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r') as f:
                    content = f.read()
                    matches = pattern.finditer(content)
                    for match in matches:
                        version = match.group(1)
                        if float(version) > 18.0: # Suspiciously high version
                            print(f"Suspicious availability check in {filepath}: iOS {version}")

if __name__ == "__main__":
    main()
