//
//  EmbeddingService.swift
//  ContraLLM
//
//  Abstraction for turning source text into vector embeddings for retrieval.
//  Not exercised by the V1 UI yet, but the interface is in place so a
//  production backend (or on-device model) can be dropped in later.
//

import Foundation

protocol EmbeddingService {
    func embed(text: String) async throws -> [Double]
}
