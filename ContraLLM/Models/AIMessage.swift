//
//  AIMessage.swift
//  ContraLLM
//
//  Represents a single turn in a conversation with the AI, used across
//  Voice, and any Ask-AI prompt bar (Podcast, Slides, Notebook).
//

import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct AICitation: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let label: String
    let detail: String?
}

struct AIMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let role: MessageRole
    var text: String
    var bulletPoints: [String]
    var citations: [AICitation]
    var suggestedFollowUps: [String]
    let createdAt: Date
    var isLoading: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        bulletPoints: [String] = [],
        citations: [AICitation] = [],
        suggestedFollowUps: [String] = [],
        createdAt: Date = Date(),
        isLoading: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.bulletPoints = bulletPoints
        self.citations = citations
        self.suggestedFollowUps = suggestedFollowUps
        self.createdAt = createdAt
        self.isLoading = isLoading
    }
}
