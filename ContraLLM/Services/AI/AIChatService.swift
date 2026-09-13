//
//  AIChatService.swift
//  ContraLLM
//
//  Provider-independent abstraction for conversational AI. Production
//  implementations (OpenAI, Anthropic, Gemini, OpenRouter, vLLM, Ollama, ...)
//  should call a backend/API gateway — never embed a provider key in-app.
//

import Foundation

protocol AIChatService {
    func send(message: String, workspace: Workspace) async throws -> AIMessage
    func generateWorkspaceTitle(from source: SourceItem) async throws -> String
}

enum AIServiceError: LocalizedError {
    case network
    case invalidResponse
    case rateLimited
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .network: return "Couldn't reach the AI service. Check your connection and try again."
        case .invalidResponse: return "The AI returned an unexpected response."
        case .rateLimited: return "Too many requests right now. Please wait a moment and try again."
        case .unauthorized: return "This workspace isn't configured with a valid backend connection."
        }
    }
}
