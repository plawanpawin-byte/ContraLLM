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
}

protocol DocumentProcessingService {
    func process(source: SourceItem) async throws -> ProcessedContent
}
