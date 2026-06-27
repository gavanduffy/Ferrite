import re
import sys

def add_to_pbx(project_path):
    with open(project_path, 'r') as f:
        lines = f.readlines()

    # Define files to add
    # Format: (filename, path_in_group, group_name, group_uuid, file_uuid, build_file_uuid)
    files_to_add = [
        ('DesignTokens.swift', 'DesignTokens.swift', 'Design', '0CC667AA39723DFAD7FE9520', '0CC667AB39723DFAD7FE9521', '0CC667AC39723DFAD7FE9522'),
        ('Keyboard.swift', 'Keyboard.swift', 'Extensions', '0CA148C8288903F000DE2211', '0C70E40728C40C4E00A5C72E', '0C70E40828C40C4E00A5C72F'),
        ('LibraryHeaderView.swift', 'LibraryHeaderView.swift', 'CommonViews', '0CA148C0288903F000DE2211', '0CA3B23E28C2AA5600616D3B', '0CA3B23F28C2AA5600616D3C'),
        ('SearchableContent.swift', 'SearchableContent.swift', 'CommonViews', '0CA148C0288903F000DE2211', '0CA3B24028C2AA5600616D3D', '0CA3B24128C2AA5600616D3E'),
        ('SectionHeaderView.swift', 'SectionHeaderView.swift', 'CommonViews', '0CA148C0288903F000DE2211', '0CA3B24228C2AA5600616D3F', '0CA3B24328C2AA5600616D40'),
        ('TestHostingView.swift', 'TestHostingView.swift', 'CommonViews', '0CA148C0288903F000DE2211', '0CA3B24428C2AA5600616D41', '0CA3B24528C2AA5600616D42'),
        ('SourceCatalogButtonView.swift', 'SourceCatalogButtonView.swift', 'Buttons', '0C44E2AA28D4E09B007711AE', '0C794B6F289DACF100DD1CC9', '0C794B70289DACF100DD1CCA')
    ]

    new_content = "".join(lines)

    # 1. Add PBXBuildFile
    build_file_section = "/* Begin PBXBuildFile section */\n"
    for name, _, _, _, file_uuid, build_uuid in files_to_add:
        entry = f"\t\t{build_uuid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {name} */; }};\n"
        new_content = new_content.replace(build_file_section, build_file_section + entry)

    # 2. Add PBXFileReference
    file_ref_section = "/* Begin PBXFileReference section */\n"
    for name, path, _, _, file_uuid, _ in files_to_add:
        entry = f"\t\t{file_uuid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n"
        new_content = new_content.replace(file_ref_section, file_ref_section + entry)

    # 3. Add to PBXGroup
    # Handle 'Design' group specially as it might not exist
    if '0CC667AA39723DFAD7FE9520 /* Design */' not in new_content:
        design_group = """		0CC667AA39723DFAD7FE9520 /* Design */ = {
			isa = PBXGroup;
			children = (
				0CC667AB39723DFAD7FE9521 /* DesignTokens.swift */,
			);
			path = Design;
			sourceTree = "<group>";
		};
"""
        new_content = new_content.replace('/* Begin PBXGroup section */\n', '/* Begin PBXGroup section */\n' + design_group)
        # Add Design group to Ferrite group (0CA148BA288903F000DE2211)
        ferrite_group_start = new_content.find('0CA148BA288903F000DE2211 /* Ferrite */ = {')
        children_start = new_content.find('children = (', ferrite_group_start) + len('children = (')
        new_content = new_content[:children_start] + '\n\t\t\t\t0CC667AA39723DFAD7FE9520 /* Design */,' + new_content[children_start:]

    for name, _, group_name, group_uuid, file_uuid, _ in files_to_add:
        if name == 'DesignTokens.swift': continue # Already handled

        group_marker = f'{group_uuid} /* {group_name} */ = {{'
        group_start = new_content.find(group_marker)
        if group_start == -1:
             print(f"Error: Group {group_name} ({group_uuid}) not found")
             continue
        children_start = new_content.find('children = (', group_start) + len('children = (')
        entry = f"\n\t\t\t\t{file_uuid} /* {name} */,"
        new_content = new_content[:children_start] + entry + new_content[children_start:]

    # 4. Add to PBXSourcesBuildPhase
    sources_phase_start = new_content.find('0CAF1C64286F5C0E00296F86 /* Sources */ = {')
    sources_list_start = new_content.find('files = (', sources_phase_start) + len('files = (')
    for name, _, _, _, _, build_uuid in files_to_add:
        entry = f"\n\t\t\t\t{build_uuid} /* {name} in Sources */,"
        new_content = new_content[:sources_list_start] + entry + new_content[sources_list_start:]

    with open(project_path, 'w') as f:
        f.write(new_content)

if __name__ == "__main__":
    add_to_pbx('Ferrite.xcodeproj/project.pbxproj')
