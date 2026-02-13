import os

path = "Ferrite/Views/SheetViews/DebridTransferBrowserView.swift"
with open(path, "r") as f:
    content = f.read()

# It seems I had some issues with regex. Let's just truncate the file at the last struct start.
struct_start = content.rfind("@MainActor struct DebridTransferBrowserView_Previews")
if struct_start != -1:
    new_content = content[:struct_start] + """@MainActor struct DebridTransferBrowserView_Previews: PreviewProvider {
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
}
"""
    with open(path, "w") as f:
        f.write(new_content)
