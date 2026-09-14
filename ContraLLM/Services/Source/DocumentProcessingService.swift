//
//  DocumentProcessingService.swift
//  ContraLLM
//
//  Provider-independent abstraction for extracting and understanding content
//  from an imported source (PDF parsing, transcript fetch, web scraping, ...).
//

import Foundation

struct ProcessedContent {
    let notebook: [NotebookBlock]
    let slides: [Slide]
    /// Plain-text extracted from the source, if any was available. Stored on
    /// the resulting Workspace so later AI chat calls can ground answers in
    /// the real source instead of just its title.
    var sourceText: String? = nil
}

protocol DocumentProcessingService {
    func process(source: SourceItem) async throws -> ProcessedContent
}
