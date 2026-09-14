//
//  BackendAIChatService.swift
//  ContraLLM
//
//  Real AIChatService implementation that calls the Contra backend
//  (see backend/worker), which in turn calls Anthropic. Activated whenever
//  Settings → AI → "Use demo AI provider" is off. Falls back to the mock
//  provider's behavior is handled by ServiceContainer, not here — this type
//  only knows how to talk to the backend.
//

import Foundation

final class BackendAIChatService: AIChatService {
    private let client: BackendAPIClient

    init(configuration: APIConfiguration) {
        self.client = BackendAPIClient(configuration: configuration)
    }

    func generateWorkspaceTitle(from source: SourceItem) async throws -> String {
        struct Req: Encodable { let sourceName: String; let sourceType: String; let sourceText: String? }
        struct Res: Decodable { let title: String }

        let res: Res = try await client.post(
            path: "/v1/title",
            body: Req(sourceName: source.displayName, sourceType: source.type.rawValue, sourceText: nil)
        )
        return res.title
    }

    func send(message: String, workspace: Workspace) async throws -> AIMessage {
        struct HistoryTurn: Encodable { let role: String; let text: String }
        struct Req: Encodable {
            let workspaceTitle: String
            let sourceName: String
            let sourceText: String?
            let history: [HistoryTurn]
            let message: String
        }
        struct Res: Decodable { let text: String; let bullets: [String]; let followUps: [String] }

        let history: [HistoryTurn] = decodeChatHistory(workspace)
            .suffix(8)
            .map { HistoryTurn(role: $0.role == .user ? "user" : "assistant", text: $0.text) }

        let res: Res = try await client.post(
            path: "/v1/chat",
            body: Req(
                workspaceTitle: workspace.title,
                sourceName: workspace.sourceDisplayName,
                sourceText: workspace.sourceText,
                history: history,
                message: message
            )
        )

        return AIMessage(
            role: .assistant,
            text: res.text,
            bulletPoints: res.bullets,
            citations: workspace.sourceText != nil
                ? [AICitation(label: workspace.sourceDisplayName, detail: "Source")]
                : [],
            suggestedFollowUps: res.followUps
        )
    }

    private func decodeChatHistory(_ workspace: Workspace) -> [AIMessage] {
        guard let data = workspace.chatHistoryData,
              let messages = try? JSONDecoder().decode([AIMessage].self, from: data) else {
            return []
        }
        return messages
    }
}
