import os
import re

def fix_transfer_browser_preview():
    path = "Ferrite/Views/SheetViews/DebridTransferBrowserView.swift"
    with open(path, "r") as f:
        content = f.read()

    new_struct = """@MainActor struct DebridTransferBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        DebridTransferBrowserView(
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
        .environmentObject(LoggingManager())
    }
}"""
    # Replace the old struct
    content = re.sub(r'@MainActor struct DebridTransferBrowserView_Previews: PreviewProvider \{.*?\}', new_struct, content, flags=re.DOTALL)

    with open(path, "w") as f:
        f.write(content)

fix_transfer_browser_preview()
