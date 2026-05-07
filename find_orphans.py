import os
import re

def main():
    with open('Ferrite.xcodeproj/project.pbxproj', 'r') as f:
        pbx_content = f.read()

    # Extract all file names referenced in pbxproj
    # Typical line: 0C0167DB29293FA900B65783 /* RealDebridModels.swift */ = {isa = PBXFileReference; ... path = RealDebridModels.swift; ... };
    referenced_files = set(re.findall(r'path = ([^;]+);', pbx_content))
    referenced_files = {f.strip('"') for f in referenced_files}

    orphans = []
    for root, dirs, files in os.walk('Ferrite'):
        for name in files + dirs:
            # Skip hidden files and some standard ones
            if name.startswith('.') or name == 'Contents.json':
                continue

            # Check if name is referenced
            if name not in referenced_files:
                # Some files might be in a folder that IS referenced.
                # For simplicity, let's just list them.
                full_path = os.path.join(root, name)
                orphans.append(full_path)

    if orphans:
        print("Potentially orphaned files (on disk but not directly in pbxproj):")
        for o in sorted(orphans):
            # Filter out files that are likely inside referenced folders like .xcassets or .xcdatamodeld
            if '.xcassets/' in o or '.xcdatamodeld/' in o or '.imageset/' in o or '.appiconset/' in o:
                continue
            print(f" - {o}")
    else:
        print("No orphaned files detected.")

if __name__ == "__main__":
    main()
