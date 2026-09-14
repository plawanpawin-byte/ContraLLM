//
//  ChatViewModel.swift
//  ContraLLM
//
//  Reusable conversational state for any surface with an Ask-AI prompt bar
//  (Voice, Podcast, Slides, Notebook). Conversations persist to the
//  Workspace (workspace.chatHistoryData) after every exchange, and are
//  restored from there on init — so re-opening a workspace continues the
//  same conversation instead of starting over, and the backend AI (which
//  reads that same history) has real memory of everything discussed before.
//

import Foundation
import SwiftData

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [AIMessage]
    @Published var isSending = false
    @Published var errorMessage: String?

    private let workspace: Workspace
    private let aiChatService: AIChatService
    /// Set after init via attachModelContext(_:) — @Environment isn't
    /// available yet inside a View's own init(), so callers grab it in
    /// onAppear instead of passing it through the initializer.
    private var modelContext: ModelContext?

    init(
        workspace: Workspace,
        initialMessages: [AIMessage] = [],
        aiChatService: AIChatService? = nil
    ) {
        self.workspace = workspace
        self.aiChatService = aiChatService ?? ServiceContainer.shared.aiChatService

        if let data = workspace.chatHistoryData,
           let saved = try? JSONDecoder().decode([AIMessage].self, from: data),
           !saved.isEmpty {
            // Continue the real conversation instead of re-showing the canned intro.
            self.messages = saved
        } else {
            self.messages = initialMessages
        }
    }

    func attachModelContext(_ context: ModelContext) {
        modelContext = context
    }

    func send(_ text: String, contextPrefix: String? = nil) {
        let userMessage = AIMessage(role: .user, text: text)
        messages.append(userMessage)

        let loadingMessage = AIMessage(role: .assistant, text: "", isLoading: true)
        messages.append(loadingMessage)
        isSending = true
        errorMessage = nil

        Task {
            do {
                let prompt = contextPrefix.map { "\($0): \(text)" } ?? text
                let response = try await aiChatService.send(message: prompt, workspace: workspace)
                messages.removeAll { $0.id == loadingMessage.id }
                messages.append(response)
                persist()
            } catch {
                messages.removeAll { $0.id == loadingMessage.id }
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    /// Saves the conversation onto the workspace so the AI remembers it next
    /// time (BackendAIChatService reads workspace.chatHistoryData for
    /// context) and so it survives app relaunches.
    private func persist() {
        workspace.chatHistoryData = try? JSONEncoder().encode(messages)
        try? modelContext?.save()
    }
}
