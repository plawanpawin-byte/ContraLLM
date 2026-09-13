//
//  ProcessingViewModel.swift
//  ContraLLM
//
//  Drives the Processing screen's animated step progression, then produces a
//  fully-formed Workspace (title + notebook + slides) from a SourceItem.
//

import Foundation

@MainActor
final class ProcessingViewModel: ObservableObject {
    enum State: Equatable {
        case running
        case failed(String)
        case done
    }

    @Published private(set) var activeStepIndex: Int = 0
    @Published private(set) var state: State = .running
    @Published private(set) var resultWorkspace: Workspace?

    let steps: [ProcessingStep] = [
        ProcessingStep(title: "Reading source"),
        ProcessingStep(title: "Extracting content"),
        ProcessingStep(title: "Understanding key ideas"),
        ProcessingStep(title: "Creating your workspace"),
        ProcessingStep(title: "Creating learning formats")
    ]

    private let source: SourceItem
    private let aiChatService: AIChatService
    private let documentProcessingService: DocumentProcessingService

    init(
        source: SourceItem,
        aiChatService: AIChatService = ServiceContainer.shared.aiChatService,
        documentProcessingService: DocumentProcessingService = ServiceContainer.shared.documentProcessingService
    ) {
        self.source = source
        self.aiChatService = aiChatService
        self.documentProcessingService = documentProcessingService
    }

    func start() {
        Task { await run() }
    }

    private func run() async {
        state = .running
        activeStepIndex = 0
        do {
            try await advance() // Reading source
            let content = try await documentProcessingService.process(source: source)
            try await advance() // Extracting content
            try await advance() // Understanding key ideas
            let title = try await aiChatService.generateWorkspaceTitle(from: source)
            try await advance() // Creating your workspace

            let workspace = Workspace(title: title, sourceDisplayName: source.displayName, sourceType: source.type)
            workspace.notebookData = try? JSONEncoder().encode(content.notebook)
            workspace.slidesData = try? JSONEncoder().encode(content.slides)

            try await advance() // Creating learning formats

            resultWorkspace = workspace
            state = .done
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func advance() async throws {
        try await Task.sleep(nanoseconds: 550_000_000)
        if activeStepIndex < steps.count - 1 {
            activeStepIndex += 1
        }
    }

    func retry() {
        Task { await run() }
    }
}
