//
//  SpeechToTextService.swift
//  ContraLLM
//
//  Provider-independent abstraction for converting spoken audio into text.
//  A production implementation might wrap Apple's Speech framework, Whisper,
//  or a backend streaming endpoint.
//

import Foundation

protocol SpeechToTextService {
    /// Starts listening and returns the finalized transcript once the
    /// caller stops recording.
    func startListening() async throws
    func stopListening() async throws -> String
    var isListening: Bool { get }
}
