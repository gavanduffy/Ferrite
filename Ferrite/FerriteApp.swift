//
//  FerriteApp.swift
//  Ferrite
//
//  Created by Brian Dashore on 7/1/22.
//

import SwiftUI

@main
struct FerriteApp: App {
    init() {
        let oldKey = "Behavior.DisableRequestTimeout"
        let newKey = "Behavior.EnableRequestTimeout"

        if UserDefaults.standard.object(forKey: oldKey) != nil {
            let oldValue = UserDefaults.standard.bool(forKey: oldKey)
            UserDefaults.standard.set(!oldValue, forKey: newKey)
            UserDefaults.standard.removeObject(forKey: oldKey)
        }
    }

    let persistenceController = PersistenceController.shared

    @StateObject var scrapingModel: ScrapingViewModel = .init()
    @StateObject var logManager: LoggingManager = .init()
    @StateObject var debridManager: DebridManager = .init()
    @StateObject var navModel: NavigationViewModel = .init()
    @StateObject var pluginManager: PluginManager = .init()
    @StateObject var backupManager: BackupManager = .init()

    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    scrapingModel.logManager = logManager
                    debridManager.logManager = logManager
                    pluginManager.logManager = logManager
                    backupManager.logManager = logManager
                    navModel.logManager = logManager
                }
                .environmentObject(debridManager)
                .environmentObject(scrapingModel)
                .environmentObject(logManager)
                .environmentObject(navModel)
                .environmentObject(pluginManager)
                .environmentObject(backupManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
