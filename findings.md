# Findings & Research

## Key Files
| Area | Files | Notes |
| --- | --- | --- |
| Cloud management | Views/ComponentViews/Library/DebridCloudView.swift, CloudDownloadView.swift, CloudMagnetView.swift | Cloud list is a List with downloads and magnets; new segmented UI needed for current/past. |
| Download/Add flow | Views/AddView.swift | Previously single-entry; now supports multi-entry with TextEditor. |
| Navigation | ViewModels/NavigationViewModel.swift, Views/MainView.swift | Handles tab selection and deep links; magnet:// handling added. |
| App registration | Info.plist | ferrite:// and magnet:// URL schemes registered; torrent document type configured. |

## Implementation Notes
- Cloud history is stored as `DebridCloudHistoryItem` (Codable) in `DebridModels.swift` and persisted in UserDefaults ("Debrid.CloudHistory").
- DebridManager merges current cloud downloads/magnets into history on fetch to build a past-downloads list.
- DebridCloudView now supports a segmented control with a history list filtered by provider, search text, and current cloud IDs.
- AddView is now a Download page with multi-entry processing (web links + magnets) and multiple torrent uploads.

## Open Items
- UI screenshots still needed once a runnable iOS environment is available.

## Build Health Scan (Sentinel) - 2025-05-22
### Identified Issues
- **Dangling Reference:** `SelectedDebridFilterView.swift` was referenced in `project.pbxproj` but missing from the filesystem.
- **Invalid Package Version:** `swiftui-introspect` was set to `26.0.0` (invalid placeholder/future version).
- **Incorrect Swift Version:** `SWIFT_VERSION` was set to `5.0` instead of `5.8`.
- **Invalid API Usage:** `glassEffect` and `#available(iOS 26.0, *)` guards were used in `Ferrite/Extensions/View.swift`, which are non-existent in the target environment.

### Fixes Applied
- Removed all references to `SelectedDebridFilterView.swift` from `Ferrite.xcodeproj/project.pbxproj`.
- Updated `swiftui-introspect` requirement to `1.2.1` in `Ferrite.xcodeproj/project.pbxproj`.
- Updated `SWIFT_VERSION` to `5.8` across all build configurations in `project.pbxproj`.
- Refactored `liquidGlass` in `Ferrite/Extensions/View.swift` to use native `.thinMaterial` and remove invalid availability guards/API calls.
