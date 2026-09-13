//
//  SourceItem.swift
//  ContraLLM
//
//  Represents a single piece of content the user has imported (a file or a URL).
//

import Foundation

enum SourceType: String, Codable, CaseIterable {
    case pdf
    case document
    case text
    case website
    case youtube
    case googleDocs
    case audio

    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .document: return "Document"
        case .text: return "Text"
        case .website: return "Website"
        case .youtube: return "YouTube"
        case .googleDocs: return "Google Docs"
        case .audio: return "Audio"
        }
    }

    var symbolName: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .document: return "doc.text"
        case .text: return "text.alignleft"
        case .website: return "globe"
        case .youtube: return "play.rectangle.fill"
        case .googleDocs: return "doc.badge.gearshape"
        case .audio: return "waveform"
        }
    }
}

struct SourceItem: Identifiable, Codable, Hashable {
    let id: UUID
    let type: SourceType
    let displayName: String
    let localURL: URL?
    let remoteURL: URL?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        type: SourceType,
        displayName: String,
        localURL: URL? = nil,
        remoteURL: URL? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.displayName = displayName
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.createdAt = createdAt
    }
}

// MARK: - URL Classification

enum SourceURLClassifier {
    /// Inspects a raw URL string and determines the most appropriate SourceType.
    static func classify(_ rawValue: String) -> SourceType? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased(),
              trimmed.lowercased().hasPrefix("http") else {
            return nil
        }

        if host.contains("youtube.com") || host.contains("youtu.be") {
            return .youtube
        }
        if host.contains("docs.google.com") {
            return .googleDocs
        }
        return .website
    }

    static func isLikelyURL(_ rawValue: String) -> Bool {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
    }
}
