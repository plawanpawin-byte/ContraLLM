//
//  MockAIChatService.swift
//  ContraLLM
//
//  Demo/offline implementation of AIChatService. Lets the entire app be used
//  without any backend or API key configured. Swap for a production
//  implementation that calls the Contra backend once available.
//

import Foundation

final class MockAIChatService: AIChatService {

    func generateWorkspaceTitle(from source: SourceItem, sourceText: String?) async throws -> String {
        try await Task.sleep(nanoseconds: 400_000_000)

        let name = source.displayName
            .replacingOccurrences(of: ".pdf", with: "")
            .replacingOccurrences(of: ".txt", with: "")
            .replacingOccurrences(of: ".mp3", with: "")
            .replacingOccurrences(of: ".wav", with: "")
            .replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        switch source.type {
        case .youtube:
            return "How Modern LLM Inference Works"
        case .googleDocs:
            return "Notes on \(capitalizedWords(name))"
        case .website:
            return "Exploring \(capitalizedWords(name))"
        case .audio:
            return "Understanding \(capitalizedWords(name))"
        case .pdf, .document, .text:
            return "Understanding \(capitalizedWords(name))"
        }
    }

    func send(message: String, workspace: Workspace) async throws -> AIMessage {
        try await Task.sleep(nanoseconds: 700_000_000)

        let lower = message.lowercased()
        let text: String
        let bullets: [String]
        let followUps: [String]

        if lower.contains("summar") {
            text = "Summary of \"\(workspace.title)\": the source lays out a core problem, introduces a mechanism to solve it, and shows why that mechanism generalizes well beyond the original example."
            bullets = ["Core problem the source addresses", "The mechanism it introduces to solve it", "Why the idea generalizes further"]
            followUps = ["What's the most important idea?", "Explain this in simple terms"]
        } else if lower.contains("simple") {
            text = "In simple terms, \"\(workspace.title)\" breaks down a complex idea into a few core building blocks that work together."
            bullets = ["The source introduces a core problem", "It proposes a clear mechanism to solve it", "The result generalizes to many use cases"]
            followUps = ["What's the most important idea?", "Why does this matter?"]
        } else if lower.contains("important") {
            text = "The most important idea in this source is the central mechanism it introduces — everything else builds on top of it."
            bullets = []
            followUps = ["Can you explain this in simple terms?", "What are the key takeaways?"]
        } else if lower.contains("why") {
            text = "This matters because it changes how we approach the underlying problem, making solutions more efficient and more general."
            bullets = []
            followUps = ["What's the most important idea?", "Give me an example"]
        } else {
            text = "Here's a quick take based on \"\(workspace.sourceDisplayName)\": the source centers on \(workspace.title.lowercased()), and its key contribution is a reusable idea you can apply elsewhere."
            bullets = []
            followUps = ["Explain this in simple terms", "What's the most important idea?", "Why does this matter?"]
        }

        return AIMessage(
            role: .assistant,
            text: text,
            bulletPoints: bullets,
            citations: [AICitation(label: workspace.sourceDisplayName, detail: "Source")],
            suggestedFollowUps: followUps
        )
    }

    private func capitalizedWords(_ s: String) -> String {
        s.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
