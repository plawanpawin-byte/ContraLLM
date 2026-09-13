//
//  ContraLLMApp.swift
//  ContraLLM
//

import SwiftUI
import SwiftData

@main
struct ContraLLMApp: App {
    let modelContainer: ModelContainer

    init() {
        self.modelContainer = PersistenceController.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    PersistenceController.seedIfNeeded(context: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
