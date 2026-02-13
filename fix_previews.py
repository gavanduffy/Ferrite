import os
import re

def fix_cloud_magnet_preview():
    path = "Ferrite/Views/ComponentViews/Library/Cloud/CloudMagnetView.swift"
    with open(path, "r") as f:
        content = f.read()

    # Remove the old static vars for managers
    content = re.sub(r'static var debridManager = DebridManager\(\)\s+static var navModel = NavigationViewModel\(\)\s+static var logManager = LoggingManager\(\)', '', content)

    # Update the previews property to include local managers
    new_previews = """    static var previews: some View {
        let debridManager = DebridManager()
        let navModel = NavigationViewModel()
        let logManager = LoggingManager()

        return Group {"""
    content = re.sub(r'static var previews: some View \{\s+Group \{', new_previews, content)

    with open(path, "w") as f:
        f.write(content)

def fix_cloud_download_preview():
    path = "Ferrite/Views/ComponentViews/Library/Cloud/CloudDownloadView.swift"
    with open(path, "r") as f:
        content = f.read()

    # Already has local variables, just ensuring @MainActor is there
    if "@MainActor struct CloudDownloadView_Previews" not in content:
        content = content.replace("struct CloudDownloadView_Previews", "@MainActor struct CloudDownloadView_Previews")

    with open(path, "w") as f:
        f.write(content)

def fix_transfer_browser_preview():
    path = "Ferrite/Views/SheetViews/DebridTransferBrowserView.swift"
    with open(path, "r") as f:
        content = f.read()

    # Ensure @MainActor and add missing environment objects for completeness
    if "@MainActor struct DebridTransferBrowserView_Previews" not in content:
        content = content.replace("struct DebridTransferBrowserView_Previews", "@MainActor struct DebridTransferBrowserView_Previews")

    # Add environment objects
    if ".environmentObject" not in content[content.find("DebridTransferBrowserView_Previews"):]:
        new_preview_call = """        DebridTransferBrowserView(
            debridSource: RealDebrid() as DebridSource,
            initialFiles: [
                DebridTransferFile(id: "1", name: "Example.mkv"),
                DebridTransferFile(id: "2", name: "Sample.srt")
            ],
            title: "Example",
            resultFromCloud: true
        )
        .environmentObject(NavigationViewModel())
        .environmentObject(DebridManager())
        .environmentObject(LoggingManager())"""
        content = re.sub(r'DebridTransferBrowserView\(\s+debridSource: RealDebrid\(\) as DebridSource,\s+initialFiles: \[.*?\]\s+title: "Example",\s+resultFromCloud: true\s+\)', new_preview_call, content, flags=re.DOTALL)

    with open(path, "w") as f:
        f.write(content)

fix_cloud_magnet_preview()
fix_cloud_download_preview()
fix_transfer_browser_preview()
