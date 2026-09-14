//
//  Workspace.swift
//  ContraLLM
//
//  A Workspace is created once a Source has been analyzed. It is the container
//  for the four learning experiences: Voice, Podcast, Slides, Notebook.
//

import Foundation
import SwiftData

@Model
final class Workspace {
    @Attribute(.unique) var id: UUID
    var title: String
    var sourceDisplayName: String
    var sourceTypeRaw: String
    var createdAt: Date

    // Serialized payloads for the generated learning formats.
    // Stored as JSON-encoded Data so the model stays simple for SwiftData.
    var notebookData: Data?
    var slidesData: Data?
    var podcastData: Data?
    var chatHistoryData: Data?
    /// Plain-text content extracted from the source (PDF/text/website), used
    /// to ground real AI chat/processing calls. Capped in length. Absent for
    /// sources where extraction wasn't possible (e.g. YouTube, audio).
    var sourceTextData: Data?

    var sourceText: String? {
        get { sourceTextData.flatMap { String(data: $0, encoding: .utf8) } }
        set { sourceTextData = newValue?.data(using: .utf8) }
    }

    var sourceType: SourceType {
        SourceType(rawValue: sourceTypeRaw) ?? .text
    }

    init(
        id: UUID = UUID(),
        title: String,
        sourceDisplayName: String,
        sourceType: SourceType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.sourceDisplayName = sourceDisplayName
        self.sourceTypeRaw = sourceType.rawValue
        self.createdAt = createdAt
    }

    /// Which of the 4 learning formats currently have generated content.
    var availableOutputs: [String] {
        var outputs: [String] = []
        if notebookData != nil { outputs.append("Notebook") }
        if slidesData != nil { outputs.append("Slides") }
        if podcastData != nil { outputs.append("Podcast") }
        outputs.append("Voice") // Voice is always available (live chat)
        return outputs
    }
}
