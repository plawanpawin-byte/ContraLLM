//
//  MockSpeechServices.swift
//  ContraLLM
//
//  Demo implementations of SpeechToTextService / TextToSpeechService so the
//  Voice experience works fully offline. Production builds can swap these for
//  Apple's Speech framework / AVSpeechSynthesizer or a backend provider.
//

import Foundation

final class MockSpeechToTextService: SpeechToTextService {
    private(set) var isListening: Bool = false

    func startListening() async throws {
        isListening = true
    }

    func stopListening() async throws -> String {
        isListening = false
        try await Task.sleep(nanoseconds: 300_000_000)
        return "What's the most important idea here?"
    }
}

final class MockTextToSpeechService: TextToSpeechService {
    func synthesize(text: String, voice: VoiceProfile) async throws -> URL {
        try await Task.sleep(nanoseconds: 300_000_000)
        // No real audio file in mock mode; callers should treat nil-content
        // gracefully. We return a placeholder file URL in the caches directory.
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("mock-tts-\(UUID().uuidString).caf")
    }
}
