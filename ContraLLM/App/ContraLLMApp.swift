//
//  ContraLLMApp.swift
//  ContraLLM
//

import SwiftUI
import SwiftData

@main
struct ContraLLMApp: App {
    let modelContainer: ModelContainer
    @AppStorage(AppStorageKey.themeMode) private var themeModeRaw: String = AppThemeMode.system.rawValue

    init() {
        self.modelContainer = PersistenceController.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    PersistenceController.seedIfNeeded(context: modelContainer.mainContext)
                }
                .preferredColorScheme((AppThemeMode(rawValue: themeModeRaw) ?? .system).colorScheme)
        }
        .modelContainer(modelContainer)
    }
}
