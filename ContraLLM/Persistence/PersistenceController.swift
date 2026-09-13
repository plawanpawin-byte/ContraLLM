//
//  PersistenceController.swift
//  ContraLLM
//
//  Wraps the SwiftData ModelContainer used to persist Workspaces in Library.
//

import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([Workspace.self])

    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Fall back to an in-memory store so the app never fails to launch,
            // even if the on-disk store is unavailable or incompatible.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallback]))
                ?? fatalErrorContainer()
        }
    }

    private static func fatalErrorContainer() -> ModelContainer {
        fatalError("Unable to create ModelContainer for ContraLLM.")
    }

    /// Seeds a demo workspace on first launch so Library is never empty and
    /// the app can be demoed without adding a source manually.
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let defaultsKey = "com.contra.llm.didSeedDemoWorkspace"
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }
        UserDefaults.standard.set(true, forKey: defaultsKey)

        let source = SourceItem(type: .pdf, displayName: "Attention Is All You Need.pdf")
        let workspace = Workspace(
            title: "Understanding Transformer Architecture",
            sourceDisplayName: source.displayName,
            sourceType: source.type
        )
        workspace.notebookData = try? JSONEncoder().encode(MockContent.notebookBlocks(for: source))
        workspace.slidesData = try? JSONEncoder().encode(MockContent.slides(for: source))
        workspace.chatHistoryData = try? JSONEncoder().encode(MockContent.sampleConversation(title: workspace.title))

        context.insert(workspace)
        try? context.save()
    }
}
