import os
import re

def fix_debrid_manager():
    path = "Ferrite/ViewModels/DebridManager.swift"
    with open(path, "r") as f:
        content = f.read()

    # Remove redundant [weak self] in MainActor.run inside scheduleRemoteDelete
    content = content.replace("await MainActor.run { [weak self] in", "await MainActor.run {")

    with open(path, "w") as f:
        f.write(content)

def fix_cloud_magnet_preview():
    path = "Ferrite/Views/ComponentViews/Library/Cloud/CloudMagnetView.swift"
    # Using a simpler string replacement for the previews
    with open(path, "r") as f:
        content = f.read()

    struct_start = content.rfind("@MainActor struct CloudMagnetView_Previews")
    if struct_start != -1:
        new_struct = r"""@MainActor struct CloudMagnetView_Previews: PreviewProvider {
    static var sampleMagnet = DebridCloudMagnet(
        id: "m1",
        fileName: "Sample Series - Episode 1 — A very long title intended to exercise wrapping and accessibility dynamic type scaling",
        status: "downloaded",
        hash: "abc123",
        links: ["https://example.com/video.m3u8"]
    )

    static var previews: some View {
        let debridManager = DebridManager()
        let navModel = NavigationViewModel()
        let logManager = LoggingManager()

        return Group {
            // Default size
            CloudMagnetView(debridSource: RealDebrid() as DebridSource, searchText: .constant(""))
                .environmentObject(navModel)
                .environmentObject(debridManager)
                .environmentObject(logManager)
                .previewDisplayName("Magnets — Default")

            // Accessibility large
            CloudMagnetView(debridSource: RealDebrid() as DebridSource, searchText: .constant(""))
                .environmentObject(navModel)
                .environmentObject(debridManager)
                .environmentObject(logManager)
                .environment(\.sizeCategory, .accessibilityExtraLarge)
                .previewDisplayName("Magnets — Large Dynamic Type")

            // Accessibility XXL
            CloudMagnetView(debridSource: RealDebrid() as DebridSource, searchText: .constant(""))
                .environmentObject(navModel)
                .environmentObject(debridManager)
                .environmentObject(logManager)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .previewDisplayName("Magnets — Accessibility XXL")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
"""
        new_content = content[:struct_start] + new_struct
        with open(path, "w") as f:
            f.write(new_content)

fix_debrid_manager()
fix_cloud_magnet_preview()
