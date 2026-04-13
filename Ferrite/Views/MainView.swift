//
//  MainView.swift
//  Ferrite
//
//  Created by Brian Dashore on 7/11/22.
//

import SwiftUI
import Combine
import UIKit


struct MainView: View {
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var logManager: LoggingManager
    @EnvironmentObject var debridManager: DebridManager
    @EnvironmentObject var scrapingModel: ScrapingViewModel
    @EnvironmentObject var backupManager: BackupManager
    @EnvironmentObject var pluginManager: PluginManager

    @AppStorage("Updates.AutomaticNotifs") var autoUpdateNotifs = true


    @State private var showUpdateAlert = false

    @State private var releaseVersionString: String = ""

    @State private var releaseUrlString: String = ""

    // Observe keyboard so the bottom tab bar can move out of the way
    @StateObject private var keyboard = KeyboardObserver()

    var body: some View {

        ZStack(alignment: .bottom) {
            TabView(selection: $navModel.selectedTab) {
                ContentView()
                    .tag(NavigationViewModel.ViewTab.search)

                LibraryView()
                    .tag(NavigationViewModel.ViewTab.library)


                AddView()

                    .tag(NavigationViewModel.ViewTab.add)



                SettingsView()
                    .tag(NavigationViewModel.ViewTab.settings)
             }

            .toolbar(.hidden, for: .tabBar)




            GlassTabBarView(selection: $navModel.selectedTab)

                .padding(.horizontal, DesignTokens.TabBar.horizontalPadding)

                .padding(.bottom, DesignTokens.TabBar.bottomPadding)

                .frame(height: DesignTokens.TabBar.height)

                // Hide tab bar when keyboard is visible or when scrolling down
                .opacity((keyboard.isVisible || navModel.isTabBarHidden) ? 0 : 1)
                .offset(y: (keyboard.isVisible || navModel.isTabBarHidden) ? 100 : 0)
                .animation(.easeOut(duration: 0.25), value: keyboard.isVisible || navModel.isTabBarHidden)

        }

        .sheet(item: $navModel.currentChoiceSheet) { item in
            switch item {
            case .action:
                ActionChoiceView()
            case .batch:
                BatchChoiceView()
            case .activity:
                ShareSheet(activityItems: navModel.activityItems)
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            logManager.info("Ferrite started")
        }
        .task {
            if
                autoUpdateNotifs,
                Application.shared.osVersion.toString() >= Application.shared.minVersion
            {
                // MARK: If scope bar duplication happens, this may be the problem

                // Sleep for 2 seconds to allow for view layout and app init
                try? await Task.sleep(seconds: 2)

                do {
                    guard let latestRelease = try await Github().fetchLatestRelease() else {
                        logManager.error(
                            "Github: No releases found",
                            description: "Github error: No releases found"
                        )
                        return
                    }

                    let releaseVersion = String(latestRelease.tagName.dropFirst())
                    if releaseVersion > Application.shared.appVersion {
                        releaseVersionString = latestRelease.tagName
                        releaseUrlString = latestRelease.htmlUrl

                        logManager.info("Update available to \(releaseVersionString)")
                        showUpdateAlert.toggle()
                    }
                } catch {
                    let error = error as NSError

                    if error.code == -1009 {
                        logManager.info(
                            "Github: The connection is offline",
                            description: "The connection is offline"
                        )
                    } else {
                        logManager.error(
                            "Github: \(error)",
                            description: "A Github error was logged"
                        )
                    }
                }

                logManager.info("Github release updates checked")
            }
        }
        .onOpenURL { url in
            if url.scheme == "file" {
                if url.pathExtension.lowercased() == "torrent" {
                    navModel.pendingTorrentUrls = [url]
                    navModel.selectedTab = .add
                    return
                }

                // Attempt to copy to backups directory if backup doesn't exist
                backupManager.copyBackup(backupUrl: url)

                backupManager.showRestoreAlert.toggle()
            } else if url.scheme == "magnet" {
                // Handle magnet:// URLs
                navModel.pendingMagnetLink = url.absoluteString
                navModel.selectedTab = .add
            }
        }
        // Global alerts and dialogs for backups
        .confirmationDialog(
            "Restore backup?",
            isPresented: $backupManager.showRestoreAlert,
            titleVisibility: .visible
        ) {
            Button("Merge", role: .destructive) {
                Task {
                    await backupManager.restoreBackup(pluginManager: pluginManager, doOverwrite: false)
                }
            }
            Button("Overwrite", role: .destructive) {
                Task {
                    await backupManager.restoreBackup(pluginManager: pluginManager, doOverwrite: true)
                }
            }
        } message: {
            Text(
                "Merge (preferred): Will merge your current data with the backup \n\n" +
                    "Overwrite: Will delete and replace all your data \n\n" +
                    "If Merge causes app instability, uninstall Ferrite and use the Overwrite option."
            )
        }
        .alert("Backup restored", isPresented: $backupManager.showRestoreCompletedAlert) {
            Button("OK", role: .cancel) {
                backupManager.restoreCompletedMessage = []
            }
        } message: {
            Text(backupManager.restoreCompletedMessage.joined(separator: " \n\n"))
        }
        // Updater alert
        .alert("Update available", isPresented: $showUpdateAlert) {
            Button("Download") {
                guard let releaseUrl = URL(string: releaseUrlString) else {
                    return
                }

                UIApplication.shared.open(releaseUrl)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Ferrite \(releaseVersionString) can be downloaded. \n\n" +
                    "This alert can be disabled in Settings."
            )
        }
        .overlay {
            VStack {
                Spacer()
                if logManager.showToast {
                    Group {
                        switch logManager.toastType {
                        case .info:
                            Text(logManager.toastDescription ?? "This shouldn't be showing up... Contact the dev!")
                        case .warn:
                            Text("Warn: \(logManager.toastDescription ?? "This shouldn't be showing up... Contact the dev!")")
                        case .error:
                            Text("Error: \(logManager.toastDescription ?? "This shouldn't be showing up... Contact the dev!")")
                        }
                    }
                    .padding(12)
                    .font(.caption)
                    .liquidGlassToast()
                }

                if logManager.showIndeterminateToast {
                    VStack {
                        Text(logManager.indeterminateToastDescription ?? "Loading...")
                            .lineLimit(1)

                        HStack {
                            IndeterminateProgressView()

                            if let cancelAction = logManager.indeterminateCancelAction {
                                Button("Cancel") {
                                    cancelAction()
                                    logManager.hideIndeterminateToast()
                                }
                            }
                        }
                    }
                    .padding(12)
                    .font(.caption)
                    .liquidGlassToast()
                    .frame(width: 200)

                                }




                                Rectangle()

                                    .foregroundColor(.clear)

                                    .frame(height: 60)
                            }


            .animation(.easeInOut(duration: 0.3), value: logManager.showToast || logManager.showIndeterminateToast)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
//

// MARK: - Workaround for missing project references
// The following types are defined here because their source files are missing
// from the Xcode project configuration, causing compilation failures.


/// Centralized design tokens for the Ferrite app.
///
/// Use these tokens to keep spacing, corner radii, shadows, and sizes consistent
/// across the codebase. Avoid hard-coded numbers in views; reference these tokens instead.
enum DesignTokens {
    enum Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
    }

    enum CornerRadius {
        static let micro: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let pill: CGFloat = 999 // use for capsule-like shapes
    }

    enum Stroke {
        /// Very thin subtle stroke useful for glass outlines.
        static let ultraThin: CGFloat = 0.5
        /// Standard outline width.
        static let thin: CGFloat = 1.0
    }

    enum Shadow {
        static let subtle = ShadowSpec(radius: 2, y: 1, color: Color.black.opacity(0.02))
        static let medium = ShadowSpec(radius: 4, y: 2, color: Color.black.opacity(0.04))
        static let prominent = ShadowSpec(radius: 8, y: 4, color: Color.black.opacity(0.06))

        struct ShadowSpec {
            let radius: CGFloat
            let y: CGFloat
            let color: Color
        }
    }

    enum TabBar {
        /// Smaller height for the tab bar (reduced from 56)
        static let height: CGFloat = 44
        /// Even more compact height when keyboard visible
        static let compactHeight: CGFloat = 40
        /// Tighter horizontal padding to keep bar closer to edges
        static let horizontalPadding: CGFloat = 8
        /// Minimal bottom padding to keep bar closer to screen edge
        static let bottomPadding: CGFloat = 4
        static let cornerRadius: CGFloat = CornerRadius.medium
    }

    enum Sizes {
        static let iconSmall: CGFloat = 14
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 28

        static let progressHeight: CGFloat = 6
        static let rowVerticalPadding: CGFloat = 10
    }

    enum Typography {
        // Use the system text styles which automatically scale with Dynamic Type.
        static var largeTitle: Font { .largeTitle }
        static var title: Font { .title }
        static var title2: Font { .title2 }
        static var headline: Font { .headline }
        static var body: Font { .body }
        static var callout: Font { .callout }
        static var caption: Font { .caption }

        // Convenience helper to return a scaled SwiftUI Font with weight
        static func scaled(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
            // Prefer the built-in text style so SwiftUI dynamic type scaling is preserved.
            switch textStyle {
            case .largeTitle: return .system(.largeTitle, design: .default).weight(weight)
            case .title: return .system(.title, design: .default).weight(weight)
            case .title2: return .system(.title2, design: .default).weight(weight)
            case .headline: return .system(.headline, design: .default).weight(weight)
            case .body: return .system(.body, design: .default).weight(weight)
            case .callout: return .system(.callout, design: .default).weight(weight)
            case .subheadline: return .system(.subheadline, design: .default).weight(weight)
            case .caption: return .system(.caption, design: .default).weight(weight)
            case .caption2: return .system(.caption2, design: .default).weight(weight)
            default: return .system(.body, design: .default).weight(weight)
            }
        }
    }

    // MARK: - Helpful view modifiers and helpers

    /// Apply a subtle card background style with material, stroke and shadow.
    static func cardBackground<R: Shape>(cornerRadius: CGFloat = CornerRadius.medium) -> some ViewModifier {
        CardBackgroundModifier(cornerRadius: cornerRadius)
    }

    private struct CardBackgroundModifier: ViewModifier {
        var cornerRadius: CGFloat

        func body(content: Content) -> some View {
            content
                .padding(Spacing.small)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.primary.opacity(0.04), lineWidth: Stroke.ultraThin))
                .shadow(color: Shadow.subtle.color, radius: Shadow.subtle.radius, x: 0, y: Shadow.subtle.y)
        }
    }
}


/// Observes global keyboard notifications and publishes the current keyboard height and visibility.
/// - Publishes `height` which is the keyboard's vertical size (0 when hidden).
/// - Publishes `isVisible` which is true when keyboard is shown.
final class KeyboardObserver: ObservableObject {
    /// Current keyboard height in points (0 when hidden).
    @Published public private(set) var height: CGFloat = 0

    /// Whether the keyboard is visible.
    @Published public private(set) var isVisible: Bool = false

    private var cancellables = Set<AnyCancellable>()

    /// Initialize and start observing keyboard notifications.
    init() {
        // keyboardWillShow -> produce height and duration
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo }
            .map { info -> (height: CGFloat, duration: Double, curve: UInt) in
                let frame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
                let height = frame.height
                let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                let curve = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 0
                return (height: height, duration: duration, curve: curve)
            }

        // keyboardWillHide -> emit zero height
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> (height: CGFloat, duration: Double, curve: UInt) in
                (height: 0, duration: 0.25, curve: 0)
            }

        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] info in
                guard let self = self else { return }
                // Animate updates to match keyboard animation timing for smoother UI adjustments
                // Use UIView animation curve if available for close match to system animation
                let animationOptions: UIView.AnimationOptions
                if info.curve != 0 {
                    animationOptions = UIView.AnimationOptions(rawValue: info.curve << 16)
                } else {
                    animationOptions = [.curveEaseOut]
                }

                UIView.animate(withDuration: info.duration, delay: 0, options: animationOptions, animations: {
                    self.height = info.height
                    self.isVisible = info.height > 0
                }, completion: nil)
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
