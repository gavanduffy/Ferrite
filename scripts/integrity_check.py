import os
import re

def get_files_on_disk(root_dir):
    on_disk = []
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            # Skip hidden files
            if file.startswith('.'):
                continue
            full_path = os.path.join(root, file)
            on_disk.append(full_path)
        # Also track directories that are treated as files in Xcode (.xcassets, .xcdatamodeld)
        for d in dirs:
            if d.endswith(('.xcassets', '.xcdatamodeld', '.docc')):
                on_disk.append(os.path.join(root, d))
    return on_disk

def get_project_items(project_file):
    with open(project_file, 'r') as f:
        content = f.read()

    # Find all PBXFileReference paths
    file_refs = re.findall(r'isa = PBXFileReference; [^}]*?path = (.*?);', content)
    file_refs = [ref.strip('"') for ref in file_refs]

    # Find all PBXGroup paths (though they are usually just folders)
    group_refs = re.findall(r'isa = PBXGroup; [^}]*?path = (.*?);', content)
    group_refs = [ref.strip('"') for ref in group_refs]

    # Find items in PBXBuildFile (these are the ones actually being compiled/used)
    build_files = re.findall(r'/\* (.*?) in (Sources|Resources|Frameworks) \*/', content)
    build_file_names = [name for name, section in build_files]

    return set(file_refs), set(group_refs), set(build_file_names)

def check_integrity():
    root = 'Ferrite'
    project_path = 'Ferrite.xcodeproj/project.pbxproj'

    disk_files = get_files_on_disk(root)
    project_file_refs, project_group_refs, build_file_names = get_project_items(project_path)

    disk_basenames = {os.path.basename(f): f for f in disk_files}

    orphaned = []
    for f in disk_files:
        basename = os.path.basename(f)
        if basename not in project_file_refs:
            orphaned.append(f)

    missing = []
    for ref in project_file_refs:
        # Ignore things like .app, frameworks, or items outside Ferrite if any
        if ref.endswith(('.app', '.framework', '.dylib')):
            continue
        if ref not in disk_basenames:
            missing.append(ref)

    not_in_sources = []
    for f in disk_files:
        if f.endswith('.swift'):
            basename = os.path.basename(f)
            if basename in project_file_refs and basename not in build_file_names:
                not_in_sources.append(f)

    print("--- ORPHANED FILES (On disk but not in PBXFileReference) ---")
    for f in sorted(orphaned):
        print(f)

    print("\n--- MISSING FILES (In PBXFileReference but not on disk) ---")
    for f in sorted(missing):
        print(f)

    print("\n--- FILES IN PROJECT BUT NOT IN ANY BUILD PHASE ---")
    for f in sorted(not_in_sources):
        print(f)

if __name__ == "__main__":
    check_integrity()
