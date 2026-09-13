//
//  NotebookBlock.swift
//  ContraLLM
//
//  Notebook content model. A Notebook is a sequence of typed blocks that get
//  rendered with distinct visual treatment (see NotebookBlockView).
//

import Foundation

enum NotebookBlockKind: String, Codable {
    case heading
    case paragraph
    case keyIdea
    case definition
    case quote
    case highlight
    case citation
    case researchFinding
    case importantPoint
    case question
    case aiSummary
}

/// A styled run of text inside a notebook block, allowing selective
/// bold / underline / highlight / accent-color treatment inline.
struct InlineSpan: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let text: String
    var bold: Bool = false
    var underline: Bool = false
    var highlighted: Bool = false
    var accent: Bool = false
}

struct NotebookBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let kind: NotebookBlockKind
    /// Plain fallback text (used when spans is empty).
    let text: String
    /// Optional rich inline spans for selective styling.
    var spans: [InlineSpan] = []
    /// Optional secondary text, e.g. definition term, citation source.
    var caption: String? = nil
}
