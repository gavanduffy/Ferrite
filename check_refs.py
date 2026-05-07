import os
import re
import sys

def main():
    with open('Ferrite.xcodeproj/project.pbxproj', 'r') as f:
        content = f.read()

    # Find all path = ... lines
    paths = re.findall(r'path = ([^;]+);', content)

    # Also find children = (...) blocks to understand structure
    # This is more complex, let's stick to paths for now and see where they are

    missing = []
    for path in paths:
        path = path.strip('"')
        # Some paths are absolute or relative to some group.
        # Most are just filenames.
        # We'll search for them in the Ferrite directory.

        found = False
        for root, dirs, files in os.walk('Ferrite'):
            if path in files or path in dirs:
                found = True
                break

        if not found and not path.endswith('.app'): # Ignore built products
             # Check if it's a known system framework or something
             if '/' not in path and '.' in path:
                 missing.append(path)

    if missing:
        print("Potentially missing files referenced in project:")
        for m in sorted(set(missing)):
            print(f" - {m}")
    else:
        print("No missing files detected in project.pbxproj")

if __name__ == "__main__":
    main()
