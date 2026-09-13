//
//  Slide.swift
//  ContraLLM
//

import Foundation

struct Slide: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let title: String
    let body: String
    let keyPoints: [String]
    let quote: String?
    let symbolName: String
    let hasCitation: Bool
}
