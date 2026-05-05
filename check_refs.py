import os
import re

def get_all_filesystem_files():
    fs_files = {}
    for root, dirs, files in os.walk('.'):
        # Handle directory-based assets
        for d in list(dirs):
            if d.endswith(('.xcassets', '.xcdatamodeld', '.appiconset', '.imageset', '.xcdatamodel', '.bundle')):
                path = os.path.join(root, d).lstrip('./')
                fs_files[d] = path
                # Don't recurse into these directories for individual files if we treat them as single entities
                # but we might want to check if they are in pbxproj as well.
                # Actually, pbxproj often references the directory itself.

        for f in files:
            path = os.path.join(root, f).lstrip('./')
            if f not in fs_files:
                fs_files[f] = path
    return fs_files

def check_pbxproj(filepath):
    if not os.path.exists(filepath):
        print(f"Error: {filepath} not found")
        return

    with open(filepath, 'r') as f:
        content = f.read()

    # Get all filesystem files
    fs_files = get_all_filesystem_files()

    # Find paths in PBXFileReference
    # Typical line: 0C64A4A2288903880079976D /* DebridManager.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = DebridManager.swift; sourceTree = "<group>"; };
    file_refs = re.findall(r'/\* ([^*]+) \*/ = {isa = PBXFileReference; .*? path = ([^;]+);', content)

    dangling_refs = []
    referenced_filenames = set()

    for display_name, path in file_refs:
        path = path.strip('"')
        referenced_filenames.add(path)

        # Check if file exists. path in pbxproj is often just filename, relative to group.
        # This makes it hard to verify exactly, but if the filename exists NOWHERE on disk, it's a dangling ref.
        if path not in fs_files and not path.startswith('/'):
             # Some paths might be actual paths from project root
             if not os.path.exists(path):
                 dangling_refs.append((display_name, path))

    # Orphaned files: Swift files in Ferrite/ that are NOT in referenced_filenames
    orphaned_files = []
    for root, dirs, files in os.walk('Ferrite'):
        for f in files:
            if f.endswith('.swift'):
                if f not in referenced_filenames:
                    orphaned_files.append(os.path.join(root, f))

    print("--- DANGLING REFERENCES (in pbxproj but not on disk) ---")
    for name, path in dangling_refs:
        print(f"Name: {name}, Path: {path}")

    print("\n--- ORPHANED FILES (on disk but not in pbxproj) ---")
    for path in orphaned_files:
        print(path)

check_pbxproj('Ferrite.xcodeproj/project.pbxproj')
