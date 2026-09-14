//
//  ChatViewModel.swift
//  ContraLLM
//
//  Reusable conversational state for any surface with an Ask-AI prompt bar
//  (Voice, Podcast, Slides, Notebook).
//

import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [AIMessage]
    @Published var isSending = false
    @Published var errorMessage: String?

    private let workspace: Workspace
    private let aiChatService: AIChatService

    init(
        workspace: Workspace,
        initialMessages: [AIMessage] = [],
        aiChatService: AIChatService? = nil
    ) {
        self.workspace = workspace
        self.messages = initialMessages
        self.aiChatService = aiChatService ?? ServiceContainer.shared.aiChatService
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
            } catch {
                messages.removeAll { $0.id == loadingMessage.id }
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}
