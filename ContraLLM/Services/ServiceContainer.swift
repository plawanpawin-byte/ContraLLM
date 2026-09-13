//
//  ServiceContainer.swift
//  ContraLLM
//
//  Single place that wires concrete service implementations to the protocols
//  the rest of the app depends on. Today everything resolves to the Mock/*
//  demo providers so the app is fully usable without a backend. Swap any
//  property here for a production implementation without touching call sites.
//

import Foundation

@MainActor
final class ServiceContainer {
    static let shared = ServiceContainer()

    let aiChatService: AIChatService
    let podcastService: PodcastService
    let documentProcessingService: DocumentProcessingService
    let speechToTextService: SpeechToTextService
    let textToSpeechService: TextToSpeechService

    private init() {
        // Wire mock/demo providers by default. A production backend can be
        // swapped in here based on APIConfigurationStore.shared.configuration.
        self.aiChatService = MockAIChatService()
        self.podcastService = MockPodcastService()
        self.documentProcessingService = MockDocumentProcessingService()
        self.speechToTextService = MockSpeechToTextService()
        self.textToSpeechService = MockTextToSpeechService()
    }
}
